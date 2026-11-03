# KubeKey 4.x Kubernetes 生产部署与运维手册

> **文档版本**：1.0  
> **整理日期**：2026-11-03  
> **目标**：使用 KubeKey 4.x 快速部署、长期维护原生 Kubernetes 集群；优先保证升级可控、扩缩容方便、故障可恢复。  
> **部署基线**：Ubuntu 24.04 LTS、3 Control Plane + 2 Worker、containerd、Calico、3 节点 etcd、KubeKey CLI。  
> **说明**：以下所有 `192.168.50.x`、`api.k8s.internal`、SSH 用户和磁盘规格均为**示例值**，执行前必须替换。本手册是部署模板，未在你的实际服务器和网络上执行安装或验证。

---

## 目录

1. [方案总览与版本策略](#1-方案总览与版本策略)
2. [架构及资源规划](#2-架构及资源规划)
3. [部署前检查](#3-部署前检查)
4. [安装 KubeKey 4.x](#4-安装-kubekey-4x)
5. [生成 Inventory 与集群配置](#5-生成-inventory-与集群配置)
6. [部署 Kubernetes](#6-部署-kubernetes)
7. [集群验收](#7-集群验收)
8. [Ingress、存储与基础组件](#8-ingress存储与基础组件)
9. [日常运维与扩缩容](#9-日常运维与扩缩容)
10. [版本升级标准流程](#10-版本升级标准流程)
11. [etcd 备份与灾难恢复](#11-etcd-备份与灾难恢复)
12. [监控、告警及安全](#12-监控告警及安全)
13. [故障排查](#13-故障排查)
14. [单节点快速测试](#14-单节点快速测试)
15. [GitLab 变更管理和上线清单](#15-gitlab-变更管理和上线清单)
16. [官方参考资料](#16-官方参考资料)

---

## 1. 方案总览与版本策略

### 1.1 选择 KubeKey 的原因

- 通过 `kk` CLI 管理 Kubernetes 集群创建、增删节点及版本升级，无须单独维护 Ansible 控制端。
- 通过 `Inventory` 定义主机，通过 `Config` 定义集群参数，便于保存在 GitLab 中做审计与回滚对比。
- 支持在线与离线部署；但离线包、操作系统依赖包及私有镜像仓库仍须事先准备。
- 可以部署**原生 Kubernetes**，不强制安装 KubeSphere 或 Sealos Cloud。

### 1.2 固定版本（示例基线）

| 项目 | 建议 | 说明 |
|---|---|---|
| KubeKey | **v4.0.7** | 本文固定的、可查到 SHA-256 的官方正式版本；不使用动态 latest |
| Kubernetes | **v1.36.5（已核实的受支持版本）** | 上游发布记录显示 2026-09-15 发布；实际安装时需再次核对是否有更新补丁及镜像可用性 |
| Ubuntu | 24.04 LTS | 统一操作系统及内核；避免生产节点随意混用发行版 |
| containerd | 由 KubeKey 管理 | 不在安装前单独混装 Docker/kubelet/kubeadm |
| CNI | Calico | 常规 Java 微服务场景，初期不引入多 CNI |
| etcd | external 模式，部署于 3 个 Master | 这里的 external 是 KubeKey 的独立 etcd 服务部署模式，并不要求额外购买 3 台机器 |
| API HA | KubeKey 集成的 kube-vip，ARP 模式 | **仅适合底层网络允许 VIP 漂移/ARP 广播的场景** |

> 截至整理日期，GitHub Release 页面可见 v4.0.8，但 v4.0.7 仍被标为 `Latest`。为使文档可重现，这里明确锁定 v4.0.7；若准备采用 v4.0.8，请先更新版本、校验值和兼容性测试记录，**不要混用不同版本文档/安装产物**。

> Kubernetes `v1.36.5` 是已在 Kubernetes 官方发布记录中核实的有效补丁版本（截至资料检索，2026-09-15 发布，v1.36 分支计划支持至 2027-06-28）。**Kubernetes v1.34 已在 2026-10-27 结束支持，不适合作为本次新建生产集群的基线。** 如果安装当天已有新的 v1.36 安全补丁，应优先评估新补丁；部署前验证 KubeKey v4.0.7、镜像源、Calico 和 containerd 版本。

---

## 2. 架构及资源规划

### 2.1 推荐拓扑

```text
                 运维机 / GitLab CI（不必是集群节点）
                              │ SSH / kubectl
                              ▼
               api.k8s.internal:6443
                        │
                kube-vip: 192.168.50.10
                        │
      ┌─────────────────┼────────────────────┐
      │                 │                    │
    cp-01             cp-02                cp-03
  192.168.50.11     192.168.50.12        192.168.50.13
  apiserver         apiserver            apiserver
  etcd              etcd                 etcd
      └─────────────────┬────────────────────┘
                        │ Kubernetes 控制平面
           ┌────────────┴────────────┐
           │                         │
      worker-01                 worker-02
    192.168.50.21             192.168.50.22
   Java / Nacos / CI          Java / Nacos / CI
```

> 3 个 Master 与 3 个 etcd 成员可承受**一个** etcd/Master 成员故障；2 个 Worker 不能单独保证有状态业务高可用，仍需要副本数、反亲和、PDB、存储多副本和备份。

### 2.2 节点资源建议

| 节点 | 示例 IP | 角色 | CPU | 内存 | 系统磁盘 | 容器数据磁盘 |
|---|---|---|---:|---:|---:|---:|
| cp-01 | 192.168.50.11 | Control Plane + etcd | 8C | 16G | 200G | 200G |
| cp-02 | 192.168.50.12 | Control Plane + etcd | 8C | 16G | 200G | 200G |
| cp-03 | 192.168.50.13 | Control Plane + etcd | 8C | 16G | 200G | 200G |
| worker-01 | 192.168.50.21 | Worker | 8C | 16G | 200G | 200G |
| worker-02 | 192.168.50.22 | Worker | 8C | 16G | 200G | 200G |

这些是相对宽裕的生产起点，并非 Kubernetes 的最低资源要求。etcd 数据建议使用低延迟 SSD，避免在负载过高或 IO 抖动明显的卷上运行。Nacos、数据库和 CI Runner 的 CPU/内存/IO 需要单独容量评估。

### 2.3 网络规划

| 项目 | 示例值 | 要求 |
|---|---|---|
| Node 网段 | `192.168.50.0/24` | 节点 IP 固定、可互通 |
| API VIP | `192.168.50.10` | 未被其他设备使用，允许主节点间漂移 |
| API DNS | `api.k8s.internal` | 从每台节点和运维机稳定解析至 VIP |
| Pod CIDR | `10.233.64.0/18` | 不得与机房路由、VPC、VPN、其他集群冲突 |
| Service CIDR | `10.233.0.0/18` | 不得与 Pod / Node / 企业现有网段重叠 |
| Service NodePort | `30000-32767/TCP,UDP` | 仅在需要时开放，不对公网全量暴露 |
| SSH | `22/TCP` | 仅允许运维机 -> 集群节点 |
| API Server | `6443/TCP` | 仅开放给节点和授权管理网络 |
| etcd | `2379-2380/TCP` | 仅 etcd/Control Plane 成员互访 |
| kubelet | `10250/TCP` | 控制平面到节点，严格限制来源 |
| Calico | 按封装模式开启 IPIP（IP 协议 4）或 VXLAN（UDP 4789），BGP 使用 TCP 179 | **以实际 Calico 模式为准**，无需全部开启 |

**注意**：ARP 模式的 kube-vip 依赖二层网络广播能力。一些云虚拟网络、跨网段主机或禁止 VIP/ARP 漂移的交换环境不支持。遇到这种情况改用**独立高可用四层负载均衡器**，并调整 `control_plane_endpoint`，不要直接照搬 kube-vip 示例。

---

## 3. 部署前检查

### 3.1 所有节点的基础准备

在**五台节点**分别执行。若已有运维基线，请按现有标准处理，避免脚本覆盖安全配置。

```bash
# Ubuntu 24.04 LTS
cat /etc/os-release
uname -r
hostnamectl
ip -br addr
lsblk -f
df -h
free -h

sudo apt-get update
sudo apt-get install -y \
  sudo curl wget tar openssl ca-certificates \
  socat conntrack ipset ebtables chrony ipvsadm \
  vim jq dnsutils

sudo systemctl enable --now chrony
chronyc tracking
timedatectl

# 检查 swap；生产环境推荐禁用 swap 以减少 kubelet 兼容性问题
swapon --show
sudo swapoff -a
# 手工检查 /etc/fstab 并注释 swap 挂载行，确保重启后不恢复。
# 不建议直接用宽泛的 sed 命令修改所有配置。
```

建议将 `/var/lib/containerd` 与 etcd 数据目录 `/var/lib/etcd` 的容量及 IO 纳入监控。若有独立磁盘，应在安装 KubeKey **之前**完成分区、文件系统和挂载，并记录 UUID 到 `/etc/fstab`。**不要对已有数据盘执行格式化命令。**

### 3.2 主机名、时间、DNS

每台节点设置唯一主机名，例如：

```bash
# 仅在 cp-01 上执行，其余节点换成自身名称
sudo hostnamectl set-hostname cp-01
```

确保节点间主机名可互相解析，并配置 `api.k8s.internal -> 192.168.50.10` 的内网 DNS 记录；没有内部 DNS 时也可在每台节点和运维机的 `/etc/hosts` 中维护：

```text
192.168.50.10 api.k8s.internal
192.168.50.11 cp-01
192.168.50.12 cp-02
192.168.50.13 cp-03
192.168.50.21 worker-01
192.168.50.22 worker-02
```

```bash
getent hosts api.k8s.internal
getent hosts cp-02
ping -c 2 cp-02
```

VIP 只有在 kube-vip 部署后才应应答；安装前 `ping 192.168.50.10` 不通并不自动代表 DNS 失败。

### 3.3 SSH 免密

在**独立运维机**或临时安装机上：

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C kubekey-ops
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.50.11
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.50.12
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.50.13
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.50.21
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.50.22

ssh -o BatchMode=yes root@192.168.50.11 'hostname && id'
```

若安全策略禁用 root SSH，请改为具备 `sudo` 权限的专用部署用户，并参考官方连接器文档设置提权；**不要在 GitLab 仓库里保存 SSH 密码或私钥**。安装前还要确认节点能访问所需软件下载站和容器镜像仓库。

### 3.4 部署前核对清单

- [ ] 五台主机系统时间一致，节点互通，DNS 有效。
- [ ] SSH 密钥可连通五台主机，安装账号有足够权限。
- [ ] `swapoff` 已处理并验证重启后仍符合要求。
- [ ] 预留 Pod/Service CIDR，与公司网络无冲突。
- [ ] VIP 未被其他设备使用；ARP/VIP 漂移得到网络团队确认。
- [ ] 持久化存储方案明确；NFS/CSI 不要与 etcd 数据盘混淆。
- [ ] 防火墙遵循最小开放原则，未直接向公网暴露 etcd 和 kubelet。

---

## 4. 安装 KubeKey 4.x

### 4.1 生产推荐：固定发布包并校验 SHA-256

以下以 **Linux amd64、KubeKey v4.0.7** 为例；ARM64 必须下载对应的 ARM64 文件并替换校验值。

```bash
sudo mkdir -p /opt/kubekey/v4.0.7
sudo chown "$(id -un):$(id -gn)" /opt/kubekey/v4.0.7
cd /opt/kubekey/v4.0.7

curl -fL --retry 3 -o kk.tar.gz \
  https://github.com/kubesphere/kubekey/releases/download/v4.0.7/kubekey-v4.0.7-linux-amd64.tar.gz

# 此校验值来自该版本 GitHub Releases 页面；下载不匹配必须停止
printf '%s  %s\n' \
  '712f81d4a4e2ba79c834c3837017688c875bd1e110b150e30fafde2f5246241f' \
  kk.tar.gz | sha256sum -c -

tar -tzf kk.tar.gz | head -30
tar -xzf kk.tar.gz

# 不同发布包的目录布局可能不同，先确认 kk 的实际路径
find . -type f -name kk -print
# 如果发现 ./kk：
./kk version
```

> 如果解压后的二进制不是 `./kk`，下文的 `./kk` 改为上一步 `find` 找到的真实路径，或将文件安装至受控的 `/usr/local/bin/kk`。不要在未验证包内容前盲目覆盖系统二进制。

### 4.2 快速下载（仅适合试验）

```bash
mkdir -p ~/kubekey-test && cd ~/kubekey-test
curl -sfL https://get-kk.kubesphere.io | \
  SKIP_WEB_INSTALLER=true SKIP_PACKAGE=true sh -
./kk version
```

生产环境优先使用 **4.1 节固定版本**，不要使用自动更新的 `latest` 下载脚本。

---

## 5. 生成 Inventory 与集群配置

> **特别重要：KubeKey 4.x 使用 `Inventory` + `Config` 两个资源文件，不能直接照抄 KubeKey 3.x 的 `Cluster/v1alpha2` 配置。**

### 5.1 先生成默认文件

在 KubeKey 工作目录：

```bash
./kk create inventory -o .
./kk create config --with-kubernetes v1.36.5 -o .

ls -l inventory.yaml config-v1.36.5.yaml
cp inventory.yaml inventory.yaml.orig
cp config-v1.36.5.yaml config-v1.36.5.yaml.orig
```

**推荐修改 KubeKey 自动生成的文件**，保留其他默认字段。下述示例为**需要填写的关键字段的完整 YAML 示例**，不保证覆盖所有环境定制项目；正式安装时与生成文件对比、校验。

### 5.2 `inventory.yaml`（3 Master + 2 Worker）

```yaml
apiVersion: kubekey.kubesphere.io/v1
kind: Inventory
metadata:
  name: default
spec:
  hosts:
    cp-01:
      connector:
        type: ssh
        host: 192.168.50.11
        port: 22
        user: root
        private_key: /root/.ssh/id_ed25519
      internal_ipv4: 192.168.50.11
    cp-02:
      connector:
        type: ssh
        host: 192.168.50.12
        port: 22
        user: root
        private_key: /root/.ssh/id_ed25519
      internal_ipv4: 192.168.50.12
    cp-03:
      connector:
        type: ssh
        host: 192.168.50.13
        port: 22
        user: root
        private_key: /root/.ssh/id_ed25519
      internal_ipv4: 192.168.50.13
    worker-01:
      connector:
        type: ssh
        host: 192.168.50.21
        port: 22
        user: root
        private_key: /root/.ssh/id_ed25519
      internal_ipv4: 192.168.50.21
    worker-02:
      connector:
        type: ssh
        host: 192.168.50.22
        port: 22
        user: root
        private_key: /root/.ssh/id_ed25519
      internal_ipv4: 192.168.50.22
  groups:
    k8s_cluster:
      groups:
        - kube_control_plane
        - kube_worker
    kube_control_plane:
      hosts:
        - cp-01
        - cp-02
        - cp-03
    kube_worker:
      hosts:
        - worker-01
        - worker-02
    etcd:
      hosts:
        - cp-01
        - cp-02
        - cp-03
```

- `spec.hosts` 是 SSH 连接配置；`spec.groups` 是角色归属。
- `etcd` 组映射到三个 Master，用于 KubeKey `etcd.deployment_type: external` 的部署方式。
- `private_key` 是**运行 KubeKey 的机器**上的私钥路径。请确认 KubeKey 实际执行账号能够读取对应文件；若使用非 root 账号，不能原样照搬 `/root/.ssh`。

### 5.3 `config-v1.36.5.yaml` 关键配置

以下表示合并进 `spec` 下的关键字段。建议在 `kk create config` 生成的文件里**逐项修改同名字段**，避免直接丢弃自动生成的组件版本参数。

```yaml
apiVersion: kubekey.kubesphere.io/v1
kind: Config
spec:
  # 国内下载困难时可改为 cn，并确认目标版本可在对应源取得
  zone: ""

  kubernetes:
    cluster_name: prod-k8s
    kube_version: v1.36.5
    apiserver:
      port: 6443
      certSANs:
        - api.k8s.internal
        - 192.168.50.10
    control_plane_endpoint:
      host: api.k8s.internal
      port: 6443
      type: kube-vip
      kube_vip:
        # API VIP；必须是保留且未被占用的地址
        address: 192.168.50.10
        mode: ARP
        env:
          # 如果以后单独使用 MetalLB，避免 kube-vip 同时管理 Service VIP
          svc_enable: "false"

  # KubeKey 的 external etcd：独立 etcd 服务；成员可共置于 3 台 Master
  etcd:
    deployment_type: external
    backup:
      backup_dir: /var/lib/etcd-backup
      keep_backup_number: 24
      on_calendar: "*-*-* *:00/30:00"

  cri:
    container_manager: containerd
    cgroup_driver: systemd

  cni:
    type: calico
    pod_cidr: 10.233.64.0/18
    service_cidr: 10.233.0.0/18
    ipv4_mask_size: 24

  native:
    ntp:
      enabled: true
      servers:
        - pool.ntp.org
    timezone: Asia/Shanghai
```

**核对事项**：

1. `kubernetes.control_plane_endpoint.host` 配置的是稳定的 DNS 名称，DNS 必须指向 VIP；该地址同时需加入 API Server 证书 SAN。
2. `kube-vip` 的实际镜像版本、接口选择和 ARP 行为以 KubeKey v4.0.7 生成配置/模板为准；虚拟机及云平台须先验证 VIP 漂移。
3. `etcd.deployment_type=external` 对应 Inventory 的 `etcd` 节点组。**不要把 etcd 组配置成一个成员**却误认为具备 HA。
4. `native.ntp.servers` 应按实际网络改成公司内网时间源；`Asia/Shanghai` 为示例时区，可按实际要求修改。
5. 如果你已经有独立的 HAProxy/四层 LB，请将 `control_plane_endpoint` 改为官方 `local`/外部 LB 对应方式，**必须先部署并验证这个 LB**，不能仅在配置里填写地址。
6. Pod/Service CIDR 不应在集群运行后随意变更。

**配置验证**：

```bash
# 结构校验，只证明 YAML 格式可解析，不等于 KubeKey 的全部语义校验
python3 - <<'PY'
import yaml
for filename in ('inventory.yaml', 'config-v1.36.5.yaml'):
    with open(filename, encoding='utf-8') as f:
        doc = yaml.safe_load(f)
    assert doc['apiVersion'] == 'kubekey.kubesphere.io/v1'
    print(filename, doc['kind'])
PY

# 如未安装 PyYAML：python3 -m pip install pyyaml（建议在虚拟环境中）
./kk create cluster --help
```

> 执行前应对生成配置与上述关键字段进行人工审查，`create cluster --help` 用于确认 CLI 参数，**不会对整个集群进行预检或部署**。

---

## 6. 部署 Kubernetes

### 6.1 在线安装

在运维机的 KubeKey 工作目录执行：

```bash
./kk create cluster \
  -i inventory.yaml \
  -c config-v1.36.5.yaml
```

KubeKey 会进行基础检查、软件下载、节点初始化及 Kubernetes/etcd/CNI 安装。完成时间受机器配置和网络影响。

### 6.2 首次安装后配置 kubectl

在 `cp-01` 上检查：

```bash
sudo test -f /etc/kubernetes/admin.conf && echo 'kubeconfig exists'
sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes -o wide
```

如需要给运维账号使用 `kubectl`：

```bash
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
chmod 600 ~/.kube/config
kubectl get nodes -o wide
```

**注意**：`admin.conf` 通常包含集群管理员凭据，不能直接提交 GitLab 或通过公共聊天工具发送。生产应为人员和 CI 创建最小权限身份，而不是长期共享管理员 kubeconfig。

### 6.3 关键检查

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get deployments,statefulsets,daemonsets -A
kubectl get --raw='/readyz?verbose'

# 运维机应能通过 VIP/DNS 访问 API
getent hosts api.k8s.internal
curl -k --connect-timeout 5 https://api.k8s.internal:6443/readyz
```

未经身份认证时，`curl` 返回 401/403 也可证明 HTTPS API 端口可达；需用带认证的 `kubectl get --raw` 判断业务 API 健康。`curl -k` 仅用于网络排错，**不应用于生产客户端长期绕过证书校验**。

---

## 7. 集群验收

### 7.1 验收判定

- 5 个节点均 `Ready`；控制平面机器正确标注角色。
- CoreDNS、Calico、kube-proxy（或实际替代方案）等系统 Pod 正常。
- Kubernetes API 通过 VIP/DNS 可以访问，API Server 证书 SAN 正确。
- 3 个 etcd 成员健康，Leader 正常；**只查 `kubectl get nodes` 不足以代表 etcd 健康**。
- 至少两台 Worker 可跨节点通信；Pod 能解析 Service DNS。
- 对存储类创建 PVC、写入数据、重新调度后完成恢复验证。
- 监控、证书提醒、etcd 备份与异机复制已启用。

### 7.2 DNS 与服务发现验证

```bash
kubectl -n default create deployment dns-test --image=busybox:1.36 -- sleep 3600
kubectl -n default rollout status deployment/dns-test --timeout=180s
kubectl -n default exec deploy/dns-test -- nslookup kubernetes.default.svc.cluster.local
kubectl -n default delete deployment dns-test
```

这里的测试镜像需能从相应镜像仓库拉取；失败时先区分镜像拉取和 DNS 故障。

### 7.3 HA 演练（维护窗口）

1. 验证三个 Master 和三个 etcd 成员都健康，做好最新快照。
2. 在网络及虚拟化团队确认后，**只**对一个 Master 进行有控制的重启/隔离测试。
3. 检查 VIP 是否漂移、API 是否恢复、其他 Master 和 Worker 是否正常。
4. 恢复被隔离节点，确认 etcd 三成员恢复健康后才执行下一次演练。

**禁止**第一次演练就同时关闭两台 Master：三成员 etcd 将失去多数派。

---

## 8. Ingress、存储与基础组件

### 8.1 推荐组件表

| 需求 | 选型建议 | 为什么 |
|---|---|---|
| 应用入口 | 支持 Gateway API 的控制器或现有 Ingress Controller | 避免入口方案与集群安装强绑定 |
| Service LoadBalancer | MetalLB（裸金属）或现有云 LB | 与 API VIP 地址池隔离 |
| 持久化存储 | 现有企业存储 CSI、Ceph CSI、Longhorn | 避免生产 StatefulSet 只依赖节点本地磁盘 |
| GitOps | Argo CD | GitLab 统一应用变更记录 |
| 包管理 | Helm | Nacos、Redis、监控组件安装更容易升级和回滚 |
| 监控 | kube-prometheus-stack | Prometheus/Grafana/Alertmanager/Exporters |
| 备份 | etcd 快照 + 业务 DB 备份 + Velero/CSI 快照 | **etcd 快照无法替代 PV/数据库备份** |

### 8.2 对 Nacos / Java 服务的建议

- Nacos 生产采用 3 副本，跨 Worker/故障域调度，并检查后端数据库的独立高可用。
- **只有 2 台 Worker** 时，3 个 Nacos Pod 不等于分布在 3 台故障独立主机；若要求严格三故障域，请增加第 3 台 Worker。
- 所有 Java 服务按实际压测结果设置 `requests/limits`、探针、优雅停止、PDB 和 Topology Spread。
- Redis/MySQL/PostgreSQL 是否运行于 Kubernetes，要独立评估存储故障域、备份、恢复时间目标（RTO）和恢复点目标（RPO）。
- GitLab Runner 的构建负载与在线业务隔离，建议专用 Runner 节点池、Namespace 和资源配额。

### 8.3 避免混淆两个 VIP/入口

- **API VIP `192.168.50.10:6443`**：供 kubelet、kubectl、控制平面组件访问 Kubernetes API。
- **应用 Ingress / Gateway 入口**：使用另一组独立 IP/DNS/负载均衡配置，不要随意复用 API VIP。

---

## 9. 日常运维与扩缩容

### 9.1 常用命令

```bash
# 节点及资源
kubectl get nodes -o wide
kubectl top nodes
kubectl top pods -A

# 工作负载与事件
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp | tail -60
kubectl describe node worker-01

# 日志
kubectl logs -n <namespace> <pod> --tail=200
journalctl -u kubelet -n 200 --no-pager
systemctl status containerd

# 磁盘与运行时
sudo crictl ps -a
sudo crictl images
df -h /var/lib/containerd /var/lib/etcd
```

`kubectl top` 需要 Metrics Server 或等效 metrics API 正常运行。

### 9.2 新增一个 Worker

先完成 OS、网络、时间、SSH 和磁盘初始化，再在 `inventory.yaml` 的 `spec.hosts` 新增：

```yaml
    worker-03:
      connector:
        type: ssh
        host: 192.168.50.23
        port: 22
        user: root
        private_key: /root/.ssh/id_ed25519
      internal_ipv4: 192.168.50.23
```

上述片段应放在 `spec.hosts` 下，不能放在 `spec.groups` 下。随后执行：

```bash
./kk add nodes \
  --worker worker-03 \
  -i inventory.yaml \
  -c config-v1.36.5.yaml \
  --override

kubectl get nodes -o wide
```

`--override` 会在成功后更新 Inventory，因此执行前先提交 Git、创建备份，之后复核 Git Diff 再提交新版本。也可先将节点加入 `kube_worker.hosts`，按官方分组方式扩容，不要两种模式混杂使用。新增 Master/etcd 需单独评估 etcd 成员数量与 API HA。

### 9.3 删除 Worker

```bash
# 先确认业务已迁移、PV/Local PV 风险已评估
kubectl cordon worker-03
kubectl drain worker-03 --ignore-daemonsets --delete-emptydir-data --timeout=10m

# 审核无误后，通过 KubeKey 删除节点
./kk delete nodes worker-03 \
  -i inventory.yaml \
  -c config-v1.36.5.yaml \
  --override

kubectl get nodes
```

`--delete-emptydir-data` **会丢弃相应 Pod 的临时数据**；如果存储使用 local PV，不能仅靠 drain 完成无损迁移。KubeKey 删除节点内部也会处理驱逐、集群节点清理等操作，执行前仍须确认数据和维护窗口。**删除 Master/etcd 的操作不要照搬 Worker 手册**，先计算多数派并制定替换方案。

### 9.4 Worker 维护

```bash
kubectl cordon worker-01
kubectl drain worker-01 --ignore-daemonsets --delete-emptydir-data --timeout=10m
# 执行 OS 更新和重启，等待 Node Ready
kubectl uncordon worker-01
kubectl get nodes -o wide
```

每次只维护一台 Worker，并确认应用 PDB、就绪探针和副本数允许驱逐；如果 PDB 阻止 drain，优先解决容量/副本问题，不要使用 `--disable-eviction` 强制绕过保护。

---

## 10. 版本升级标准流程

> **高风险注意事项：官方明确说明，KubeKey 4.x 的 `kk upgrade cluster` 会逐台升级控制平面，但 Worker 可能并行升级，且不会自动 `cordon/drain`。** 因此本手册**不承诺业务零中断**。对于需要严格不间断的生产业务，建议先引入临时 Worker 容量或设计额外迁移方案，测试后再执行。

### 10.1 升级前

1. 确定当前 KubeKey、Kubernetes、containerd、Calico、etcd 版本及目标版本兼容性。
2. 在预发集群演练，核对 Helm Chart、CSI、Ingress、Nacos、GitLab Runner 等兼容性。
3. 备份 `inventory.yaml`、`config-*.yaml`、KubeKey 工作目录、kubeconfig、etcd 数据和业务数据。
4. 检查 3 个 etcd 成员健康、无磁盘告警、API VIP 正常。
5. 检查 PDB、Pod 分布，提供可用的额外 Worker 容量，必要时安排业务维护窗口。
6. 升级涉及多 Kubernetes 次版本时，按 KubeKey 实际的升级路径与上游 kubeadm 支持策略逐级验证。

### 10.2 执行示例

以下是**演示命令**，不是本文件默认需要执行的升级目标；目标版本应按升级当日的官方兼容矩阵填写：

```bash
# 查看当前版本
kubectl version
./kk version

# 示例：将已部署的更低版本升级至 v1.36.5
./kk upgrade cluster \
  -i inventory.yaml \
  -c config.yaml \
  --with-kubernetes v1.36.5
```

- `--all` 会进一步升级相关组件（包括 etcd、CRI、CNI、StorageClass），**不要作为日常默认参数**。
- 可以通过 `--set upgrade.cni=true` 等参数单独控制；请先检查实际目标版本组合。
- 升级成功后，按照**最终实际版本**生成并保存新的 Config 文件，而不只是修改文件名。
- **不要在仅有两台 Worker 时，同时 drain 两台 Worker**；KubeKey 默认 Worker 并行升级也需在维护窗口内验证业务风险。

### 10.3 升级后

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get --raw='/readyz?verbose'
kubectl rollout status -n <namespace> deployment/<name> --timeout=180s
```

检查集群告警、DNS、服务入口、存储挂载和业务 smoke test。升级失败后不可简单执行 `kk delete cluster` 当作回滚；应依照故障类型选择修复、恢复 etcd 快照或重建集群。

---

## 11. etcd 备份与灾难恢复

### 11.1 备份策略

对生产建议：

- **etcd**：每 30 分钟保留快照，至少保留多份近期快照；按故障恢复目标增加频率。
- **异机/异地**：备份副本同步至独立备份服务或对象存储（开启加密与版本保护）。
- **PV/数据库**：独立进行数据库逻辑备份、WAL/binlog/物理备份及 CSI/存储快照。
- **验证**：每季度在隔离测试环境做一次完整 etcd 恢复演练；每日检查备份成功与文件可读。

KubeKey Config 中的示例：

```yaml
spec:
  etcd:
    backup:
      backup_dir: /var/lib/etcd-backup
      keep_backup_number: 24
      on_calendar: "*-*-* *:00/30:00"
```

> 这只是 KubeKey 的备份参数，**必须现场确认备份任务实际创建并持续运行**。本地保留 24 份、每 30 分钟一次，相当于约 12 小时本地窗口；异机备份保留策略应单独配置。

### 11.2 检查备份产物

在 etcd 成员节点：

```bash
sudo ls -lah /var/lib/etcd-backup/
sudo find /var/lib/etcd-backup -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' | sort | tail -20
sudo systemctl list-timers --all | grep -i etcd || true
sudo journalctl --since '24 hours ago' | grep -iE 'etcd.*backup|backup.*etcd' | tail -40
```

先根据实际安装版本找到 `etcdctl` / `etcdutl`、证书路径、备份文件格式。推荐在具有相同工具版本的隔离机器进行快照校验：

```bash
# 将 /path/to/snapshot.db 换成真实存在的快照路径
etcdutl snapshot status /path/to/snapshot.db -w table
```

`etcdutl` 命令取决于实际 etcd 版本和工具安装方式。若只有 `etcdctl`，应参考该版本的官方快照文档，**不要假定所有版本命令一致**。

### 11.3 灾难恢复原则

1. 冻结写入与运维变更，确认是否为单节点故障、etcd 失去多数派或全部状态不可恢复。
2. 从**可信备份**选择恢复点，记录快照版本、文件校验和及预期 RPO。
3. 备份现有数据目录及证书，不要对仍在工作的 etcd 成员直接覆盖 `/var/lib/etcd`。
4. 在隔离环境演练 `etcdutl snapshot restore`，根据当前 etcd 部署方式重建成员 ID、peer URL 和初始集群信息。
5. 恢复 API 后核验工作负载、PV、CRD、证书、CNI 及业务数据一致性；业务库可能还要独立恢复。

> **切勿把 `etcdutl snapshot restore` 简化成“把快照复制到三台 Master 然后重启服务”**。三节点 etcd 恢复涉及成员身份、引导配置与一致性，必须按当前部署拓扑的正式应急预案逐步操作。生产应急操作必须经过双人复核。

### 11.4 KubeKey 重要文件备份

务必保护 KubeKey 工作目录、PKI 证书、配置文件；尤其是官方所述的工作目录下 `kubekey/pki/root.crt`（按实际安装路径），它可能在后续节点扩容中使用。该目录可能包含私钥、令牌等敏感资料，应存于**加密且访问受控**的备份，不要上传到普通 Git 仓库。

另外，KubeKey 在创建/增加节点时可能备份 `/etc/kubernetes/kubeadm-config.yaml` 到 `/etc/kubekey/backup/kubernetes`。**这不是 etcd 快照**。

---

## 12. 监控、告警及安全

### 12.1 最少监控指标

| 类别 | 必须监控 |
|---|---|
| Node | CPU、内存、磁盘、inode、网络丢包、时间同步 |
| kubelet / containerd | Node Ready、Pod 重启、镜像拉取失败、容器运行时异常 |
| etcd | leader 数量、健康成员数、WAL fsync、DB 大小、空间配额、备份成功 |
| Kubernetes | API 请求错误率和延迟、Pod Pending、调度失败、CoreDNS 错误 |
| 业务 | Java JVM 内存、GC、线程、Hikari 连接池、Nacos 健康与 SQL 连接 |
| 证书 | API/etcd 相关证书到期时间 |
| 存储 | PV 使用率、容量、延迟、CSI 错误、快照/备份失败 |

### 12.2 安全基线

- API/SSH 仅允许授权网段访问，禁止直接将 etcd 端口暴露到公网。
- 运维人员使用 RBAC 和个人身份，CI/CD 使用独立 ServiceAccount/短期凭据。
- GitLab 配置仓库存放**非敏感**集群配置；SSH 私钥、CA 私钥、镜像仓库口令使用受控密钥管理系统。
- 开启 Kubernetes 审计日志及组件安全补丁管理；定期审查特权 Pod、hostPath、hostNetwork。
- 建议配置命名空间 ResourceQuota、LimitRange、Pod Security Admission，并根据业务设计 NetworkPolicy。
- 不要在生产环境图省事长期停用防火墙、关闭证书校验，或给所有运维账号集群管理员权限。

---

## 13. 故障排查

### 13.1 节点 NotReady

```bash
kubectl describe node worker-01
ssh root@192.168.50.21 'systemctl --no-pager status kubelet containerd'
ssh root@192.168.50.21 'journalctl -u kubelet -n 150 --no-pager'
```

检查系统时间、磁盘空间、runtime、DNS、CNI Pod、证书到期以及 API VIP 连通性。

### 13.2 Pod 无法通信

```bash
kubectl -n kube-system get pods -o wide
kubectl get pods -A -o wide
kubectl get networkpolicy -A
ip route
```

先确认 Calico DaemonSet、节点路由与防火墙的 IPIP/VXLAN/BGP 实际模式。`NetworkPolicy` 的存在可能导致目标端口不可访问，不应把所有连通性问题都归为 Ingress。

### 13.3 API VIP 无法访问

```bash
getent hosts api.k8s.internal
nc -vz api.k8s.internal 6443
kubectl get --raw=/readyz
```

- 检查 kube-vip 静态 Pod 与 Master API Server 进程状态。
- 检查交换网络是否允许 ARP/VIP 漂移以及 VIP 是否被占用。
- 若部署于不支持漂移的云网，迁移至真实四层 LB，不要仅修改 DNS。

### 13.4 etcd 异常

- 不要为了强制启动而随意删除 `/var/lib/etcd`。
- 优先确认多数派、磁盘写入时延、证书、端口 2379/2380 和最近备份。
- 单成员故障优先修复/替换该成员，恢复三成员健康后再考虑下一个成员。
- 多成员损坏或失去多数派进入 11.3 节灾备流程。

### 13.5 离线下载及镜像失败

```bash
# 在线环境若 GitHub 访问受限可尝试官方国内镜像模式
export KKZONE=cn
```

使用 `KKZONE=cn` 时注意可用的 Kubernetes 版本和组件可能受镜像源约束。离线安装**必须有针对实际 K8s、OS、CNI、CRI 构建的 artifact 包**，不能简单断网后重复在线安装命令。

---

## 14. 单节点快速测试

用于验证 KubeKey、K8s YAML、Helm、Nacos 部署流程；**不具备生产 HA**。

```bash
# 在已准备好的单台 Ubuntu 测试机上，以适当权限运行
mkdir -p ~/kubekey-single && cd ~/kubekey-single
curl -sfL https://get-kk.kubesphere.io | \
  SKIP_WEB_INSTALLER=true SKIP_PACKAGE=true sh -

./kk create cluster

kubectl get nodes -o wide
kubectl get pods -A
```

上述 `kk create cluster` 是官方简化安装入口，依赖默认版本和配置；如果要与生产保持严格一致，应改用第 5 节的 `Inventory/Config` 显式指定版本，并依照单节点网络/etcd 角色重新生成配置。**不要把生产的 3 Master kube-vip 配置原样复制到单节点**。

---

## 15. GitLab 变更管理和上线清单

### 15.1 推荐仓库目录

```text
k8s-infra/
├── README.md
├── clusters/
│   ├── prod/
│   │   ├── inventory.yaml
│   │   ├── config-v1.36.5.yaml
│   │   ├── versions.md
│   │   └── CHANGELOG.md
│   └── staging/
│       ├── inventory.yaml
│       └── config.yaml
├── manifests/
│   ├── monitoring/
│   ├── ingress/
│   ├── storage/
│   └── argocd/
├── scripts/
│   ├── preflight.sh
│   ├── healthcheck.sh
│   └── backup-verify.sh
└── runbooks/
    ├── upgrade.md
    ├── add-node.md
    ├── remove-node.md
    ├── etcd-recovery.md
    └── failover-test.md
```

建议初期使用手工变更审批执行 KubeKey：发起 MR → 审查 YAML/兼容矩阵 → 备份 → 在测试环境验证 → 维护窗口执行 → 检查 → 更新版本记录。**不要让每次 GitLab Push 自动触发生产 `kk create cluster`、`delete nodes` 或 `upgrade cluster`。**

### 15.2 上线前最终确认

- [ ] 使用固定版 KubeKey，可验证 SHA-256。
- [ ] 固定 Kubernetes 和组件版本，测试环境已验证同一套配置。
- [ ] 所有节点时间/存储/DNS/SSH/防火墙符合要求。
- [ ] API VIP 可漂移，或已替换为独立 HA LB。
- [ ] `inventory.yaml` 与 `config.yaml` 经审核，不含口令/私钥。
- [ ] 3 Master + 3 etcd 健康，2 Worker 均 Ready。
- [ ] CNI、CoreDNS、API、Pod 跨节点网络和 Service DNS 验证通过。
- [ ] 业务具备副本、反亲和、PDB、就绪与存活探针。
- [ ] 存储故障域与数据恢复方案已演练。
- [ ] etcd 备份定时成功，异机保存并验证可恢复。
- [ ] 证书、监控、日志、容量阈值与告警联系人已配置。
- [ ] 完成单 Master 故障演练并记录 RTO。
- [ ] 集群升级/扩容/节点替换流程已留存，明确负责人。

---

## 16. 官方参考资料

以下为主要一手参考，**尽量使用与安装工具相同的版本标签**进行核对，而不是直接套用不断变化的 `main` 分支：

1. KubeKey Releases：<https://github.com/kubesphere/kubekey/releases>
2. KubeKey v4.0.7 在线安装：<https://github.com/kubesphere/kubekey/blob/v4.0.7/docs/en/installation/online.md>
3. KubeKey v4.0.7 配置参考：<https://github.com/kubesphere/kubekey/blob/v4.0.7/docs/zh/reference/config.md>
4. KubeKey 节点扩容：<https://github.com/kubesphere/kubekey/blob/main/docs/en/installation/add-nodes.md>
5. KubeKey 节点删除：<https://github.com/kubesphere/kubekey/blob/main/docs/en/installation/delete-nodes.md>
6. KubeKey 集群升级：<https://github.com/kubesphere/kubekey/blob/main/docs/en/installation/upgrade-cluster.md>
7. KubeKey 离线部署：<https://github.com/kubesphere/kubekey/blob/main/docs/en/installation/offline.md>
8. Kubernetes 发布与维护周期：<https://kubernetes.io/releases/>；Kubernetes v1.36：<https://kubernetes.io/releases/1.36/>
9. etcd 恢复指南：<https://etcd.io/docs/>

---

**结论：** 对“少量自建生产集群、日常容易维护”的目标，推荐保留 **KubeKey CLI + GitLab 配置管理 + Prometheus/Grafana + Argo CD + 定期异机备份** 的最小技术栈。优先把 **API VIP、etcd 快照、扩缩容与升级规范** 做扎实，再按实际业务需要添加 Ingress、CSI、日志与安全平台。
