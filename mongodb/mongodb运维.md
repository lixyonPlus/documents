MongoDB副本集设置
 - mongod --port "PORT" --dbpath "YOUR_DB_DATA_PATH" --replSet "REPLICA_SET_INSTANCE_NAME"
  - mongod --port 27017 --dbpath "D:\set up\mongodb\data" --replSet rs0
    - 以上实例会启动一个名为rs0的MongoDB实例，其端口号为27017。
    - 启动后打开命令提示框并连接上mongoDB服务。  
    - 在Mongo客户端使用命令rs.initiate()来启动一个新的副本集。
    - 我们可以使用rs.conf()来查看副本集的配置
    - 查看副本集状态使用 rs.status() 命令
副本集添加成员
  - rs.add(HOST_NAME:PORT)
    - rs.add("mongod1.net:27017")
  - MongoDB中你只能通过主节点将Mongo服务添加到副本集中， 判断当前运行的Mongo服务是否为主节点可以使用命令db.isMaster() 。MongoDB的副本集与我们常见的主从有所不同，主从在主机宕机后所有服务将停止，而副本集在主机宕机后，副本会接管主节点成为主节点，不会出现宕机的情况。
  
MongoDB 后台管理 Shell
  - 如果你需要进入MongoDB后台管理，你需要先打开mongodb装目录的下的bin目录，然后执行mongo.exe文件，MongoDB Shell是MongoDB自带的交互式Javascript shell,用来对MongoDB进行操作和管理的交互式环境。
  - 当你进入mongoDB后台后，它默认会链接到 test 文档（数据库）：


MongoDB 分片
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
  
- MongoDB数据备份
  - mongodump -h dbhost -d dbname -o dbdirectory
    - -h：MongDB所在服务器地址，例如：127.0.0.1，当然也可以指定端口号：127.0.0.1:27017
    - -d：需要备份的数据库实例，例如：test
    - -o：备份的数据存放位置，例如：c:\data\dump，当然该目录需要提前建立，在备份完成后，系统自动在dump目录下建立一个test目录，这个目录里面存放该数据库实例的备份数据。
    ```
    mongodump
    ```
    `执行以上命令后，客户端会连接到ip为 127.0.0.1 端口号为 27017 的MongoDB服务上，并备份所有数据到 bin/dump/ 目录中。命令输出结果如下：`
    ![mongodump](https://www.runoob.com/wp-content/uploads/2013/12/mongodump.png)
    - mongodump 命令可选参数列表如下所示：
      - mongodump --host HOST_NAME --port PORT_NUMBER	该命令将备份所有MongoDB数据	mongodump --host runoob.com --port 27017
      - mongodump --dbpath DB_PATH --out BACKUP_DIRECTORY		mongodump --dbpath /data/db/ --out /data/backup/
      - mongodump --collection COLLECTION --db DB_NAME
      
 MongoDB数据恢复
  - mongorestore -h <hostname><:port> -d dbname <path>
     - --host <:port>, -h <:port>：MongoDB所在服务器地址，默认为： localhost:27017
     - --db , -d ：需要恢复的数据库实例，例如：test，当然这个名称也可以和备份时候的不一样，比如test2
     - --drop 恢复的时候，先删除当前数据，然后恢复备份的数据。就是说，恢复后，备份后添加修改的数据都会被删除，慎用哦！
     - <path>：mongorestore 最后的一个参数，设置备份数据所在位置，例如：c:\data\dump\test。你不能同时指定 <path> 和 --dir 选项，--dir也可以设置备份目录。
     - --dir：指定备份的目录

