# KubeKey + Traefik 域名解析与 HTTPS 证书配置运维手册

> 适用场景：KubeKey 4.x 自建 Kubernetes、MetalLB L2、Traefik v3 双副本、cert-manager、Prometheus/Grafana/OpenObserve。
>
> 文档版本：v1.0 ｜ 更新：2026-11-03 ｜ 目标：可重复部署、自动续期、安全隔离、易于维护。
>
> **执行须知**：文中的 `example.com`、`ops@example.com`、`203.0.113.10`、`192.168.50.240` 都是**示例**；其中 `203.0.113.10` 是文档保留的示例公网 IP，并非真实可访问地址。执行前必须替换为实际域名、公网 IP、内网网段和服务名称。不要直接把占位符部署到生产环境。

## 1. 目标与推荐方案

本手册解决以下问题：

1. 域名解析到 Traefik 网关（公网与内网两种）。
2. 使用 cert-manager 向 Let's Encrypt 申请 HTTPS 证书，并自动续期。
3. 采用 `Ingress + TLS Secret`，让 Traefik 两个副本共用有效的证书。
4. 将 OpenObserve / Grafana 管理入口限制在内网或 VPN，不依赖“域名不可猜测”保护系统。
5. 完成签发验证、续期检查、故障定位和恢复操作。

**推荐优先级：**

- 仅内网 / VPN 的管理域名：**DNS-01**（例如 DNS 服务商 Cloudflare），无须开放公网 80/443，也可以签发公开受信任的域名证书。
- 真实对外业务域名：**HTTP-01**，只要公网 80 端口能够正确到达 Traefik；也可以统一使用 DNS-01。
- 没有可控的公网注册域名 / 没有 DNS API：采用**企业内部 CA**，或只通过 `kubectl port-forward` 使用管理界面；不要误以为 HTTP-01 可以为 `*.local` 等内部名称获得公开证书。

不建议让每个 Traefik Pod 自己维护 `acme.json`；已有两个 Traefik 副本时，统一交给 cert-manager 管理 Kubernetes TLS Secret 更方便维护。

## 2. 网络拓扑与 IP/域名规划

### 2.1 原有集群假设

| 角色 | 主机名 | 示例 IP | 说明 |
|---|---|---|---|
| Master 1 | master-01 | 192.168.50.11 | K8s Control Plane / etcd |
| Master 2 | master-02 | 192.168.50.12 | K8s Control Plane / etcd |
| Master 3 | master-03 | 192.168.50.13 | K8s Control Plane / etcd |
| Worker 1 | worker-01 | 192.168.50.21 | Traefik / 业务 |
| Worker 2 | worker-02 | 192.168.50.22 | Traefik / 可观测性 |
| MetalLB 业务 VIP | traefik Service | **192.168.50.240** | `LoadBalancer` 的内网入口 |
| 互联网出口 | 路由器/防火墙 | **203.0.113.10（示例）** | 由网络管理员确认真实公网 IP |

**重要：** `192.168.50.240` 不是 Kubernetes API Server 的 VIP，不能与控制平面的 VIP 重复；MetalLB 地址必须在局域网可达、未被 DHCP 分配、没有其他设备占用。MetalLB L2 通常由一个节点宣告 VIP，后端 Traefik 可以运行多个副本。

### 2.2 域名与用途规划

| 域名（示例） | 适用网络 | 解析 / 可达目标 | 验证方式 |
|---|---|---|---|
| `api.example.com` | 公网业务（可选） | 公网 IP `203.0.113.10` → NAT → `192.168.50.240` | HTTP-01 或 DNS-01 |
| `grafana.ops.example.com` | **仅内网/VPN** | 私有 DNS → **内网入口** | DNS-01 |
| `openobserve.ops.example.com` | **仅内网/VPN** | 私有 DNS → **内网入口** | DNS-01 |

> **不能将公网 A 记录直接写成 `192.168.50.240`，期望互联网能访问。** RFC1918 私网 IP 无法在公共互联网路由。业务对外开放时，必须拥有可访问公网地址，并设置防火墙 NAT 或上游公网负载均衡。

