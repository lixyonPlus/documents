[Uploading JumpServer_堡垒机_部署实施与安全运维方案.md…]()
# JumpServer 堡垒机部署实施与安全运维方案

> **适用环境**：Ubuntu 24.04 LTS + JumpServer Community Edition + Tailscale + KubeKey Kubernetes（3 Master / 2 Worker）  
> **文档版本**：v1.0 | **编写日期**：2026-11-03  
> **推荐基线**：JumpServer v5.1.1（撰写时已核实的 V5 正式版本；上线前重新检查安全公告）  
> **适用人员**：平台管理员、Kubernetes 运维、系统安全审计人员  
> **实施原则**：堡垒机放在 K8s 集群外、最小暴露、每人独立账号、强制 MFA、默认拒绝、可审计、可恢复。

---

## 目录

1. [建设目标与选型结论](#1-建设目标与选型结论)
2. [目标架构与访问路径](#2-目标架构与访问路径)
3. [节点、资源和网络规划](#3-节点资源和网络规划)
4. [部署准备和主机加固](#4-部署准备和主机加固)
5. [安装 JumpServer Community](#5-安装-jumpserver-community)
6. [接入 Tailscale 和最小访问权限](#6-接入-tailscale-和最小访问权限)
7. [内网 DNS 与 HTTPS](#7-内网-dns-与-https)
8. [账号、资产和授权策略](#8-账号资产和授权策略)
9. [接入 Kubernetes 和日常操作方式](#9-接入-kubernetes-和日常操作方式)
10. [会话录像、审计和告警](#10-会话录像审计和告警)
11. [备份与灾难恢复](#11-备份与灾难恢复)
12. [升级、扩容和维护 SOP](#12-升级扩容和维护-sop)
13. [安全加固清单](#13-安全加固清单)
14. [上线测试与验收](#14-上线测试与验收)
15. [应急预案与常见故障](#15-应急预案与常见故障)
16. [实施计划与交付物](#16-实施计划与交付物)
17. [风险与边界](#17-风险与边界)
18. [官方参考资料](#18-官方参考资料)

---

## 1. 建设目标与选型结论

### 1.1 建设目标

- 运维人员在外网通过 **Tailscale** 加密网络访问 JumpServer；不向互联网开放堡垒机 Web、KoKo SSH、K8s API、节点 SSH。
- 统一管理五台 K8s 服务器的 SSH / SFTP 访问和日志审计；后续按需接入其他 Linux 主机。
- 使用个人 JumpServer 账号、强制 MFA、资产授权、操作留痕与会话回放。
- Kubernetes 资源操作优先通过有限权限的 K8s 资产功能；完整 `kubectl` 工作流应另设受控运维主机和 Kubernetes RBAC。
- 单节点优先，以简单、可备份、可恢复为核心；接受计划维护窗口和短暂中断。

### 1.2 版本和部署方式

**推荐：JumpServer Community Edition v5.1.1 + 官方 Docker Compose 安装方式 + 独立 Ubuntu 虚拟机。**

- 不在被管理的 Kubernetes 集群内部部署 JumpServer，以免集群故障导致运维入口失效。
- 单节点方案使用安装器内置 PostgreSQL 和 Redis；不额外搭建 HA PostgreSQL、Redis、NFS、MinIO、Elasticsearch。
- 使用官方 `jmsctl.sh` 管理安装、备份、服务与升级，不直接修改生成的 Compose 文件作为常规运维方式。
- 社区版支持 SSH、Web Terminal、基础资产与审计、Kubernetes 资产访问等能力；**高级多租户、自定义角色和部分企业级能力以官方版本功能矩阵为准**。不假定社区版拥有所有企业功能。

### 1.3 为什么不选双节点 HA

当前只有少量运维人员且能接受短暂中断。双节点 HA 还需要外部数据库、缓存、共享/对象存储以及负载均衡，本质上增加故障点。若以后达到“堡垒机故障不能阻断运维”的 SLA，再建设 HA。

---

## 2. 目标架构与访问路径

```text
远程运维人员（Mac / Windows）
  ├── 公司身份账号 + MFA
  └── Tailscale 客户端
          │ WireGuard/Tailscale 加密链路
          ▼
  Tailnet 内的 JumpServer（独立 VM，不在 K8s 中）
  jump.ops.example.com  → Tailscale IP（100.x.y.z，动态分配示例）
  ┌─────────────────────────────────────────────┐
  │ JumpServer Community                        │
  │ Web/Core : HTTPS 443                         │
  │ KoKo     : TCP 2222（有需要才向运维用户开放） │
  │ PostgreSQL/Redis : 仅内部容器网络             │
  │ 会话审计/录像 : 本机持久化 + 异机备份         │
  └──────────────────┬──────────────────────────┘
                     │ 物理/虚拟内网：SSH 22
                     ▼
         KubeKey Kubernetes 集群
     192.168.50.11  k8s-master-01
     192.168.50.12  k8s-master-02
     192.168.50.13  k8s-master-03
     192.168.50.21  k8s-worker-01
     192.168.50.22  k8s-worker-02
                     │
          受控 Kubernetes 访问
                     ▼
      Kubernetes API VIP（独立地址）:6443

其他运维界面 Grafana / OpenObserve / Argo CD
  继续使用原有 Tailscale Subnet Router → MetalLB VIP → Traefik 443
  不强制让这些 Web 控制台再经过 JumpServer 转发。
```

**重要：** 跳板机上的 Tailscale 是“设备直连”用途；不在 JumpServer 上宣告 `192.168.50.0/24` 子网路由，也不启用 Exit Node。既有独立 Subnet Router 仅承担 Grafana 等 HTTPS 内网入口访问。

**故障隔离：** JumpServer 故障时，预留一条**单独保护的带外/KVM/应急 SSH** 路径，防止单点故障造成无法恢复。

---

## 3. 节点、资源和网络规划

### 3.1 主机规格

| 项目 | 推荐起步 | 说明 |
|---|---:|---|
| 主机 | 独立 Ubuntu 24.04 LTS VM | 避免与 K8s、业务混部 |
| CPU | 4 vCPU | 官方安装最低规格 4 核 |
| 内存 | 16 GiB | 官方最低 8 GiB，预留审计和容器峰值 |
| 系统盘 | 60 GiB SSD | OS、镜像与运行时 |
| 数据盘 | 200–300 GiB SSD | `/data/jumpserver`，录像增长后再扩容 |
| 单节点可用性 | 无自动 HA | 主机故障需要修复/恢复 |
| 运维人员 | 初期约 2–10 人 | 不是性能承诺；以并发及录像实测为准 |

**容量提醒：** 你此前提到的 **20 GB/天是应用日志量**，**不是堡垒机会话录像量**，不能直接用 20 GB/天乘以保留天数计算 JumpServer 磁盘。上线一周后统计录像实际增长速度，再定容量与保留策略。

### 3.2 IP 与域名（全部为示例，必须替换）

| 对象 | 示例 | 用途 |
|---|---|---|
| JumpServer LAN | `192.168.50.253` | 连接 K8s 主机与内部管理网络 |
| JumpServer Tailnet | `100.x.y.z` | 仅运维人员通过 Tailscale 访问 |
| JumpServer 域名 | `jump.ops.example.com` | 仅 Split DNS 或受管终端解析到 Tailnet IP |
| Traefik MetalLB VIP | `192.168.50.240` | Grafana 等内部 Web 管理平台 |
| K8s API VIP | `<K8S_API_VIP>` | Kubernetes 6443，**不可与 MetalLB VIP 相同** |
| 备份服务器 | `<BACKUP_SERVER_IP>` | 接收加密备份，独立故障域 |

### 3.3 网络端口矩阵

| 源 | 目标 | 协议/端口 | 策略 |
|---|---|---|---|
| 已审批运维终端（Tailnet） | JumpServer Tailnet IP | TCP 443 | 必须允许 |
| 已审批运维终端（Tailnet） | JumpServer Tailnet IP | TCP 2222 | 仅需原生 SSH 终端时开放 |
| 指定主机管理员（Tailnet/LAN） | JumpServer 宿主机 | TCP 22 | 仅管理员维护服务器时允许 |
| JumpServer LAN IP | 5 个 K8s 节点 | TCP 22 | 必须允许，主机 SSH |
| JumpServer LAN IP | K8s API VIP | TCP 6443 | 接入 Kubernetes 资产时按需允许 |
| JumpServer | 备份系统 | TCP 22/443 等 | 按实际备份方式允许 |
| 非授权用户 / 公网 | JumpServer 各端口 | 任意 | 拒绝 |
| 任何外部终端 | 内置 PG/Redis | 5432 / 6379 | 拒绝 |

JumpServer 还定义了 RDP、数据库代理等其他端口；本次不启用就不开放。注意其安装器默认 Docker 网段常见为 `192.168.250.0/24`，要核对与机房 CIDR、Pod CIDR、Service CIDR、Tailscale 路由不存在冲突。

> **特别警告：Docker 发布的容器端口可能绕过简单的 UFW 入站规则。** 最好同时在交换机/虚拟化防火墙层实现入站 ACL，并核查 `docker ps` 和实际端口监听。不要把 `ufw deny 443` 当作 Docker 端口绝对隔离保证。

---

## 4. 部署准备和主机加固

> 以下命令在 JumpServer 的独立 Ubuntu VM 上执行。**修改 SSH、防火墙前务必保留虚拟化控制台/带外入口**，避免远程断连。

### 4.1 基础检查

```bash
sudo hostnamectl set-hostname jumpserver-01
hostnamectl
ip -br a
ip route
lsblk -f
timedatectl
free -h
nproc
```

设置静态 IP：按照已采用的 Ubuntu 24.04 Netplan 服务器初始化文档逐机配置，不要直接照抄网卡名；通过 `sudo netplan try` 回滚保护验证。分配固定 LAN IP `192.168.50.253` 前确认未被占用。

### 4.2 系统更新和常用工具

```bash
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
sudo apt-get install -y ca-certificates curl wget vim jq rsync chrony \
  openssh-server gnupg lsof net-tools
sudo systemctl enable --now chrony ssh
chronyc tracking
```

配置服务器时间同步，确认宿主机不与 Ubuntu Docker、NTP、DNS 或反向代理已有进程冲突。**若安装器会安装 Docker Engine，不需提前再安装另一套冲突版本的容器运行时。**

### 4.3 独立数据磁盘

将专用数据盘挂载到 `/data/jumpserver`；文件系统推荐 ext4 或 XFS。

```bash
lsblk -f
sudo mkdir -p /data/jumpserver
# 在完成磁盘分区、格式化和 UUID/fstab 配置后：
findmnt /data/jumpserver
df -h /data/jumpserver
```

**禁止在未确认设备用途时直接 `mkfs`**，格式化会清空磁盘。正式安装前确认数据盘持久挂载、可写且空间充足。

### 4.4 SSH 和宿主机访问

- 创建个人 Linux 管理员账号，使用个人 SSH 公钥；禁止共享 root 密码。
- 验证新的管理会话可用后，再禁用 root 远程 SSH 登录与密码登录。
- **不建议把 JumpServer 自身加为普通 JumpServer 用户可管理的高权限资产**，避免自我授权和权限循环。
- 管理宿主机的 SSH 22 端口只允许管理员通过 Tailnet 或管理 VLAN 访问。

---

## 5. 安装 JumpServer Community

### 5.1 版本固定与官方来源

撰写时确认 JumpServer V5.1.1 为官方发布的正式版，官方安装器仓库：

- https://github.com/jumpserver/installer/releases/tag/v5.1.1
- https://www.jumpserver.com/docs/installation

官方提供 `quick_start.sh` 在线安装命令，但该入口指向**最新版本**，对生产变更可重复性不够理想。因此推荐从 **v5.1.1 Release 页面**下载对应安装器资产，**以 Release Assets 实际文件名为准**，做 SHA-256 校验后执行。不要从不明第三方脚本或镜像站下载。

#### 推荐方式 A：下载固定版本安装器（生产）

1. 访问上述官方 Release 页面；下载与平台匹配的 `jumpserver-installer-v5.1.1.tar.gz`（若资产名称变化，以实际发布资产为准）。
2. 从可信下载路径取得 SHA-256 信息或对下载文件记录自己的校验基线；核验来源可信后再解压。
3. 拷贝到服务器 `/opt`，确认文件名：

```bash
cd /opt
ls -lh jumpserver-installer-*.tar.gz
sha256sum jumpserver-installer-*.tar.gz
# 将输出与已核验发布包校验值比对；不要仅凭本地 sha256 结果断言来源可信。

tar -xzf jumpserver-installer-v5.1.1.tar.gz
cd jumpserver-installer-v5.1.1
chmod +x jmsctl.sh
sudo ./jmsctl.sh --help
sudo ./jmsctl.sh install
sudo ./jmsctl.sh start
sudo ./jmsctl.sh status
```

**说明：** 如果上游 Release 资产实际文件名或解压目录不同，以上命令中的名称需按下载内容替换；安装器可能交互式安装 Docker 与 Compose。**不要将未知安装包直接执行为 root。**

#### 可选方式 B：官方在线快速安装（测试/评估）

```bash
# 官方在线入口：会自动安装当前最新发布版本，而非固定 v5.1.1。
# 在生产环境使用前应先下载并审阅脚本内容。
cd /opt
curl -fsSLo quick_start.sh \
  https://github.com/jumpserver/jumpserver/releases/latest/download/quick_start.sh
less quick_start.sh
sudo bash quick_start.sh
```

### 5.2 检查服务与配置文件

```bash
# 使用安装器实际所在目录执行：
cd /opt/jumpserver-installer-v5.1.1  # 若目录不同，请替换
sudo ./jmsctl.sh status
sudo ./jmsctl.sh tail core

sudo test -f /opt/jumpserver/config/config.txt && echo 'config exists'
sudo ls -ld /data/jumpserver
sudo ss -lntp | grep -E ':(80|443|2222|22)\b' || true
sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

JumpServer 配置通常位于 `/opt/jumpserver/config/config.txt`，持久化目录为 `/data/jumpserver`。确认这两个实际路径后再配置备份。

### 5.3 第一次登录和立即加固

- 先仅从可信 LAN 或 Tailscale 测试，**不要临时开放公网**。
- 初始账户通常是 `admin` / `ChangeMe`，**首次登录立即更换为高强度唯一密码**，启用 MFA，并单独保管应急管理员账户。
- 进入管理界面配置全局 MFA、登录失败锁定、密码策略、空闲会话超时。
- 检查 `/api/health/` 和 Web 登录状态；确认证书有效之后再推广使用。

---

## 6. 接入 Tailscale 和最小访问权限

### 6.1 在 JumpServer 宿主机安装 Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh -o /tmp/install-tailscale.sh
less /tmp/install-tailscale.sh
sudo bash /tmp/install-tailscale.sh
sudo tailscale up
sudo tailscale ip -4
sudo tailscale status
```

在浏览器完成公司账号认证，并从 Tailscale 管理控制台对设备进行审批。推荐设置设备标签 `tag:jumpserver`，由管理员拥有该标签。**不要运行 `tailscale set --advertise-routes=192.168.50.0/24`**。

### 6.2 示例 Tailnet Grants

下面是**最小化示意**；替换真实用户、标签并融合现有 Grants，**不能直接覆盖生产 Tailnet 的所有既有策略**。

```json
{
  "groups": {
    "group:ops": ["ops1@example.com", "ops2@example.com"],
    "group:platform-admin": ["platform-admin@example.com"]
  },
  "tagOwners": {
    "tag:jumpserver": ["autogroup:admin"]
  },
  "acls": [],
  "grants": [
    {
      "src": ["group:ops", "group:platform-admin"],
      "dst": ["tag:jumpserver"],
      "ip": ["tcp:443", "tcp:2222"]
    },
    {
      "src": ["group:platform-admin"],
      "dst": ["tag:jumpserver"],
      "ip": ["tcp:22"]
    }
  ]
}
```

配置要点：

1. Tailnet 默认可能存在宽泛允许规则；**删除或收敛旧规则**，否则新加的最小权限规则不会自动否定旧的允许规则。
2. 勾选 Device Approval / 设备审批；公司身份提供方强制 MFA。
3. 普通运维人员**不允许**直接从 Tailnet 访问 K8s Master/Worker 或数据库，业务访问必须经过 JumpServer 或另行授权。
4. Subnet Router 的 ACL 与 JumpServer 宿主机网络防火墙是两套边界，应分别审计。
5. 做授权和拒绝测试，包括非运维用户的拒绝测试。

### 6.3 验证

运维人员电脑：

```bash
tailscale status
# 名称和地址按实际替换：
nc -vz jump.ops.example.com 443
nc -vz jump.ops.example.com 2222
curl -I https://jump.ops.example.com
```

未获授权的 Tailnet 账号应**不能**连接 443/2222；公网非 Tailnet 环境应无法访问这些入口。

> **网络边界**：即使采用 Tailscale 标签与 Grants，宿主机仍具有 LAN IP。必须阻止未授权的局域网终端直连 `192.168.50.253:443/2222`，推荐在上游防火墙/网络 ACL 限制，并实际扫描验证。

---

## 7. 内网 DNS 与 HTTPS

### 7.1 域名解析

使用 `jump.ops.example.com`，通过分离式 DNS 让运维客户端解析到 JumpServer **Tailscale IP**（或通过受控 DNS CNAME 指向合适的 Tailnet MagicDNS 名称）。不要在公网 DNS 给此域名发布指向内网地址的 A 记录，也不要为了证书申请将 JumpServer 暴露到公网。

```bash
nslookup jump.ops.example.com
curl -Iv https://jump.ops.example.com
```

### 7.2 证书申请方案

优先使用**已有企业 CA**，或者对受控公网域名使用 **ACME DNS-01** 签发可信证书。DNS-01 不需要公网访问 JumpServer 80/443，但必须有该域名 DNS 管理权限和可用的 DNS API/人工挑战流程。

不建议在 JumpServer 机器上额外部署一整套 cert-manager 或引入 Traefik 作为堡垒机的强制依赖；直接用 JumpServer 原生 HTTPS 功能即可。

将证书放入（路径以官方文档为准）：

```bash
sudo install -d -m 0700 /opt/jumpserver/config/nginx/cert
sudo install -m 0644 /secure/input/fullchain.pem \
  /opt/jumpserver/config/nginx/cert/server.crt
sudo install -m 0600 /secure/input/privkey.pem \
  /opt/jumpserver/config/nginx/cert/server.key
```

编辑 `/opt/jumpserver/config/config.txt`（备份之后操作）：

```ini
HTTPS_PORT=443
SERVER_NAME=jump.ops.example.com
SSL_CERTIFICATE=server.crt
SSL_CERTIFICATE_KEY=server.key
```

同时检查配置中 `DOMAINS` 是否包含 `jump.ops.example.com`，以及 HTTPS 下的 Cookie 安全参数是否启用。若安装器已生成这些键，**修改已有键值，不要重复追加同名键**。

```bash
sudo cp -a /opt/jumpserver/config/config.txt \
  /opt/jumpserver/config/config.txt.bak.$(date +%Y%m%d-%H%M%S)
sudo chmod 0600 /opt/jumpserver/config/config.txt
# 编辑完成后，在安装器目录执行：
sudo ./jmsctl.sh restart
curl -Iv https://jump.ops.example.com
```

**续期 SOP**：由受控证书续期任务更新上述 `server.crt` 和 `server.key`，核验新证书期限、权限和 SAN 后，在维护窗口 `jmsctl.sh restart`；设置证书剩余有效期 < 30 天告警。不要将私钥提交 GitLab。

---

## 8. 账号、资产和授权策略

### 8.1 管理对象与人员分层

| 组别 | 用户 | 访问资产 | 权限 |
|---|---|---|---|
| `js-platform-admin` | 平台管理员 | 所有 JumpServer 管理配置 | 少量、高强度 MFA |
| `js-k8s-ops` | K8s 运维 | Master/Worker SSH；按需 K8s 资源 | 最小授权，默认非 root |
| `js-app-ops` | 应用运维 | 授权 Worker / 命名空间 | 不访问 Master、etcd |
| `js-security-audit` | 审计人员 | 审计记录和录像 | 查看审计，不授予资产登录 |
| `js-breakglass` | 应急管理员 | 紧急恢复入口 | 只在应急流程使用、独立保管 |

具体角色菜单和细粒度能力可能受 Community / Enterprise 版本限制；可以优先组合**用户组、资产节点、账号授权**完成权限隔离，不假设社区版拥有企业级自定义 RBAC。

### 8.2 资产树设计

```text
/production
  /kubernetes
    /control-plane
      k8s-master-01   192.168.50.11
      k8s-master-02   192.168.50.12
      k8s-master-03   192.168.50.13
    /worker
      k8s-worker-01   192.168.50.21
      k8s-worker-02   192.168.50.22
  /operations
    <kubectl-ops-host>  （仅在需要时增加）
  /other-linux
```

### 8.3 接入顺序（JumpServer UI）

官方建议的顺序是：**用户和用户组 → 资产 → 账号 → 授权 → ACL → Workbench 连接验证**。

1. `Console → Users/Groups`：创建真实个人账号，不共享 `admin`，启用全局 MFA。
2. `Console → Assets`：按上述树创建节点；每台 Linux 资产使用固定 IP、SSH/22。
3. `Console → Accounts`：为资产绑定 `jmsops` 等非 root 管理账号。密码/私钥由受控渠道添加，不写进文档。
4. `Console → Policies → Authorizations`：按用户组、资产节点、登录账号赋权，最好设置有效期。
5. `Console → Policies → ACLs`：根据社区版可用能力，限制连接方式、上传下载、危险操作等；**命令过滤不能替代 Linux sudo 权限或 K8s RBAC**。
6. `Workbench → My Assets`：普通运维账号登录，确认只能看到本组资产并可正常进入终端。
7. `Audits → Sessions`：检查登录会话、命令和录像是否写入。

### 8.4 Linux 主机建议

- 在 Master、Worker 上建立专用 `jmsops` 账户，配置强制 SSH 公钥认证；将 JumpServer 管理的公钥加入该账户 `~/.ssh/authorized_keys`。
- **不要把所有服务器 root 密码批量录入 JumpServer**；普通任务不使用 root，真正的 root 恢复凭据独立保管。
- 所有提权都经 Linux sudo 规则或逐项授权执行，并保留系统审计。不要用全局 `NOPASSWD:ALL` 作为默认配置。
- Linux 主机防火墙原则上仅允许 **JumpServer LAN IP** SSH/22 和独立应急运维入口；别误拦截 KubeKey 的控制机或自动化维护路径。
- 已上线的普通用户不应能绕过堡垒机直接连接生产主机。

---

## 9. 接入 Kubernetes 和日常操作方式

### 9.1 两种运维模式

| 模式 | 方案 | 适用范围 | 关键约束 |
|---|---|---|---|
| A（先上线） | JumpServer Kubernetes 资产（`k8s` 协议） | 容器终端、资源浏览、常规检查 | 根据 Community 版可用功能与凭据方式验证 |
| B（长期推荐） | JumpServer SSH → **独立运维主机** → `kubectl` | 日常脚本、Helm、集群维护 | 运维主机使用个人 kubeconfig + K8s RBAC |

**不要默认认为 JumpServer 中的 K8s 资产代理可以替代你本机所有 `kubectl`/`helm` 工作流。** 官方 V5 客户端支持 Kubernetes 资产的资源浏览器和容器终端，但完整 API 客户端能力应在试点阶段逐项测试。

### 9.2 Kubernetes 资产验证

1. 在 JumpServer 中创建 K8s 类型的云资产，地址使用**内网 K8s API VIP**。
2. 选择该版本支持的 K8s 凭据方式；对测试命名空间创建受限的 ServiceAccount / 授权，**不要导入 `admin.conf` 或给予 cluster-admin**。
3. 确认 JumpServer LAN IP → `<K8S_API_VIP>:6443` 连通，并通过 CA 证书验证。
4. 以普通用户测试查看授权工作负载、进入容器终端；确认不能跨命名空间查看敏感 Secret 或管理节点。
5. 检查 JumpServer 会话记录、K8s API 审计和 Kubernetes RBAC 是否正确生效。

**K8s 身份审计注意**：如果多人通过同一个 ServiceAccount token 操作，Kubernetes API 审计可能只显示 ServiceAccount 身份，而不是具体自然人。因此必须结合 JumpServer 的个人登录/会话记录；高安全环境应使用个人身份认证、短期凭据、原生 Kubernetes RBAC。

### 9.3 完整 kubectl 工作流

如果需要完整 `kubectl`, `helm`, `k9s`：

- 配置一台**独立 `kubectl-ops` VM**（可复用已存在、符合安全基线的运维管理机），但不在 JumpServer 主机上直接保存 `admin.conf`。
- 将 `kubectl-ops` 作为 Linux SSH 资产接入 JumpServer，给每个运维人员独立 Linux 用户。
- 为每个用户配置 Kubernetes 个人身份（OIDC/短期 kubeconfig 或受控证书）和按命名空间的 RBAC。
- K8s API VIP 仅允许 `kubectl-ops` 主机 / 必要自动化系统访问；管控审计日志同步到日志平台。
- 涉及集群级危险变更要有独立审批和回滚 SOP，不能把堡垒机会话录像当作自动审批。

### 9.4 对接 KubeKey、GitLab、Argo CD

- **KubeKey**：继续由受控管理机/CI 作业发起升级和扩缩容；变更与审批进 GitLab，不让 JumpServer 直接变成集群控制平面。
- **Argo CD**：应用发布优先使用 GitOps，个人应急登录通过 Tailscale + Traefik；保留 Argo CD 自身 RBAC。
- **Traefik**：继续处理 Grafana、OpenObserve、Argo CD 内部 HTTPS；**JumpServer 建议直接在独立 VM 上提供 HTTPS，不强制依赖 K8s 内 Traefik**。
- **OpenObserve**：可接收 JumpServer 系统/访问日志用于检索，但**不能取代 JumpServer 原生录像及数据库审计的长期备份**。

---

## 10. 会话录像、审计和告警

### 10.1 审计检查项

在 `Audits → Sessions → Asset Sessions` 检查：

- 谁在什么时间以哪个资产账号连接了哪台机器。
- 会话状态（进行中/历史）、时长、连接来源及协议。
- Web SSH/KoKo 的会话录像、命令记录、文件传输记录是否可用。
- 是否可以由审计角色回放已结束会话；普通运维角色不应查看不属于自己的敏感记录。

**局限**：堡垒机会话录像不等于所有底层行为均可审计。例如进入容器后运行的程序、sudo 后的进程、直接 API 操作、文件读取都可能需要 Linux auditd/K8s API audit 互补。**禁止将会话录像当作唯一安全证据**。

### 10.2 初期建议策略

| 数据 | 保留建议 | 执行方式 |
|---|---|---|
| 登录/管理操作记录 | 180 天（依合规调整） | JumpServer 系统设置 |
| SSH 会话录像 | 90 天起 | 本机数据盘 + 异机备份 |
| 关键管理员录像 | 180 天或更久 | 单独加密归档 |
| 系统应用日志 | 30–90 天 | 系统日志平台 |
| 数据库备份 | 每日 + 每周验证 | 异机加密存储 |

保留天数属于**建议策略而非产品默认值**；并非所有 Community 版都有相同的自动清理能力，需结合实际版本和法规要求验证。录像、文件传输内容可能包含密码、令牌和敏感个人信息，审计人员本身也要受权限约束。

### 10.3 监控与告警

- 宿主机 `node_exporter`：CPU、内存、磁盘、inode、网络。
- 外部 HTTPS 探活：`https://jump.ops.example.com/api/health/`（探测方必须能访问 Tailnet）。
- Docker 容器健康：所有预期服务容器是否正常。
- 磁盘使用率：`/data/jumpserver` >70% 预警，>85% 严重；inode 同样监控。
- 登录失败、账号锁定、管理员权限变更、MFA 政策变更、离线备份失败，应通知平台运维与安全负责人。
- 不要把 JumpServer 的管理员密钥、登录令牌、连接 token、Kubernetes kubeconfig 发到 Prometheus labels / 日志中。

---

## 11. 备份与灾难恢复

### 11.1 备份的三类资产

| 数据 | 常见位置 | 重要性 |
|---|---|---|
| 数据库逻辑备份 | `/data/jumpserver/db_backup`（以实际配置为准） | 用户、资产、授权、命令索引 |
| 静态数据/录像 | `/data/jumpserver/core/data/media` 等 | 会话录像、上传记录 |
| 私密配置和密钥 | `/opt/jumpserver/config/config.txt`、证书目录 | **`SECRET_KEY`、`BOOTSTRAP_TOKEN` 等必须保留** |

**只备份数据库不够；只备份录像也不够。** 数据库、录像、应用配置及密钥必须成套恢复，而且要加密异机备份。不要直接在线 rsync PostgreSQL 数据目录作为数据库一致性备份。

### 11.2 手工备份（首次上线必须成功）

```bash
# 在实际安装器目录执行
sudo ./jmsctl.sh backup_db
sudo ls -lah /data/jumpserver/db_backup/

# 检查重要数据路径
sudo du -sh /data/jumpserver/core/data/media 2>/dev/null || true
sudo ls -l /opt/jumpserver/config/config.txt
```

建议采用备份服务器拉取或备份 Agent 加密上传方式。简单基线：

```bash
# 在有合法读取权限的备份作业中：
# 1) 先执行 jmsctl.sh backup_db。
# 2) 复制 db_backup 下的新逻辑备份、core/data/media、config/config.txt、证书等。
# 3) 通过 SSH/加密对象存储传输至异机。
# 4) 记录 SHA-256、完成通知及失败告警。
# 5) 定期在隔离的恢复测试 VM 演练还原。
```

生产中建议使用 Borg/Restic 等**支持加密、快照、保留策略**的备份工具，备份目标不要与 JumpServer 在同一物理故障域。**如果复制正在写入中的录像文件，需要在低峰时做快照或短暂停止相关服务以得到一致性时间点**。

### 11.3 建议 RPO/RTO（目标值，需演练确认）

| 指标 | 目标 | 前提 |
|---|---|---|
| RPO | ≤24 小时 | 每日备份成功且异机可取 |
| RTO | 2–4 小时目标 | 恢复 VM/镜像/配置与备份均可用 |
| 恢复演练 | 每季度一次 | 验证回放录像和账号解密 |

### 11.4 恢复 SOP（维护窗口）

1. 建立干净 VM；安装**与备份相同的 JumpServer 版本**和兼容数据库引擎。
2. 恢复持久化目录下必要的媒体/录像，恢复 `/opt/jumpserver/config/config.txt` 的密钥与证书；绝不更换原 `SECRET_KEY` / `BOOTSTRAP_TOKEN`。
3. 停止 JumpServer 服务，选择匹配的数据库逻辑备份：

```bash
sudo ./jmsctl.sh stop
sudo ./jmsctl.sh restore_db /data/jumpserver/db_backup/<verified-file>.dump
sudo ./jmsctl.sh start
sudo ./jmsctl.sh status
```

4. 若备份文件是 `.sql` 或位于其他目录，按实际文件格式与脚本提示操作；**不允许直接照抄占位文件名运行**。
5. 验证 `/api/health/`、普通账号 MFA、资产 SSH、历史录像回放、账号凭据解密。
6. 按批准流程恢复 Tailscale 标签和 DNS，完成安全审计。

### 11.5 备份安全

- 异机备份加密，授权仅备份管理员和恢复管理员可读；私钥、数据库、录像都属于高敏感数据。
- 备份密钥采用独立密码管理器/硬件安全模块保管，并留可审计的应急恢复渠道。
- 对备份成功率、过期时长和完整性验证设置告警。
- 定期抽样恢复录像，避免“备份文件存在但无法回放”的假成功。

---

## 12. 升级、扩容和维护 SOP

### 12.1 日常命令

```bash
# 在 JumpServer 安装器目录执行
sudo ./jmsctl.sh status
sudo ./jmsctl.sh tail core
sudo ./jmsctl.sh tail koko
sudo ./jmsctl.sh backup_db
sudo df -h /data/jumpserver
sudo docker ps
```

`stop/restart/down` 会断开正在进行的运维会话，需在维护窗口执行。

### 12.2 固定版本升级

1. 审阅目标版本 Release Notes、安全公告、兼容性；确保 Community 版功能未发生影响。
2. 通知运维人员，停止/保存活跃操作，保留一条独立应急管理通道。
3. 先备份数据库、录像、配置和密钥；完成恢复测试后再变更。
4. 下载**目标固定版本**官方安装器，检查 SHA-256、签名/官方来源；解压到新目录。
5. 在新安装器目录执行：

```bash
sudo ./jmsctl.sh upgrade
sudo ./jmsctl.sh start
sudo ./jmsctl.sh status
```

6. 验证登录、MFA、Linux SSH、K8s 资产、录像回放、证书和存储容量。
7. 数据库架构升级后，不保证回退旧应用版本安全；**回滚应使用升级前同版本的整套数据/配置恢复到隔离节点后切换**，而非简单降级镜像。

### 12.3 日常运维节奏

| 频率 | 工作 |
|---|---|
| 每日 | 检查服务可用、备份结果、磁盘、失败登录告警 |
| 每周 | 检查活跃用户、授权过期、异常 SSH 连接及录像 |
| 每月 | 检查官方安全公告，评估安全补丁；清理长期未用账号 |
| 每季度 | 完整恢复演练；MFA/离职撤权/应急登录演练 |
| 版本升级前 | 核对兼容性、维护窗口、备份及回滚方案 |

### 12.4 扩容判定

当并发连接明显增长、录像查询变慢、数据库或内存持续高负载时，先对 VM 纵向扩容（CPU/内存/SSD）。只有在不可接受单节点中断，或运维人员数量、审计 SLA 显著增加时，才考虑官方双节点 HA 拓扑和外部 PostgreSQL/Redis/对象存储。

---

## 13. 安全加固清单

- [ ] JumpServer 不在 K8s 集群内，不暴露公网 IP 的管理端口。
- [ ] Tailscale 公司身份源启用 MFA、Device Approval、最小化 Grants。
- [ ] 主机 LAN 443/2222 入口受上游 ACL 限制，不仅依赖 UFW。
- [ ] Tailscale 不发布整个机房网段，不作为默认 Exit Node。
- [ ] 登录域名启用有效 HTTPS，证书续期自动化并有到期告警。
- [ ] 默认 `admin` 密码已更改；业务运维用独立个人账号，启用全局 MFA。
- [ ] 每人仅授权必要资产、账号、有效期；审计角色不能登录主机。
- [ ] K8s API 不向公网开放；不保存共享 `admin.conf` 在 JumpServer 中。
- [ ] 限制运维主机 SSH 入站来源；生产机器限制 root 远程登录。
- [ ] 宿主机与容器镜像更新；持续关注 JumpServer 安全公告。
- [ ] 录像与密钥已加密异机备份并完成恢复演练。
- [ ] 离职人员在身份源、Tailnet、JumpServer、Linux/K8s 同步撤权。
- [ ] 应急管理员账号与设备独立封存，测试恢复路径。

**供应链提醒：** 2026 年官方曾发布过 JumpServer Access Key 泄露相关安全公告，不能因为堡垒机只在 VPN 内就忽略补丁。对已知漏洞应优先使用官方安全修复版本，并根据公告评估令牌撤销/密钥轮换。

---

## 14. 上线测试与验收

| 测试项 | 操作 | 合格标准 |
|---|---|---|
| 网络隔离 | 公网和未审批设备访问 443/2222 | 连接失败 |
| 合规准入 | 已批准 Tailnet 运维用户访问 | 正常访问 |
| MFA | 不提供二次因素登录 | 无法成功登录 |
| 个人权限 | 应用运维查看 Master | 不显示或无权限 |
| SSH | 授权账号连接 Worker | 成功、可回放 |
| 文件传输 | 普通用户尝试未授权下载 | 被禁止或有审计记录 |
| K8s | 受限身份查看非授权命名空间 | Kubernetes RBAC 拒绝 |
| 审计 | SSH 后退出，打开历史会话 | 能查看记录及录像 |
| 备份 | 运行 backup_db + 文件备份 | 异机能验证文件完整性 |
| 恢复 | 在隔离 VM 重建 | 密码可解密、录像可回放 |
| 证书 | 核查 SAN、TLS 版本与到期时间 | 全部符合要求 |
| 应急 | JumpServer 宕机后使用带外入口 | 运维人员仍能恢复集群 |

### 上线前关键命令

```bash
sudo ./jmsctl.sh status
sudo docker ps
sudo ss -lntp
sudo df -h /data/jumpserver
sudo tailscale status
sudo tailscale ip -4
curl -k -I https://127.0.0.1/api/health/  # 仅本机诊断；正式客户端不能忽略 TLS 校验
```

---

## 15. 应急预案与常见故障

| 现象 | 优先排查 | 应对 |
|---|---|---|
| Web 无法访问 | Tailnet Grants、DNS、TLS、443 端口、容器状态 | 从独立带外入口登录 VM 排障 |
| 浏览器 400/403 | `DOMAINS` / `SERVER_NAME` / Host、Cookie 设置 | 检查可信域名后重启 |
| 2222 SSH 连接失败 | KoKo 状态、端口、资产授权 | `jmsctl tail koko` |
| SSH 资产连接失败 | JumpServer → 目标 22、资产密钥、Linux sshd、firewall | 针对单台资产验证 |
| 录像无法回放 | 录制服务、媒体目录、磁盘、数据库元数据 | 恢复对应媒体备份并验证 |
| 部署后磁盘迅速增长 | 录像/容器日志/备份保留 | 扩盘、调整保留；不可直接随意删除数据库数据 |
| 管理员账号无法登录 | MFA 设备失效/账号锁定 | 使用官方账户恢复 SOP，记录审批 |
| 数据泄漏怀疑 | 账户异常、token/密钥、审计回放 | 立即隔离设备、吊销令牌、评估轮换凭据 |
| JumpServer 完全宕机 | 宿主机、磁盘、内置 PG/Redis | 按第 11 章使用异机备份恢复 |

**不建议**在故障中途临时将服务器 SSH、K8s API 或管理平台暴露到公网“应急登录”。应使用事先演练的带外/隔离管理通道。

---

## 16. 实施计划与交付物

| 阶段 | 实施内容 | 验收产物 |
|---|---|---|
| P0：准备 | 资源、DNS、IP、上游 ACL、证书、备份目标 | 网络与资产清单 |
| P1：基础部署 | Ubuntu、数据盘、JumpServer v5.1.1、Tailscale | 访问与安装记录 |
| P2：安全配置 | HTTPS、全局 MFA、用户组、权限边界 | 安全配置检查表 |
| P3：资产接入 | 5 台 Linux 主机、必要 K8s 资产 | 连通性和拒绝测试 |
| P4：审计备份 | 录像、异机加密备份、告警 | 备份成功记录与恢复报告 |
| P5：移交运维 | 升级、应急、人员离职撤权、月度巡检 | SOP、负责人、演练证明 |

### GitLab 推荐目录（只存放非敏感配置）

```text
infra-security/
├── README.md
├── jumpserver/
│   ├── architecture.md
│   ├── inventory.csv              # 仅资产名、环境、地址，不放密码
│   ├── permissions.md
│   ├── backup-runbook.md
│   ├── upgrade-runbook.md
│   ├── security-checklist.md
│   └── release-manifest.md
├── tailscale/
│   └── grants-example.json        # 模板，不包含私密令牌
└── operations/
    ├── breakglass.md
    └── acceptance-checklist.md
```

**禁止上传** `config.txt`、数据库备份、录像、证书私钥、个人 kubeconfig、SSH 私钥、API Token、Tailscale Auth Key 等敏感资料至普通 GitLab 仓库。

---

## 17. 风险与边界

1. **单点故障**：JumpServer 单节点不能提供持续运维访问。必须保留应急通道、异机备份；不能称为高可用。
2. **存储中高敏感信息**：资产登录凭据、SSH 会话录像可能包含生产机密；应严控管理者、审计者与备份人员权限。
3. **Tailscale 不是全部安全边界**：尾网权限只控制通过 Tailnet 的路径；本地 LAN/容器端口需要独立 ACL。
4. **社区版功能约束**：高级 SSO、细粒度自定义 RBAC、部分客户端能力和高级审计策略可能需要企业版；上线前验证具体功能。
5. **K8s 双重审计**：JumpServer K8s 资产功能不保证精确覆盖所有 `kubectl` 行为。必须使用 Kubernetes RBAC + API Audit。
6. **证书运维**：`jump.ops.example.com` 是内网访问名，但 TLS CA 仍须被客户端信任；DNS-01 与 DNS Split 方案独立规划。
7. **安装器版本**：本文固定 v5.1.1，是基于撰写日期的验证；以后部署必须按当时官方安全公告重新审查版本和兼容性。
8. **客户端代理**：有些协议可能不适合只代理 Web 443；若使用 SSH 桌面客户端，需核实 KoKo 2222 的开放和公司网络策略。

---

## 18. 官方参考资料

> 本文示例与基线在 **2026-11-03** 依据官方资料核对，以下链接请作为以后升级的权威入口。

- JumpServer V5 安装说明：https://www.jumpserver.com/docs/installation
- 官方固定版本 Release（v5.1.1）：https://github.com/jumpserver/installer/releases/tag/v5.1.1
- 单节点及 HA 拓扑：https://www.jumpserver.com/docs/operations/deployment-topologies
- 配置文件说明：https://www.jumpserver.com/docs/operations/configuration
- 端口矩阵：https://www.jumpserver.com/docs/operations/network-ports
- 原生 HTTPS：https://www.jumpserver.com/docs/operations/enable-https
- 安全加固：https://www.jumpserver.com/docs/operations/security-hardening
- CLI 管理：https://www.jumpserver.com/docs/operations/cli-tools
- 备份恢复：https://www.jumpserver.com/docs/operations/backup-restore
- 升级维护：https://www.jumpserver.com/docs/operations/upgrade-maintenance
- 第一次资产接入：https://www.jumpserver.com/docs/quickstart
- 审计会话：https://www.jumpserver.com/docs/features/audits/sessions/asset-sessions
- Kubernetes/桌面客户端：https://www.jumpserver.com/docs/features/client/asset-connection
- Tailscale ACL/Grants：https://tailscale.com/kb/1324/grants

---

## 最终落地建议

先以 **1 台独立 4C16G VM、200–300GiB SSD + JumpServer V5 Community + 主机直连 Tailscale** 上线，严格限制 HTTPS/KoKo 访问，只接管 5 台 Linux K8s 主机的 SSH，验证 MFA、会话录像、身份授权、备份恢复后，再逐步接入 Kubernetes 资产。对于 `kubectl/helm` 高风险操作，继续使用独立运维机 + Kubernetes RBAC + GitLab/Argo CD 变更流程，不把堡垒机变成万能的 root 控制台。
