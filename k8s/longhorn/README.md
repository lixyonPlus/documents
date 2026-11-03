# Longhorn 三节点物理服务器 Kubernetes 生产部署手册

> 版本：1.0 ｜修订日期：2026-11-03  
> 适用：KubeKey 安装的 Kubernetes、3 台具备数据盘的物理节点、Longhorn **V1** 数据引擎  
> 目标：简单运维、三副本、独立 SSD、独立对象存储备份  
> 本文仅是可执行的实施模板；**尚未在你的集群实测**。所有占位符、设备路径、节点名称及版本必须先核对。

## 0. 交付文件

```text
longhorn-3node/
├── README.md                        # 本手册
├── values.yaml                      # Helm 安装配置
├── storageclass-longhorn-prod.yaml  # 三副本生产 StorageClass
├── smoke-test.yaml                  # PVC + Pod 数据持久性测试
└── node-check.sh                    # 仅读取数据的节点检查脚本
```

## 1. 推荐部署架构

```text
                    Kubernetes / KubeKey
                  ┌────────────────────────┐
                  │ Nacos / Nexus / DB 等  │
                  │ StatefulSet / PVC      │
                  └────────────┬───────────┘
                               │ CSI
                     StorageClass longhorn-prod
                               │ 3 同步副本
           ┌───────────────────┼────────────────────┐
           │                   │                    │
   worker-01              worker-02             worker-03
   10.0.10.11             10.0.10.12            10.0.10.13
   /var/lib/longhorn      /var/lib/longhorn     /var/lib/longhorn
   独立 SSD              独立 SSD              独立 SSD
           └───────────────────┼────────────────────┘
                               │
                      独立 S3 / MinIO 备份
```

上述地址是**示例**。3 节点需要各自独立故障域，并且三个节点都能运行 Longhorn 工作负载；Kubernetes 控制平面的高可用需要单独设计。**只有 3 个存储节点时，一台故障后可以继续使用剩余副本（需满足工作负载调度、卷健康及控制平面条件），但通常无法立即恢复到分布在 3 个不同节点上的 3 副本**。如需要故障后立即重建完整冗余，应预留第四个可用存储节点。

### 1.1 资源建议

| 项目 | 每节点参考 | 说明 |
| --- | --- | --- |
| CPU | 8 vCPU 或以上 | 含 K8s + 业务负载，非 Longhorn 独占 |
| 内存 | 16–32GiB 或以上 | 数据库负载较重则加大 |
| 系统盘 | 独立 SSD | 放置 OS、containerd、kubelet |
| 数据盘 | 独立 1–2TB 企业级 SSD/NVMe | 文件系统 ext4 或 XFS |
| 网络 | 优先 10GbE | 1GbE 可测试，写入和重建较慢 |
| 数据引擎 | V1 | 不启用 V2 的额外依赖 |
| 卷副本 | 3 | 每卷尽量分布在三台机器 |
| 备份 | 独立 S3 兼容存储 | 不要把唯一备份放在本 Longhorn 上 |

容量示例：3 × 1TB SSD = 3TB 原始容量；3 副本理论有效容量约 1TB，**不含**文件系统开销、空间预留、快照及恢复空间。为了降低风险，应用数据应显著低于理论容量上限。

### 1.2 版本选择（必须先执行）

```bash
kubectl version --client
kubectl version -o yaml | sed -n '/serverVersion:/,+8p'
kubectl get nodes -o wide
helm version
```

| Kubernetes 服务器版本 | 本文建议的 Longhorn 版本 | 备注 |
| --- | --- | --- |
| ≥ 1.34 | `1.13.0` | 按 1.13.0 **安装要求**选择；需再核对发行说明 |
| 1.25–1.33 | `1.12.1` | 按 1.12.1 **安装要求**选择；老的 K8s 版本应规划升级 |
| < 1.25 | 不使用本文部署命令 | 先升级集群并核对版本支持 |

**版本说明：** 官方 1.13.0 的安装页面写明 Kubernetes ≥1.34；其 Best Practices 页面同时出现不同的最低版本说明。为避免安装失败，本文以更严格的**安装要求页**为准。新装集群也应优先使用尚在维护期的 Kubernetes。不要把表中兼容性理解为每个旧 Kubernetes 小版本都仍受到上游维护。

下文用变量指定版本，在管理机上选择**一项**：