> **内网 DNS 不等于安全隔离。** 如果 `api.example.com` 与 `grafana.ops.example.com` 共享同一个暴露在公网的 Traefik VIP，攻击者可以手工设置 `Host: grafana.ops.example.com` 绕过“内网 DNS 不公开”。生产中建议采用下列方式之一：
>
> ① 全部应用仅内网访问（最简单）；② 公网业务使用公网 Traefik，管理系统使用**另一个仅内网可达的 Traefik 实例/VIP**；③ 暂时不给管理系统配置 Ingress，仅通过堡垒机/VPN + `kubectl port-forward` 访问。额外的登录认证/访问白名单只能作为辅助措施，不能替代网络边界隔离。

### 2.3 建议选哪种模式

- **模式 A（最适合当前内部运维）：** 仅内网域名，MetalLB VIP `192.168.50.240`，内网 DNS 或 VPN DNS 解析它，DNS-01 申请证书，**不要在公网路由器上转发 80/443**。
- **模式 B（混合公网业务与内网运维）：** `api.example.com` 通过公网 IP/NAT 访问公网 Traefik；OpenObserve、Grafana 不共享公网入口，使用独立内部 Traefik/VIP 或 `port-forward`。本手册提供证书和路由模板，独立内部网关的副本和 LB 地址需另行部署。

## 3. 施工前检查清单

在有 `kubectl` 和 `helm` 权限的运维机执行：

```bash
kubectl get nodes -o wide
kubectl get ingressclass
kubectl get pods -A | grep -E 'traefik|metallb|cert-manager' || true
kubectl get svc -A | grep LoadBalancer || true
helm list -A
```

确认：

- `IngressClass` 名称为 `traefik`，并且 Traefik 的 `web`（80）/`websecure`（443）入口已启用。
- MetalLB IP 地址池、L2Advertisement 均已生效，Traefik 的 `Service` 类型为 `LoadBalancer`。
- DNS 域名已在真实 DNS 平台托管，具备添加 A/TXT 记录或创建 DNS API Token 的权限。
- 集群各节点有可靠时间同步，cert-manager Pod 可访问 ACME API 和所选 DNS 服务商 API（如使用 DNS-01）。
- 证书 TLS Secret 应放在**Ingress 所在的 namespace**；`ClusterIssuer` 引用的 DNS API Token Secret 默认放在 `cert-manager` namespace。

查找 Traefik 的实际命名空间、服务名和 VIP：

```bash
kubectl get svc -A | grep -i traefik
kubectl get ingressclass traefik -o yaml
# 以下命令中的 namespace/release 如与实际不同，请替换
kubectl -n traefik get svc
kubectl -n traefik get svc traefik -o wide
```

如果目前还没有 MetalLB IP 池配置，才使用以下示例。**已有生产 IP 池时不要覆盖或重复创建同名对象。**

`metallb-traefik-ip.yaml`：

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: traefik-public
  namespace: metallb-system
