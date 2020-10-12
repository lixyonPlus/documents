### mongo复制集
 复制集的作用
- 在实现高可用的同时，复制集实现了其他几个附加作用:
- 数据分发:将数据从一个区域复制到另一个区域，减少另一个区域的读延迟 
- 读写分离:不同类型的压力分别在不同的节点上执行
- 异地容灾:在数据中心故障时候快速切换到异地

### 典型复制集结构
一个典型的复制集由3个以上具有投票权的节点组成，包括:
- 一个主节点(PRIMARY):接受写入操作和选举时投票
- 两个(或多个)从节点(SECONDARY):复制主节点上的新数据和选举时投票 
- 不推荐使用 Arbiter(投票节点)

### 数据是如何复制的?
- 当一个修改操作，无论是插入、更新或删除，到达主节点时，它对数据的操作将被 记录下来(经过一些必要的转换)，这些记录称为 oplog。
- 从节点通过在主节点上打开一个 tailable 游标不断获取新进入主节点的 oplog，并 在自己的数据上回放，以此保持跟主节点的数据一致。

### 通过选举完成故障恢复
- 具有投票权的节点之间两两互相发送心跳;
- 当5次心跳未收到时判断为节点失联;
- 如果失联的是主节点，从节点会发起选举，选出新的主节点;
- 如果失联的是从节点则不会产生新的选举;
- 选举基于 RAFT一致性算法 实现，选举成功的必要条件是大多数投票节点存活;
- $\color{red}{复制集中最多可以有50个节点，但具有投票权的节点最多7个}$

### 影响选举的因素
- 整个集群必须有大多数节点存活;
- 被选举为主节点的节点必须:
- 能够与多数节点建立连接
- 具有较新的 oplog
- 具有较高的优先级(如果有配置)

### 复制集节点有以下常见的选配项:
- 是否具有投票权(v 参数):有则参与投票;
- 优先级(priority 参数):优先级越高的节点越优先成为主节点。优先级为0的节点无法成 为主节点;
- 隐藏(hidden 参数):复制数据，但对应用不可见。隐藏节点可以具有投票仅，但优先 级必须为0;
- 延迟(slaveDelay 参数):复制 n 秒之前的数据，保持与主节点的时间差。

### $\color{red}{增加复制节点不会增加系统写性能}$
--- 
- 配置mongo配置文件
```yaml
# mongod.conf
systemLog:
  destination: file
  path: /data1/mongod.log   # 日志文件路径
  logAppend: true
storage:
  dbPath: /data1    # 数据目录
net:
  bindIp: 0.0.0.0
  port: 28017   # 端口
replication:
  replSetName: rs0
processManagement:
  fork: true 
```

- 创建复制集
```javascript
// 方法1，注意:此方式hostname 需要能被解析
# mongo --port 28017
> rs.initiate()
> rs.add(”HOSTNAME:28018") 
> rs.add(”HOSTNAME:28019")

// ---------------------------------------------------
// 方法2
# mongo --port 28017
> rs.initiate({
    _id: "rs0",
    members: [{
        _id: 0,
        host: "primary:27017"
    },{
        _id: 1,
        host: "secondary1:27017"
    },{
        _id: 2,
        host: "secondary2:27017"
    }]
})
```

