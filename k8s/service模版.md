
```
apiVersion: v1
kind: Service
metadata:
  name: string # 名称
  labels: # 标签（k/v）
    k: v # service标签
spec:
  type: NodePort      #这里代表是NodePort类型的
  ports:
  - port: 80          #这里的端口和clusterIP对应，该端口供集群内部访问。
    targetPort: 8081  #该端口一定要和container容器暴露出来的端口对应
    protocol: TCP #协议
    nodePort: 32143   # 所有的节点都会开放此端口，此端口供外部调用。[30000 - 32767]
  selector:
    k: v          # 要匹配的Pod的Label标签
```