spec:
  addresses:
    - 192.168.50.240/32
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: traefik-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - traefik-public
```

```bash
# 已配置过同地址池则跳过；MetalLB 安装 namespace 不一定是 metallb-system
kubectl apply -f metallb-traefik-ip.yaml
kubectl -n metallb-system get ipaddresspools,l2advertisements
```

## 4. DNS 解析配置

### 4.1 公开业务域名 A 记录

以 `api.example.com` 为例，在 DNS 运营商控制台设置：

| 记录类型 | 主机记录 | 记录值 | TTL |
|---|---|---|---|
| A | `api` | `203.0.113.10`（**实际部署必须替换**） | 300 或自动 |

公网侧还必须配置路由器/防火墙：

```text
公网 TCP/80  → 192.168.50.240:80
公网 TCP/443 → 192.168.50.240:443
```

要求公网 IP 为真实可达地址；如果运营商处于 CGNAT、上级防火墙不开放端口，HTTP-01 无法按本方案验证，此时可选择 DNS-01（但业务公网访问仍需可达入口）。公网业务还应配置适当的 WAF、速率限制和访问日志。

**Cloudflare 用户注意：** 初次排查 HTTP-01 建议使用 DNS only（灰云）确保链路清晰；如果必须启用代理（橙云），需额外核对代理端口/规则/SSL 模式不会阻断 `/.well-known/acme-challenge/`。启用代理后 `dig` 得到 Cloudflare 的 IP 属于正常现象，无法直接据此判断你的源站公网 IP。

### 4.2 内网 / VPN 域名解析

内部 DNS（如企业 DNS、AdGuard Home、dnsmasq、内网 CoreDNS）增加：

| 记录类型 | 名称 | 目标 |
|---|---|---|
| A | `grafana.ops.example.com` | `192.168.50.240`（**仅模式 A：VIP 不对公网转发**） |
| A | `openobserve.ops.example.com` | `192.168.50.240`（**仅模式 A：VIP 不对公网转发**） |

模式 B 必须将以上目标改为**专用内网 Traefik VIP**，不能只靠私有 DNS 保护与公网共享的入口。需要从外部办公地点访问时，先连接 VPN，并确保 VPN 客户端使用企业内网 DNS。

测试：

```bash
# 在客户端安装 dnsutils：Ubuntu 可使用 sudo apt-get install dnsutils
nslookup grafana.ops.example.com
nslookup openobserve.ops.example.com

# 在内网或 VPN 下，应该解析为实际的内部入口 VIP
dig +short grafana.ops.example.com A

# 公网视角：验证真实公网业务域名的 A 记录
dig @1.1.1.1 +short api.example.com A
```

纯内网场景不要为管理域名公开一条指向管理 VIP 的 A 记录。DNS-01 只需要公开 DNS 区域支持自动创建 `_acme-challenge` TXT 记录，实际服务 A 记录可以仅存在内部 DNS。

### 4.3 一次性调试（不修改 DNS）

```bash
# 内网测试 SNI、Host 及 Traefik 路由（证书尚未签发时暂用 -k）
curl -vk --resolve grafana.ops.example.com:443:192.168.50.240 \
  https://grafana.ops.example.com/

# 对公网 DNS 排障，使用实际公网 IP，而不是示例地址
# curl -vk --resolve api.example.com:443:<真实公网IP> https://api.example.com/
```

`/etc/hosts` 可以短期调试，但**不适合作为团队长期 DNS 方案**，也不能代替 Let's Encrypt 的域名所有权验证。

## 5. 校验 Traefik TLS 和 HTTP 入口

从现有 Helm 安装导出配置：

```bash
# 根据 helm list -A 确认 release 的 namespace 和名称
helm -n traefik get values traefik -o yaml > traefik-values-backup.yaml
helm -n traefik get manifest traefik > traefik-manifest-backup.yaml
kubectl -n traefik get svc traefik -o yaml > traefik-svc-backup.yaml
```

需要在**原有完整的** `traefik-values.yaml` 中确认下面的关键字段（这是配置**片段**，不是可直接替换生产 values 的完整文件）：

```yaml
# 示例片段：与现有 Traefik Chart 版本 values 对照
providers:
  kubernetesIngress:
    enabled: true
    ingressClass: traefik

ports:
  web:
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
    exposedPort: 443
    expose:
      default: true

ingressClass:
  enabled: true
  name: traefik
  isDefaultClass: false
```

> 如果之前已按《Traefik 高可用网关部署方案》配置，这些字段通常已就绪，不需要重复部署。`allowACMEByPass` 可让 cert-manager 的 HTTP-01 Solver 路由正确处理 ACME challenge，不被入口级重定向抢占。**不要使用只有上面片段的文件直接执行 `helm upgrade -f`，可能意外重置副本、节点调度、资源限制和 LoadBalancer 配置。**

若确需修改，先确认版本、保留全部原 values，并做渲染校验：

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm -n traefik list
# 用 helm list / helm show chart 确认现有 Chart 版本，
# 然后先 helm template 渲染完整 values，评估 diff，安排维护窗口升级。
```