# mongo 分片集群
### 为什么要使用分片集群?
- 数据容量日益增大，访问性能日渐降低，怎么破? 
- 新品上线异常火爆，如何支撑更多的并发用户?
- 单库已有 10TB 数据，恢复需要1-2天，如何加速? 
- 地理分布数据
![分片集群](https://s1.ax1x.com/2020/10/10/0yIp3q.png)
- mongos路由节点
  - 提供集群单一入口
  - 转发应用端请求
  - 选择合适数据节点进行读写
  - 合并多个数据节点的返回
  - 无状态 建议至少2个
- 配置节点mongod
  - 配置(目录)节点
  - 提供集群元数据存储
  - 分片数据分布的映射
  - 普通复制集架构
- 数据节点mongod
  - 以复制集为单位 
  - 横向扩展 
  - 最大1024分片 
  - 分片之间数据不重复 
  - 所有分片在一起才可完整工作

### 分片集群数据分布方式
- 基于范围
- 基于 Hash
- 基于 zone / tag

### 分片集群数据分布方式 – 基于范围
![分片集群](https://s1.ax1x.com/2020/10/10/0yoxlq.png)

### 分片集群数据分布方式 – 基于哈希
![分片集群](https://s1.ax1x.com/2020/10/10/0yTe6x.png)

### 分片集群数据分布方式 – 自定义Zone
![分片集群](https://s1.ax1x.com/2020/10/10/0yTtjP.png)

### 分片大小
- 分片的基本标准:
  - 关于数据:数据量不超过3TB，尽可能保持在2TB一个片; -
  - 关于索引:常用索引必须容纳进内存;
- 按照以上标准初步确定分片后，还需要考虑业务压力，随着压力增大，CPU、RAM、 磁盘中的任何一项出现瓶颈时，都可以通过添加更多分片来解决。

### 合理的架构 – 需要多少个分片
- A = 所需存储总量 / 单服务器可挂载容量 8TB / 2TB = 4
- B = 工作集大小 / 单服务器内存容量 400GB / (256G * 0.6) = 3
- C = 并发量总数 / (单服务器并发量 * 0.7)[额外开销] 30000 / (9000*0.7) = 6
- 分片数量 = max(A, B, C) = 6

### 分片关键字
- 片键 shard key:文档中的一个字段
- 文档 doc :包含 shard key 的一行数据
- 块 Chunk :包含 n 个文档
- 分片 Shard:包含 n 个 chunk
- 集群 Cluster: 包含 n 个分片
![分片集群](https://s1.ax1x.com/2020/10/10/0yHMJH.png)

### 选择基数大的片键
- 对于小基数的片键:
  - 因为备选值有限，那么块的总数量就有限; 
  - 随着数据增多，块的大小会越来越大;
  - 水平扩展时移动块会非常困难;
- 例如:存储一个高中的师生数据，以年龄(假设年龄范围为15~65岁)作为片键， 那么:
  - 15<=年龄<=65，且只为整数 
  - 最多只会有51个chunk

### 选择分布均匀的片键
- 对于分布不均匀的片键:
  - 造成某些块的数据量急剧增大
  - 这些块压力随之增大
  - 数据均衡以 chunk 为单位，所以系统无能为力
- 例如:存储一个学校的师生数据，以年龄(假设年龄范围为15~65岁)作为片键， 那么:
  - 15<=年龄<=65，且只为整数
  - 大部分人的年龄范围为15~18岁(学生)
  - 15、16、17、18四个 chunk 的数据量、访问压力远大于其他 chunk

### 分片集群搭建
![集群架构](https://s1.ax1x.com/2020/10/12/028FbD.png)
![节点分布](https://s1.ax1x.com/2020/10/12/023zCR.png) 
1. 配置域名解析
   - 在3个节点上分别执行以下3条命令，注意替换实际IP地址
```shell
echo "192.168.1.1 geekdemo1 member1.example.com member2.example.com" >> /etc/hosts 
echo "192.168.1.2 geekdemo2 member3.example.com member4.example.com" >> /etc/hosts 
echo "192.168.1.3 geekdemo3 member5.example.com member6.example.com" >> /etc/hosts
```
2. 准备分片目录
   - 在各服务器上创建数据目录，我们使用 `/data`，请按自己需要修改为其他目录:
```shell
# 在member1 / member3 / member5 上执行以下命令:
mkdir -p /data/shard1/ mkdir -p /data/config/
# 在member2 / member4 / member6 上执行以下命令:
mkdir -p /data/shard2/ mkdir -p /data/mongos/
```
3. 创建第一个分片用的复制集
```shell
# 在 member1 / member3 / member5 上执行以下命令。
mongod --bind_ip 0.0.0.0 --replSet shard1 --dbpath /data/shard1 --logpath /data/shard1/mongod.log --port 27010 --fork --shardsvr --wiredTigerCacheSizeGB 1
```
4. 初始化第一个分片复制集
```shell
> mongo --host member1.example.com:27010
> rs.initiate({
    _id: "shard1",
    "members" : [
      {"_id": 0,
       "host" : "member1.example.com:27010"
      },
      {"_id": 1,
       "host" : "member3.example.com:27010"
      },
      {"_id": 2,
       "host" : "member5.example.com:27010"
      }
    ]
})
```
5. 创建config server复制集
```shell
# 在 member1 / member3 / member5 上执行以下命令。
mongod --bind_ip 0.0.0.0 --replSet config --dbpath /data/config --logpath /data/config/mongod.log --port 27019 --fork --configsvr --wiredTigerCacheSizeGB 1
```
6. 初始化config server复制集
```shell
> mongo --host member1.example.com:27019
> rs.initiate({
    _id: "config",
    "members" : [
      {"_id": 0,
      "host":"member1.example.com:27019"
      },
      {"_id": 1,
      "host":"member3.example.com:27019"
      },  
      {"_id": 2,
      "host":"member5.example.com:27019"
      }
    ]
})
```
7. 在第一台机器上搭建 mongos
```shell
> mongos --bind_ip 0.0.0.0 --logpath /data/mongos/mongos.log --port 27017 --fork --configdb config/member1.example.com:27019,member3.example.com:27019,member5.example.com:27019
# 连接到mongos, 添加分片
> mongo --host member1.example.com:27017
mongos > sh.addShard("shard1/member1.example.com:27010,member3.example.com:27010,member5 .example.com:27010");
```
8. 创建分片表
```shell
# 连接到mongos, 创建分片集合
> mongo --host member1.example.com:27017
mongos > sh.status()
mongos > sh.enableSharding("foo")
mongos > sh.shardCollection("foo.bar", {_id: 'hashed'})
mongos > sh.status()
```
```shell
# 插入测试数据
use foo
for (var i = 0; i < 10000; i++) {
  db.bar.insert({i: i}); 
}
```
9. 创建第2个分片的复制集
```shell
# 在 member2 / member4 / member6 上执行以下命令。
> mongod --bind_ip 0.0.0.0 --replSet shard2 --dbpath /data/shard2 --logpath /data/shard2/mongod.log --port 27011 --fork --shardsvr --wiredTigerCacheSizeGB 1
```
10. 初始化第二个分片的复制集
```
> mongo --host member2.example.com:27011
> rs.initiate({
    _id: "shard2",
    "members" : [
      {
        "_id": 0,
        "host" : "member2.example.com:27011"
      },
      {
        "_id": 1,
        "host" : "member4.example.com:27011" 
      },
      {
        "_id": 2,
        "host" : "member6.example.com:27011"
      }
    ]
  });
```
11. 加入第2个分片
```shell
# 连接到mongos, 添加分片
> mongo --host member1.example.com:27017
mongos > sh.addShard("shard2/member2.example.com:27011,member4.example.com:27011, member6.example.com:27011");
mongos > sh.status()
```
---

# 两地三中心灾备架构
![](https://s1.ax1x.com/2020/10/12/0Rr5QS.png)
1. 配置域名解析
```shell
# 在3台虚拟机上分别执行以下3条命令，注意替换实际IP地址
echo "192.168.1.1 geekdemo1 member1.example.com member2.example.com" >> /etc/hosts 
echo "192.168.1.2 geekdemo2 member3.example.com member4.example.com" >> /etc/hosts 
echo "192.168.1.3 geekdemo3 member5.example.com" >> /etc/hosts
```
2. 启动5个MongoDB实例
```shell
# 在虚拟机1上执行以下命令
mkdir -p member1 member2
mongod --dbpath ~/member1 --replSet demo --bind_ip 0.0.0.0 --port 10001 --fork --logpath member1.log 
mongod --dbpath ~/member2 --replSet demo --bind_ip 0.0.0.0 --port 10002 --fork --logpath member2.log
# 在虚拟机2上执行以下命令
mkdir -p member3 member4
mongod --dbpath ~/member3 --replSet demo --bind_ip 0.0.0.0 --port 10003 --fork --logpath member3.log 
mongod --dbpath ~/member4 --replSet demo --bind_ip 0.0.0.0 --port 10004 --fork --logpath member4.log
# 在虚拟机3上执行以下命令
mkdir -p member5
mongod --dbpath ~/member5 --replSet demo --bind_ip 0.0.0.0 --port 10005 --fork --logpath member5.log
```
3. 初始化复制集
```shell
# 在虚拟机3上执行以下命令测试所有实例正常工作
mongo member1.example.com:10001 
mongo member2.example.com:10002 
mongo member3.example.com:10003 
mongo member4.example.com:10004 
mongo member5.example.com:10005
# 初始化复制集
mongo member1.example.com:10001 
rs.initiate(
  {
    "_id" : "demo", "version" : 1,
    "members" :[
      {"_id": 0, "host" : "member1.example.com:10001" },
      {"_id": 1, "host" : "member2.example.com:10002" },
      {"_id": 2, "host" : "member3.example.com:10003" },
      {"_id":3,  "host" : "member4.example.com:10004" },
      {"_id": 4, "host" : "member5.example.com:10005" }
    ]
  }
)  
```
4. 配置选举优先级
把第一台机器上的2个实例的选举优先级调高为5和10(默认为1)
(通常都有主备数据中心之分，我们希望给主数据中心更高的优先级)
```javascript
mongo member1.example.com:10001
cfg = rs.conf() 
cfg.members[0].priority = 5 
cfg.members[1].priority = 10 
rs.reconfig(cfg)
```
5. 启动持续写脚本(每2秒写一条记录)
在第3台机器上，执行以下mongo shell脚本
```javascript
// mongo --retryWrites 
mongodb://member1.example.com:10001,member2.example.com:10002,member3.example.com:10003,member4. example.com:10004,member5.example.com:10005/test?replicaSet=demo
// cat ingest-script

db.test.drop()
for(var i=1;i<1000;i++){
  db.test.insert({item: i});
  inserted = db.test.findOne({item: i}); 
  if(inserted)
    print(" Item "+ i +" was inserted ” + new Date().getTime()/1000 + );
  else
    print("Unexpected "+ inserted)
  sleep(2000);
}

```
---

### 判断当前运行的Mongo服务是否为主节点可以使用命令db.isMaster()

### 配置mongo允许从节点读数据
```javascript
# mongo localhost:28018
> rs.slaveOk()
```

---


# MongoDB升级流程
### MongoDB单机升级流程
![](https://s1.ax1x.com/2020/10/12/0R6oLD.md.png)
### MongoDB 复制集升级流程
![](https://s1.ax1x.com/2020/10/12/0Rcopq.md.png)
### MongoDB 分片集群升级流程
![](https://s1.ax1x.com/2020/10/12/0RgcCR.png)
### 版本升级:在线升级
- MongoDB支持在线升级，即升级过程中不需要间断服务;
- 升级过程中虽然会发生主从节点切换，存在短时间不可用，但是:
  - 3.6版本开始支持自动写重试可以自动恢复主从切换引起的集群暂时不可写;
  - 4.2开始支持的自动读重试则提供了包括主从切换在内的读问题的自动恢复;
- 升级需要逐版本完成，不可以跳版本:
   - 正确:3.2->3.4->3.6->4.0->4.2
   - 错误:3.2->4.2
   - 原因:
   - MongoDB复制集仅仅允许相邻版本共存
   - 有一些升级内部数据格式如密码加密字段，需要在升级过程中由mongo进行转换

