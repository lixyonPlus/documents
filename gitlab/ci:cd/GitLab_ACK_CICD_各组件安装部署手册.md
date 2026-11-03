# GitLab + ACK CI/CD 各组件安装部署手册

> 版本：v1.0 · 编制日期：2026-11-01  
> 适用：已有 GitLab、自管阿里云 ACK、Java 21 / Spring Boot / Maven 微服务；新建 CI/CD 平台。  
> 基线架构：GitLab CI/CD → Kubernetes GitLab Runner → Maven/Jib → 阿里云 ACR → GitOps 仓库 → Argo CD → ACK。  
> 性质：**可执行实施方案与示例配置**，不是已在你的集群实测的部署记录。

---

## 0. 使用说明：请先读

1. 本文默认 GitLab **已经存在并可访问**。不重新安装 GitLab Server，也不安装 Jenkins 或 Tekton。
2. 示例中的 `gitlab.example.com`、`registry.example.com`、`YOUR_...`、集群地址、令牌、Chart 版本都是**占位符**，替换并验证后才能部署。
3. **先 POC 后生产**。先选择一个隔离 ACK 测试集群、一个 Spring Boot 示例服务，跑通端到端流水线。
4. Helm Chart、Kubernetes CRD、构建镜像与部署组件都需**记录已测试版本**；文中命令使用 `--version "$..._CHART_VERSION"`，故意不自动追随 latest。
5. 所有包含口令的文件禁止进入 Git；尽量通过 Secret Manager / External Secrets 管理，POC 使用临时 Secret 只是便于验证。
6. Runner 会执行仓库代码，**CI Namespace 不是强隔离边界**。不可信代码优先在独立 CI 集群执行；低成本 POC 仅在隔离节点池与严格权限下运行。
7. 与前版《GitLab ACK CI/CD 落地实施方案》和 `gitlab-ack-cicd-kit.zip` 配套。配套文件可作起点，但必须检查与目标 Helm Chart 版本是否一致。

### 0.1 组件清单

| 层次 | 组件 | 部署方式 | 位置 | 优先级 |
|---|---|---|---|---|
| 管理 | kubectl、Helm、Git、可选 Argo CD CLI | 软件包 | 运维主机 | P0 |
| 集群 | ACK、CoreDNS、CNI、节点池 | 已存在/控制台配置 | 阿里云 | P0 |
| SCM / CI 控制面 | GitLab | 复用现有 | 自建/SaaS | P0 |
| CI 执行 | GitLab Runner | 官方 Helm Chart | `ci-manager` | P0 |
| CI 任务 | Maven、JDK21、Jib | 构建镜像与 Maven 插件 | `ci-jobs` Pod | P0 |
| 容器仓库 | 阿里云 ACR | 控制台开通 | 阿里云托管 | P0 |
| 部署引擎 | Argo CD | Argo Helm Chart | `argocd` | P0 |
| 部署配置 | GitOps、Kustomize | GitLab 仓库 | GitLab | P0 |
| 扫描 | Trivy | CI 镜像/CLI | CI Job | P1 |
| 代码质量 | SonarQube | Helm + 外部数据库 | `sonarqube` | P1 |
| 监控 | kube-prometheus-stack | Helm | `monitoring` | P1 |
| Secret 同步 | External Secrets Operator | Helm | `external-secrets` | P2 |
| AI 审查 | AI Agent + Skills | CI Job | `ci-jobs` | P2 |

### 0.2 前提资料收集表

在部署记录中填好：

| 项目 | 示例 | 确认人 |
|---|---|---|
| GitLab 地址 | `https://gitlab.example.com` |  |
| GitLab 类型 | GitLab.com / 自建 GitLab |  |
| ACK 地域/集群 ID | `cn-hangzhou` / `<cluster-id>` |  |
| ACK Kubernetes 版本/CNI | `kubectl version` 和集群控制台 |  |
| CI 机型与节点池 | 独立 CI 节点池，`workload=ci` |  |
| GitLab 到 ACK 网络 | TLS 可连通、DNS 可解析 |  |
| ACK 到 Maven 仓库 | 企业 Nexus / Maven Central |  |
| ACK 到 ACR 网络 | 优先同地域 VPC / 内网地址 |  |
| ACR 地址 | `registry.example.com` |  |
| GitOps 仓库地址 | `https://gitlab.example.com/platform/gitops.git` |  |
| 生产 ACK | 独立集群为佳 |  |
| 数据库存储 | SonarQube 外部 PostgreSQL（P1） |  |

### 0.3 安装顺序

