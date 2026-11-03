[KubeKey_Traefik_OpenObserve_20GB每日_部署与运维方案.md](https://github.com/user-attachments/files/34309850/KubeKey_Traefik_OpenObserve_20GB._.md)
# KubeKey + Traefik + OpenObserve 可观测性部署与运维手册

> **适用范围**：自建物理服务器 Kubernetes（KubeKey 4.x），3 Master + 2 Worker，Calico，Traefik 网关，Longhorn（可替换为符合要求的 CSI 存储）。  
> **容量基线**：每天约 **20 GB 原始容器日志**，日志保留 15 天，Trace 初期保留 7 天；允许 OpenObserve 短暂不可用。  
> **方案版本**：v1.0，2026-11-03。  
> **实施原则**：优先减少维护组件，指标告警与日志链路解耦；所有组件版本固定、所有敏感信息以 Kubernetes Secret 管理；上线前按文档验收。  
> **说明**：本文中的域名、StorageClass、VIP、节点规格都是示例；必须替换为实际参数。本手册是部署基线，不代表已经在你的集群中执行。

---

## 1. 架构结论

推荐采用 **OpenObserve Standalone + OpenTelemetry Collector + kube-prometheus-stack + Traefik**：

```text
                   Kubernetes 集群 (KubeKey / Calico)
 ┌────────────────────────────────────────────────────────────────┐
 │ Worker 1 / Worker 2 / 控制平面节点（视允许调度范围）           │
 │                                                                │
 │ Java Spring Boot -- Actuator/Micrometer --> Prometheus         │
 │          │                        Kubernetes/Traefik Exporter  │
 │          ├── stdout JSON 日志                                 │
 │          └── OpenTelemetry Java Agent --OTLP/HTTP--┐          │
 │                                                    │          │
 │ 各节点 /var/log/pods --> OTel Collector DaemonSet --┤          │
 │                                                    │          │
 │                                      OTLP/HTTP + Basic Auth    │
 │                                                    ▼          │
 │                                OpenObserve Standalone (1 Pod) │
 │                                SQLite + Parquet + 500Gi PVC   │
 │                                日志 15d / Trace 7d            │
 │                                                                │
 │ Prometheus + Alertmanager ---> 告警（不依赖 OpenObserve）      │
 │       │                                                        │
 │       └── Grafana (K8s、JVM、网关指标看板)                     │
 │                                                                │
 │ Traefik (仅内网/VPN)：Grafana UI / OpenObserve UI（可选）       │
 └────────────────────────────────────────────────────────────────┘
```

**选型边界**：

- OpenObserve **只部署一个实例**，**不**启用 PostgreSQL、NATS、MinIO 或 OpenObserve Cluster Mode。
- OpenObserve 日志/Trace 使用同一个数据卷；元数据 SQLite 也在卷上。**单节点可短暂中断，不是高可用**。
- Prometheus + Alertmanager 保持独立，即使日志平台故障，节点、Pod、PV 告警仍可以发出。
- OTel Collector 统一采集容器 stdout，并接收 Java 应用的 OTLP Trace；Prometheus 指标仍通过 ServiceMonitor 抓取。
- 默认仅通过 `kubectl port-forward` 访问平台；需要域名时才通过 Traefik 发布**内网/VPN 限制的管理入口**，绝不直接将管理 UI 开放到公网。

### 1.1 这套架构能提供什么

| 能力 | 组件 | 说明 |
| --- | --- | --- |
| 容器、业务日志 | OTel Collector + OpenObserve | K8s 命名空间、Pod、容器元数据；全文/SQL 查询 |
| 分布式链路 | OTel Java Agent + OpenObserve | HTTP、数据库、Redis 等 Trace；支持按 Trace ID 关联 |
| 资源与 JVM 指标 | Prometheus + Grafana | `kube-prometheus-stack`、Actuator/Micrometer |
| 网关指标 | Traefik + Prometheus | 吞吐、错误率、延迟（需启用 Traefik Prometheus metrics） |
| 基础设施告警 | Prometheus + Alertmanager | 节点不可用、Pod 重启、PVC 不足、日志写入中断 |
| 对外管理入口 | Traefik（可选） | TLS + VPN/防火墙访问控制 |

### 1.2 非目标和限制

- 不覆盖 MySQL/PostgreSQL 审计日志的法定留存需求；合规审计须单独设计归档与访问控制。
- 单节点 SQLite + 单个 RWO PVC 可在卷损坏、元数据损坏时丢失服务；**备份与恢复演练是上线前置条件**。
- OTel 采集队列不是永久消息总线；长时间故障、队列满、节点日志轮转都可能产生缺口。
- 文中 20 GB/天按**原始日志大小**估算，实际索引、压缩、查询缓存和 Trace 数据需压测。

---

## 2. 节点与资源规划

### 2.1 现有五节点的部署布局

| 逻辑节点 | 原用途 | 新增可观测组件 | 建议 |
| --- | --- | --- | --- |
| master-01/02/03 | Control Plane + etcd | OTel Collector DaemonSet（可选） | 若采集控制面节点日志，则添加控制面容忍度；控制采集资源占用 |
| worker-01 | 业务 | Prometheus、Grafana、OTel Agent | 应为可观测负载提供资源预留 |
| worker-02 | 业务 | OpenObserve、OTel Agent | 建议单独标签管理，避免与高负载 Java 业务竞争 |

> 这里不要求 OpenObserve 必须运行在 worker-02；可通过节点标签指定稳定节点。如果两台 Worker 都只有 8C16G 并运行大量 Java 业务，**建议新增专用观测 Worker，或者给现有 Worker 扩容**。

### 2.2 起步规格（申请资源，不是吞吐保证）

| 组件 | 副本 | CPU requests / limits | Memory requests / limits | 持久化 |
| --- | ---: | --- | --- | --- |
| OpenObserve Standalone | 1 | 2 / 6 Core | 8 / 16 Gi | 500Gi PVC，SSD |
| Prometheus | 1 | 1 / 3 Core | 4 / 8 Gi | 100Gi PVC，15 天指标 |
| Grafana | 1 | 100m / 1 Core | 256Mi / 2Gi | 10Gi PVC |
| Alertmanager | 1（可逐步提高） | 100m / 500m | 128Mi / 512Mi | 5Gi PVC |
| OTel Collector | 每节点 1 | 150m / 1 Core | 256Mi / 1Gi | 默认内存队列；后续可选主机持久化队列 |

`kube-prometheus-stack` 同时包含 operator、kube-state-metrics 和 node-exporter，仍需另外预留资源。先按照表格部署并观察 7～14 天，再按峰值、指标基数和查询并发调整。

### 2.3 容量估算

```text
20 GB/day × 15 days = 300 GB（原始）
压缩比按 2:1 至 5:1 假设：长期压缩存储约 60～150 GB
额外需要：WAL、索引、SQLite、查询缓存、临时压缩文件、写入峰值、Trace
第一阶段：500Gi 逻辑卷作为保守起点，保留容量监控与扩容余地
```

重要事项：

1. **500Gi 是 PVC 逻辑容量，不等于压缩后实际占用或物理磁盘成本。**
2. 如果 Longhorn 采用 2 副本，满额时数据本身最多可消耗约 **1TiB 级别物理空间**，另需快照、重建和磁盘空闲余量；实际使用量随写入增长。
3. 不要把两台 Worker 的磁盘空间全部分给 Longhorn，建议保持充分未分配余量（初期至少 25%～30%，再依据真实复制策略评估）。
4. 20 GB/天平均约 0.23 MB/s，并不代表高峰负载；应压测 5～10 倍突发写入以及同时查询。

---

## 3. 前置检查

在能够访问 Kubernetes 的运维机执行：

```bash
kubectl version --client
helm version
kubectl get nodes -o wide
kubectl get pods -A | grep -E 'traefik|cert-manager|longhorn' || true
kubectl get storageclass -o wide
kubectl get csidrivers
kubectl get crd servicemonitors.monitoring.coreos.com 2>/dev/null || true
kubectl get ns
```

**部署顺序提示**：由于 OpenObserve 的 `ServiceMonitor` 和 Collector 的 `PodMonitor` 都依赖 Prometheus Operator CRD，**实际首次执行顺序为：第 8 节先安装 kube-prometheus-stack → 第 6 节安装 OpenObserve → 第 7 节安装 OTel Collector → 第 9～11 节接入业务并验收**。各章按组件功能分组编排，不表示应机械按章节编号顺序执行。

**准入条件**：

- KubeKey 安装完成且所有节点 Ready，DNS/网络插件正常；CoreDNS 可解析集群内 Service。
- 存在可使用的 SSD StorageClass，支持 `ReadWriteOnce`，最好支持动态扩容。
- Longhorn 如仅有两个可运行副本的存储节点，检查 StorageClass **副本数是否为 2**；不要沿用 3 副本配置导致 PVC Pending/Degraded。
- 已有 Traefik `IngressClass=traefik`；管理界面只允许内网/VPN 使用。
- 运维机可以访问 Helm Chart 仓库和镜像仓库；离线环境需预先镜像同步，本手册按联网部署。
- 已建立异机备份位置；不能只在同一个 Kubernetes PV 上留快照。

建议创建命名空间和 GitLab 配置仓库：

```bash
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
mkdir -p observability/{values,manifests,runbooks,vendor}
cd observability
```

推荐目录：

```text
observability/
├── versions.env                         # 固定 chart 版本（提交 Git）
├── values/
│   ├── openobserve-values.yaml
│   ├── otel-collector-values.yaml
│   └── kube-prometheus-values.yaml
├── manifests/
│   ├── longhorn-observability-sc.yaml   # 可选
│   └── openobserve-ingress.yaml         # 可选，管理网络专用
├── runbooks/
│   └── disaster-recovery.md
└── vendor/                              # helm show values/渲染文件可留存
```

> 禁止把账号、密码、Basic Auth Token、`kubectl get secret -o yaml` 输出、备份密钥提交到 Git。

---

## 4. 统一版本管理

首次部署可以从官方稳定 Chart 仓库解析**当时的正式版本**，随后把解析出的版本写到 `versions.env` 并在 GitLab 中锁定。**以后升级禁止自动漂移到最新版**。

```bash
helm repo add openobserve https://charts.openobserve.ai
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

O2_CHART_VERSION=$(helm show chart openobserve/openobserve-standalone | awk '/^version:/ {print $2}')
OTEL_CHART_VERSION=$(helm show chart open-telemetry/opentelemetry-collector | awk '/^version:/ {print $2}')
KPS_CHART_VERSION=$(helm show chart prometheus-community/kube-prometheus-stack | awk '/^version:/ {print $2}')

printf 'O2_CHART_VERSION=%s\nOTEL_CHART_VERSION=%s\nKPS_CHART_VERSION=%s\n' \
  "$O2_CHART_VERSION" "$OTEL_CHART_VERSION" "$KPS_CHART_VERSION" > versions.env
cat versions.env

# 留存所用 Chart 的原始 values，核查配置键是否一致
helm show values openobserve/openobserve-standalone --version "$O2_CHART_VERSION" > vendor/openobserve-default-values.yaml
helm show values open-telemetry/opentelemetry-collector --version "$OTEL_CHART_VERSION" > vendor/otel-default-values.yaml
helm show values prometheus-community/kube-prometheus-stack --version "$KPS_CHART_VERSION" > vendor/kps-default-values.yaml
```

> `helm show chart` 首次解析时采用当时最新候选版本，故生产落地前必须通过 `helm search repo ... --versions`、官方升级说明和测试集群校验。`versions.env` 必须经过评审后提交；后续使用 `set -a; . ./versions.env; set +a` 复用。OpenObserve Chart 的 `image.*.tag` 与 `appVersion` 不一定相同，升级时应同时核对 Chart 和镜像应用版本。

---

## 5. Longhorn 存储准备

### 5.1 推荐：专用的 2 副本 StorageClass（可选）

仅当你确认使用 Longhorn、可用存储节点确实只有两台、且实际磁盘可用空间足够时，创建：

**`manifests/longhorn-observability-sc.yaml`**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-observability-r2
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "30"
  fsType: "ext4"
```

```bash
kubectl apply -f manifests/longhorn-observability-sc.yaml
kubectl get storageclass longhorn-observability-r2 -o yaml
```

如已有验证过的 StorageClass，可直接沿用，把下文配置里的 `longhorn-observability-r2` 替换为真实名称。注意 `Retain` 可以降低误删 PVC 时丢失 PV 的风险，但也需要人工清理遗留 PV；它不代替备份。

---

## 6. OpenObserve Standalone 安装

### 6.1 创建管理员 Secret 和 Collector 授权 Secret

OpenObserve 官方 `openobserve-standalone` Chart 支持 `auth.existingRootUserSecret`。避免在 `values.yaml` 里写明文密码。**以下脚本在有可信终端的运维机上执行；通过只允许当前用户访问的临时文件创建 Secret。**

```bash
umask 077
read -r -p 'OpenObserve root email: ' O2_EMAIL
read -r -s -p 'OpenObserve root password: ' O2_PASSWORD; echo
[ -n "$O2_EMAIL" ] && [ -n "$O2_PASSWORD" ] || { echo 'credentials must not be empty'; exit 1; }

TMP_ENV=$(mktemp)
trap 'rm -f "$TMP_ENV"' EXIT
printf 'ZO_ROOT_USER_EMAIL=%s\nZO_ROOT_USER_PASSWORD=%s\n' \
  "$O2_EMAIL" "$O2_PASSWORD" > "$TMP_ENV"
kubectl -n observability create secret generic openobserve-admin \
  --from-env-file="$TMP_ENV" --dry-run=client -o yaml | kubectl apply -f -

AUTH_HEADER="Basic $(printf '%s:%s' "$O2_EMAIL" "$O2_PASSWORD" | base64 | tr -d '\n')"
printf 'AUTH_HEADER=%s\n' "$AUTH_HEADER" > "$TMP_ENV"
kubectl -n observability create secret generic openobserve-otel-auth \
  --from-env-file="$TMP_ENV" --dry-run=client -o yaml | kubectl apply -f -

unset O2_EMAIL O2_PASSWORD AUTH_HEADER
rm -f "$TMP_ENV"
trap - EXIT
```

> Secret 本身不是加密保险箱：需要启用 Kubernetes etcd Encryption at Rest、RBAC 最小授权和必要的备份加密；采集账号建议后续使用权限更低的专用账号替换 root 账号。此处使用 root Basic Auth 只是为了首次安装可复现。

### 6.2 OpenObserve Helm values

**`values/openobserve-values.yaml`**

```yaml
# 对照 charts/openobserve-standalone/values.yaml；适用于官方 standalone Chart
enterprise:
  enabled: false

auth:
  existingRootUserSecret:
    name: openobserve-admin
    emailKey: ZO_ROOT_USER_EMAIL
    passwordKey: ZO_ROOT_USER_PASSWORD

persistence:
  enabled: true
  size: 500Gi
  storageClass: longhorn-observability-r2
  accessModes:
    - ReadWriteOnce

config:
  ZO_LOCAL_MODE: "true"
  ZO_LOCAL_MODE_STORAGE: "disk"
  ZO_META_STORE: "sqlite"
  ZO_COMPACT_DATA_RETENTION_DAYS: "15"
  ZO_PROMETHEUS_ENABLED: "true"
  ZO_TELEMETRY: "false"
  RUST_LOG: "info"

resources:
  requests:
    cpu: "2"
    memory: 8Gi
  limits:
    cpu: "6"
    memory: 16Gi

service:
  type: ClusterIP
  http_port: 5080
  grpc_port: 5081

# Prometheus Operator 已安装后可抓取 OpenObserve 自身指标
serviceMonitor:
  enabled: true
  additionalLabels:
    release: monitoring
  interval: 30s
  path: /metrics

# 不使用 Chart 自带 Ingress；如需管理域名，另见第 10 节
# 不直接对外提供 /metrics、/api/metrics、采集接口
ingress:
  enabled: false
```

按需设置 `nodeSelector`：

```bash
# 可选：将 OpenObserve 固定到指定 Worker，确保该 Worker 有足够磁盘/内存
kubectl label node worker-02 observability.openobserve/primary=true --overwrite
```

然后添加至 values 根节点：

```yaml
nodeSelector:
  observability.openobserve/primary: "true"
```

**如果没有独立资源的 Worker，先不要添加 nodeSelector。** 让调度器依据 requests 自动选择合适节点。PVC 的迁移需要结合 Longhorn 卷健康状况处理。

### 6.3 渲染、安装、验收

**必须先完成第 8 节，确认 `servicemonitors.monitoring.coreos.com` CRD 已安装**；否则下列渲染文件中的 ServiceMonitor 在 Kubernetes API Server 校验时会报资源类型不存在。

```bash
set -a; . ./versions.env; set +a

helm template o2 openobserve/openobserve-standalone \
  -n observability --version "$O2_CHART_VERSION" \
  -f values/openobserve-values.yaml > vendor/openobserve-rendered.yaml

# 检查渲染结果中的 Secret 引用、PVC、Service 和单节点工作负载
kubectl apply --dry-run=client -f vendor/openobserve-rendered.yaml >/dev/null

helm upgrade --install o2 openobserve/openobserve-standalone \
  --namespace observability --version "$O2_CHART_VERSION" \
  -f values/openobserve-values.yaml --wait --timeout 15m

kubectl -n observability get pods,deploy,sts,svc,pvc -o wide
kubectl -n observability get servicemonitor
kubectl -n observability get events --sort-by=.lastTimestamp | tail -30
```

服务名按官方示例应为 `o2-openobserve-standalone`；**如 Helm 渲染生成了不同名字，以 `kubectl get svc` 的实际结果为准**。

```bash
kubectl -n observability port-forward svc/o2-openobserve-standalone 5080:5080
# 运维机浏览器：http://127.0.0.1:5080
# 登录使用前面创建的邮箱和密码
```

必须确认 PVC 为 `Bound`，OpenObserve Pod 为 `Running/Ready`，界面可访问，`/healthz` 正常。

### 6.4 设置日志与 Trace 保留周期

- 全局 `ZO_COMPACT_DATA_RETENTION_DAYS: "15"` 使普通日志默认最多保留 15 天。
- Trace 建议进入 OpenObserve → Streams → 选择 trace stream → Settings，将**流级 `data_retention` 设置为 7 天**。流的 `data_retention` 会覆盖全局设置；最低保留限制以当前版本官方文档为准。
- 若已经创建多个日志流，分别核对其 `data_retention`；禁止误把关键审计日志与普通日志采用同一删除策略。
- 数据过期清理是后台任务，不保证配置变更后立刻释放所有磁盘空间。

---

## 7. OpenTelemetry Collector：日志与 Trace 统一入口

### 7.1 为什么选择 DaemonSet

官方 Helm Chart 的 `presets.logsCollection` 能读取 `/var/log/pods/*/*/*.log`，`presets.kubernetesAttributes` 附加 Pod 和 Namespace 元数据。DaemonSet 确保每个节点上的容器日志都能在本地采集。此处同时启用内部 ClusterIP Service，让 Java Agent 把 OTLP Trace 发送至 Collector，后者再写到 OpenObserve。

### 7.2 Collector Helm values

**`values/otel-collector-values.yaml`**

```yaml
mode: daemonset

# Contrib 发行版包含 filelog、k8sattributes 等组件
image:
  repository: otel/opentelemetry-collector-contrib
command:
  name: otelcol-contrib

presets:
  logsCollection:
    enabled: true
    includeCollectorLogs: false  # 避免日志自我循环
    storeCheckpoints: true       # 在宿主机保存 filelog 读取位置；将使采集 Pod 使用 root
  kubernetesAttributes:
    enabled: true

# 如需采集 Master 节点的容器 stdout 日志，允许在控制平面节点调度
# 请评估安全策略：collector 读取节点日志需要宿主机访问权限
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule

service:
  enabled: true
  type: ClusterIP

extraEnvs:
  - name: OO_AUTH_HEADER
    valueFrom:
      secretKeyRef:
        name: openobserve-otel-auth
        key: AUTH_HEADER

# 只需要 OTLP 端口；其他接入协议不用就关掉
ports:
  otlp:
    enabled: true
  otlp-http:
    enabled: true
  jaeger-compact:
    enabled: false
  jaeger-thrift:
    enabled: false
  jaeger-grpc:
    enabled: false
  zipkin:
    enabled: false
  metrics:
    enabled: true

resources:
  requests:
    cpu: 150m
    memory: 256Mi
  limits:
    cpu: "1"
    memory: 1Gi

podMonitor:
  enabled: true
  extraLabels:
    release: monitoring

config:
  receivers:
    jaeger: null
    zipkin: null
    prometheus: null
    otlp:
      protocols:
        grpc:
          endpoint: ${env:MY_POD_IP}:4317
        http:
          endpoint: ${env:MY_POD_IP}:4318

  processors:
    memory_limiter:
      check_interval: 5s
      limit_mib: 800
      spike_limit_mib: 150
    batch:
      timeout: 5s
      send_batch_size: 1024

  exporters:
    debug: null
    otlphttp/openobserve:
      endpoint: http://o2-openobserve-standalone.observability.svc.cluster.local:5080/api/default
      headers:
        Authorization: ${env:OO_AUTH_HEADER}
      retry_on_failure:
        enabled: true
        initial_interval: 5s
        max_interval: 30s
        max_elapsed_time: 0s
      sending_queue:
        enabled: true
        num_consumers: 2
        queue_size: 5000

  service:
    pipelines:
      metrics: null   # JVM/K8s metrics 由 Prometheus 负责，不重复写入 OpenObserve
      logs:
        receivers: [otlp]  # chart 的 logsCollection preset 会附加 filelog receiver
        processors: [memory_limiter, batch]
        exporters: [otlphttp/openobserve]
      traces:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlphttp/openobserve]
