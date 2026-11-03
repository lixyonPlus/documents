# Nacos 3.2.3 Kubernetes 部署清单（高可用 / 单节点）

参考：[`nacos-group/nacos-k8s`](https://github.com/nacos-group/nacos-k8s) 的 StatefulSet、Headless Service、健康检查、持久化与认证配置。

> **版本固定：** `nacos/nacos-server:v3.2.3`，与所参考的官方 Helm Chart 默认版本一致。此套文件为**原生 Kubernetes YAML**，不需要 Helm、NFS provisioner 或 peer-finder 插件。
>
> **使用范围：** 主要按阿里云 ACK 设计；也适用于其他 Kubernetes 集群，但必须调整 StorageClass。两套部署各自使用独立 Namespace，可以并存。
>
> **未经实际 ACK 集群联调：** 已检查配置结构；实际运行还取决于镜像可拉取、Pod 节点调度、CSI 存储、数据库网络及数据库初始化。

## 1. 文件

| 文件 | 用途 |
| --- | --- |
| `nacos-ha.yaml` | 3 节点高可用部署：Namespace、ConfigMap、2 个 Service、PDB、StatefulSet、独立 PVC |
| `nacos-standalone.yaml` | 单节点部署：Namespace、2 个 Service、StatefulSet、PVC，使用嵌入式存储 |
| `install.sh` | 创建随机的认证 Secret（不写在 Git/YAML 里），配置 HA MySQL 密码并应用清单 |

## 2. 对比

| 项目 | 高可用 | 单节点 |
| --- | --- | --- |
| Namespace | `nacos-ha` | `nacos-standalone` |
| Nacos 节点 | 3 | 1 |
| 数据源 | 已初始化的**外部高可用 MySQL** | 嵌入式存储（本地 PVC 持久化） |
| 存储 | 3 块互不共享的 20Gi PVC | 1 块 10Gi PVC |
| 故障容忍 | 可以容忍 **1 台 Nacos 节点** 故障，条件是 MySQL、网络和多数派正常 | Pod 可重启；不可用期间服务中断 |
| 调度 | 强制跨不同 Kubernetes 节点，尽量跨可用区 | 无强制分散 |
| 维护 | PDB `minAvailable: 2`，滚动更新 | 无 PDB |
| 扩缩容 | 固定 3 节点；修改成员列表与副本数后再扩缩容 | 固定 1 节点 |

高可用部署**不包含高可用 MySQL 服务本身**。可在 ACK 上使用阿里云 RDS MySQL 高可用版，或其他已配置容灾与备份的 MySQL；否则数据库会成为单点。

## 3. 准备工作

- Kubernetes 集群能够拉取 `nacos/nacos-server:v3.2.3` 镜像（若使用内网镜像仓库，修改两份 YAML 中的 `image`）。
- `kubectl` 能访问目标集群，并有权创建 Namespace、Secret、StatefulSet、Service、ConfigMap、PVC 和 PodDisruptionBudget。
- 已安装 `openssl` 与 `bash`（只在运行 `install.sh` 的客户端需要）。
- `kubectl get storageclass` 检查存储类。YAML 默认设置 `storageClassName: alicloud-disk-essd`，如果集群无此类，先把两个 YAML 的字段改成实际存在的、支持动态卷创建的 StorageClass。
- HA 部署需要至少 3 台可调度、能挂载持久卷的工作节点，且必须允许各 Pod 互相通过 TCP `8848` 与 `9849` 通信；客户服务使用 `8848/9848`。如有 NetworkPolicy，需要显式放行。
- 默认 Kubernetes 集群 DNS 域为 `cluster.local`。若你的集群域不同，修改 `nacos-ha.yaml` 的 `NACOS_SERVERS`。

### 高可用版：准备外部 MySQL

1. 准备可从 ACK Pod 网络访问的 MySQL 服务（推荐 MySQL 8.0 或兼容版本）。
2. 用数据库管理员账号执行以下**示例 SQL**；用独立、安全的密码替换示例占位符：

```sql
CREATE DATABASE IF NOT EXISTS nacos CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'nacos_app'@'%' IDENTIFIED BY 'REPLACE_WITH_STRONG_PASSWORD';
GRANT ALL PRIVILEGES ON nacos.* TO 'nacos_app'@'%';
```

生产环境请按来源网段收敛 MySQL 用户访问范围及安全组规则，并配置数据库备份。

3. 下载并向**新建的空数据库**导入**对应 Nacos 3.2.3 版本**的官方表结构（**不要对已有生产库直接重新导入**）：

```bash
curl -fsSL \
  'https://raw.githubusercontent.com/alibaba/nacos/3.2.3/plugin-default-impl/nacos-default-datasource-plugin/nacos-datasource-plugin-mysql/src/main/resources/META-INF/mysql-schema.sql' \
  -o mysql-schema.sql

# 举例：使用管理员或有建表权限的账户导入
mysql -h <mysql-host> -P 3306 -u <mysql-admin-user> -p nacos < mysql-schema.sql
```

4. 编辑 `nacos-ha.yaml` 中的 ConfigMap：

```yaml
MYSQL_SERVICE_HOST: "CHANGE_ME_MYSQL_HOST" # 改为实际的 MySQL 地址
MYSQL_SERVICE_PORT: "3306"
MYSQL_SERVICE_DB_NAME: "nacos"
MYSQL_SERVICE_USER: "nacos_app"
```

### 说明：为什么数据库密码不在 ConfigMap 里？

ConfigMap 只能放非敏感配置信息。数据库密码保存在 `nacos-mysql` Secret，鉴权 token 与服务端身份信息保存在 `nacos-auth` Secret。脚本在首次安装时创建，后续运行**不会自动轮换**已有密钥，避免重启后跨节点认证失效。

## 4. 安装

在解压后的 `nacos-k8s-manifests` 目录中执行。

### 4.1 高可用模式

```bash
# 先完成 MySQL 初始化、配置 nacos-ha.yaml 的 MYSQL_SERVICE_HOST，检查 StorageClass
bash install.sh ha

# 查看结果
kubectl -n nacos-ha get pods -o wide
kubectl -n nacos-ha get svc,pvc,pdb
kubectl -n nacos-ha rollout status statefulset/nacos --timeout=15m
```

脚本会在终端交互式读取 MySQL 密码；非交互部署则预先设置 `NACOS_MYSQL_PASSWORD` 环境变量（注意环境变量可能被终端历史、CI 日志或宿主机进程查看到；CI 应使用安全的 Secret 注入方式）。

### 4.2 单节点模式

```bash
bash install.sh standalone
kubectl -n nacos-standalone get pods,svc,pvc
```

单节点模式不需要 MySQL，数据写入独立 PVC。删除 Pod 不会自动删除 PVC；删除 PVC 会丢失该节点持久化数据。

### 4.3 只执行 YAML，不用安装脚本

手工先建立目标 Namespace 以及 Secret 后，也可直接使用 `kubectl apply -f nacos-ha.yaml` 或 `kubectl apply -f nacos-standalone.yaml`。Secret 要求：

- `nacos-auth`：`token`（**Base64 编码且解码后至少 32 字节**）、`identity-key`、`identity-value`。
- HA 额外需要 `nacos-mysql`：键为 `password`。

不要在源码仓库中提交真实密码或 Token。

## 5. 访问方式

### 集群内访问

| 部署 | Java / Nacos SDK 服务地址 | 控制台地址（仅集群内部） |
| --- | --- | --- |
| HA | `nacos.nacos-ha.svc.cluster.local:8848` | `http://nacos.nacos-ha.svc.cluster.local:8080/` |
| 单节点 | `nacos.nacos-standalone.svc.cluster.local:8848` | `http://nacos.nacos-standalone.svc.cluster.local:8080/` |

Nacos 2.x/3.x SDK 可能根据服务地址 `8848` 自动推导 gRPC `9848`，务必保证这两个端口都能从客户端访问。Nacos 3.x 控制台位于 `8080`，**不是** `8848/nacos`。

### 本地运维访问控制台（不暴露公网）

```bash
# 高可用
kubectl -n nacos-ha port-forward svc/nacos 8080:8080
# 单节点二选一（不要同时占用本机 8080）
kubectl -n nacos-standalone port-forward svc/nacos 8080:8080
```

浏览器打开 `http://127.0.0.1:8080/`，首次部署时按控制台指引初始化管理员密码。当前清单明确打开了客户端 API、管理员 API、控制台 API 鉴权；应用程序客户端也需要配置 Nacos 用户名/密码，或按 SDK 说明使用令牌。

### 外部访问 / ACK SLB

这两套 YAML 默认只暴露 ClusterIP，避免将管理控制台直接放到公网。若需要 ACK 内网 SLB/ALB，建议另建专用的内网负载均衡，将 TCP `8848` 和 `9848` 同时暴露；外部端口映射要满足 SDK 的 `+1000` 规则。**不要仅靠 HTTP Ingress 代理 `8848` 却忽略 gRPC `9848`**。建议管理端口 `8080` 通过 VPN、堡垒机或 `port-forward` 访问。

## 6. 运维验证

```bash
# HA Pod 跨节点分布
kubectl -n nacos-ha get pods -o wide

# HA 成员列表（与 3 个副本一致）
kubectl -n nacos-ha exec nacos-0 -- cat /home/nacos/conf/cluster.conf

# 检查健康状态
kubectl -n nacos-ha port-forward svc/nacos 8080:8080
curl -fsS http://127.0.0.1:8080/v3/console/health/readiness

# 日志
kubectl -n nacos-ha logs nacos-0 --tail=200

# PVC
kubectl -n nacos-ha get pvc
```

每台 Nacos 使用**自己的** PVC（不要多个节点共用同一块 RWO 卷）。PDB 只约束自愿驱逐，不保证所有故障情况下的可用性；真正的 HA 还取决于多可用区部署、外部 MySQL 可用性、网络与数据库恢复能力。

## 7. 常见问题

- **Pod Pending**：检查 3 台工作节点、存储类与磁盘可用区，`kubectl -n nacos-ha describe pod nacos-0`；强制跨主机反亲和可能导致节点不足时无法调度。
- **ImagePullBackOff**：检查镜像仓库访问、代理、内网镜像同步及凭据。
- **数据库初始化错误**：确认表结构已导入、MySQL 版本、字符集、用户授权、密码、VPC/安全组、白名单、连通性。
- **启动失败 / CrashLoopBackOff**：检查 Secret 名称与键；`token` 必须为 Base64 文本，解码长度至少 32 字节。
- **启动很慢**：配置了最长约 10 分钟的 `startupProbe` 容错，超过时间仍需检查日志与数据库。此探针不会替代真正的故障修复。
- **增加集群节点**：当前使用静态的 `NACOS_SERVERS`，不支持只修改 replicas 后自动完成成员注册。需要同步修改成员列表并规划重启与数据一致性；如经常弹性扩缩，建议改用官方 Helm peer-finder / Nacos Operator。
- **镜像升级**：不要直接把 3.2.x 换为 3.3.x；应先查官方升级指南、备份 MySQL 与所有 PVC、确认新版本数据库迁移与认证默认行为。
- **恢复与备份**：高可用模式需备份 MySQL 及 Nacos 运行状态；单节点至少备份 PVC，避免节点/磁盘故障造成数据丢失。

## 8. 参考来源

- Nacos K8s 官方仓库：<https://github.com/nacos-group/nacos-k8s>
- 官方 Helm StatefulSet：<https://github.com/nacos-group/nacos-k8s/blob/master/helm/templates/statefulset.yaml>
- 官方 Helm 默认 values：<https://github.com/nacos-group/nacos-k8s/blob/master/helm/values.yaml>
- 官方 Docker `NACOS_SERVERS` 示例：<https://github.com/nacos-group/nacos-docker/blob/master/env/nacos-hostname.env>
- Nacos 3.2 鉴权文档：<https://nacos.io/docs/v3.2/manual/admin/auth/>
- Nacos 3.2.3 官方 MySQL schema：<https://github.com/alibaba/nacos/blob/3.2.3/plugin-default-impl/nacos-default-datasource-plugin/nacos-datasource-plugin-mysql/src/main/resources/META-INF/mysql-schema.sql>