```text
ACK 网络与节点池
  -> 运维机 kubectl/Helm
  -> ACR 企业版及凭证
  -> GitLab Runner + RBAC + 测试 Job
  -> Maven/Jib 构建镜像并推送 ACR
  -> GitOps 仓库、Kustomize
  -> Argo CD、AppProject、Application
  -> Dev 自动部署 + Prod 审批和手动同步
  -> Trivy / SonarQube / Prometheus / Secret 管理 / AI Review
```

---

## 1. 基础环境安装与检查（P0）

### 1.1 运维机安装工具

推荐在一台受控运维机器上操作，**不要在生产 GitLab Runner Job 中安装或使用集群管理员 kubeconfig**。

Mac 可使用 Homebrew：

```bash
brew install kubectl helm git
# 如要使用 Argo CD CLI：
brew install argocd

kubectl version --client
helm version
git --version
```

Linux 可按照 Kubernetes、Helm 官方安装指南下载签名二进制；不要直接执行来源不明的在线安装脚本。运维机还需能访问 ACK API Server。

### 1.2 连接 ACK

1. 在阿里云 ACK 控制台获取**符合用户权限的 KubeConfig**，优先短期凭证或运维身份。不要把 kubeconfig 放进 GitLab 变量给普通 Job。
2. 配置 `KUBECONFIG` 或导入到 `~/.kube/config`。
3. 验证：

```bash
kubectl config get-contexts
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide
kubectl get storageclass
kubectl -n kube-system get pods
```

**验收**：Node Ready、CoreDNS 正常、存储类可用，CI 节点能访问 GitLab、ACR、Maven 仓库。

### 1.3 资源隔离和 Namespace

```bash
kubectl create namespace ci-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ci-jobs --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace app-dev --dry-run=client -o yaml | kubectl apply -f -
# 生产环境建议在独立 ACK 集群创建对应 namespace
```

为专用 CI 节点池设置标签 `workload=ci`，并根据组织策略设置污点/容忍与 NodeSelector。示例：

```bash
kubectl get nodes -l workload=ci
```

不要为了让 Job 调度成功就给生产节点随意添加 CI 标签。若集群配置污点，需在 Runner Kubernetes Executor 中设置对应 toleration。

### 1.4 网络检查和治理

- ACK CI 节点 → GitLab HTTPS/API：443 通畅；自建 GitLab 的证书链可信。
- ACK CI 节点 → ACR 内网镜像域名；按需配置 VPC/安全组访问。
- ACK CI 节点 → Maven 仓库、镜像基础层仓库；若无法访问国外网络，准备公司内 Nexus/镜像缓存与 ACR 镜像同步。
- Argo CD → GitOps Git 仓库、目标 ACK API Server；尽量通过私网。
- 应用节点 → ACR Pull 可用；`ImagePullBackOff` 优先检查凭证、VPC/域名、仓库权限。
- 网络策略是否生效取决于 ACK CNI 与实际配置。部署 NetworkPolicy 后要做允许与拒绝流量测试。

---

## 2. 阿里云 ACR 安装/开通（P0）

ACR 是阿里云托管服务，**无需 Helm 安装到 ACK**。

### 2.1 控制台开通

1. 打开阿里云 **容器镜像服务 ACR** 控制台，选择与 ACK 相同/低延迟地域。
2. 生产优先 **企业版**；选择实例、网络/VPC、存储与访问控制。个人版没有企业版 SLA，不建议用于正式生产。
3. 创建命名空间（如 `business`），创建私有镜像仓库（如 `order-service`）。
4. 开启可用的**镜像标签不可覆盖**策略，并定义镜像清理、保留周期。
5. 为推送和拉取操作配置独立的最小权限 RAM 身份；生产优先使用临时访问凭证。

镜像引用示例：

```text
<ACR_REGISTRY_HOST>/business/order-service:<commit-sha>
```

### 2.2 构建推送权限

ACR 访问凭证与 RAM 账号登录密码不同；固定密码有效期长，正式系统建议采用官方临时凭证流程。POC 可使用受限的固定凭证，之后替换。

GitLab `Settings → CI/CD → Variables` 中至少设置：

| 变量 | 说明 | 保护 |
|---|---|---|
| `ACR_HOST` | 镜像仓库域名，不含协议 | 普通 |
| `ACR_NAMESPACE` | `business` | 普通 |
| `ACR_USERNAME` | 仅可推送指定仓库的身份 | Protected / Masked |
| `ACR_PASSWORD` | ACR 对应认证密码 | Protected / Masked / Hidden（可用时） |

**验收**：一个经过保护的 main 分支 CI Job 可以推送 `order-service:<commit-sha>`；普通 MR 无法获取写凭证。

### 2.3 ACK 运行时拉取权限

优先使用 ACK 与 ACR 企业版的安全身份集成/托管拉取能力；不支持的情形可在**业务 Namespace**中设置受限的 `imagePullSecret`。

示例（仅 POC；密码不要写进 Git 或命令历史）：

