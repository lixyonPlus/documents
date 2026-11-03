# KubeKey + Traefik 高可用网关部署与运维方案

> 版本：v1.0 ｜ 更新：2026-11-03  
> 目标：自建物理服务器 Kubernetes / KubeKey 4.x / Ubuntu 24.04 LTS / 3 Control Plane + 2 Worker  
> 原则：便于维护、可滚动升级、稳定的统一业务入口、配置可版本化  
> **说明**：所有 IP、域名、邮箱、节点名均为示例，执行前必须替换并核实；生产部署请固定各 Helm Chart 的**已验证版本**。本方案未经在你的实际集群上实测，须先在测试环境完成验收。

## 1. 结论与技术选型

**推荐组合：KubeKey + Calico + MetalLB（L2）+ Traefik Proxy v3（双副本）+ cert-manager + GitLab。**

- **KubeKey**：Kubernetes 集群生命周期管理；与业务网关解耦。
- **MetalLB**：为 Traefik Service 提供物理机环境里的固定 `LoadBalancer` IP。
- **Traefik**：统一处理 HTTP / HTTPS / WebSocket 路由和反向代理。
- **cert-manager**：申请、续期、以 Kubernetes TLS Secret 方式保存证书（不依赖每个 Traefik Pod 独自维护 ACME 状态）。
- **Ingress**：第一阶段使用标准 Kubernetes Ingress，简单、成熟、部署成本低；需要高级能力时使用 IngressRoute；未来可迁移 Gateway API。
- **Helm + GitLab**：保存 Chart 版本、values、基础设施 YAML、审批记录。

与其它入口方案的取舍：

| 入口方式 | 推荐场景 | 优点 | 注意点 |
| --- | --- | --- | --- |
| **MetalLB L2 + Traefik** | 同 VLAN 的 2～10 台服务器，少量集群 | 组件少，容易配置 | 同一个 VIP 通常仅由一台节点宣告；故障切换受 ARP/NDP 更新影响 |
| 外部 LB + Traefik NodePort | 已有 F5 / 硬件 LB / HAProxy 高可用集群 | 可由外部 LB 做健康检查与多节点分发 | 要额外维护外部 LB |
| MetalLB BGP + Traefik | 跨 VLAN、较大规模、有 BGP 路由器 | 可结合路由实现多节点 ECMP | 网络管理复杂，要求运维和网络团队配合 |
| hostNetwork / hostPort | 非常受限的实验环境 | 不依赖 MetalLB | 易出现端口冲突，运维和扩容体验较差 |

**重要**：MetalLB 的业务 VIP 与 kube-vip/Keepalived 用于 Kubernetes API Server 的 VIP 必须区分；同一个 IP 不能同时分配给两个组件。

## 2. 目标架构及 IP 规划

```text
                    [客户端 / 浏览器 / API 调用方]
                            |
                     DNS：api.example.com
                            |
                  [公网路由器/防火墙 (可选)]
                  NAT TCP 80/443 → 192.168.50.240
                            |
                 [MetalLB 业务 VIP .240]
                            |
                  [Traefik Service:80/443]
                            |
                +-----------+-----------+
                |                       |
           [Traefik Pod A]          [Traefik Pod B]
           Worker-01                Worker-02
                +-----------+-----------+
                            |
                 [Kubernetes ClusterIP]
                  /          |          \
              Java API    WebSocket    Nacos UI

API Server HA VIP：单独分配，例如 192.168.50.200（不能与 .240 冲突）
```

| 角色 | 示例主机 | 示例内网 IP |
| --- | --- | --- |
| Master 1 | k8s-master-01 | 192.168.50.101 |
| Master 2 | k8s-master-02 | 192.168.50.102 |
| Master 3 | k8s-master-03 | 192.168.50.103 |
| Worker 1 | k8s-worker-01 | 192.168.50.111 |
| Worker 2 | k8s-worker-02 | 192.168.50.112 |
| Kubernetes API VIP | 单独由 KubeKey HA 配置管理 | 192.168.50.200 |
| **Traefik 业务 VIP** | **由 MetalLB 管理，不配置在 Netplan 上** | **192.168.50.240** |

