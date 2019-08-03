

docker : 
  namespace : 环境隔离（进程、网络以及文件系统）
  cgroup：资源隔离（cpu、内存）
  UnionFS（镜像分层存储）

k8S：
  master：master节点是k8s集群的控制节点，负责整个集群的管理与控制。
  kube-apiserver：集群控制的入口，提供http服务。
  kube-controller-manager：集群中所有资源对象的自动化控制中心。
  kube-scheduler：负责pod的调度
  node：NODE节点是k8s集群中的工作节点，Node上的工作负载由master节点分配，工作负载主要是运行容器应用。
  kubelet：负责Pod的创建、启动、监控、重启、销毁等工作，同时与master节点协作，实现集群管理的基本功能。
  kube-proxy：实现k8s service的通信和负载均衡。
  Pod：k8s最基本的部署调度单元，每个pod可以由一个或多个业务容器和一个根容器（pause）组成，一个pod表示一个应用实例。
  Deployment：表示部署，内部用replicaset实现，可以用来生成相应的replicaset完成pod副本的创建。
  service：k8S最主要的资源对象，k8S中的service对象可以对应微服务中的服务，service定义了服务的访问入口，服务的调用者通过这个地址访问service后端的pod副本实例。service通过label selector同pod副本建立关系，deployment保证pod副本的数量，也是保证服务的伸缩性。
                      
 Pod创建流程：                                                      
  ●用户通过REST API创建一个Pod
  ●apiserver将其写入etcd
  ●scheduluer 检测到未绑定Node的Pod,开始调度并更新Pod的Node绑定
  ●kubelet检测到有新的Pod调度过来，通过container runtime运行该Pod
  ●kubelet 通过container runtime取到Pod状态，并更新到apiserver中