```bash
kubectl -n app-dev create secret docker-registry acr-pull \
  --docker-server="$ACR_HOST" \
  --docker-username="$ACR_PULL_USER" \
  --docker-password="$ACR_PULL_PASSWORD"
```

在 Deployment PodSpec 设置：

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
        - name: acr-pull
```

密钥应只放在目标 Namespace，不要复制到所有 Namespace。生产建议改为专门的 Secret 管理组件。

---

## 3. GitLab Runner 安装（P0，关键环节）

### 3.1 GitLab 创建 Runner

1. 在 GitLab 项目或 Group 的 Runners 页面创建新 Runner。
2. 选择 Tag：`ack-ci`；关闭 `Run untagged jobs`；按需限制到受控项目。
3. 获取以 `glrt-` 开头的 **Runner Authentication Token**。不使用旧的 Registration Token 工作流。
4. 先用普通 Runner 执行测试，再为敏感发布任务另设权限更严格的 Runner。

### 3.2 创建执行 Job 的 ServiceAccount

```bash
kubectl -n ci-jobs create serviceaccount ci-job \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n ci-jobs patch serviceaccount ci-job \
  --type=merge \
  -p '{"automountServiceAccountToken":false}'
```

Job 默认不能访问集群 Kubernetes API。**Runner Manager 的身份与 CI Job 的身份必须分开**。

### 3.3 存储 Runner Token

```bash
read -r -s -p 'Runner glrt- token: ' RUNNER_TOKEN; echo

kubectl -n ci-manager create secret generic gitlab-runner-auth \
  --from-literal=runner-token="$RUNNER_TOKEN" \
  --from-literal=runner-registration-token=''

unset RUNNER_TOKEN
```

生产改用受控 Secret 提供方和轮换流程，不建议在普通运维机长期保留这个 Token。

### 3.4 Runner Values 文件

保存为 `runner-values.yaml`：

```yaml
gitlabUrl: "https://gitlab.example.com"
concurrent: 5
checkInterval: 3

rbac:
  create: true
  clusterWideAccess: false
  rules:
    - apiGroups: [""]
      resources: ["events"]
      verbs: ["list"]
    - apiGroups: [""]
      resources: ["pods"]
      verbs: ["create", "delete", "get", "list", "watch"]
    - apiGroups: [""]
      resources: ["pods/attach", "pods/exec"]
      verbs: ["create", "delete", "get", "patch"]
    - apiGroups: [""]
      resources: ["pods/log"]
      verbs: ["get", "list"]
    - apiGroups: [""]
      resources: ["secrets"]
      verbs: ["create", "delete", "get", "update"]
    - apiGroups: [""]
      resources: ["serviceaccounts"]
      verbs: ["get"]
    - apiGroups: [""]
      resources: ["services"]
      verbs: ["create", "get"]

runners:
  secret: gitlab-runner-auth
  jobNamespace: ci-jobs
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "ci-jobs"
        image = "maven:3.9-eclipse-temurin-21"
        privileged = false
        service_account = "ci-job"
        cpu_request = "500m"
        cpu_limit = "2"
        memory_request = "1Gi"
        memory_limit = "4Gi"
        helper_cpu_request = "100m"
        helper_memory_request = "128Mi"
        [runners.kubernetes.node_selector]
          "workload" = "ci"
```

上述 RBAC 权限参考 GitLab 官方默认 Executor 规则，不是“所有版本的永久最小权限集”；请按 Runner 版本、执行策略、Feature Flags 验证并进一步收紧。尤其注意：Runner Manager 为执行任务**需要创建 Job Secret**，但这不意味着应给 CI Job 同样的权限。不要用 `cluster-admin` 修复权限问题。

### 3.5 Helm 部署（固定版本）

```bash
helm repo add gitlab https://charts.gitlab.io
helm repo update gitlab
helm search repo -l gitlab/gitlab-runner

# 在环境变量中填入已验证的版本，例如从上述列表选取
: "${RUNNER_CHART_VERSION:?请先设置已测试的 Runner Chart 版本}"

helm template ack-ci gitlab/gitlab-runner \
  --namespace ci-manager \
  --version "$RUNNER_CHART_VERSION" \
  -f runner-values.yaml > /tmp/ack-ci-rendered.yaml

# 重点审核 Role/RoleBinding 的 Namespace 与 ServiceAccount
kubectl apply --dry-run=server -f /tmp/ack-ci-rendered.yaml

helm upgrade --install ack-ci gitlab/gitlab-runner \
  --namespace ci-manager \
  --version "$RUNNER_CHART_VERSION" \
  -f runner-values.yaml \
  --wait --timeout 10m