前提：以上物理节点及业务 VIP 所在网络可二层互通；交换机、安全设备与虚拟化平台允许 ARP/NDP 宣告；`.240` 已从 DHCP 地址池和手工 IP 分配范围中排除，未被其它设备使用。

如果服务器分布在不同二层网络，不能简单套用下面的 MetalLB L2 配置，应改用 BGP 或外部 LB。

## 3. 部署前核查

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get ingressclass
kubectl get svc -A | grep LoadBalancer || true
helm version
kubectl -n kube-system get configmap kube-proxy -o yaml | grep -A8 -E 'mode:|ipvs:'
```

确认：

1. 两个 Worker 为 `Ready` 且可正常运行 Pod。
2. Calico 网络已正常部署，Pod 到 Service 的连通性正常。
3. 目前没有与 Traefik 竞争入口 IP 的另一个 LoadBalancer；已有 Ingress Controller 时不要把 Traefik 设置为默认 IngressClass。
4. 如 kube-proxy 使用 **IPVS**，需确认 `ipvs.strictARP: true`；若不是 IPVS，按当前网络栈和 MetalLB 文档判断，不要无依据直接改配置。
5. 集群具备 Helm 3 或与你选定 Chart 兼容的 Helm 客户端。
6. 防火墙允许客户端到业务 VIP 的 TCP/80、TCP/443；MetalLB 通信、集群 CNI 和 DNS 正常。

公网访问还需：

- 域名 `api.example.com` 的 DNS A 记录指向**公网 IP**，而不是直接把 `192.168.50.240` 作为公网地址。
- 路由器/防火墙将公网 **TCP 80/443** 转发到 `192.168.50.240:80/443`；双路由器/防火墙 HA 需另外设计。
- HTTP-01 证书验证要求 Let's Encrypt 能从互联网经 80 端口访问到域名对应的 challenge 路径。

仅内网使用则可直接使用内部 DNS 将业务域名解析到 VIP，证书可采用内部 CA；内网-only 场景不满足公网 HTTP-01 条件时，不要直接套用 Let's Encrypt 的 HTTP-01 方案。

## 4. 安装 MetalLB

### 4.1 创建命名空间及安全标签

MetalLB speaker 需要网络相关的较高权限。以下标签是按官方 Helm 安装要求为 MetalLB 专用 namespace 设置的，**不要扩大到业务命名空间**。

```bash
kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace metallb-system \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged --overwrite

helm repo add metallb https://metallb.github.io/metallb
helm repo update
helm search repo metallb/metallb --versions | head
```

### 4.2 安装 L2 所需的原生 Speaker 模式

以下使用 MetalLB 官方 Chart 的原生 speaker（不开 FRR-K8s）配置，避免为只有 L2 需求的环境额外引入 FRR 组件；请以所选 Chart 版本的 `helm show values` 验证参数。

`metallb-values.yaml`：

```yaml
frrk8s:
  enabled: false
speaker:
  frr:
    enabled: false
```

```bash
# 从上面输出中选一个经过验证且支持当前 Kubernetes 的 Chart 版本
export METALLB_CHART_VERSION='<validated-metallb-chart-version>'

helm show values metallb/metallb --version "$METALLB_CHART_VERSION" > metallb-default-values.yaml
helm upgrade --install metallb metallb/metallb \
  -n metallb-system \
  --version "$METALLB_CHART_VERSION" \
  -f metallb-values.yaml \
  --wait --timeout 10m

kubectl -n metallb-system get pods -o wide
```

### 4.3 配置业务 VIP 地址池

`metallb-ip-pool.yaml`：

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: traefik-public
  namespace: metallb-system
spec:
  addresses:
    - 192.168.50.240/32
  autoAssign: false
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: traefik-public-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - traefik-public
```

