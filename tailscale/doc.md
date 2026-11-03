[Tailscale_KubeKey_Traefik_内网互通部署与运维方案.md](https://github.com/user-attachments/files/34310670/Tailscale_KubeKey_Traefik_.md)
# Tailscale 内网互通部署与运维方案

> 适用环境：KubeKey 4.x 自建 Kubernetes（3 Master + 2 Worker）、Calico、MetalLB、Traefik、cert-manager、Grafana、OpenObserve。  
> 文档版本：1.0；编写日期：2026-11-03。  
> 设计目标：远程安全访问机房运维服务；运维简单；与现有 Kubernetes 解耦；允许单路由器故障时切换。  
> **说明：本文中的 IP、域名、账号均为示例，务必替换。不要直接执行示例地址的网络配置。**

## 1. 选型结论

优先方案：**两台独立 Ubuntu 24.04 服务器/虚拟机运行 Tailscale Subnet Router + Tailnet Grants 最小权限 + Split DNS + 现有 Traefik HTTPS**。

- **不要**在每个 Kubernetes Pod 或每台 Worker 上安装 Tailscale。第一阶段不需要 Tailscale Operator。
- **不要**暴露 Kubernetes API Server、Node SSH、Grafana 或 OpenObserve 端口到公网。
- **不要**把整个 Kubernetes Pod CIDR 或 Service CIDR 加入 Tailscale 广告路由；访问 Web 服务统一走 MetalLB VIP 与 Traefik。
- 初期只发布 HTTPS VIP 和内网 DNS 的 `/32` 路由；确需 SSH 时另行开放特定管理节点，或在风险评估后扩大网段。
- 这里的“内网打通”第一阶段是**远程个人设备 → 机房内网**，第二阶段才扩展为**办公室/异地机房之间的双向站点互通**。两者的 NAT 与路由设计不同。

## 2. 规划前提与网络地址

| 项目 | 示例值 | 注意事项 |
|---|---|---|
| K8s 物理网络 | `192.168.50.0/24` | 现有自建机房网络，确认与外部人员家用网段不冲突 |
| Traefik MetalLB VIP | `192.168.50.240` | 使用先前规划的业务入口 VIP，**非 Kubernetes API VIP** |
| Subnet Router A | `192.168.50.250` | 独立 Linux VM / 物理机，固定 IP |
| Subnet Router B | `192.168.50.251` | 独立 Linux VM / 物理机，固定 IP |
| 内网 DNS | `192.168.50.53` | 可使用现有路由器/企业 DNS/独立 DNS 服务；没有时先不配置 Split DNS |
| 运维域名 | `grafana.ops.example.com` | 内网 A 记录指向 `192.168.50.240` |
| 运维域名 | `openobserve.ops.example.com` | 内网 A 记录指向 `192.168.50.240` |
| 运维域名 | `argocd.ops.example.com` | 可选，内网 A 记录指向同一 VIP |
| Tailnet | 使用组织自己的 Tailscale 网络 | 建议企业身份源/MFA/设备审批 |

**必须核对：** `192.168.50.250`、`.251` 和 `.53` 是否真的空闲；网络是否为同一二层或存在正确路由；路由器到 MetalLB VIP 的 TCP 443 是否可达。预留地址应移出 DHCP 地址池；远端常见家庭网络若也使用 `192.168.50.0/24`，应调整远端网段或对发布路由做更精确的规划。

### 流量路径

```text
Mac / Windows (Tailscale Client)
    → 加密 Tailnet（直连或 DERP 中继）
    → Subnet Router A / B（独立 Ubuntu）
    → 192.168.50.240:443（MetalLB）
    → Traefik Ingress
    → grafana / openobserve / argocd Service
```

Tailscale 自动进行 NAT 穿透尝试；无法直连时可能使用 DERP 中继，公网出口无需主动开放入站 443/SSH/API Server。公司防火墙仍需允许客户端、子网路由器向 Tailscale 所需控制面/中继服务发起出站通信。

## 3. 部署模式选择

| 模式 | 特征 | 是否推荐 |
|---|---|---|
| 每台服务器安装 Tailscale | 服务器节点众多、设备治理复杂 | 初期不推荐 |
| Tailscale Kubernetes Operator | 原生 CRD 暴露服务、精细化服务接入 | 后期按需采用 |
| **独立 Subnet Router** | 不修改 K8s CNI，直接访问内网 VIP | **首选** |
| 双路由器发布同一前缀 | 故障转移 | **建议生产部署** |
| Site-to-site 双向路由 | 办公网与机房互相访问，需网关静态路由 | 第二阶段 |

### 建议资源

每台子网路由器可从 `1～2 vCPU、1～2 GiB 内存、16～20 GiB 磁盘、Ubuntu 24.04` 起步。真实容量需根据并发用户数、流量、是否经 DERP 转发以及 CPU 加密能力压测确定。两台路由器尽量位于不同物理宿主机、电源或故障域。**不要将每日 20 GB 的集群日志采集链路经由 Tailscale**；Tailscale 在此只承载人员访问运维后台，不参与集群内部日志写入。

## 4. 部署前检查

在每台子网路由器上执行：

```bash
hostnamectl
ip -br address
ip route
ping -c 3 192.168.50.240
curl -kIv --connect-timeout 5 https://192.168.50.240/ || true
```

最后一条用来测试 TCP/TLS 可达性，证书的主机名不匹配是预期现象。若要验证真实 SNI/证书：

```bash
curl -Iv --resolve grafana.ops.example.com:443:192.168.50.240 \
  https://grafana.ops.example.com/
```

路由器安装时应具有稳定的内网静态 IP（按之前的 Netplan 配置手册逐台应用）、正常 DNS、NTP 和公网出站能力。若有 UFW/iptables/nftables 自定义规则，必须允许 `tailscale0 → LAN` 的转发并按安全基线检查，不能因为装了 Tailscale 就认为现有防火墙自动放行。

## 5. 安装 Tailscale Subnet Router

**本章节在两台 Ubuntu 24.04 子网路由器上分别执行**。优先使用官方 apt 软件源及固定版本管理；以下官方快速安装脚本适合初始化验证。

```bash
sudo apt-get update
sudo apt-get install -y curl ca-certificates
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale version
```

启用内核 IPv4 转发：

```bash
cat <<'SYSCTL' | sudo tee /etc/sysctl.d/99-tailscale-subnet.conf
net.ipv4.ip_forward = 1
SYSCTL
sudo sysctl --system
sysctl net.ipv4.ip_forward
```

在各自的终端登录 Tailnet：

```bash
sudo tailscale up
```

输出设备授权 URL 后，在浏览器中登录 Tailscale 管理账号完成设备注册。不要把长期有效的 auth key 写入共享脚本或 GitLab 仓库。

**第一阶段仅开放 Traefik VIP 与 DNS 两个 `/32` 地址：**

```bash
sudo tailscale set \
  --advertise-routes=192.168.50.240/32,192.168.50.53/32

sudo tailscale status
sudo tailscale ip -4
```

如果暂时没有独立内网 DNS，则先只宣告业务 VIP：

```bash
sudo tailscale set --advertise-routes=192.168.50.240/32
```

> **HA 注意：** A/B 两台路由器都必须发布**完全相同**的前缀。这个阶段保持默认 SNAT 开启，不在冗余路由器上设置 `--accept-routes`；否则备机可能错误地从主机绕行到本地子网。默认 SNAT 可简化返回路由，代价是后端看到的源 IP 可能是子网路由器的 LAN IP。

## 6. 在管理控制台批准子网路由

打开 [Tailscale Admin Console — Machines](https://login.tailscale.com/admin/machines)：

1. 找到两台子网路由器，并确认其属于组织 Tailnet。
2. 打开设备的 **Edit route settings / Review subnet routes**。
3. 分别批准 `192.168.50.240/32` 和 `192.168.50.53/32`（未部署 DNS 时忽略后者）。
4. 两台路由器需要批准**相同的前缀集合**；否则路由故障切换可能不生效。
5. 对长期运行的可信路由设备，结合组织安全政策管理设备密钥有效期、设备所有者和设备审批；禁用设备密钥到期需明确治理责任。
6. 测试客户端到两个路由器及 VIP 的连通性。

**路由获批准 != 任意用户获准访问。** 还需要配置 Tailnet Grants，以及目标服务器的网络防火墙/应用认证。

## 7. 设置 Tailnet Grants 最小权限

在 [Access controls](https://login.tailscale.com/admin/acls) 编辑并验证规则。以下是**替换式示例**，不可无检查地覆盖生产中已有策略。请将邮箱替换为真实的已加入 Tailnet 用户：

```json
{
  "groups": {
    "group:ops": ["ops1@example.com", "ops2@example.com"]
  },
  "grants": [
    {
      "src": ["group:ops"],
      "dst": ["192.168.50.240/32"],
      "ip": ["tcp:443"]
    },
    {
      "src": ["group:ops"],
      "dst": ["192.168.50.53/32"],
      "ip": ["udp:53", "tcp:53"]
    }
  ]
}
```

- 如 Tailnet 已存在其他 Grants、SSH 规则、tags 或自动批准规则，应**合并**而不是直接替换。
- 需移除不符合最小权限的默认 `allow all` ACL，否则新增 Grants 不能实现预期隔离。
- 若只允许两位运维访问 Grafana 与 OpenObserve，上述规则可限制为内网 VIP 的 `443`，但**不能区分同一 VIP:443 上不同 Hostname**：所有通过该 VIP 暴露的站点都共享网络访问入口。Grafana、OpenObserve 仍需强身份认证，建议通过 Traefik ForwardAuth/OIDC 或外部访问代理进一步控制。
- 不应仅靠私有 DNS 名称实现安全隔离，也不能把 HTTPS 证书当成认证和授权。
- 需要 SSH/控制平面访问时，对指定 K8s 节点 IP 追加 `/32` 广告路由，并使用独立运维组限制 `tcp:22`、`tcp:6443`；保留主机侧防火墙与 SSH 密钥认证。

## 8. 远程客户端接入

### Mac / Windows

安装官方客户端并登录同一 Tailnet。子网路由被批准后，一般会自动接收相关路由。实际是否生效需检查客户端路由与本地防火墙。

### Linux

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
sudo tailscale set --accept-routes=true

tailscale status
ip route get 192.168.50.240
curl -Iv --resolve grafana.ops.example.com:443:192.168.50.240 \
  https://grafana.ops.example.com/
```

`tailscale ping <router-A 的 Tailscale 地址或名称>` 用于诊断尾网端到端连通性；访问 VIP 的 TCP 443 仍需独立验证。

## 9. 内网 DNS、MagicDNS 与 HTTPS

### 9.1 DNS 建议

- **MagicDNS** 主要用于解析 **Tailnet 内已注册设备** 的名称，不会自动为 `grafana.ops.example.com` 这样的自有域名创建业务 A 记录。
- 在现有内部 DNS `192.168.50.53` 添加：

```dns
# 逻辑示例：请在现有 DNS 管理平台创建对应 A 记录
# grafana.ops.example.com      A 192.168.50.240
# openobserve.ops.example.com  A 192.168.50.240
# argocd.ops.example.com       A 192.168.50.240
```

- 在 Tailscale Admin Console → **DNS** 中，为 `ops.example.com` 设置 **Restricted nameserver / Split DNS**，目标为 `192.168.50.53`。
- `192.168.50.53/32` 必须是已批准并可通过 Tailnet 到达的地址，DNS 防火墙需允许 UDP/TCP 53。
- 如果 DNS 服务部署在某个不同网段，需要额外发布其地址、打通路由和 ACL。
- 验证：`nslookup grafana.ops.example.com`、macOS `dscacheutil -q host -a name grafana.ops.example.com`。

### 9.2 HTTPS 证书

继续采用前一阶段的 **Traefik + cert-manager + Let's Encrypt DNS-01**：

- `grafana.ops.example.com` 和 `openobserve.ops.example.com` 解析到**内网** VIP `192.168.50.240`。
- 使用公共域名的**公有 DNS 区域**进行 DNS-01 TXT 所有权验证，证书可正常向 Let's Encrypt 申请；DNS-01 **不要求**管理站点对公网开放 80/443。
- 公网 DNS 无需为内部管理服务公布内网 VIP 的 A 记录；使用 Split DNS 返回私有 IP。
- Kubernetes Ingress 的 TLS Secret 由 cert-manager 维护，证书终止仍在 Traefik；Tailscale 负责网络隧道，不负责这批自定义业务域名的证书签发。

示例 Ingress（仅供确认现有配置）：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-internal
  namespace: monitoring
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - grafana.ops.example.com
      secretName: grafana-ops-tls
  rules:
    - host: grafana.ops.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 80
```

请将示例 `grafana` Service 名称和端口改为 `kubectl -n monitoring get svc` 显示的真实值。若已有 Grafana Ingress，不必创建第二份冲突的 Ingress。**不要在公网路由器上将 VIP:443 转发到公网**，管理站点也需做 Traefik 主机访问限制/独立入口隔离。

## 10. 高可用和故障演练

两台独立 Subnet Router 对相同 `/32` 路由完成批准后，Tailscale 可在活动路由器不可用时选择备用路由器；切换通常不是零中断。官方旧版 HA 说明给出大约 15 秒级别的切换量级，实际应通过现场演练测量。

建议先确认 A/B 两台设备均能从 LAN 到达 MetalLB VIP，再执行：

```bash
# 在远端已连接 Tailnet 的客户端持续测试
while true; do
  date
  curl -sS -o /dev/null -w '%{http_code} %{time_total}s\n' \
    --max-time 5 https://grafana.ops.example.com/ || true
  sleep 2
done
```

在维护窗口停止 A 的 `tailscaled`，观察请求恢复，然后重新启动 A：

```bash
# Router A，维护窗口内执行
sudo systemctl stop tailscaled
# 验证备用路由工作后恢复
sudo systemctl start tailscaled
sudo tailscale status
```

若两台路由器本身共享同一个物理宿主机、交换机或出口，则仍存在共同故障点。MetalLB VIP 和 Traefik 的高可用需单独测试：Tailscale 子网路由冗余不能替代 Kubernetes 的入口高可用。

## 11. 第二阶段：办公网 ↔ 机房网双向互通（可选）

仅在确实需要**办公室内任意设备 ↔ 机房内任意设备**互通时启用。示例：

| 站点 | 子网 | 站点路由器 |
|---|---|---|
| 机房 A | `192.168.50.0/24` | `192.168.50.250` |
| 办公室 B | `192.168.60.0/24` | `192.168.60.250` |

原则：

1. 两个网段**不能冲突**；每个站点至少一台 Linux 子网路由器，启用 `net.ipv4.ip_forward=1`。
2. 在 A 站点路由器发布 `192.168.50.0/24`，在 B 发布 `192.168.60.0/24`。
3. 此时为了保留原始两端 LAN IP，按官方站点互通模式配置 `--snat-subnet-routes=false` 和对端路由接收 `--accept-routes`。
4. 在两个 LAN 的**默认网关或三层交换机**分别添加指向对端网段的静态路由：A 的网关将 `192.168.60.0/24` 指向 `192.168.50.250`；B 的网关将 `192.168.50.0/24` 指向 `192.168.60.250`。若不控制默认网关，就不能把这种模式称为“整个办公室透明互通”。
5. 双方向设置 Tailnet Grants 与网关防火墙转发规则，检查 MSS/MTU、回程路由和跨站点 DNS。
6. 若 A 站点同时部署两台**同前缀的 HA Router**，不可直接对这两台打开 `--accept-routes` 而不验证本地路由，避免备用节点经主节点绕行。应先单路由器完成双向联通，再进行冗余与路由策略评估。
7. 网关静态路由指向的单个地址也是故障点；若办公网双向互通要求 HA，需要额外设计网关冗余或动态路由，不能仅靠在 Tailnet 上加第二台路由器实现端到端 HA。

在 A 路由器单节点测试场景：

```bash
sudo tailscale set \
  --advertise-routes=192.168.50.0/24 \
  --snat-subnet-routes=false \
  --accept-routes=true
```

在 B 路由器单节点测试场景：

```bash
sudo tailscale set \
  --advertise-routes=192.168.60.0/24 \
  --snat-subnet-routes=false \
  --accept-routes=true
```

> **这两条命令属于替代的第二阶段配置，不可在第一阶段未做好静态路由时直接照搬。** 它们会替换原先广告的 `/32` 路由，需要重新审核路由和访问权限。强烈建议单独变更窗口测试。

## 12. 日常运维 SOP

| 频率 | 操作 | 示例命令/入口 |
|---|---|---|
| 持续 | 监控 `tailscaled` 服务和业务 HTTPS 可达性 | `systemctl is-active tailscaled`；外部探测 |
| 每周 | 审查设备在线状态、未批准设备、异常密钥和路由 | Admin Console / Machines |
| 每月 | 审查 Tailnet Grants、组织成员、设备授权 | Admin Console / Access controls |
| 每月 | 操作系统与 Tailscale 安全更新 | `sudo apt-get update && sudo apt-get upgrade`，逐台执行 |
| 每季度 | 模拟 Router A 下线，验证 Router B 自动接管 | 故障演练记录 |
| 每季度 | 测试内网 DNS 和 HTTPS 证书续期 | `dig`、`curl -Iv`、`kubectl get certificate -A` |

建议把 Tailnet 权限策略保存在 GitLab，采用 Review/Merge Request 审批，不要提交任何 auth key、OAuth Secret 或私钥。对两台 Subnet Router 配置宿主机监控、磁盘告警、时间同步以及防火墙变化审计。

常用诊断：

```bash
sudo tailscale status
tailscale ip -4
tailscale netcheck
ip route
sysctl net.ipv4.ip_forward
sudo systemctl status tailscaled --no-pager
sudo journalctl -u tailscaled -n 100 --no-pager
```

### 故障检查顺序

| 故障 | 优先检查 |
|---|---|
| Tailscale 能连、VIP 无法访问 | 路由批准、Grants、LAN 可达性、防火墙 FORWARD |
| IP 能访问，域名无法解析 | Split DNS、DNS 服务器是否可达、DNS 端口 ACL、A 记录 |
| IP 和域名可访问，HTTPS 报错 | Traefik Host 路由、TLS Secret、cert-manager Certificate |
| 只能从一台路由器访问 | 两台是否宣告**完全相同**的前缀、管理员是否均批准 |
| 客户端本地网络也是 `192.168.50.0/24` | 网络重叠，调整路由或网段规划 |
| 跨办公室一端能连另一端不能 | SNAT、回程静态路由、网关防火墙、ACL |
| 慢或连接不稳 | `tailscale netcheck`、直连/DERP、丢包、链路 MTU、CPU |

## 13. 上线验收清单

- [ ] 两台 Subnet Router 有稳定内网静态 IP，且不与 DHCP/MetalLB VIP 冲突。
- [ ] 两台路由器 `tailscaled` 自启、IPv4 转发开启。
- [ ] 两台均宣告且获批**完全一致**的 VIP `/32`（和 DNS `/32`）路由。
- [ ] 非授权 Tailnet 用户无法访问 `192.168.50.240:443`。
- [ ] 授权人员可通过 Mac/Windows/Linux Tailscale 访问 `grafana.ops.example.com` 和 `openobserve.ops.example.com`。
- [ ] 所有管理站点具有有效 HTTPS，应用自身认证与角色控制已启用。
- [ ] 公网防火墙没有开放 SSH、Kubernetes API 和内部运维系统管理端口。
- [ ] Router A 失效时经 Router B 恢复，记录实际故障切换时长。
- [ ] Prometheus/Grafana 对两个 Router 的存活和访问端点有告警；告警不完全依赖被监控的 Tailscale 访问链路。
- [ ] Tailnet ACL/Grants 已经 Review 并存档，敏感凭据没有进入 GitLab 明文仓库。

## 14. 官方参考资料

- Linux 安装：https://tailscale.com/docs/install/linux
- Subnet Router：https://tailscale.com/docs/features/subnet-routers/how-to/setup
- 子网路由 HA：https://tailscale.com/docs/how-to/set-up-high-availability
- Site-to-site：https://tailscale.com/docs/features/site-to-site
- Tailnet Grants：https://tailscale.com/docs/features/access-control/grants
- DNS / Split DNS：https://tailscale.com/docs/reference/dns-in-tailscale
- Kubernetes Operator（可选）：https://tailscale.com/docs/kubernetes-operator

---

**最终建议：** 当前先做**远程运维设备→Traefik 入口 VIP**，范围小、故障面小、权限清晰。等远程运维稳定后，再按真实需求接入 SSH/API 节点或异地办公网。整个过程不改变 KubeKey / Calico / Longhorn / OpenObserve 的部署结构。