## 6. 安装 cert-manager（已安装则跳过）

参考官方 OCI Helm Chart。以下版本按 2026-11-03 已核对的官方文档示例；实际部署前应确认是否有更新的兼容版本，并在测试环境先验证。

```bash
helm upgrade --install cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --version v1.21.3 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait --timeout 10m

kubectl -n cert-manager get pods
kubectl get crd | grep cert-manager.io
kubectl -n cert-manager rollout status deploy/cert-manager
kubectl -n cert-manager rollout status deploy/cert-manager-webhook
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector
```

**已有 cert-manager 版本时不要直接运行 `helm upgrade` 覆盖配置；** 先记录 `helm get values`、Chart 版本，检查新旧版本兼容性与 CRD 升级说明。集群应只有一套受控 cert-manager 管理同一组资源。

## 7. 方案一：HTTP-01（适合公开业务域名）

### 7.1 前提

- `api.example.com` 的公共 A 记录指向实际公网入口。
- 外网 TCP/80 能到达 Traefik `web` 入口；证书申请只用 443 **不够**。
- Traefik `IngressClass=traefik`、`web` 80 正常、Solver Pod 可从 Traefik 访问。
- 不能用 HTTP-01 签发 `*.example.com` 通配符证书。

### 7.2 创建测试与生产 ClusterIssuer

`issuer-http01.yaml`：

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-http-staging
spec:
  acme:
    email: ops@example.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-http-staging-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-http-prod
spec:
  acme:
    email: ops@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-http-prod-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik
```

```bash
# 修改 email 为实际工作邮箱，再执行
kubectl apply -f issuer-http01.yaml
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-http-staging
```

## 8. 方案二：DNS-01（推荐管理域名，Cloudflare 示例）

本节以**权威 DNS 实际由 Cloudflare 管理的注册域名**为例。如果域名托管在阿里云 DNS、DNSPod 等，必须换成对应的 DNS-01 Solver/Webhook，不要套用 Cloudflare 配置。

### 8.1 创建最小权限 DNS API Token

在 Cloudflare 控制台创建 API Token，建议赋予：

- `Zone / DNS / Edit`
- `Zone / Zone / Read`
- Zone 资源：**仅选 `example.com`**，不要默认授权所有域名。

Token 只能由 cert-manager 管理员持有，不要提交到 GitLab，不能写进 `ClusterIssuer` 明文 YAML。

### 8.2 安全创建 Kubernetes Secret

在受信任的运维终端执行（`cert-manager` 为默认 Cluster Resource Namespace）：

```bash
umask 077
TOKEN_FILE="$(mktemp)"
read -r -s -p 'Cloudflare API Token: ' CF_API_TOKEN; echo
printf '%s' "$CF_API_TOKEN" > "$TOKEN_FILE"
unset CF_API_TOKEN

kubectl -n cert-manager create secret generic cloudflare-api-token-secret \
  --from-file=api-token="$TOKEN_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

rm -f "$TOKEN_FILE"
kubectl -n cert-manager get secret cloudflare-api-token-secret
```

避免将令牌放在 shell 历史记录、命令行文字或运维日志中。Secret 应启用 Kubernetes 静态数据加密、RBAC 限制、加密备份，并建立 Token 轮换流程。

### 8.3 创建 DNS-01 ClusterIssuer

`issuer-dns01-cloudflare.yaml`：

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns-staging
spec:
  acme:
    email: ops@example.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-dns-staging-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns-prod
spec:
  acme:
    email: ops@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-dns-prod-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
```

```bash
# 修改 email，并确认 DNS 的 NS 已指向 Cloudflare 权威 DNS
kubectl apply -f issuer-dns01-cloudflare.yaml
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-dns-staging
```

若 ClusterIssuer 的 `Ready=False`，先查看状态与 cert-manager 日志；部分 ACME 账户初始化也会影响就绪状态。DNS-01 签发时 cert-manager 会创建短暂的 TXT 记录 `_acme-challenge.<域名>`，不需要公网开放业务服务的 80/443。