```bash
kubectl apply -f metallb-ip-pool.yaml
kubectl -n metallb-system get ipaddresspool,l2advertisement
```

`autoAssign: false` 防止新建的其它 `LoadBalancer` Service 自动占用这一个保留地址；Traefik 将通过注解显式申请 `.240`。

## 5. 安装 Traefik v3（双副本）

### 5.1 标记允许部署 Traefik 的 Worker

```bash
kubectl label node k8s-worker-01 ingress-ready=true --overwrite
kubectl label node k8s-worker-02 ingress-ready=true --overwrite
kubectl get nodes --show-labels | grep ingress-ready
```

如果实际节点名称不同，以 `kubectl get nodes` 的结果为准。

### 5.2 添加官方 Helm 仓库

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm search repo traefik/traefik --versions | head
```

**不要混用网上其它 Chart 大版本的 values 示例。** 先选定 Chart 版本，然后通过 `helm show values traefik/traefik --version ...` 对照。以下示例采用 Traefik 官方当前 Chart 的 `ports.web.http.redirections.entryPoint` 结构。

### 5.3 配置 `traefik-values.yaml`

```yaml
# 适用于 Traefik v3 的官方 Helm Chart；生产前以固定 Chart 版本验证
deployment:
  kind: Deployment
  replicas: 2
  minReadySeconds: 5

# 两台 Worker + required anti-affinity：更新时先释放一个旧 Pod，
# 否则默认 maxSurge=1/maxUnavailable=0 会导致新 Pod 无节点可调度。
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 0
    maxUnavailable: 1

nodeSelector:
  ingress-ready: "true"

affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: traefik
        topologyKey: kubernetes.io/hostname

podDisruptionBudget:
  enabled: true
  minAvailable: 1

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: "1"
    memory: 512Mi

ingressClass:
  enabled: true
  isDefaultClass: false
  name: traefik

providers:
  kubernetesIngress:
    enabled: true
    ingressClass: traefik
    publishedService:
      enabled: true
  kubernetesCRD:
    enabled: true
    allowCrossNamespace: false
    allowExternalNameServices: false
  kubernetesGateway:
    enabled: false # 第一阶段先用 Ingress；迁移 Gateway API 时再启用

service:
  annotations:
    metallb.io/address-pool: traefik-public
    metallb.io/loadBalancerIPs: "192.168.50.240"
  spec:
    type: LoadBalancer
    externalTrafficPolicy: Cluster

ports:
  web:
    port: 8000
    exposedPort: 80
    expose:
      default: true
    allowACMEByPass: true
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    port: 8443
    exposedPort: 443
    expose:
      default: true

api:
  dashboard: true
  insecure: false

ingressRoute:
  dashboard:
    enabled: true
    entryPoints:
      - traefik # 只绑定内部管理 EntryPoint，Service 不暴露此端口

log:
  level: INFO
accessLog:
  enabled: true

metrics:
  prometheus:
    service:
      enabled: false # 接入 Prometheus Operator 后再按需设置 ServiceMonitor
    serviceMonitor:
      enabled: false
