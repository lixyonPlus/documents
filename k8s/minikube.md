1. 获取minikube二进制文件
2. 获取kubectl二进制文件
3. 启动:
   minikube start --vm-driver=virtualbox --image-mirror-contry=cn --image-repository=registry.cn-hangzhou.aliyuncs.com/google_containers --iso-url=https://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/iso/minikube-v1.7.3.iso  --registry-mirror=https://hub-mirror.c.163.com
4.查看minikube状态 minikube status