```

部署后 Collector 的实际 Service 名由 Helm Release 决定。本文使用 release `otel-collector`，默认名称一般为 `otel-collector-opentelemetry-collector`；如果不同，以实际查询结果为准。

**当前队列策略的局限**：`storeCheckpoints: true` 只保存日志读取进度，并不代表 `sending_queue` 持久化；上面发送队列位于内存，Collector 重启或长时间 OpenObserve 不可用时仍可能丢数据。要实现更高数据完整性，需要另行启用 Collector `file_storage` 持久化发送队列、规划每节点磁盘配额并测试重启/磁盘满行为；不要误把重试配置理解为零丢失保证。

### 7.3 安装

**必须先完成第 8 节，确认 `podmonitors.monitoring.coreos.com` CRD 已安装**；否则 Collector chart 的 PodMonitor 无法创建。

```bash
set -a; . ./versions.env; set +a
helm template otel-collector open-telemetry/opentelemetry-collector \
  -n observability --version "$OTEL_CHART_VERSION" \
  -f values/otel-collector-values.yaml > vendor/otel-rendered.yaml
kubectl apply --dry-run=client -f vendor/otel-rendered.yaml >/dev/null

helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  -n observability --version "$OTEL_CHART_VERSION" \
  -f values/otel-collector-values.yaml --wait --timeout 10m