```

解释：

- 2 个 Pod 通过 `podAntiAffinity` 分散到不同 Worker；若某台 Worker 故障，现存 Pod 仍可提供服务，但修复前失去冗余。
- **更新注意**：只有两台能调度 Traefik 的 Worker 且采用硬反亲和时，必须避免 `maxSurge: 1` 造成升级 Pod 无法调度，因此这里设置 `maxSurge: 0` / `maxUnavailable: 1`，升级期间有短暂单副本窗口。要做到更新期间始终保持双副本，需增加第三个可调度入口节点或调整容量/调度策略。
- `externalTrafficPolicy: Cluster` 更简单，但经过节点网络转发时**真实客户端 IP 可能丢失**。如果必须保存真实源 IP，再评估 `Local`、节点分布、入口健康检查及上层代理信任配置。
- `allowACMEByPass: true` 用于避免 HTTP-01 challenge 路由被全局 HTTPS 重定向挡住；证书签发仍须真实验证。
- Traefik Dashboard 只绑定管理入口 `traefik`，Service 不暴露该端口，平时通过授权的 `kubectl port-forward` 访问，不要在公网配置它的路由。
- 512Mi 是起步限额，生产应根据并发、长连接数量、指标和代理负载调整。
- 不开启 `hostNetwork`，也不在 Worker 物理机上直接监听 80/443，避免端口冲突。

### 5.4 预览与安装

```bash
export TRAEFIK_CHART_VERSION='<validated-traefik-chart-version>'

helm show chart traefik/traefik --version "$TRAEFIK_CHART_VERSION"
helm show values traefik/traefik --version "$TRAEFIK_CHART_VERSION" > traefik-default-values.yaml
helm template traefik traefik/traefik \
  -n traefik --version "$TRAEFIK_CHART_VERSION" \
  -f traefik-values.yaml > traefik-rendered.yaml

helm upgrade --install traefik traefik/traefik \
  -n traefik --create-namespace \
  --version "$TRAEFIK_CHART_VERSION" \
  -f traefik-values.yaml \
  --wait --timeout 10m

kubectl -n traefik get deploy,pod,svc,pdb -o wide
kubectl get ingressclass
```

期望：两个 Traefik Pod 分别在不同 Worker 上；Traefik Service 的 `EXTERNAL-IP` 显示 `192.168.50.240`；`80/TCP` 与 `443/TCP` 已暴露。

若 Pod 因反亲和约束 Pending，先检查节点标签、可调度性、资源和 Helm 生成的标签，而不是直接删除反亲和规则。

## 6. TLS 证书：推荐 cert-manager

**建议用 cert-manager，而不是 Traefik 每个副本自己管理 ACME 本地文件。** 多副本模式下，TLS Secret 更便于共享、轮转和恢复。

### 6.1 安装 cert-manager

以下示例版本来自官方安装文档，实际安装前需与 Kubernetes 版本和团队升级策略确认。

```bash
helm upgrade --install cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --version v1.21.3 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait --timeout 10m

kubectl -n cert-manager get pods
```

### 6.2 创建 Let's Encrypt Staging / Production Issuer

**前提：** 公网 DNS、NAT、TCP/80、证书申请域名已配置。更换 `ops@example.com` 为你实际能收邮件的地址。先使用 Staging 验证，再换 Production，防止触发正式环境证书申请频率限制。

`cluster-issuers.yaml`：

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    email: ops@example.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: ops@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik
```

```bash
kubectl apply -f cluster-issuers.yaml
kubectl get clusterissuer
```

内网-only 环境改用公司 CA / 自建 CA 或 DNS-01（有权限控制的 DNS Provider），不要指望一个无法从公网访问的 RFC1918 地址通过公网 HTTP-01 验证。

## 7. 部署一个实际路由验证

先用 staging 签发、测试 DNS/路由，再把注解中的 `letsencrypt-staging` 改为 `letsencrypt-prod`，并更换证书 Secret 名称以触发正式签发。

### 7.1 部署示例服务

`whoami.yaml`：

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
  namespace: demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whoami
  template:
    metadata:
      labels:
        app: whoami
    spec:
      containers:
        - name: whoami
          image: traefik/whoami:v1.11.0
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: whoami
  namespace: demo
spec:
  type: ClusterIP
  selector:
    app: whoami
  ports:
    - name: http
      port: 80
      targetPort: 80
```

```bash
kubectl apply -f whoami.yaml
kubectl -n demo rollout status deployment/whoami
```

### 7.2 配置 Ingress

`whoami-ingress.yaml`：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami
  namespace: demo
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - whoami.example.com
      secretName: whoami-staging-tls
  rules:
    - host: whoami.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: whoami
                port:
                  number: 80
```