```

提醒：Helm Chart 的 `rbac.create` 和 `runners.jobNamespace` 在不同版本的生成对象名称/Namespace 可能发生变化。以 `helm template` 和集群实际资源为准。

### 3.6 Runner 验收

```bash
kubectl -n ci-manager get deployments,pods,sa,rolebinding
kubectl -n ci-jobs get sa,role,rolebinding,pods
helm status ack-ci -n ci-manager
kubectl -n ci-manager logs deployment/ack-ci-gitlab-runner --tail=100
```

Deployment 名称要以实际安装结果为准。然后在 GitLab 建一个测试仓库：

```yaml
# .gitlab-ci.yml
stages: [test]

test-runner:
  stage: test
  tags: [ack-ci]
  image: alpine:3.20
  script:
    - echo "CI Runner online"
    - cat /etc/os-release
```

检查 Pipeline 成功，同时在 ACK `ci-jobs` 中观察 Job Pod 创建、退出与清理。

进行权限验证（用实际 Manager ServiceAccount 名称替换）：

```bash
kubectl auth can-i create pods -n ci-jobs \
  --as=system:serviceaccount:ci-manager:ACK_CI_RUNNER_SA

kubectl auth can-i create deployments -n app-prod \
  --as=system:serviceaccount:ci-manager:ACK_CI_RUNNER_SA
```

期望第一项 `yes`、第二项 `no`。如果失败，修正 Role/RoleBinding，绝不临时开全局管理员权限。

**回退**：先在 GitLab Pause Runner，待 Job 结束，再执行 `helm rollback ack-ci <REVISION> -n ci-manager`；若卸载，使用 `helm uninstall ack-ci -n ci-manager`，并单独处理已创建的 Secret。

---

## 4. Maven / JDK21 / Jib 构建环境（P0）

### 4.1 不要在 ACK 安装常驻 Maven 服务

Runner 通过 Kubernetes Job Pod 直接使用容器镜像：

```text
maven:3.9-eclipse-temurin-21
```

如公司内网限制公网镜像下载，应同步该镜像及 Jib 基础镜像到受控 ACR，随后将 CI `image` 改为公司镜像地址。

### 4.2 Spring Boot 工程中的 Jib 插件

在 Maven `pom.xml` 的 `build/plugins` 增加：

```xml
<plugin>
  <groupId>com.google.cloud.tools</groupId>
  <artifactId>jib-maven-plugin</artifactId>
  <version>3.5.2</version>
  <configuration>
    <from>
      <image>eclipse-temurin:21-jre</image>
    </from>
    <container>
      <ports><port>8080</port></ports>
      <jvmFlags><jvmFlag>-XX:MaxRAMPercentage=75</jvmFlag></jvmFlags>
    </container>
  </configuration>
</plugin>
```

这个示例展示最小 Java 镜像构建能力；正式环境必须将基础镜像固定到已批准的 Digest，最好同步到内部 ACR，并核对支持的系统架构。

### 4.3 最小 `.gitlab-ci.yml`

```yaml
workflow:
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
    - when: never

stages: [test, publish]

default:
  image: maven:3.9-eclipse-temurin-21
  tags: [ack-ci]

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository"

test:
  stage: test
  script:
    - mvn -B -ntp verify
  artifacts:
    when: always
    reports:
      junit:
        - "**/target/surefire-reports/TEST-*.xml"
        - "**/target/failsafe-reports/TEST-*.xml"

publish:
  stage: publish
  rules:
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
  script:
    - export DOCKER_CONFIG="$CI_PROJECT_DIR/.docker"
    - mkdir -p "$DOCKER_CONFIG"
    - export AUTH_B64="$(printf '%s:%s' "$ACR_USERNAME" "$ACR_PASSWORD" | base64 | tr -d '\n')"
    - printf '{"auths":{"%s":{"auth":"%s"}}}\n' "$ACR_HOST" "$AUTH_B64" > "$DOCKER_CONFIG/config.json"
    - chmod 600 "$DOCKER_CONFIG/config.json"
    - export IMAGE="$ACR_HOST/$ACR_NAMESPACE/$CI_PROJECT_NAME:$CI_COMMIT_SHA"
    - mvn -B -ntp -DskipTests -Djib.to.image="$IMAGE" compile jib:build
  after_script:
    - rm -rf "$CI_PROJECT_DIR/.docker"
