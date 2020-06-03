# K8S命令

### 可以使用以下命令显示节点状态和有关节点的其他详细信息：
> kubectl describe node <insert-node-name-here>

### 在仅有两种资源的情况下，可以使用"资源类型/资源名"的语法在命令行中同时指定这两个资源：
> kubectl delete deployments/my-nginx services/my-nginx-svc

### 使用 -l 或 --selector 指定的筛选器（标签查询）能很容易根据标签筛选资源：
> kubectl delete deployment,services -l app=nginx

### 在project/k8s/development目录下递归创建服务(--recursive)
> kubectl apply -f project/k8s/development --recursive

### kubectl label pods -l app=nginx tier=fe