## 9. 最小可用 HTTPS 测试（建议先测试，再上业务）

使用 HTTP-01 的公开 `api.example.com`，或 DNS-01 的内部域名执行一次 Staging 签发。以下采用内部 DNS-01 路线。

### 9.1 测试服务 Deployment/Service

`demo-whoami.yaml`：

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gateway-demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
  namespace: gateway-demo
spec:
  replicas: 1
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
            - name: http
              containerPort: 80
          resources:
            requests:
              cpu: 20m
              memory: 32Mi
            limits:
              cpu: 200m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: whoami
  namespace: gateway-demo
spec:
  selector:
    app: whoami
  ports:
    - name: http
      port: 80
      targetPort: http
```

```bash
kubectl apply -f demo-whoami.yaml
kubectl -n gateway-demo rollout status deployment/whoami
```

### 9.2 先使用 Staging 测试 HTTPS

`demo-whoami-ingress.yaml`：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami
  namespace: gateway-demo
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-dns-staging
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - whoami.ops.example.com
      secretName: whoami-staging-tls
  rules:
    - host: whoami.ops.example.com
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
# 确保 whoami.ops.example.com 在内网 DNS 解析到仅内部可访问的 Traefik VIP
kubectl apply -f demo-whoami-ingress.yaml
kubectl -n gateway-demo get ingress,certificate,certificaterequest,order,challenge
kubectl -n gateway-demo describe certificate whoami-staging-tls
kubectl -n gateway-demo get secret whoami-staging-tls

# Staging 签发的证书不被浏览器默认信任，测试时临时 -k
curl -vk --resolve whoami.ops.example.com:443:192.168.50.240 \
  https://whoami.ops.example.com/
```

> `whoami` 是临时调试服务，上生产前应删除。部分版本的镜像 Tag 可能被上游清理或更换，请部署前确认镜像仍可拉取，或使用公司镜像仓库中的经验证版本。

### 9.3 切换到正式证书（Production）

确认 Staging 流程完整通过后，将上面 Ingress 的：

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-dns-prod
spec:
  tls:
    - hosts:
        - whoami.ops.example.com
      secretName: whoami-prod-tls
```

**注意：上面是替换片段，不是完整 Ingress YAML；其余路由规则必须保留。**

```bash
# 修改完成后重新执行
kubectl apply -f demo-whoami-ingress.yaml
kubectl -n gateway-demo get certificates
kubectl -n gateway-demo describe certificate whoami-prod-tls

# 正式证书下不使用 -k，验证完整证书链及主机名
curl -v --resolve whoami.ops.example.com:443:192.168.50.240 \
  https://whoami.ops.example.com/
```

正式证书就绪后删除 Staging Certificate/旧 Secret 可以减少管理混淆，但删除前确认新路由和新 Secret 正常使用。**不要反复快速请求 Production 证书，避免触发 Let's Encrypt 速率限制。**

## 10. OpenObserve HTTPS 管理域名（仅模式 A / 独立内网网关）

已有 OpenObserve Standalone，部署在 `observability` namespace，假定 Service 是 `o2-openobserve-standalone:5080`。先验证：

```bash
kubectl -n observability get svc | grep -i openobserve
kubectl -n observability get endpointslices -l kubernetes.io/service-name=o2-openobserve-standalone
```

`openobserve-ingress.yaml`：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: openobserve-ui
  namespace: observability
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-dns-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
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

```bash
# 只有确认该 IngressClass 绑定的 Traefik VIP 不可从公网访问，才可以部署
kubectl apply -f openobserve-ingress.yaml
kubectl -n observability get ingress openobserve-ui
kubectl -n observability get certificate openobserve-ui-tls
kubectl -n observability describe certificate openobserve-ui-tls