kubectl -n observability get daemonset,pods,svc -o wide
kubectl -n observability logs -l app.kubernetes.io/instance=otel-collector \
  --all-containers --tail=100 --prefix
```

如果出现 `unknown receiver/processor/exporter`，先核对 `otelcol-contrib` 镜像版本、Chart 版本和渲染 ConfigMap。Collector `storeCheckpoints` 的 root/hostPath 策略需要经过安全评审；如果集群禁止特权写宿主机，可改为 `false`，接受重启时可能重复或丢失少量日志的风险。

---

## 8. Prometheus + Grafana + Alertmanager

### 8.1 采用 kube-prometheus-stack

**这是首次部署时最先执行的核心安装步骤。** OpenObserve/Collector 的监控自发现资源依赖本节创建的 Prometheus Operator CRD。安装并验证它们后，再执行第 6、7 节。

**`values/kube-prometheus-values.yaml`**

```yaml
prometheus:
  prometheusSpec:
    retention: 15d
    # 允许跨命名空间发现 ServiceMonitor / PodMonitor
    serviceMonitorNamespaceSelector: {}
    podMonitorNamespaceSelector: {}
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn-observability-r2
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 100Gi
    resources:
      requests:
        cpu: "1"
        memory: 4Gi
      limits:
        cpu: "3"
        memory: 8Gi

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn-observability-r2
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 5Gi
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi

