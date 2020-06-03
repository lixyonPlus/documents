
# k8S

![api文档](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.18)

![kubectl文档](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands)

### master节点是k8s集群的控制节点，负责整个集群的管理与控制。
  - kube-apiserver：集群控制的入口，提供http服务。
  - kube-controller-manager：集群中所有资源对象的自动化控制中心。
    - 节点控制器（Node Controller）: 负责在节点出现故障时进行通知和响应。
    - 副本控制器（Replication Controller）: 负责为系统中的每个副本控制器对象维护正确数量的 Pod。
    - 端点控制器（Endpoints Controller）: 填充端点(Endpoints)对象(即加入 Service 与 Pod)。
    - 服务帐户和令牌控制器（Service Account & Token Controllers）: 为新的命名空间创建默认帐户和 API 访问令牌。
  - kube-scheduler：负责pod的调度

### NODE节点是k8s集群中的工作节点，Node上的工作负载由master节点分配，工作负载主要是运行容器应用。
  - kubelet：负责Pod的创建、启动、监控、重启、销毁等工作，同时与master节点协作，实现集群管理的基本功能。
  - kube-proxy：实现k8s service的通信和负载均衡。

### k8s基本对象
  - Pod：k8s最基本的部署调度单元，每个pod可以由一个或多个业务容器和一个根容器（pause）组成，一个pod表示一个应用实例。
  - Service：k8S最主要的资源对象，k8S中的service对象可以对应微服务中的服务，service定义了服务的访问入口，服务的调用者通过这个地址访问service后端的pod副本实例。service通过label selector同pod副本建立关系，deployment保证pod副本的数量，也是保证服务的伸缩性。
  - Volume:
  - Namespace:
  
### Controller高级对象
  - Deployment：表示部署，内部用replicaset实现，可以用来生成相应的replicaset完成pod副本的创建。
  - DaemonSet

 ### Pod创建流程
  - 用户通过REST API创建一个Pod
  - apiserver将其写入etcd
  - scheduluer 检测到未绑定Node的Pod,开始调度并更新Pod的Node绑定
  - kubelet检测到有新的Pod调度过来，通过container runtime运行该Pod
  - kubelet 通过container runtime取到Pod状态，并更新到apiserver中

### 某些资源和API组默认情况下处于启用状态。 可以通过在apiserver上设置 --runtime-config 来启用或禁用它们。

### 在 extensions/v1beta1 API 组中，DaemonSets，Deployments，StatefulSet, NetworkPolicies, PodSecurityPolicies 和 ReplicaSets 是默认禁用的。 

### kubectl apply -f https://k8s.io/examples/application/deployment.yaml--record
    --record 记录日志信息,可以很方便的查看每次 revision 的变化。
      kubectl rollout history xxx 查询所有的
      kubectl rollout history deployment XXX --revision=1    查询单个

### kubectl apply 与 create 区别:
      kubectl create命令可创建新资源。 因此，如果再次运行该命令，则会抛出错误，因为资源名称在名称空间中应该是唯一的。yaml文件必须是完整的配置字段内容
      kubectl apply命令将配置应用于资源。 如果资源不在那里，那么它将被创建。 kubectl apply命令可以第二次运行，因为它只是应用如下所示的配置。 在这种情况下，配置没有改变。 所以，pod没有改变。yaml文件可以不完整，只写需要的字段	


### Kubernetes 会创建三个初始命名空间：
  - default 没有指明使用其它命名空间的对象所使用的默认命名空间
  - kube-system Kubernetes系统创建对象所使用的命名空间
  - kube-public 这个命名空间是自动创建的，所有用户（包括未经过身份验证的用户）都可以读取它。这个命名空间主要用于集群使用，以防某些资源在整个集群中应该是可见和可读的。这个命名空间的公共方面只是一种约定，而不是要求。