curl -v https://openobserve.ops.example.com/
```

**重要安全边界：** 管理界面包含 API 和敏感日志查询功能，不能因其使用 HTTPS 就公开在互联网。OpenObserve Collector → OpenObserve 应保持使用集群内部 Service 的 OTLP/HTTP 接口，不要绕到公网 Traefik。若你的集群同时承载公网业务但目前只有一个公共 Traefik VIP，**暂时不部署此 Ingress**；使用以下方式更安全：

```bash
kubectl -n observability port-forward svc/o2-openobserve-standalone 5080:5080
# 经堡垒机/VPN 访问本地 http://127.0.0.1:5080
```

## 11. Grafana HTTPS 管理域名（仅模式 A / 独立内网网关）

如果沿用此前 `kube-prometheus-stack` release=`monitoring`，Grafana Service 通常为 `monitoring-grafana:80`，以实际查询为准：

```bash
kubectl -n observability get svc | grep -i grafana
```

`grafana-ingress.yaml`：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ui
  namespace: observability
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-dns-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - grafana.ops.example.com
      secretName: grafana-ui-tls
  rules:
    - host: grafana.ops.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: monitoring-grafana
                port:
                  number: 80
```

```bash
kubectl apply -f grafana-ingress.yaml
kubectl -n observability get certificate grafana-ui-tls
curl -v https://grafana.ops.example.com/login
```

如果 Grafana 配置了明确的外部地址，建议将 Helm values 的 `grafana.grafana.ini.server.root_url` 设为 `https://grafana.ops.example.com/`，避免 OAuth 回调、跳转或分享链接使用错误地址。变更需**合并至现有完整的 kube-prometheus-stack values 后**再按固定 Chart 版本执行 Helm 升级，不能只用这一项覆盖原配置。

## 12. 公网 Java 业务服务 HTTPS 示例（可选）

如果使用 HTTP-01，并已经配置公网 DNS/NAT：

`api-ingress.yaml`：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
  namespace: application
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-http-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - api.example.com
      secretName: api-example-com-tls
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 8080
```

部署前先使用 Staging 签发测试；`application` namespace、`api-service` 的名称和端口需要与你的实际 Spring Boot Service 相符。HTTPS 终止发生在 Traefik，后端是否使用 HTTP 或 mTLS 由你的内网安全要求决定；WebSocket 客户端使用 `wss://api.example.com/...`。

> 公网 DNS 名称仅表明路由身份；配套仍需应用认证、网关限流、适当的 CORS/Headers 策略、访问日志以及后端服务权限控制。不要通过公网 Ingress 直接暴露 `/actuator/prometheus`、Traefik Dashboard 或数据库管理端口。

## 13. 校验流程与验收标准

### 13.1 DNS 与连通性

```bash
# 公网业务：公共 DNS 应解析到真实公网 IP（下面示例地址需替换）
dig @1.1.1.1 +short api.example.com A

# 管理域名：只有内网/VPN DNS 应解析到内部 Traefik VIP
nslookup grafana.ops.example.com
nslookup openobserve.ops.example.com

# HTTPS 握手、状态码、证书验证
curl -Ivs https://grafana.ops.example.com/login
curl -Ivs https://openobserve.ops.example.com/
```

### 13.2 cert-manager 状态

```bash
kubectl get clusterissuer
kubectl -n observability get ingress,certificate,certificaterequest,order,challenge
kubectl -n observability describe certificate grafana-ui-tls
kubectl -n observability describe certificate openobserve-ui-tls
kubectl -n cert-manager logs deploy/cert-manager --tail=200
```

TLS Secret 内容（证书、公钥信息；避免输出私钥）：

```bash
kubectl -n observability get secret grafana-ui-tls \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -subject -issuer -dates -ext subjectAltName

# 直接检查 HTTPS 终端实际提供的证书（SNI 必须正确）
openssl s_client -connect grafana.ops.example.com:443 \
  -servername grafana.ops.example.com </dev/null 2>/dev/null | \
  openssl x509 -noout -subject -issuer -dates
```

**验收标准**：

- DNS 解析目标符合网络模式；公网不能访问内网管理界面。
- `ClusterIssuer Ready=True`，应用的 `Certificate Ready=True`。
- `curl` 不带 `-k` 也能通过证书校验，证书 SAN 覆盖实际域名。
- HTTP 入口按预期 301/308 跳转 HTTPS；HTTP-01 验证路径能正常由 Solver 处理。
- OpenObserve/Grafana 无公网泄露；证书过期预警和续期流程已验证。