```

说明：

- 上述方式用 Docker 配置文件传递 Jib Registry 凭证，避免在 Maven 参数里直接给出口令。仍需将秘密变量保护起来、关闭敏感命令调试日志，并测试 Jib 是否正确读取 `DOCKER_CONFIG`。
- 不允许从不可信 MR 执行 `publish`；main 分支必须受保护。
- `-DskipTests` 仅用于已经通过前序测试的发布阶段；不要以此代替测试。
- 建议后续引入 Nexus Maven 代理、Jib 构建缓存和镜像漏洞扫描。
- GitLab Job 容器的默认用户、代理/证书及基础镜像来源，需要按照公司环境调整。

**验收**：MR 触发测试但不推送；main 合并后镜像成功推送 ACR，Tag 对应 Commit SHA，镜像在 ACK 可拉取。

---

## 5. GitOps 仓库和 Kustomize（P0）

### 5.1 建立独立仓库

在 GitLab 建立私有仓库 `platform/gitops`：

```text
gitops/
├── apps/
│   └── order-service/
│       ├── base/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/kustomization.yaml
│           └── prod/kustomization.yaml
└── argocd/
    ├── appprojects/
    └── applications/
```

### 5.2 配置示例

`apps/order-service/base/deployment.yaml`：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  replicas: 1
  selector:
    matchLabels: {app: order-service}
  template:
    metadata:
      labels: {app: order-service}
    spec:
      imagePullSecrets: [{name: acr-pull}]
      containers:
        - name: order-service
          image: registry.example.com/business/order-service:INITIAL_SHA
          ports: [{containerPort: 8080}]
          resources:
            requests: {cpu: 100m, memory: 256Mi}
            limits: {cpu: "1", memory: 1Gi}
          readinessProbe:
            httpGet: {path: /actuator/health/readiness, port: 8080}
            initialDelaySeconds: 10
            periodSeconds: 10
```

`base/service.yaml`：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: order-service
spec:
  selector: {app: order-service}
  ports:
    - port: 80
      targetPort: 8080
```

`base/kustomization.yaml`：

```yaml
resources:
  - deployment.yaml
  - service.yaml
```

`overlays/dev/kustomization.yaml`：

```yaml
namespace: app-dev
resources:
  - ../../base
images:
  - name: registry.example.com/business/order-service
    newTag: INITIAL_SHA
```

注意：Spring Boot 服务需要真正启用 Actuator 和探针端点，否则上述 Readiness 探针会失败。生产还要设置 Liveness、滚动发布参数以及 PodDisruptionBudget（如适用）。

### 5.3 本地验证渲染

```bash
kubectl kustomize apps/order-service/overlays/dev
```

**验收**：渲染后 Namespace、镜像 Tag、资源限制、探针路径符合预期。

### 5.4 GitLab 分支保护

- GitOps `main` 禁止普通开发者直接推送。
- Dev 配置变更可由 CI Bot 创建 MR，经审批合并。
- Prod 配置单独审批；不能让普通业务构建 Job 直接写生产 `main`。
- 持续交付由**更新 GitOps 的 SHA/Digest**实现，不由 CI 执行 `kubectl apply`。
- 初期建议手工创建第一条 GitOps MR，端到端验证后接入模板包中的自动创建 MR 脚本。

---

## 6. Argo CD 安装（P0）

### 6.1 Helm 安装

Argo CD 官方提供 Manifest，社区维护 Helm Chart。此处选 Helm 便于锁版、回退和配置管理。**生产需规划 Argo CD HA 和独立运维权限**；下面是 POC 单实例安装。

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo
helm search repo -l argo/argo-cd

: "${ARGOCD_CHART_VERSION:?请先设置已测试的 Argo CD Chart 版本}"

cat > argocd-values.yaml <<'YAML'
server:
  service:
    type: ClusterIP
YAML

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version "$ARGOCD_CHART_VERSION" \
  -f argocd-values.yaml \
  --wait --timeout 15m
```

POC 检查：

```bash
kubectl -n argocd get pods,services
helm status argocd -n argocd
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

浏览器打开 `https://localhost:8080`（默认自签证书可能需要临时信任），不要未经认证直接暴露公网。

首次登录初始密码（若该 Chart/版本创建了默认 Secret）：

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 --decode; echo
```

首次登录后立即修改管理员密码，按组织身份平台配置 SSO/RBAC，正式环境禁用或严格控制默认 admin。

### 6.2 注册 GitLab GitOps 私有仓库

推荐只读 GitLab Deploy Token 或专用只读账号，将仓库 `https://gitlab.example.com/platform/gitops.git` 接入 Argo CD。

可通过 Argo CD UI 的 Settings → Repositories 录入；生产建议使用 External Secrets 同步 Repository 凭证，并限制可访问的仓库。

**注意 GitLab 仓库 URL 使用 `.git` 后缀**，避免 GitLab HTTP Redirect 导致 Argo CD 无法解析仓库。

### 6.3 建立 AppProject（示例）

`business-dev-project.yaml`：

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: business-dev
  namespace: argocd
spec:
  description: Development services
  sourceRepos:
    - https://gitlab.example.com/platform/gitops.git
  destinations:
    - server: https://kubernetes.default.svc
      namespace: app-dev
  clusterResourceWhitelist: []
  namespaceResourceBlacklist:
    - group: ""
      kind: Secret
    - group: rbac.authorization.k8s.io
      kind: Role
    - group: rbac.authorization.k8s.io
      kind: RoleBinding
