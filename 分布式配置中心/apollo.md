## apollo

- apollo基于springcloud生态配置，使用eureka做服务发现注册，ribbon做负载均衡
- Namespace：表示一个配置文件
- 集群：一个环境可以包含多个集群（通过idc指定应用的集群）
- 环境：每个环境需要重新部署一个节点服务
### 容器化部署时，如果有多个网卡，可以忽略部分网卡
```yaml
spring:
  application:
      name: apollo-configservice
  profiles:
    active: ${apollo_profile}
  cloud:
    inetutils:
      ignoredInterfaces:
        - docker0
        - veth.*
```