grafana:
  persistence:
    enabled: true
    type: pvc
    storageClassName: longhorn-observability-r2
    size: 10Gi
  # 管理员密码必须通过已有 Secret 注入，禁止 values.yaml 明文密码
  admin:
    existingSecret: grafana-admin
    userKey: admin-user
    passwordKey: admin-password
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: "1"
      memory: 2Gi
```

Grafana Secret 示例：

```bash
umask 077
read -r -s -p 'Grafana admin password: ' GRAFANA_PASSWORD; echo
GF_FILE=$(mktemp)
trap 'rm -f "$GF_FILE"' EXIT
printf 'admin-user=admin\nadmin-password=%s\n' "$GRAFANA_PASSWORD" > "$GF_FILE"
kubectl -n observability create secret generic grafana-admin \
  --from-env-file="$GF_FILE" --dry-run=client -o yaml | kubectl apply -f -
unset GRAFANA_PASSWORD
rm -f "$GF_FILE"; trap - EXIT
```

安装：

```bash
set -a; . ./versions.env; set +a
helm template monitoring prometheus-community/kube-prometheus-stack \
  -n observability --version "$KPS_CHART_VERSION" \
  -f values/kube-prometheus-values.yaml > vendor/kps-rendered.yaml

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n observability --version "$KPS_CHART_VERSION" \
  -f values/kube-prometheus-values.yaml --wait --timeout 20m