```

```bash
kubectl apply -f business-dev-project.yaml
kubectl -n argocd get appprojects
```

这仅限制 Argo CD Project 的资源范围。还应收紧 Argo CD 控制器在目标 ACK 集群的 Kubernetes RBAC；默认全权限安装不适合多租户生产。

### 6.4 创建 Dev Application

`order-service-dev.yaml`：

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: order-service-dev
  namespace: argocd
spec:
  project: business-dev
  source:
    repoURL: https://gitlab.example.com/platform/gitops.git
    targetRevision: main
    path: apps/order-service/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: app-dev
  syncPolicy:
    automated:
      enabled: true
      prune: false
      selfHeal: true
```

```bash
kubectl apply -f order-service-dev.yaml
kubectl -n argocd get applications
kubectl -n app-dev get deployments,pods,services
```

如部署到了**另一个 ACK 集群**，必须先安全注册该集群并把 `destination.server` 改成注册的实际地址，不能照抄 `kubernetes.default.svc`。

### 6.5 Prod 流程

- 生产 AppProject 仅允许目标生产 ACK / Namespace 与特定 GitOps Repo。
- 生产 Application 初期**不开启自动同步**。
- 审批 Prod 配置 MR 后，由发布负责人在 Argo CD 执行 Sync。
- 使用 Dev/Test 已验证的**同一镜像 Digest**进行生产提升。
- 回滚采取 Git Revert + 受控 Argo CD Sync；数据库更改必须向后兼容。

**验收**：更新 GitOps Dev 镜像版本并合并 MR 后，Argo CD 检测差异并部署到 `app-dev`；任何普通 Runner Job 都没有直接修改业务集群 Deployment 的权限。

---

## 7. Trivy 镜像扫描（P1）

Trivy 是执行工具，**不必部署独立服务器**。推荐在 GitLab CI Job 中使用固定版本的官方镜像/CLI。

示例（在 main 构建并推送成功后执行；需有镜像 Pull 权限）：

```yaml
scan-image:
  stage: scan
  tags: [ack-ci]
  image:
    name: aquasec/trivy:0.76.1
    entrypoint: [""]
  script:
    - trivy --version
    - trivy image --image-src remote --exit-code 1 \
        --severity HIGH,CRITICAL \
        "$ACR_HOST/$ACR_NAMESPACE/$CI_PROJECT_NAME:$CI_COMMIT_SHA"
  rules:
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
```

此处需要把 `scan` 加入 `stages`、配备私有 ACR Pull 认证，并检查 CI 运行容器能够访问 Trivy 漏洞数据库。如果使用独立 Trivy 扫描容器，镜像读取凭证也要安全提供。可先将扫描设为非阻断收集误报，再逐步升级为门禁。

**验收**：已知漏洞镜像产生报告；严重漏洞符合既定策略时阻断；扫描数据库更新失败要区别于“镜像无漏洞”。

---

## 8. SonarQube 安装（P1）

SonarQube 是**代码质量服务器**，不同于 Trivy。可先复用企业已有实例；没有再部署。

### 8.1 前提

- 独立 PostgreSQL（生产不使用内置 H2）；数据库版本需与选用的 SonarQube Community Build 兼容。
- 足够的内存、持久化与 Linux 内核参数，具体以选定 SonarQube 版本要求为准。
- 受控 Ingress/TLS/SSO 或内网访问。

### 8.2 Helm 安装示例

```bash
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update sonarqube
helm search repo -l sonarqube/sonarqube
kubectl create namespace sonarqube --dry-run=client -o yaml | kubectl apply -f -
```

根据官方 Chart 说明创建 `sonarqube-values.yaml`，启用 `community.enabled: true`、指定外部 PostgreSQL、持久化、监控 Passcode 和资源限制；**数据库、Passcode 不应直接写进可提交 Git 的 values 文件**。

```bash
: "${SONAR_CHART_VERSION:?请先设置经验证的 SonarQube Chart 版本}"
helm upgrade --install sonarqube sonarqube/sonarqube \
  --namespace sonarqube \
  --version "$SONAR_CHART_VERSION" \
  -f sonarqube-values.yaml \
  -f sonarqube-secrets.values.yaml \
  --wait --timeout 20m
```

`sonarqube-secrets.values.yaml` 仅为 POC 临时做法，权限设为 600 且禁止提交 Git；正式环境使用外部 Secret 与官方 Helm 参数连接。

**验收**：SonarQube Web 能访问、连接外部 PostgreSQL、能创建 Project 和受限 Token；MR Pipeline 中 Maven Scanner 能上传结果。**社区版本具体 MR 分析与分支功能限制需按实际版本和授权核对**。