## 14. 自动续期、备份与升级

### 14.1 自动续期

cert-manager 会在到期前按证书策略自动进行续签，无需写 cron 定期调用 ACME。不要把 Let's Encrypt 证书写死在 Helm values 或制作到镜像内。

```bash
kubectl -n observability get certificates -o wide
kubectl -n observability describe certificate grafana-ui-tls
kubectl -n observability get events --sort-by=.lastTimestamp | tail -40
```

建议使用 cert-manager 自带 Prometheus 指标以及 `cert-manager` 的证书到期时间序列，设置类似“证书剩余有效期不足 14 天”的告警；规则需与实际部署版本的指标名称和 Label 进行核对，验证至少能在剩余 7 天前通知运维。

### 14.2 必须备份的对象

1. 所有 ClusterIssuer / Issuer / Certificate / Ingress 清单与 Helm values（GitLab 保存**非敏感**配置）。
2. TLS Secret、ACME 账户 Secret、Cloudflare API Token Secret（加密备份，限制访问）。
3. cert-manager Helm Chart 版本、应用 Chart 版本和变更记录。
4. 业务应急接入方案和 DNS 服务商 Token 轮换权限。

**注意：** `kubectl get secret -o yaml` 也包含 Base64 编码的敏感材料，不能直接写到普通 Git 仓库。恢复到新集群时，按正确 namespace 恢复 Secret、Issuer 和 Ingress；若选择重新签发，需要顾及域名验证条件及 CA 签发频率限制。

### 14.3 DNS API Token 轮换

- 在 DNS 控制台创建新的最小权限 Token。
- 更新 `cert-manager/cloudflare-api-token-secret`，确认 Issuer 仍正常。
- 使用 Staging 或测试域名验证新 Token 可签发证书。
- 确认无依赖后撤销旧 Token，审查云端 Token 使用日志。

### 14.4 变更管理

推荐 GitLab 存储目录：

```text
infra/k8s/networking/
├── README.md
├── domains.md                       # 域名、用途、DNS归属、证书负责人
├── cert-manager/
│   ├── versions.env                 # Helm Chart 锁定版本
│   ├── issuer-http01.yaml
│   └── issuer-dns01-cloudflare.yaml
├── traefik/
│   └── traefik-values.yaml          # 完整原始 values，保留双副本/LB
└── ingress/
    ├── grafana-ingress.yaml
    ├── openobserve-ingress.yaml
    └── api-ingress.yaml
```

严格区分测试/生产环境，CI 先做 Helm 渲染和 YAML 校验，再人工审核并应用。生产升级必须先保存当前 Helm release 和当前生效配置，避免重装证书管理导致误删 CRD/证书。

## 15. 常见问题与故障排查

| 现象 | 可能原因 | 排查动作 |
|---|---|---|
| 域名无法解析 | A 记录错误 / DNS 缓存 / 内网 DNS 没分发 | `dig`、`nslookup`，核对权威 NS 与客户端 DNS |
| `EXTERNAL-IP` Pending | MetalLB 池/宣告不匹配 | `kubectl get svc -A`、查看 IPAddressPool/L2Advertisement |
| 443 连接超时 | VIP 不可达、防火墙、NAT 错误 | 在 LAN 上先 `curl --resolve`，再测公网 |
| 页面返回 Traefik 404 | IngressClass、Host、entryPoint、后端路由不匹配 | `kubectl describe ingress`、Traefik 日志 |
| 页面返回 502/503 | Service 无就绪 Endpoint 或端口错误 | `kubectl get endpointslice`、检查后端 Pod |
| 浏览器证书不受信任 | 使用了 Staging 或旧 Secret | 核对 Issuer、Certificate、实际 SNI 下返回的证书 |
| HTTP-01 签发失败 | 公网 80 未通、ACME Solver 被拦截/重定向 | 查 `Challenge`，验证 `allowACMEByPass`、NAT 和 NetworkPolicy |
| DNS-01 一直 Pending | Token 权限不足、权威 DNS 未指向目标、TXT 未传播 | `kubectl describe challenge`、`dig TXT`、cert-manager 日志 |
| `secret not found` | TLS Secret 尚未签发或 namespace 错误 | `kubectl -n <ns> get certificate,secret` |
| 证书续期失败 | DNS Token 过期、API 无法访问、限流 | 验证 Token、出口网络、Issuer 状态和告警 |
| 内网域名却能从公网访问 | 公私共享 VIP，DNS 被误当安全机制 | 立即撤销管理 Ingress / 限制公网入口，迁移独立私有 VIP |