```bash
# 仅选择其中一个版本；不要不加核查直接复制两行
export LONGHORN_VERSION=1.13.0   # Kubernetes >=1.34
# export LONGHORN_VERSION=1.12.1 # Kubernetes 1.25–1.33
```

## 2. 先决条件与风险控制

1. 3 台节点均为 Linux，使用兼容的 containerd、内核、CNI，能互相解析及通信。
2. 三台机器都有**独立的数据盘**，挂载到 `/var/lib/longhorn`，且重启后自动挂载。
3. 物理机 RAID 控制器如支持 HBA/JBOD，优先让 Linux 直接看到磁盘；不要随意改动已经承载生产数据的 RAID 阵列。
4. 安装 `open-iscsi` 并启动 `iscsid`；需要 RWX 时安装 NFSv4 客户端。
5. DNS、容器镜像拉取、Pod 网络及节点时钟正常，CoreDNS 推荐至少两个副本。
6. 应为 Longhorn 的特权容器提供所需权限；若使用 Pod Security Admission 或 NetworkPolicy，须明确放行 Longhorn。
7. 下文的磁盘格式化操作**会清除磁盘上的所有原有数据**；禁止在尚未确认设备和备份时执行。

### 2.1 确认节点角色和污点

```bash
kubectl get nodes -o wide
kubectl describe node worker-01 | grep -A3 '^Taints:'
kubectl describe node worker-02 | grep -A3 '^Taints:'
kubectl describe node worker-03 | grep -A3 '^Taints:'
```

如果你的 3 台机器同时是 control-plane + worker，应确认 Longhorn 组件和应用 Pod 确实可以被调度。不要为了方便直接批量去掉全部 control-plane taint，应先明确 HA 与调度策略。

### 2.2 推荐节点网络检查

以下示例 IP 根据真实节点修改：

```bash
# 每个节点执行；确认三台之间低延迟、无丢包
ping -c 5 10.0.10.12
ping -c 5 10.0.10.13
ip -br addr
ip route
```

生产建议使用可靠的 10GbE 网络。无需仅因为存在第二张网卡就直接修改 Longhorn 的 `storageNetwork`：如果需要基于 Multus 的独立存储网络，应先完成 Multus、路由、MTU 和网络策略专项验证。最简方案先让 Longhorn 走稳定的 K8s 集群网络。

## 3. 三台物理机准备 Longhorn 数据盘

> 本节对 `worker-01`、`worker-02`、`worker-03` **逐台执行**，假设 Ubuntu Server 22.04/24.04；Debian 和 RHEL 系列请替换相应包管理命令。

### 3.1 安装依赖

```bash
sudo apt-get update
sudo apt-get install -y open-iscsi nfs-common cryptsetup util-linux e2fsprogs
sudo systemctl enable --now iscsid
sudo modprobe iscsi_tcp
sudo systemctl is-active iscsid
command -v iscsiadm
```

若启用了严格防火墙/NetworkPolicy，应参考 Longhorn 官方 networking 文档确认组件和各节点的连通性；不要在生产环境直接关闭全部防火墙。

### 3.2 查找正确的磁盘（只读）

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,UUID,MODEL
sudo blkid
sudo wipefs -n /dev/sdb          # 仅查看现有签名，不会清除
findmnt /var/lib/longhorn || true
ls -l /dev/disk/by-id/           # 推荐按稳定的 by-id 找设备
```

**重要：** 以下用 `/dev/disk/by-id/REPLACE_WITH_REAL_DISK_ID` 代指一块全新、无数据、未挂载的专用数据盘。它**不能**是系统盘、正在使用的 RAID 成员、LVM PV 或承载已有 Longhorn 副本的磁盘。

### 3.3 格式化数据盘（危险操作，确认后才执行）

```bash
# 严禁原样复制占位符。执行前请同时在 lsblk / blkid 中核对设备。
export LONGHORN_DISK='/dev/disk/by-id/REPLACE_WITH_REAL_DISK_ID'
readlink -f "$LONGHORN_DISK"
lsblk -f "$LONGHORN_DISK"
sudo wipefs -n "$LONGHORN_DISK"

