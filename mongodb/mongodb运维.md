### MongoDB 分片
- 为什么使用分片
    - 复制所有的写入操作到主节点
    - 延迟的敏感数据会在主节点查询
    - 单个副本集限制在12个节点
    - 当请求量巨大时会出现内存不足。
    - 本地磁盘不足
    - 垂直扩展价格昂贵
    
    ![sharding](https://www.runoob.com/wp-content/uploads/2013/12/sharding.png)

- 上图中主要有如下所述三个主要组件：
  - Shard:用于存储实际的数据块，实际生产环境中一个shard server角色可由几台机器组个一个replica set承担，防止主机单点故障
  - Config Server:mongod实例，存储了整个 ClusterMetadata，其中包括 chunk信息。
  - Query Routers:前端路由，客户端由此接入，且让整个集群看上去像单一数据库，前端应用可以透明使用。
  