### 设置后续kubectl命令使用的命名空间
  ```
      kubectl config set-context --current --namespace=<insert-namespace-name-here>
      # Validate it
      kubectl config view | grep namespace:
  ```

### 当您创建一个Service时，Kubernetes会创建一个相应的DNS条目:<service-name>.<namespace-name>.svc.cluster.local，这意味着如果容器只使用 <service-name>它将被解析到本地命名空间的服务

### 但是命名空间资源本身并不在命名空间中。而且底层资源，例如 nodes 和持久化卷不属于任何命名空间。
```
# 在命名空间中
kubectl api-resources --namespaced=true
# 不在命名空间中
kubectl api-resources --namespaced=false
```

### 标签选择器、字段选择器、注解

### 空标签选择器（即，需求为零的选择器）选择集合中的每个对象。null 值的标签选择器（仅可用于可选选择器字段）不选择任何对象

### 两个控制器的标签选择器不得在命名空间内重叠，否则它们将互相冲突。

### 当前，有 3 个组件同 Kubernetes 节点接口交互：节点控制器、kubelet 和 kubectl。

### 节点控制器负责在节点不能访问时（也即是节点控制器因为某些原因没有收到心跳，例如节点宕机）将它的 NodeStatus 的 NodeReady 状态更新为 ConditionUnknown。后续如果节点持续不可访问，节点控制器将删除节点上的所有 pods（使用优雅终止）。（默认情况下 40s 开始报告 ConditionUnknown，在那之后 5m 开始删除 pods。）节点控制器每隔 --node-monitor-period 秒检查每个节点的状态。

### 当状态发生变化时，或者在配置的时间间隔内没有更新时，kubelet 会更新 NodeStatus。 NodeStatus 更新的默认间隔为 5 分钟（比无法访问的节点的 40 秒默认超时时间长很多）。kubelet 会每 10 秒（默认更新间隔时间）创建并更新其 Lease 对象。Lease 更新独立于 NodeStatus 更新而发生。

### 从 1.4 开始，节点控制器在决定删除 pod 之前会检查集群中所有节点的状态。大部分情况下，节点控制器把驱逐频率限制在每秒 --node-eviction-rate 个（默认为 0.1）。这表示它每 10 秒钟内至多从一个节点驱逐 Pods。

### 当一个可用区域中的节点变为不健康时，它的驱逐行为将发生改变。节点控制器会同时检查可用区域中不健康（NodeReady 状态为 ConditionUnknown 或 ConditionFalse）的节点的百分比。如果不健康节点的部分超过 --unhealthy-zone-threshold （默认为 0.55），驱逐速率将会减小：如果集群较小（意即小于等于 --large-cluster-size-threshold 个 节点 - 默认为 50），驱逐操作将会停止，否则驱逐速率将降为每秒 --secondary-node-eviction-rate 个（默认为 0.01）。

### 节点上的 labels 可以和 pods 的节点 selectors 一起使用来控制调度，例如限制一个 pod 只能在一个符合要求的节点子集上运行。s标记一个节点为不可调度的将防止新建 pods 调度到那个节点之上，但不会影响任何已经在它之上的 pods。这是重启节点等操作之前的一个有用的准备步骤。例如，标记一个节点为不可调度的，执行以下命令：
> kubectl cordon $NODENAME

### 请注意，被 daemonSet 控制器创建的 pods 将忽略 Kubernetes 调度器，且不会遵照节点上不可调度的属性。这个假设基于守护程序属于节点机器，即使在准备重启而隔离应用的时候。

### Kubernetes 调度器保证一个节点上有足够的资源供其上的所有 pods 使用。它会检查节点上所有容器要求的总和不会超过节点的容量。这包括由 kubelet 启动的所有容器，但不包括由 container runtime 直接启动的容器，也不包括在容器外部运行的任何进程。

### 在某个路径下的多个子路径中组织资源，那么也可以递归地在所有子路径上执行操作，方法是在 --filename,-f 后面指定 --recursive 或者 -R。