# ⚠️ 仅新空盘：格式化会清除既有文件系统元数据及数据访问能力！
# sudo mkfs.ext4 -F -m 0 "$LONGHORN_DISK"
```

确认全部校验通过后，**人工取消最后一行注释**再执行。本文不提供自动擦盘脚本，避免误操作。生产环境更推荐先在变更单中记录磁盘序列号、型号和所属节点。

### 3.4 持久挂载

```bash
# 格式化后再执行；未格式化前 blkid 不一定有 UUID
sudo blkid "$LONGHORN_DISK"
export DISK_UUID="$(sudo blkid -s UUID -o value "$LONGHORN_DISK")"
test -n "$DISK_UUID"
sudo mkdir -p /var/lib/longhorn

# 先备份 fstab，再追加一次（避免重复写入）
sudo cp -a /etc/fstab "/etc/fstab.bak.$(date +%F-%H%M%S)"
echo "UUID=${DISK_UUID} /var/lib/longhorn ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
sudo mount -a
mountpoint /var/lib/longhorn
findmnt -no SOURCE,TARGET,FSTYPE /var/lib/longhorn
df -hT /var/lib/longhorn
```

**上线前必须进行一次重启后的挂载检查**。`nofail` 只是避免系统因盘缺失而卡住，并不能保护数据；如果磁盘挂载失败，Longhorn 有可能误把系统盘下的空目录当作数据目录。建议增加主机级监控：只有 `mountpoint -q /var/lib/longhorn` 成功才允许 Longhorn 使用该节点。

执行随包提供的只读检查脚本：

```bash
sudo bash node-check.sh
```

如果脚本提示 `ERROR: ... not a standalone mount point`，**先修复挂载，禁止继续安装**。

## 4. 标记三台存储节点

在可以执行 `kubectl` 的管理机上执行。把节点名改为你实际看到的名字：

```bash
for NODE in worker-01 worker-02 worker-03; do
  kubectl label node "$NODE" node.longhorn.io/create-default-disk=true --overwrite
  kubectl label node "$NODE" storage.longhorn.io/role=longhorn --overwrite
done

kubectl get nodes -L node.longhorn.io/create-default-disk -L storage.longhorn.io/role
```

`values.yaml` 会开启 `createDefaultDiskLabeledNodes: true`：**只有打了正确标签的节点**，Longhorn 才会自动创建 `/var/lib/longhorn` 默认数据盘。未打标签的新增节点不会被误纳入默认存储盘调度范围。此开关仅限制*默认盘创建*，**不是**限制所有 Longhorn Pod 的 NodeSelector。

务必再确认：这 3 台节点的 `/var/lib/longhorn` 是独立数据盘，且已经成功挂载。

## 5. Helm 安装 Longhorn

### 5.1 基础预检

```bash
kubectl get nodes -o wide
kubectl -n kube-system get deploy coredns
kubectl get storageclass
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm show values longhorn/longhorn --version "$LONGHORN_VERSION" > /tmp/longhorn-upstream-values.yaml
```

可额外使用官方 `longhornctl check preflight` 检查节点依赖（安装与命令示例按所选 Longhorn 版本的官方文档调整）。**不要使用 V2/SPDK 的 `--enable-spdk` 预检模式**，本文只用 V1。

### 5.2 了解安装配置

随包的 `values.yaml` 设置：

```yaml
persistence:
  defaultClass: false

defaultSettings:
  createDefaultDiskLabeledNodes: true
  defaultDataPath: /var/lib/longhorn/
  defaultReplicaCount: 3
  replicaSoftAntiAffinity: false
  replicaAutoBalance: disabled
  storageOverProvisioningPercentage: 100
  storageMinimalAvailablePercentage: 25
  storageReservedPercentageForDefaultDisk: 15
  defaultDataLocality: disabled
```

- 不把 Longhorn 直接设成全局默认 StorageClass，避免无意改变现有 PVC 行为；业务显式使用 `longhorn-prod`。
- `replicaSoftAntiAffinity: false` 表示尽量不把同卷的多个健康副本放同一节点。
- 100% 超售比例用于保守规划（但不意味着快照、扩容和写入一定不会耗尽空间）。
- `storageReservedPercentageForDefaultDisk: 15` 为建议值，按容量调整；`storageMinimalAvailablePercentage: 25` 预留调度空间。
- 若 chart 某参数的类型或名称发生变化，以**所选版本**的 `helm show values` 为准。

### 5.3 安装命令

```bash
helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --version "$LONGHORN_VERSION" \
  --values ./values.yaml \
  --wait --timeout 15m

