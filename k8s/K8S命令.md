# K8S命令

### 可以使用以下命令显示节点状态和有关节点的其他详细信息：
> kubectl describe node <insert-node-name-here>

### 在仅有两种资源的情况下，可以使用"资源类型/资源名"的语法在命令行中同时指定这两个资源：
> kubectl delete deployments/my-nginx services/my-nginx-svc

### 使用 -l 或 --selector 指定的筛选器（标签查询）能很容易根据标签筛选资源：
> kubectl delete deployment,services -l app=nginx

### 在project/k8s/development目录下递归创建服务(--recursive)
> kubectl apply -f project/k8s/development --recursive

### 将所有标签值为nginx的pod标记为前端层tier=fe
> kubectl label pods -l app=nginx tier=fe

### 查看标记的pods
> kubectl get pods -l app=nginx -L tier

### 将pod为my-nginx-v4-9gw19的添加注解
> kubectl annotate pods my-nginx-v4-9gw19 description='my frontend running nginx'

### 查看pod
> kubectl get pods my-nginx-v4-9gw19 -o yaml

### 将nginx副本的数量从3减少到1
> kubectl scale deployment/my-nginx --replicas=1

### 让系统自动选择需要 nginx 副本的数量，范围从 1 到 3，请执行以下操作：
> kubectl autoscale deployment/my-nginx --min=1 --max=3

### 使用edit更新资源（这相当于首先get资源，在文本编辑器中编辑它，然后用更新的版本apply资源）
> kubectl edit deployment/my-nginx

### --force 删除并重新创建资源
> kubectl replace -f https://k8s.io/examples/application/nginx/nginx-deployment.yaml --force

### 想要 node 名称
> nodes=$(kubectl get nodes -o jsonpath='{range.items[*].metadata}{.name} {end}')


### 想要 node IP 
> nodes=$(kubectl get nodes -o jsonpath='{range .items[*].status.addresses[?(@.type=="ExternalIP")]}{.address} {end}')

### 使用 Docker Config 创建 Secret
> kubectl create secret docker-registry <name> --docker-server=DOCKER_REGISTRY_SERVER --docker-username=DOCKER_USER --docker-password=DOCKER_PASSWORD --docker-email=DOCKER_EMAIL