---

## 9. Prometheus / Grafana（P1）

如果 ACK 已有阿里云托管 Prometheus 或企业监控平台，可优先复用，避免再维护一套。

独立部署方案：

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
helm search repo -l prometheus-community/kube-prometheus-stack

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

: "${MONITOR_CHART_VERSION:?请先设置已验证的监控 Chart 版本}"
helm upgrade --install observability \
  prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --version "$MONITOR_CHART_VERSION" \
  -f monitoring-values.yaml \
  --wait --timeout 20m
```

部署前必须准备 `monitoring-values.yaml`：Grafana 管理员认证/SSO、Prometheus 数据保留周期、持久化 PVC、资源限制和安全访问方式。Chart 通常同时安装 Prometheus Operator、Prometheus、Alertmanager、Grafana 等组件。

**建议指标**：Runner 在线/队列长度/Job 失败率、CI Job 排队时间和构建耗时；Argo CD Application Sync/Health、部署耗时；ACK 节点 CPU/内存/磁盘与 Pod CrashLoopBackOff；ACR 拉取失败率等。需要另外配置相应 Exporter/ServiceMonitor 才能采集到完整指标。

**验收**：Grafana 可见集群与 Runner 指标，模拟 Runner 离线或 Argo CD Application 异常能触发告警。

---

## 10. External Secrets Operator（P2，可选但推荐生产治理）

在团队规模增长后，建议用 External Secrets Operator（ESO）与经批准的 Secret Provider 同步凭证，而不是在 GitOps 仓库保存明文 Secret。

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update external-secrets
helm search repo -l external-secrets/external-secrets

: "${ESO_CHART_VERSION:?请先设置已验证的 ESO Chart 版本}"
helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --version "$ESO_CHART_VERSION" \
  --wait --timeout 15m
```

随后创建 `SecretStore` 或 `ClusterSecretStore`，配置连接阿里云支持的 Secret Manager / KMS 服务的身份与权限；不同 Provider 认证方式不同，**没有实际账号与授权信息时不能套用一份通用可运行的 SecretStore YAML**。

**验收**：ESO 能定期从指定凭证源同步到目标 Namespace；无权的 Namespace 不能获取其他业务 Secret；轮换原始凭证后同步生效。

---

## 11. AI Code Review（P2，无须单独安装一套 CI 平台）

- 使用 GitLab Merge Request Pipeline 启动专用 Review Job。
- Agent/Skills 放入固定版本的审查镜像，遵守最小权限。
- MR Diff 作为**不可信数据**处理；禁止被仓库内提示词诱导执行敏感操作。
- 初期只生成 JSON/Markdown 报告，不写回 MR；稳定后再用受限 Bot 创建评论。
- 不允许 AI 审查结果绕过确定性测试、静态安全检查或人工发布审批。

建议先在一两个 Spring Boot 服务试点，验证误报率、Token 成本、审查耗时和开发者接受度。

---

## 12. 部署完成后的端到端验证

### 12.1 验证测试顺序

| 步骤 | 验收操作 | 通过标准 |
|---|---|---|
| 1 | Runner Online | GitLab 中 `ack-ci` 可用 |
| 2 | MR 测试 | 自动启动 Kubernetes CI Pod 且 JUnit 报告可见 |
| 3 | 受保护 main 构建 | Jib 成功向 ACR 推送 Commit SHA 镜像 |
| 4 | K8s 拉取镜像 | `app-dev` 中不存在 ImagePullBackOff |
| 5 | GitOps MR | 受控 Bot 创建更新镜像版本的 MR |
| 6 | Argo CD Dev | Dev 配置合并后自动同步、应用健康 |
| 7 | Argo CD Prod | 未经人工审批/Sync 不会发布生产 |
| 8 | 权限否定测试 | Runner 无权限修改 `app-prod` Deployment |
| 9 | 回滚演练 | Git Revert 后恢复到已验证镜像版本 |
| 10 | 故障注入 | Runner 停止、ACR 拒绝访问、Secret 过期能被正确发现 |

### 12.2 关键诊断命令

```bash
kubectl get pods -A | grep -E 'runner|argo|order-service'
kubectl -n ci-jobs get pods -o wide
kubectl -n ci-jobs describe pod <FAILED_JOB_POD>
kubectl -n ci-manager get events --sort-by=.lastTimestamp
kubectl -n argocd get applications
kubectl -n app-dev get deploy,rs,pod,svc
kubectl -n app-dev describe deployment order-service
kubectl -n app-dev get events --sort-by=.lastTimestamp
helm list -A
```

### 12.3 常见问题速查