kubectl -n observability get pods,svc,pvc,servicemonitor,podmonitor
kubectl -n observability get prometheus,alertmanager
```

> Prometheus Operator CRD 首次安装可能需要稍长时间，先确认所有 CRD 成功创建。`ServiceMonitor` 的 `release: monitoring` 必须与 Prometheus 实际选择器匹配；最终用 Prometheus Targets 页面验证 OpenObserve、Collector、kubelet、node-exporter 都被发现。

### 8.2 Grafana 访问

```bash
kubectl -n observability get svc | grep grafana
kubectl -n observability port-forward svc/monitoring-grafana 3000:80
# http://127.0.0.1:3000
```

建议预置：Kubernetes Nodes、Kubernetes Pods、Node Exporter Full、JVM Micrometer、Traefik HTTP 指标 Dashboard。外部导入 Dashboard 前检查查询语句和 Prometheus 数据源 UID，避免与现有标签不兼容。

### 8.3 Traefik 指标

在现有 Traefik Helm values 中检查/启用 Prometheus metrics。不同 Chart 版本字段可能改变，先执行：

```bash
helm -n traefik get values traefik -a | grep -A25 'metrics:'
helm show values traefik/traefik | grep -A55 '^metrics:'
```

目标是 Traefik Pod 暴露 Prometheus metrics，KPS 发现对应 ServiceMonitor 或 PodMonitor，再验证请求量、5xx、延迟数据。**不要在不了解现有 Traefik Chart 版本时直接覆盖整个 values 文件。**

---

## 9. Spring Boot / Java 应用接入

### 9.1 JVM 指标：Micrometer + Actuator

Spring Boot 应用需提供 `/actuator/prometheus`，并通过 ServiceMonitor 由 Prometheus 抓取。此路径应限制在集群内部，不通过 Traefik 公网暴露。下面是 Spring Boot 应用配置示例（须加入 `spring-boot-starter-actuator` 与 `micrometer-registry-prometheus`）：

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    health:
      probes:
        enabled: true
  metrics:
    tags:
      application: order-service
```

ServiceMonitor 示例（前提：你的 Service 名 `order-service`，Service 端口**名称**为 `http`，Service 标签 `app: order-service`）：

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: order-service
  namespace: application
  labels:
    release: monitoring