kubectl -n longhorn-system get pods -o wide
kubectl -n longhorn-system get deploy,ds
kubectl get storageclass
```

成功标准：`longhorn-manager`、`longhorn-csi-plugin`、CSI 控制器、UI 等组件在各自期望副本上处于 Ready；3 台节点均出现在 Longhorn UI 的 Nodes 中，且具有可调度数据盘；**单靠 Helm release deployed 不能代表存储已经可用**。

### 5.4 管理界面（安全访问）

```bash
kubectl -n longhorn-system get svc longhorn-frontend
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80
```

在执行 port-forward 的本地机器打开 `http://127.0.0.1:8080`。请保持它绑定在本地回环地址，**不要直接公网暴露 UI**。需要多人管理时，使用企业 VPN/跳板机、HTTPS、身份认证及 NetworkPolicy。

检查 UI：**Node → Disks** 显示三台独立数据盘；**Volumes** 应先为空；检查磁盘 `Schedulable` 状态和可用容量。

## 6. 创建三副本 StorageClass

```bash
kubectl apply -f ./storageclass-longhorn-prod.yaml
kubectl get storageclass longhorn-prod -o yaml
```

配置：

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-prod
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
parameters:
  dataEngine: "v1"
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880"
  fsType: "ext4"
  dataLocality: "disabled"
```

生产数据使用 `Retain`，误删除 PVC 时不立即让 PV 和底层卷随之删除，但**后续重新绑定/回收仍需人工操作**，这不是备份机制。`ReadWriteOnce`（RWO）是一般数据库和 Nacos 等工作负载的常见模式；一个 RWO PVC 不意味着多个节点可以同时读写该块设备。若确需 RWX，请评估 Longhorn share-manager/NFSv4 的额外机制及故障处理。

在 Nacos、Nexus、PostgreSQL 的 StatefulSet 中设置 `storageClassName: longhorn-prod`；对数据库额外进行数据库级备份，Longhorn 备份不能替代数据库逻辑一致性策略。

## 7. 完整持久化验收测试

### 7.1 创建 2Gi PVC + 测试 Pod

```bash
kubectl apply -f ./smoke-test.yaml
kubectl -n longhorn-test get pvc,pods -o wide
kubectl -n longhorn-test wait --for=condition=Ready pod/longhorn-smoke --timeout=300s
```

如果 PVC 卡在 `Pending`，先使用 `kubectl describe pvc` 看调度原因，检查 3 台数据盘、镜像拉取和 Longhorn CSI 日志。

### 7.2 写入数据、记录校验值

```bash
kubectl -n longhorn-test exec longhorn-smoke -- sh -c \
  'date -u > /data/hello.txt && sha256sum /data/hello.txt'

kubectl -n longhorn-test exec longhorn-smoke -- \
  sha256sum /data/hello.txt
```

同时进入 Longhorn UI → Volumes → 对应 PV：确认 `Healthy` 和 **3/3 replicas**，并检查副本分布在 3 台不同物理节点。

### 7.3 删除测试 Pod，验证数据仍在

```bash
kubectl -n longhorn-test delete pod longhorn-smoke
# 因为此处是独立 Pod（不是 Deployment），需要重新 apply 以创建 Pod：
kubectl apply -f ./smoke-test.yaml
kubectl -n longhorn-test wait --for=condition=Ready pod/longhorn-smoke --timeout=300s
kubectl -n longhorn-test exec longhorn-smoke -- sha256sum /data/hello.txt
```

两次哈希应一致。使用 `kubectl get pv` 检查 `Retain` 的回收策略。

### 7.4 故障与维护模拟（只在测试窗口）

1. 先保证 Longhorn Volume `Healthy`，且 PVC 上已做一次成功备份。
2. 用 `kubectl -n longhorn-test get pod -o wide` 确认测试 Pod 所在节点。
3. 在维护窗口仅对**一台**节点执行 `kubectl cordon <node>`，再按官方维护流程做 `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --timeout=15m`；**这会驱逐同节点其他业务 Pod，生产集群不要未经审批执行**。
4. 观察 Pod 是否迁移及 PVC 是否重新 attach；观察卷 `Degraded` / `Healthy`，不得强行突破 PDB 或使用 `--force` 绕过风险检查。
5. 恢复节点后 `kubectl uncordon <node>`，待副本回到 3/3 Healthy 才开始下一台。

重要限制：3 存储节点刚好承载 3 副本，维护期间通常会降为 2/3，不能保证瞬时无中断切换；数据库应用恢复也取决于探针、Pod 策略和应用自身恢复机制。**不要同时维护两台**。

### 7.5 清理测试资源（会删除测试 PVC 请求，谨慎）

```bash
kubectl delete -f ./smoke-test.yaml
```

由于 StorageClass 采用 `Retain`，`PersistentVolume`/Longhorn 底层卷可能保留，后续要在 UI 中确认并**仅清理本次测试**的卷。**切勿批量删除其他 PV 或 Longhorn Volume**。

## 8. 配置外部 S3 / MinIO 备份

建议将备份桶部署在**独立系统**中，不要依赖同一套 Longhorn 卷。先在 S3 或 MinIO 创建专用桶、专用访问凭证和最小必要权限。建议启用 TLS，并妥善管理企业 CA。

### 8.1 创建访问密钥 Secret

在管理机创建仅当前管理员可读的临时文件（**不要提交 Git**）：

```bash
umask 077
cat > .longhorn-s3.env <<'EOF_S3'
AWS_ACCESS_KEY_ID=REPLACE_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=REPLACE_SECRET_KEY
AWS_ENDPOINTS=https://minio-backup.example.internal:9000
EOF_S3
chmod 600 .longhorn-s3.env
kubectl -n longhorn-system create secret generic longhorn-s3-credentials \
  --from-env-file=.longhorn-s3.env