| 症状 | 优先排查 |
|---|---|
| Runner Offline | GitLab URL、DNS/TLS、Runner Token、出网策略 |
| Job Pending | Tag、Runner 保护策略、节点选择、资源不足、RBAC |
| Failed to create Pod | `ci-jobs` RoleBinding、SA、Pod Security、配额 |
| Maven 拉依赖失败 | Nexus 镜像、DNS/代理、证书、出网策略 |
| Jib 推送 401/403 | ACR 登录凭证、RAM 仓库权限、Registry 地址 |
| ImagePullBackOff | ACR VPC/DNS、仓库 Pull 权限、imagePullSecrets |
| Argo CD Unknown | Git Repo 权限、Repository Secret、URL `.git` 后缀 |
| Argo CD OutOfSync | Kustomize 渲染结果、目标权限、实际资源漂移 |
| Argo CD Degraded | Probe、Pod Crash、资源、HPA/依赖服务 |
| SonarQube CrashLoop | PostgreSQL、内核参数、PVC、内存 |
| 监控无数据 | ServiceMonitor selector、采集端口、RBAC |

---

## 13. 实施排期与责任分工

| 周次 | 工作 | 验收物 |
|---|---|---|
| 第 1 周 | ACK 网络/节点池、ACR、Runner、权限 | Runner Online + MR 测试 |
| 第 2 周 | Maven/Jib、ACR、镜像规范与基础扫描 | 可追溯镜像 |
| 第 3 周 | GitOps 仓库、Kustomize、Argo CD Dev | GitOps 自动部署 |
| 第 4 周 | Prod 隔离、审批、手动 Sync、回滚 | 生产权限及回滚演练 |
| 第 5 周 | 质量门禁、Trivy、SonarQube（按需） | 扫描与质量报告 |
| 第 6 周 | 监控、模板复用、可靠性和故障演练 | 平台验收报告 |

前四周形成可交付核心链路；第 5–6 周可根据团队规模调整，避免过早堆叠组件。

### 13.1 关键安全核对

- [ ] Runner Manager 仅有 `ci-jobs` 所需 RBAC，非 `cluster-admin`。
- [ ] Runner CI Job 不自动挂载 Kubernetes API Token。
- [ ] CI Job 不使用 Docker Socket / privileged 模式。
- [ ] CI 与生产工作负载有明确网络、计算、权限隔离。
- [ ] 镜像 Tag 不可覆盖，生产尽量部署 Digest。
- [ ] ACR 凭证最小权限且仅受保护分支可用。
- [ ] GitOps 生产分支受保护，生产提升需要独立审批。
- [ ] Argo CD AppProject 限制仓库、Namespace、资源种类。
- [ ] Argo CD 控制器 Kubernetes RBAC 根据租户与集群范围审计。
- [ ] 所有密钥具备轮换与过期处理流程。
- [ ] 完成 Runner/Argo CD 升级与回滚的演练。

---

## 14. 官方资料（实施时请复核）

以下链接是本手册使用的官方材料，安装具体版本前请查看对应版本文档：

- GitLab Runner Helm 安装：https://docs.gitlab.com/runner/install/kubernetes/
- GitLab Runner Helm RBAC：https://docs.gitlab.com/runner/install/kubernetes_helm_chart_configuration/
- Argo CD Helm Chart：https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
- Argo CD 安装与高可用：https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/
- Argo CD 声明式配置与 GitLab 仓库：https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/
- 阿里云 ACK 获取 KubeConfig：https://help.aliyun.com/zh/ack/ack-managed-and-ack-dedicated/user-guide/access-clusters/
- ACR 企业版创建：https://help.aliyun.com/zh/acr/user-guide/
- ACR 访问凭证：https://www.alibabacloud.com/help/zh/acr/user-guide/configure-access-credentials
- Jib Maven Plugin：https://github.com/GoogleContainerTools/jib
- Trivy 安装：https://trivy.dev/docs/latest/getting-started/installation/
- SonarQube Community Build Helm：https://docs.sonarsource.com/sonarqube-community-build/server-installation/on-kubernetes-or-openshift/installing-helm-chart/
- kube-prometheus-stack：https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- External Secrets Operator：https://external-secrets.io/latest/introduction/getting-started/

---

## 15. 与现有文档及配置包的对应关系

- 《GitLab_ACK_CICD_落地实施方案.md》：解释选型、权限模型和总体交付流程。
- `gitlab-ack-cicd-kit.zip`：提供 Runner Values、示例 `.gitlab-ci.yml`、Kustomize、Argo CD Application、GitOps MR 脚本。
- **本安装手册**：解释各组件安装顺序、前置条件、命令、验收、故障排查和可选增强。

所有示例均属于实施模板。你需要根据现有 GitLab 是自建/SaaS、ACK CNI 和节点池、ACR 企业版实例、TLS 证书、项目分支保护等实际条件进行调整。
