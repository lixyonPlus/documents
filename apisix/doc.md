# 安装k8s
...忽略

---

# 安装helm
1.下载
https://repo.huaweicloud.com/helm/v3.7.1/helm-v3.7.1-linux-amd64.tar.gz
2. 解压
tar -zxvf helm-v3.7.1-linux-amd64.tar.gz
3. 拷贝
cp linux-amd64/helm /usr/bin
4. 验证是否安装成功
helm version

---

# 安装apisix & apisix-ingress & apisix-dashboard
- https://apisix.apache.org/zh/docs/ingress-controller/deployments/minikube/
1. 加载仓库
helm repo add apisix https://charts.apiseven.com
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
2. 创建命名空间
kubectl create ns apisix
3. 用helm方式安装apisix & apisix-ingress
  helm install apisix apisix/apisix \
    --set gateway.type=LoadBalancer \
    --set ingress-controller.enabled=true \
    --set etcd.persistence.storageClass="alicloud-disk-ssd" \
    --set etcd.persistence.size="20Gi" \
    --namespace apisix \
    --set ingress-controller.config.apisix.serviceNamespace=apisix
4. 用helm方式安装apisix-dashboard
helm install apisix-dashboard apisix/apisix-dashboard --create-namespace --namespace apisix
5. 查看资源是否正常运行
kubectl get service --namespace apisix


# apisix-dashboard配合k8s服务发现使用
- https://apisix.apache.org/zh/docs/apisix/discovery/kubernetes/
1. 创建sa,apisix默认使用的是default，需要修改apisix的yaml配置
```yaml
kind: ServiceAccount
apiVersion: v1
metadata:
 name: apisix
 namespace: apisix
---

kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 name: apisix
rules:
- apiGroups: [ "" ]
  resources: [ endpoints ]
  verbs: [ get,list,watch ]
---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
 name: apisix
roleRef:
 apiGroup: rbac.authorization.k8s.io
 kind: ClusterRole
 name: apisix
subjects:
 - kind: ServiceAccount
   name: apisix
   namespace: apisix
```
2. 服务配置如下
```json
{
  "timeout": {
    "connect": 6,
    "send": 6,
    "read": 6
  },
  "type": "roundrobin",
  "scheme": "http",
  "discovery_type": "kubernetes",
  "pass_host": "pass",
  "name": "log-record-service",
  "service_name": "hc-public/log-record-service:8080",
  "keepalive_pool": {
    "idle_timeout": 60,
    "requests": 1000,
    "size": 320
  }
}
```