spec:
  namespaceSelector:
    matchNames: [application]
  selector:
    matchLabels:
      app: order-service
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 30s
```

### 9.2 Java Trace：OpenTelemetry Java Agent

推荐把**经过版本验证**的 `opentelemetry-javaagent.jar` 在 CI 构建阶段放入应用镜像 `/otel/opentelemetry-javaagent.jar`；不要在每个 Pod 启动时从公网下载。

Pod `env` 示例：

```yaml
env:
  - name: JAVA_TOOL_OPTIONS
    value: "-javaagent:/otel/opentelemetry-javaagent.jar"
  - name: OTEL_SERVICE_NAME
    value: "order-service"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "deployment.environment=prod,service.namespace=application"
  - name: OTEL_EXPORTER_OTLP_PROTOCOL
    value: "http/protobuf"
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector-opentelemetry-collector.observability.svc.cluster.local:4318"
  - name: OTEL_TRACES_SAMPLER
    value: "parentbased_traceidratio"
  - name: OTEL_TRACES_SAMPLER_ARG
    value: "0.1"
  - name: OTEL_LOGS_EXPORTER
    value: "none"    # stdout 已由 OTel Collector filelog 采集，避免重复
  - name: OTEL_METRICS_EXPORTER
    value: "none"    # JVM metrics 已由 Prometheus 抓取，避免重复
```

说明：

- 初期 Trace 采用 10% 概率采样，错误链路可能被抽样遗漏；如要强化错误诊断，可引入尾部采样，但需要另行部署/配置 Collector Gateway，并评估内存和一致性。
- 对重要服务可以提高采样率；上线前明确包含/排除的敏感 HTTP Header、SQL 参数和个人数据。
- 使用 JSON stdout 日志，尽可能包含 `trace_id`、`span_id`、`service.name`、环境、请求 ID、异常码；确认 Logback MDC 与使用的 OTel Java Agent/日志框架版本适配。
- 若 Service DNS 不一致，使用 `kubectl -n observability get svc` 查询实际名称后替换。

---

## 10. Traefik 管理入口（可选，先不上公网）

最省心和安全的默认方案是 `kubectl port-forward`。只有运维 VPN/内网办公区需要 Web 管理界面时，再接入 Traefik。

**`manifests/openobserve-ingress.yaml`**：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: openobserve-ui
  namespace: observability
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - openobserve.ops.example.com
      secretName: openobserve-ui-tls
  rules:
    - host: openobserve.ops.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: o2-openobserve-standalone
                port:
                  number: 5080
```

**安全要求**：

1. `openobserve.ops.example.com` 是占位域名。内网域名/私有 DNS 应使用内网 CA，或用 DNS-01 完成证书验证；仅用 HTTP-01 并不总能验证纯内网地址。
2. 即便设置了应用登录，也必须在**路由器/防火墙、VPN、反向代理访问策略**层限制管理入口；推荐 Traefik Middleware `ipAllowList` 作为附加防线，但不能代替网络隔离。
3. 上述 Ingress `PathPrefix: /` 会连同 API、`/metrics` 一并转发，**不得在无额外访问控制时暴露公网**。如需公网安全访问，另加 SSO/OIDC 反向认证与专用路径/路由策略，禁止公开 metrics。
4. Collector 发往 OpenObserve 的 HTTP 仍走集群内 ClusterIP，不经 Traefik，也不需要 TLS 终止开销。

---

## 11. 上线验收

### 11.1 资源健康

```bash
kubectl -n observability get pods -o wide
kubectl -n observability get pvc,svc
kubectl -n observability get servicemonitor,podmonitor
kubectl -n observability get events --sort-by=.lastTimestamp | tail -40
kubectl top nodes
kubectl top pods -n observability
```

### 11.2 日志采集验证

在一个测试命名空间创建短生命周期 Pod，向标准输出写入**不含敏感信息**的测试日志：

```bash
kubectl create ns observability-test --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability-test run log-test \
  --image=busybox:1.36 --restart=Never \
  -- sh -c 'for i in 1 2 3 4 5; do echo "o2-smoke-test sequence=$i"; sleep 2; done'
kubectl -n observability-test logs log-test
```

随后在 OpenObserve 日志 Stream 中搜索 `o2-smoke-test`，检查 `k8s.namespace.name`、Pod、container 等属性是否已收到；验证后：

```bash
kubectl -n observability-test delete pod log-test --ignore-not-found
```

### 11.3 Trace 验证

使用启用 Java Agent 的测试服务发一次 HTTP 请求；在 OpenObserve 的 Traces 界面按 `service.name=order-service` 查找。确认应用与数据库调用 Span 数量、时长和 Trace ID 正常。排查无数据时先检查 Collector Service DNS、Java Agent 日志和 Collector exporter 的 4xx/5xx 错误。

### 11.4 监控与告警验证

- Prometheus Targets 中：Node、K8s 组件、OpenObserve `/metrics`、OTel Collector metrics 为 UP。
- Grafana Dashboard 有新数据；Alertmanager 有真实可用的通知渠道并完成一次测试。
- OpenObserve PVC、Prometheus PVC 容量及节点磁盘使用率可查询；建立 **70% 提醒、85% 严重**的初始阈值（按真实增长速率优化）。
- 分别测试 OpenObserve 停止 5 分钟和恢复后的日志连续性；**明确记录是否丢失日志**，不能只观察 UI 恢复。
- 确认 Trace 7 天、普通日志 15 天保留策略能够在后台正常清理。

---

## 12. 日常运维 SOP

### 12.1 每日（自动化）

| 项目 | 要求 | 触发处理 |
| --- | --- | --- |
| OpenObserve Pod | Running/Ready | 不健康超过 2 分钟告警 |
| Collector DaemonSet | Desired = Ready | 节点上无采集 Pod 及时告警 |
| 采集数据量 | 日写入量与七天平均对比 | 突增/骤降需要分析 |
| PVC 使用率 | 70% 提醒、85% 严重 | 评估 retention、扩容或限制噪声日志 |
| OpenObserve 查询 | 查询 5xx、查询耗时 | 检查内存、WAL、磁盘 IO |
| 节点磁盘 | Longhorn 磁盘空闲、Replica 状态 | 节点或副本异常先修复，再考虑扩容 |
| 备份 | 是否按计划完成、异机可读 | 失败优先处理 |
| Prometheus Targets | UP | 监控数据缺口立即排查 |

### 12.2 常用诊断命令