```bash
kubectl apply -f whoami-ingress.yaml
kubectl -n demo get ingress,certificate,challenge,order
kubectl -n demo describe certificate whoami-staging-tls
```

将 `whoami.example.com` 替换为你自己的可验证域名并配置 DNS。测试：

```bash
# 测试内网入口；测试证书时，应先用域名的实际可信链进行访问
curl -Ik --resolve whoami.example.com:443:192.168.50.240 \
  https://whoami.example.com

# 如仅测试入口转发且 staging 证书不受客户端信任，临时使用 -k
curl -k --resolve whoami.example.com:443:192.168.50.240 \
  https://whoami.example.com
```

通过 Staging 后，将 Ingress 注解改为 `letsencrypt-prod`、Secret 改为 `whoami-prod-tls`，重新 apply，检查证书状态，并移除测试客户端的 `-k` 选项。

## 8. Java 微服务 / WebSocket / Nacos 配置建议

### Java / Spring Boot

- Java 应用通常维持 `ClusterIP` 服务，由 Traefik 提供域名入口，不为每个应用单独开 NodePort。
- 典型路由 `api.example.com -> java-api:8080`，推荐按服务子域名划分，减少路径重写配置。
- Java 应用识别 `X-Forwarded-Proto`、`X-Forwarded-For` 时，只信任经过校验的反向代理；不要任意开启 Traefik 的 `forwardedHeaders.insecure`。
- 服务入口建议配置业务层超时、限流；网关限流不能代替鉴权和业务防刷。

### WebSocket

- Traefik 支持 WebSocket Upgrade，普通 WS/WSS 通常不需要像 ingress-nginx 一样设置额外 Upgrade Header 注解。
- 将 WebSocket 服务用正常的 HTTP Ingress / IngressRoute 路由；客户端使用 `wss://`。
- 对长连接校验超时链路：公网 LB、代理、Traefik、应用、心跳与空闲时长设置。不要只修改 K8s Service 的 timeout。

### Nacos

- **只公开 Nacos 控制台**（如确有需要），必须增加认证、IP 白名单或 VPN 访问限制。
- Nacos 业务使用到的 gRPC / TCP 端口不可简单当作普通 HTTP Ingress 处理。请按照实际版本确认协议和端口，优先保持集群内访问；若确需跨集群开放，另行采用 Traefik TCP Router / 独立 Service，并强化安全控制。
- 不建议将注册中心直接暴露在公网。

## 9. 高可用与安全

1. **两副本**：`deployment.replicas: 2`，强制跨两个 Worker 调度。
2. **PDB**：`minAvailable: 1`，防止正常 drain 同时驱逐全部 Traefik Pod；PDB 不能阻止物理节点突然宕机。
3. **不公开 Dashboard**：仅通过管理入口和 `kubectl port-forward` 临时查看；若需要长期 UI，增加单独内网域名 + SSO / BasicAuth + IP 白名单。
4. **TLS 自动化**：cert-manager 保证每个服务的 Secret 自动续期，建议对证书过期设置告警。
5. **NetworkPolicy**：若应用 namespace 使用默认拒绝，请放行 Traefik 到后端 Pod；证书挑战期间还需允许 Traefik 到 cert-manager solver Pod。
6. **限制访问入口**：生产使用公网域名时，防火墙只暴露 80/443；数据库、etcd、Kube API、Nacos 管理端口不开放公网。
7. **证书与凭据备份**：Kubernetes Secret、cert-manager Account Key、DNS API 凭据应纳入加密备份；GitLab 只提交非敏感声明式配置，敏感内容使用受控 Secret 管理方案。
8. **真实源 IP**：先使用 `Cluster` 保障部署简洁；有合规或审计需求时专门测试 `externalTrafficPolicy: Local` / BGP / 外部 LB，防止误记源地址。
9. **L2 单宣告节点**：本方案提供故障转移，不是 L2 多路径吞吐扩展。吞吐和更严格的 SLA 场景建议 BGP/外部 HA LB。