# 验证 Secret 名称后，安全删除本地临时凭证文件
rm -f .longhorn-s3.env
```

`AWS_ENDPOINTS` 仅用于 S3 兼容服务如 MinIO；AWS S3 原生服务可省略。私有 CA 环境请按 Longhorn 官方备份配置文档为 Secret 配置正确的 CA 证书，**不要为了方便禁用 TLS 校验**。

### 8.2 在 UI 中绑定备份目标

到 Longhorn UI → **Backup and Restore → Backup Targets**，新增或编辑：

```text
Backup target URL:  s3://longhorn-backup@us-east-1/
Credential Secret: longhorn-s3-credentials
```

这里 `longhorn-backup` 是示例桶名，`us-east-1` 必须与你的 S3 实际设置兼容。地址末尾的 `/` 不可省略。检查 Backup Target 状态，无权限或证书错误时先修复而不是开始周期任务。

### 8.3 创建定时备份任务

在 **Recurring Jobs** 页面，建议从最简单的策略开始：

| 任务 | Cron 示例 | 保留策略 | 说明 |
| --- | --- | --- | --- |
| 快照 | `0 */6 * * *` | 保留近 12 次 | 快照依赖当前存储集群 |
| S3 备份 | `0 2 * * *` | 保留最近 7 次 | 需外部备份目标，检查时区 |
| 恢复演练 | 每月一次 | 人工执行 | 恢复到独立测试卷进行校验 |

把任务绑定到关键业务卷；不是只创建 Job 就会自动覆盖所有卷。数据库、Nacos 配置等关键业务还应制定数据库原生备份/一致性处理。快照和副本不等于异地备份。

## 9. 监控和日常维护

### 9.1 每日/每周巡检

```bash
kubectl get nodes -o wide
kubectl -n longhorn-system get pods -o wide
kubectl -n longhorn-system get volumes.longhorn.io
kubectl get pv,pvc -A
helm -n longhorn-system list
```

推荐告警范围：节点离线、数据盘不可调度、卷 Degraded/Faulted、Longhorn 组件异常、剩余空间不足、备份失败、单卷副本数量不足、Pod 反复重启、数据盘 SMART 错误以及 p95/p99 I/O 延迟异常。建议集成已有 Prometheus + Alertmanager；可参考官方 Longhorn 监控及告警示例。

### 9.2 故障处置原则

| 现象 | 首先检查 | 不应直接执行的操作 |
| --- | --- | --- |
| PVC Pending | `kubectl describe pvc`、CSI 日志、磁盘可调度性 | 反复删除 PVC |
| Volume Degraded | UI Replica 列表、坏盘/网络/节点状态 | 同时下线第二台节点 |
| Volume Faulted | 备份、健康副本与 UI 事件 | 手工删副本文件、强制恢复 |
| 卷无法挂载 | iSCSI、CSI、kubelet、Pod events | 直接删除 Longhorn 系统组件 |
| 磁盘容量紧张 | `df -hT`、快照、备份与实际写入量 | 直接删 `/var/lib/longhorn` 里的文件 |
| 数据盘丢失 | `findmnt`、UUID、SMART、主机日志 | 在系统盘目录重新生成数据副本 |

### 9.3 单节点维护

1. 确认所有卷有可用副本，并备份核心卷。
2. `kubectl cordon <node>`，再依官方流程 `kubectl drain ... --ignore-daemonsets`。
3. 如果 drain 被阻止，先看 `kubectl describe pod`、PDB、Longhorn UI：**不要使用 `--disable-eviction` 绕过保护**。
4. 重启或维护物理机，确认 `iscsid` 活跃、数据盘已经挂载。
5. `kubectl uncordon <node>`，等待所有核心卷副本重建并恢复 Healthy，才处理下一台。

### 9.4 升级 Longhorn

不得直接运行不带版本号的 `helm upgrade`。先阅读所选目标版本发布说明、升级路径、Kubernetes 兼容性和数据引擎限制。升级前：完成并验证备份、核对所有卷 Healthy、准备足够的空间与回滚/恢复计划。

示例（`NEW_VERSION` 需要人工批准）：

```bash
export NEW_VERSION='REPLACE_WITH_VERIFIED_VERSION'
helm repo update
helm diff upgrade longhorn longhorn/longhorn \
  -n longhorn-system --version "$NEW_VERSION" -f ./values.yaml