```bash
# 组件状态
helm -n observability list
kubectl -n observability get pods -o wide
kubectl -n observability get pvc -o wide
kubectl -n observability get events --sort-by=.lastTimestamp | tail -40

# OpenObserve 日志（标签以渲染结果为准）
kubectl -n observability logs -l app.kubernetes.io/instance=o2 --tail=200 --prefix

# Collector 日志
kubectl -n observability logs -l app.kubernetes.io/instance=otel-collector --tail=200 --prefix

# PVC/存储
kubectl -n observability describe pvc
kubectl get volumeattachments.storage.k8s.io
kubectl get storageclass

# Helm 版本与最后一次部署配置
helm -n observability history o2
helm -n observability get values o2
helm -n observability history otel-collector
helm -n observability history monitoring
```

### 12.3 故障判定顺序

1. **日志突然中断**：Pod 正常？Collector Ready？OpenObserve PVC 还有空间？Collector 是否收到 `401`（认证错）、`429`（限流）、`5xx`（服务故障）、DNS/网络超时？
2. **界面很慢**：查 CPU、内存、磁盘 IO、长时间 SQL 查询、压缩任务；缩小查询时间范围后对比。
3. **数据量暴涨**：检查异常堆栈循环、Debug 日志、重复采集、OTel exporter `debug` 是否残留；必要时在 Collector 配置 drop/filter 和分级 retention。
4. **PVC Pending**：检查 StorageClass、Longhorn 副本可调度节点、容量和磁盘、节点污点、CSI 日志。
5. **Pod Pending/OOMKilled**：`kubectl describe pod`，比对资源请求与可分配资源；禁止靠无限提高 limits 掩盖泄漏。

---

## 13. 备份、恢复与数据安全

### 13.1 备份目标

| 数据 | 建议 | 重要性 |
| --- | --- | --- |
| OpenObserve PVC（含 SQLite、WAL、Parquet） | 每日至少一次异机备份，重要日志可提高频率 | 关键 |
| OpenObserve 账号/Stream/租户配置 | 备份相关配置和必要元数据 | 关键 |
| Prometheus PVC | 视 RPO 可选（指标可重采集，但历史不可补） | 中 |
| Grafana Dashboard 与数据源 | Helm values + API/JSON 导出或 GitOps | 高 |
| GitLab 仓库 | Helm values、Chart 版本、规则、SOP | 关键 |
| OpenTelemetry Collector 配置 | Helm values + Secret 备份 | 高 |

### 13.2 推荐方案：短暂停写 + Longhorn 备份到异机对象存储

由于本方案允许短暂中断，**优先选择一致性较容易保证的冷备份**：

1. 确认 Longhorn 已配置 **独立的 S3/NFS Backup Target**，有权限、可用容量和恢复验证。
2. 在维护窗口暂停 OpenObserve 采集端发送（或接受短时间重试/缓冲），并停止 OpenObserve 单节点工作负载。**仅创建 Longhorn 本地快照并不等于异机备份**。
3. 待 Pod 停止、SQLite 不再写入后，对对应 Longhorn Volume 创建备份到 Backup Target。记录备份 ID、PVC/PV/Volume 绑定关系、时间。
4. 恢复 OpenObserve 工作负载，确认健康和日志开始流入；检查队列溢出或日志缺口。
5. 每月至少在隔离测试环境进行一次从备份恢复的演练。

由于 Helm Chart 版本不同，Standalone 的实际 Workload 可能是 Deployment 或 StatefulSet，按以下方式识别，不要猜名字：

```bash
kubectl -n observability get deploy,sts -l app.kubernetes.io/instance=o2
kubectl -n observability get pvc -o wide
# 记录正确的 Kind/Name 与当前 replicas
# 维护窗口中执行：kubectl -n observability scale <kind>/<actual-name> --replicas=0
# 确认 Pod 全部退出后，通过 Longhorn UI/API 执行异机备份
# 备份完成后：kubectl -n observability scale <kind>/<actual-name> --replicas=1
```

> 不要对运行中的 SQLite 目录盲目 `tar`/`rsync`，也不要在两个 Pod 上同时挂载并写入同一个 SQLite RWO 卷；两种做法都可能导致备份不一致或数据损坏。`kubectl scale` 可能被 GitOps/控制器重新协调，执行前需暂停相关自动同步。

### 13.3 恢复流程（演练清单）

1. 暂停采集写入；确认有备份、原始 Volume/PVC 信息和操作审批。
2. 将 Longhorn Backup **恢复为新 Volume**，通过静态 PV/PVC 或 Longhorn 支持的恢复路径挂载到隔离命名空间；勿直接覆盖生产数据卷。
3. 使用同一 OpenObserve 兼容版本在隔离环境启动，验证 SQLite 元数据、日志 Stream、查询和 Trace 都可用。
4. 记录 RTO、RPO 和最大日志缺口；通过审批后再决定是否执行正式恢复。
5. 保留备份完整性校验、备份密钥和恢复记录；包含敏感日志的备份必须加密和限制访问。

**建议初始目标**：RPO ≤ 24 小时（每日备份）、RTO 2～4 小时（需演练验证），不是对系统固有能力的承诺。需要更严格 RPO 的业务不能仅依赖此单节点方案。

---

## 14. 组件升级与回滚

1. 在 GitLab MR 中修改 `versions.env` 和必要的 values；检查官方 Chart 的 `UPGRADING.md`、镜像/依赖兼容性。
2. 备份 OpenObserve PVC / SQLite 元数据及 Grafana 配置；确认有足够 PV 空间和监控告警。
3. 在测试环境先升级，验证 OTLP 接口、查询、日志与 Trace 读取。
4. 生产维护窗口内升级，观察 30～60 分钟的写入、查询、OOM、重启和 PVC 使用率。
5. 如遇数据格式或元数据迁移，**不能假定 `helm rollback` 就能回滚磁盘格式**；必须以经过测试的备份恢复流程为准。