内部 Dashboard 临时访问（需要具有 `kubectl` 权限）：

```bash
kubectl -n traefik port-forward deployment/traefik 9000:8080
# 在本机浏览器打开 http://127.0.0.1:9000/dashboard/
```

## 10. 监控与日常巡检

```bash
kubectl -n metallb-system get pods
kubectl -n traefik get pods -o wide
kubectl -n traefik get svc traefik -o wide
kubectl -n traefik get pdb
kubectl get ingress -A
kubectl get certificates -A
kubectl get challenges -A
kubectl -n traefik logs deployment/traefik --tail=100
helm list -n traefik
```

建议用 Prometheus 监控 Traefik 5xx、请求延迟 p95/p99、流量、连接数、Pod 重启；使用 Grafana 展示，并监控 MetalLB speaker/controller、VIP 探测、证书剩余有效期。

Traefik Chart 提供 `metrics.prometheus`、`serviceMonitor` 等选项。**只有集群已经安装 Prometheus Operator 对应 CRD 时** 才启用 `serviceMonitor.enabled: true`，否则 Helm 可能因缺少 CRD 而失败。可以先部署业务网关，后接入完整监控。

## 11. 升级、回滚与故障演练

### 11.1 规范升级

1. 在 GitLab MR 中更新 **Chart 固定版本**和 `traefik-values.yaml`，同步记录 Traefik App 版本。
2. 阅读版本发布说明及不兼容变更，检查 CNI、IngressClass、CRD 兼容性。
3. 测试集群运行 `helm template`、灰度回归 HTTP、HTTPS、WebSocket、证书续期。
4. 生产先备份 Helm values、Kubernetes 配置和相关 Secret，再在维护窗口执行 Helm 升级。
5. 验证 `kubectl rollout status`、Traefik Pod 分布、PDB、MetalLB VIP、监控告警。

```bash
helm -n traefik get values traefik > traefik-values.backup.yaml
helm -n traefik history traefik

helm upgrade traefik traefik/traefik \
  -n traefik \
  --version "$TRAEFIK_CHART_VERSION" \
  -f traefik-values.yaml \
  --wait --timeout 10m

kubectl -n traefik rollout status deployment/traefik
```

回滚（先检查 Helm CRD、API、Chart 的反向兼容性；`helm rollback` 不等于自动回滚 CRD 或数据库）：

```bash
helm -n traefik history traefik
helm -n traefik rollback traefik <previous-revision> --wait
```

### 11.2 故障演练

**一台 Worker 维护：**

```bash
kubectl drain k8s-worker-01 --ignore-daemonsets --delete-emptydir-data
kubectl -n traefik get pods -o wide
kubectl uncordon k8s-worker-01
```

该命令会驱逐该节点上其它业务 Pod，**仅在维护窗口、事先确认业务可迁移并有恢复手段时执行**。应持续通过独立客户端访问 VIP，观察 4xx/5xx、连接中断和切换时间。

再模拟单个 Traefik Pod 失败，并验证另一 Pod 仍能承担流量。针对 MetalLB L2 还要单独演练宣告 VIP 的节点故障及 ARP 收敛；故障恢复不是零中断保证。

## 12. GitLab 目录建议

```text
platform-infra/
├── clusters/
│   └── prod/
│       ├── kubekey/              # Inventory 和集群初始化信息；不提交明文密钥
│       ├── metallb/
│       │   ├── metallb-values.yaml
│       │   └── metallb-ip-pool.yaml
│       ├── traefik/
│       │   ├── traefik-values.yaml
│       │   └── chart-version.txt
│       ├── cert-manager/
│       │   └── cluster-issuers.yaml
│       └── routes/
│           └── whoami-ingress.yaml
└── README.md
```

