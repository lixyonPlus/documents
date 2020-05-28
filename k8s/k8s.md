
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

### kubectl apply -f https://k8s.io/examples/application/deployment.yaml --record
    --record 记录日志信息,可以很方便的查看每次 revision 的变化。
      kubectl rollout history xxx 查询所有的
      kubectl rollout history deployment XXX --revision=1    查询单个

### kubectl apply 与 create 区别:
      kubectl create命令可创建新资源。 因此，如果再次运行该命令，则会抛出错误，因为资源名称在名称空间中应该是唯一的。yaml文件必须是完整的配置字段内容
      kubectl apply命令将配置应用于资源。 如果资源不在那里，那么它将被创建。 kubectl apply命令可以第二次运行，因为它只是应用如下所示的配置。 在这种情况下，配置没有改变。 所以，pod没有改变。yaml文件可以不完整，只写需要的字段	