进一步排查：

```bash
kubectl -n cert-manager logs deploy/cert-manager --tail=200
kubectl -n cert-manager get pods -o wide
kubectl -n observability get certificates,orders,challenges
kubectl -n observability describe challenge <challenge-name>
kubectl -n observability get events --sort-by=.lastTimestamp | tail -30

# DNS-01 的 TXT 记录仅在验证窗口暂时出现，正常签发后会删除
# 在 Challenge Pending 时执行：
dig @1.1.1.1 TXT _acme-challenge.grafana.ops.example.com

# Traefik 实际 namespace/release 以现场为准
kubectl -n traefik logs deploy/traefik --tail=200
```

**切勿**为了“快速解决证书错误”在正式服务客户端永久禁用证书验证（例如 `curl -k`、Java 全局忽略证书校验），也不要临时暴露管理界面的公网入口。

## 16. 最终实施顺序（操作检查表）

- [ ] 确认域名的权威 DNS 运营商和实际环境（公网/内网/VPN）。
- [ ] 确认 MetalLB VIP、Traefik 80/443 与 IngressClass 的当前状态。
- [ ] 先决定网关是**纯内网**还是**公私分离**，不要公网 VIP 直接承载私有管理路由。
- [ ] 配置 A 记录或内部 DNS 记录；公网业务需要额外检查 NAT/安全组/防火墙。
- [ ] 安装或核实 cert-manager，记录版本和 CRD 状态。
- [ ] 推荐先创建 DNS-01 Staging/Production ClusterIssuer，Token 仅授权指定 Zone。
- [ ] 通过 Whoami 在 Staging 环境验证 DNS-01 或 HTTP-01 签发。
- [ ] 切换正式证书并使用不带 `-k` 的 curl 检验证书链。
- [ ] 管理入口只在允许的私有网络配置；或继续使用 `port-forward`。
- [ ] 配置 OpenObserve、Grafana 或 Java API 的 Ingress。
- [ ] 添加证书过期、续期失败、Traefik 错误率、VIP 可达性告警。
- [ ] 对备份恢复、DNS Token 轮换和网络故障执行一次演练。

## 17. 官方参考文档

- cert-manager Helm 安装：<https://cert-manager.io/docs/installation/helm/>
- cert-manager HTTP-01：<https://cert-manager.io/docs/configuration/acme/http01/>
- cert-manager Cloudflare DNS-01：<https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/>
- cert-manager Ingress 注解签发：<https://cert-manager.io/docs/usage/ingress/>
- cert-manager Issuer 与 ClusterIssuer Secret namespace：<https://cert-manager.io/docs/configuration/>
- Traefik Kubernetes Ingress：<https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/ingress/>
- Traefik Helm Chart：<https://github.com/traefik/traefik-helm-chart>
- MetalLB 配置：<https://metallb.io/configuration/>
- Let's Encrypt HTTP-01 / DNS-01：<https://letsencrypt.org/zh-cn/docs/challenge-types/>

---

**本手册的默认落地建议**：如果 OpenObserve 和 Grafana 是公司内部运维平台，先采用**内部 DNS + cert-manager DNS-01 + 仅内网可达的 Traefik VIP**。未来如需将 Java API 公网开放，优先为公网业务建设独立入口，避免管理面被错误暴露。