应用路由建议由相应应用团队在应用仓库通过 Helm/Argo CD 管理；基础网关、IP 池和证书颁发者配置由平台团队管理，避免不同团队同时直接修改关键网络组件。

## 13. 常见问题排查

| 现象 | 排查路径 |
| --- | --- |
| `EXTERNAL-IP: <pending>` | MetalLB controller/speaker 状态、IPAddressPool、地址注解、Service events |
| VIP 局域网 ping/访问不通 | 二层互通、ARP/NDP、交换机安全限制、防火墙、IP 冲突、L2Advertisement |
| 访问出现 404 | `IngressClass`、Host 头、Path、entryPoints、Namespace |
| 访问出现 502/503 | Service Endpoints/EndpointSlices、Pod readiness、NetworkPolicy、目标端口 |
| HTTPS 浏览器报错 | `Certificate Ready`、TLS Secret、SNI Host 与证书 SAN、证书链 |
| HTTP-01 验证失败 | DNS、公网 NAT:80、Challenge Pod、IngressClass、HTTP 重定向、NetworkPolicy |
| Traefik 只能调度 1 个 Pod | worker 标签、跨主机反亲和、节点 taints、资源不足 |
| WebSocket 频繁断开 | 外部 LB/防火墙空闲超时、应用心跳、Traefik 连接生命周期 |
| 真实客户端 IP 错误 | externalTrafficPolicy、SNAT、上层代理、可信转发头设置 |

排查命令：

```bash
kubectl -n traefik describe svc traefik
kubectl -n metallb-system get events --sort-by=.lastTimestamp | tail -30
kubectl -n traefik describe pods -l app.kubernetes.io/name=traefik
kubectl -n demo get svc,endpointslice,ingress
kubectl -n demo describe challenge
kubectl -n cert-manager logs deployment/cert-manager --tail=100
```

## 14. 部署验收清单

- [ ] 业务 VIP 与 Kubernetes API VIP 不冲突，已从 DHCP 和固定地址分配中保留
- [ ] 两台 Worker 都可调度 Traefik，两个 Pod 实际分布在不同机器
- [ ] MetalLB controller / speaker 正常，Traefik Service 获得预定 IP
- [ ] HTTP 80 能重定向到 HTTPS 443，HTTP-01 challenge 能正常完成
- [ ] 经过 Staging 测试后签发 Production 证书，自动续期机制正常
- [ ] Java HTTP API 和 WebSocket 两种业务链路均通过验证
- [ ] Dashboard 只能在管理端口 / 授权 port-forward 访问，公网不可直接匿名访问
- [ ] 监控、日志、告警、配置备份和 Helm 固定版本已落实
- [ ] 故障节点演练验证切换时间和业务实际表现
- [ ] GitLab 具备操作审批、变更记录和回滚流程

## 15. 官方资料

- Traefik Kubernetes 官方部署：https://doc.traefik.io/traefik/setup/kubernetes/
- Traefik Helm Chart：https://github.com/traefik/traefik-helm-chart
- Traefik Chart Values：https://github.com/traefik/traefik-helm-chart/blob/master/traefik/VALUES.md
- MetalLB Installation：https://metallb.io/installation/
- MetalLB Configuration：https://metallb.io/configuration/
- MetalLB Service Usage：https://metallb.io/usage/
- cert-manager Helm 安装：https://cert-manager.io/docs/installation/helm/
- cert-manager HTTP01：https://cert-manager.io/docs/configuration/acme/http01/
- Kubernetes Gateway API：https://gateway-api.sigs.k8s.io/

---

**推荐落地顺序：** 校验地址规划 → 安装 MetalLB → 安装 2 副本 Traefik → 验证内网 HTTP/HTTPS → 接入 cert-manager → 验证公网域名 → 接入业务服务 → 添加监控与故障演练。对“日常好维护”而言，先把这一条路径稳定运行，比一开始启用所有 Traefik 高级功能更有效。