```bash
set -a; . ./versions.env; set +a

helm upgrade o2 openobserve/openobserve-standalone \
  -n observability --version "$O2_CHART_VERSION" \
  -f values/openobserve-values.yaml --wait --timeout 15m

helm upgrade otel-collector open-telemetry/opentelemetry-collector \
  -n observability --version "$OTEL_CHART_VERSION" \
  -f values/otel-collector-values.yaml --wait --timeout 10m

helm upgrade monitoring prometheus-community/kube-prometheus-stack \
  -n observability --version "$KPS_CHART_VERSION" \
  -f values/kube-prometheus-values.yaml --wait --timeout 20m

helm -n observability history o2
```

**不要对 OpenObserve `helm upgrade` 直接加 `--atomic` 就视为万无一失。** 它只能协助回滚 Kubernetes 资源，不恢复 SQLite/Parquet 数据格式和不兼容迁移。

---

## 15. 安全与隔离

- 管理界面仅 VPN/内网可访问；Traefik TLS 并配套访问策略，不公开 `/metrics`。
- OpenObserve 接收端口 `5080` 只提供 ClusterIP，外部采集不直接暴露；跨集群接入再独立设计 mTLS、鉴权和限流。
- OpenObserve 内置登录认证不等于细粒度租户权限；开源版权限能力需依版本和实际企业要求核验。
- 对日志中的身份证、手机号、令牌、Cookie、SQL 参数设置采集过滤/脱敏；不要把含密码的环境变量、Secret 内容写入日志。
- OTel Collector 有宿主机日志读取权限，控制 `ServiceAccount` RBAC、Pod Security 与宿主机访问范围。
- Prometheus Alertmanager 与 Grafana 使用独立的凭据，配置仅通过 Secret 或密钥管理系统传递。
- 生产 namespace 建议补齐 NetworkPolicy，但启用时必须放通 DNS、OpenObserve 5080、Collector 4317/4318、Prometheus 抓取及 Longhorn CSI 所需流量；先观测后收紧。

---

## 16. 验收清单

- [ ] 所有 Worker/Master 中需要采集的节点都有 OTel Collector Pod
- [ ] `openobserve-standalone` 只有 1 个实例，配置 `ZO_LOCAL_MODE=true`、`ZO_META_STORE=sqlite`
- [ ] OpenObserve PVC `Bound`、IO 正常、没有异常 Longhorn 副本
- [ ] OpenObserve UI 可登录，`/healthz` 正常
- [ ] OpenObserve 能查询 K8s 测试日志及命名空间/Pod 元数据
- [ ] Java Agent 能把 Trace 发送到 Collector，OpenObserve 可以按服务搜索
- [ ] Prometheus Targets 包含节点、Prometheus 自身、OpenObserve 与 Collector
- [ ] Grafana 看板中能够看到节点、Pod、JVM、Traefik 数据
- [ ] Alertmanager 通知渠道实际发送成功
- [ ] 日志 15 天、Trace 7 天策略已在 UI/配置中核实
- [ ] OpenObserve 使用量 70%/85% 阈值已配置告警
- [ ] Longhorn 异机 Backup Target 已配置并完成恢复演练
- [ ] 模拟 OpenObserve 重启，记录 Collector 数据丢失窗口
- [ ] 管理 UI 和 metrics 未暴露公网
- [ ] `versions.env`、Chart 默认值快照、渲染结果和运维 SOP 已纳入 GitLab

---

## 17. 后续扩容阈值与演进

当出现以下情况，重新评估架构：

- 日志持续增长到 50～100 GB/天或长期查询峰值显著增加；
- 每周多次内存不足、查询超时或单节点 CPU/磁盘 IO 持续饱和；
- 公司无法接受单节点故障造成日志写入缺口；
- 出现跨团队精细权限、多租户和合规要求；
- 需要日志/Trace 多节点读写高可用。

第二期可迁移 OpenObserve 单节点到对象存储；严格高可用需按官方分布式模式设计 PostgreSQL + NATS + 对象存储，并重新评估资源和备份体系。不是简单把 `replicas: 1` 改成 `replicas: 2`。

---

## 18. 参考文档（上线前重新核对）

1. OpenObserve 官方 Standalone Helm Chart：<https://github.com/openobserve/openobserve-helm-chart/tree/main/charts/openobserve-standalone>
2. OpenObserve Chart 默认值：<https://raw.githubusercontent.com/openobserve/openobserve-helm-chart/main/charts/openobserve-standalone/values.yaml>
3. OpenObserve 存储模式：<https://openobserve.ai/docs/administration/maintenance/storage-management/storage/>
4. OpenObserve OTLP/HTTP 日志接收：<https://openobserve.ai/docs/ingestion/logs/otlp/>
5. OpenObserve 日志流保留设置：<https://openobserve.ai/docs/reference/api/stream/setting/>
6. OpenObserve 自身指标：<https://openobserve.ai/docs/administration/maintenance/expose-metrics/>
7. OTel Collector Helm 官方文档：<https://opentelemetry.io/docs/platforms/kubernetes/helm/collector/>
8. OTel Collector Chart 默认值：<https://github.com/open-telemetry/opentelemetry-helm-charts/blob/main/charts/opentelemetry-collector/values.yaml>
9. kube-prometheus-stack Chart：<https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack>
10. Traefik Kubernetes：<https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-ingress/>
11. Longhorn 备份与恢复：<https://longhorn.io/docs/>

---

**部署建议总结**：先把 OpenObserve Standalone + OTel Collector 日志/Trace 跑通，再部署/对接 Prometheus + Grafana 的基础监控和告警，最后才开启 Traefik 内网管理入口。日志系统允许短暂停机，不等于允许永久数据丢失；请将异机备份、恢复演练和 Collector 缺口测试列为上线门槛。