# 审核 diff 后在维护窗口执行：
# helm upgrade longhorn longhorn/longhorn \
#   -n longhorn-system --version "$NEW_VERSION" -f ./values.yaml \
#   --wait --timeout 20m
```

`helm diff` 需要单独安装 helm-diff 插件；如果没有该插件，可先运行 `helm template` 对照当前 release 的配置。**Kubernetes/Longhorn 版本升级不保证可安全 Helm rollback，尤其涉及 CRD 和数据格式时**；必须把备份恢复作为应急手段。

## 10. 生产上线验收清单

- [ ] Kubernetes Server 版本与所选 Longhorn 版本符合安装要求。
- [ ] 3 台节点及其应用调度角色确认无误，CoreDNS 至少 2 副本。
- [ ] 每台独立 SSD 已通过 `lsblk`、UUID、`findmnt` 和重启挂载检查。
- [ ] 每台 `iscsid` 正常，NFS 客户端按业务需要安装。
- [ ] 3 台节点的 `node.longhorn.io/create-default-disk=true` 标签正确。
- [ ] Longhorn System Pods 均 Ready；UI 可见 3 台可调度的数据盘。
- [ ] `longhorn-prod` 创建成功，测试 PVC Bound/Pod Ready。
- [ ] 测试卷 `Healthy`，3 个副本分布在不同物理机。
- [ ] Pod 重建后文件哈希一致；维护窗口完成单节点故障演练。
- [ ] 备份桶及权限正确，首次外部备份成功。
- [ ] 已进行至少一次“备份 → 独立恢复 → 校验”的恢复演练。
- [ ] 配置容量、卷健康、备份失败、SMART/节点离线告警。
- [ ] 记录磁盘序列号、网络拓扑、Longhorn 版本、备份位置及恢复手册。

## 11. 官方参考资料

- [Longhorn 文档主页](https://longhorn.io/docs/)
- [Longhorn v1.13.0 安装要求](https://longhorn.io/docs/1.13.0/deploy/install/)
- [Longhorn v1.12.1 安装要求](https://longhorn.io/docs/1.12.1/deploy/install/)
- [Helm 安装](https://longhorn.io/docs/1.13.0/deploy/install/install-with-helm/)
- [默认磁盘与节点标签](https://longhorn.io/docs/1.13.0/nodes-and-volumes/nodes/default-disk-and-node-config/)
- [StorageClass 参数](https://longhorn.io/docs/1.13.0/references/storage-class-parameters/)
- [备份目标配置](https://longhorn.io/docs/1.13.0/snapshots-and-backups/backup-and-restore/set-backup-target/)
- [周期性备份和快照](https://longhorn.io/docs/1.13.0/snapshots-and-backups/scheduling-backups-and-snapshots/)
- [节点维护](https://longhorn.io/docs/1.13.0/maintenance/maintenance/)
- [版本发布记录](https://github.com/longhorn/longhorn/releases)
