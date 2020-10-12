# MongoDB 的备份
- MongoDB 的备份机制分为: 
  - 延迟节点备份
  - 全量备份 + Oplog 增量
- 最常见的全量备份方式包括:
  - mongodump
  - 复制数据文件
  - 文件系统快照

![延迟节点备份](https://s1.ax1x.com/2020/10/12/02tRte.png)

### 命令行数据库备份与恢复工具mongodump / mongorestore
```shell
mongodump -h dbhost -d dbname -o dbdirectory
# -h：MongDB所在服务器地址，例如：127.0.0.1，当然也可以指定端口号：127.0.0.1:27017
# -d：需要备份的数据库实例，例如：test
# -c: 需要备份的集合
# -o：备份的数据存放位置，例如：c:\data\dump，当然该目录需要提前建立，在备份完成后，系统自动在dump目录下建立一个test目录，这个目录里面存放该数据库实例的备份数

mongorestore -h 127.0.0.1:27017 -d test -c test xxx.bson
# -h <:port>, -h <:port>：MongoDB所在服务器地址，默认为： localhost:27017
# -d ：需要恢复的数据库实例，例如：test，当然这个名称也可以和备份时候的不一样，比如test2
# --drop 恢复的时候，先删除当前数据，然后恢复备份的数据。就是说，恢复后，备份后添加修改的数据都会被删除，慎用哦！
# <path>：mongorestore 最后的一个参数，设置备份数据所在位置，例如：c:\data\dump\test。你不能同时指定 <path> 和 --dir 选项，--dir也可以设置备份目录。
# --dir：指定备份的目录
```

### writeConcern 决定一个写操作落到多少个节点上才算成功。writeConcern 的取值包括: 
- 0:发起写操作，不关心是否成功;
- 1~集群最大数据节点数:写操作需要被复制到指定节点数才算成功;
- majority:写操作需要被复制到大多数节点上才算成功。 
- 发起写操作的程序将阻塞到写操作到达指定的节点数为止
```javascript
db.test.insert( {count: 1}, {writeConcern: {w: “majority/all/1”}})
```

### journal定义如何才算成功
- true:写操作落到journal文件中才算成功;
- false:写操作到达内存即算作成功。
```
db.test.insert( {count: 1}, {writeConcern: {j: true}})
```

### $\color{red}{注意事项}$
- 虽然多于半数的writeConcern都是安全的，但通常只会设置majority，因为这是 等待写入延迟时间最短的选择;
- 不要设置writeConcern等于总节点数，因为一旦有一个节点故障，所有写操作都 将失败;
- writeConcern虽然会增加写操作延迟时间，但并不会显著增加集群压力，因此无论 是否等待，写操作最终都会复制到所有节点上。设置 writeConcern 只是让写操作 等待复制后再返回而已;
- 应对重要数据应用{w:“majority”}，普通数据可以应用{w:1}以确保最佳性能。


### 在读取数据的过程中我们需要关注以下两个问题: 
- 从哪里读? 由readPreference 来解决
- 什么样的数据可以读? 由readConcern来解决

### readPreference决定使用哪一个节点来满足正在发起的读请求。
readPreference 场景举例
- 用户下订单后马上将用户转到订单详情页——primary/primaryPreferred。因为此 时从节点可能还没复制到新订单;
- 用户查询自己下过的订单——secondary/secondaryPreferred。查询历史订单对 时效性通常没有太高要求;
- 生成报表——secondary。报表对时效性要求不高，但资源需求大，可以在从节点 单独处理，避免对线上用户造成影响;
- 将用户上传的图片分发到全世界，让各地用户能够就近读取——nearest。每个地区 的应用选择最近的节点读取数据。
可选值包括:
- primary:只选择主节点;
- primaryPreferred:优先选择主节点，如果不可用则选择从节点;
- secondary:只选择从节点;
- secondaryPreferred:优先选择从节点， 如果从节点不可用则选择主节点;
- nearest:选择最近的节点;
``` javascript
//通过 MongoDB 的连接串参数
mongodb://host1:27107,host2:27107,host3:27017/?replicaSet=rs&readPre ference=secondary
//通过 MongoDB 驱动程序 API
MongoCollection.withReadPreference(ReadPreferencereadPref)
//Mongo Shell
db.collection.find({}).readPref(“secondary”)
```


### readPreference与Tag
readPreference 只能控制使用一类节点。Tag 则可以将节点选择控制 到一个或几个节点。考虑以下场景:
主
- 一个5个节点的复制集;
- 3个节点硬件较好，专用于服务线上客户;
- 2个节点硬件较差，专用于生成报表; 可以使用 Tag 来达到这样的控制目的:
- 为3个较好的节点打上{purpose:"online"};
- 为2个较差的节点打上{purpose:"analyse"};
可以使用 Tag 来达到这样的控制目的:
- 为3个较好的节点打上{purpose:"online"};
- 为2个较差的节点打上{purpose:"analyse"};
- 在线应用读取时指定online，报表读取时指定reporting。

### $\color{red}{readPreference注意事项}$
- 指定readPreference时也应注意高可用问题。例如将readPreference指定primary，则发生 故障转移不存在 primary 期间将没有节点可读。如果业务允许，则应选择 primaryPreferred;
- 使用Tag时也会遇到同样的问题，如果只有一个节点拥有一个特定Tag，则在这个节点失效时 将无节点可读。这在有时候是期望的结果，有时候不是。例如:
- 如果报表使用的节点失效，即使不生成报表，通常也不希望将报表负载转移到其他节点上，此时只有一个 节点有报表 Tag 是合理的选择;
- 如果线上节点失效，通常希望有替代节点，所以应该保持多个节点有同样的Tag;
- Tag有时需要与优先级、选举权综合考虑。例如做报表的节点通常不会希望它成为主节点，则 优先级应为 0。

### readConcern
在readPreference选择了指定的节点后，readConcern决定这个节点上的数据哪些是可读的，类似于关系数据库的隔离级别。可选值包括:
- available:读取所有可用的数据;
- local:读取所有可用且属于当前分片的数据;
- majority:读取在大多数节点上提交完成的数据; 
- linearizable:可线性化读取文档;
- snapshot:读取最近快照中的数据;

### readConcern: local和available
在复制集中local和available是没有区别的。两者的区别主要体现在分片集上。考虑以下场景: 
- 一个chunkx正在从shard1向shard2迁移;
- 整个迁移过程中chunkx中的部分数据会在shard1和shard2中同时存在，但源分片shard1仍然是chunk x的负责方:
    - 所有对chunkx的读写操作仍然进入shard1;
    - config中记录的信息chunkx仍然属于shard1;
    - 此时如果读shard2，则会体现出local和available的区别:
    - local:只取应该由shard2负责的数据(不包括x); 
    - available:shard2上有什么就读什么(包括x)
$\color{red}{注意事项}$
- 虽然看上去总是应该选择local，但毕竟对结果集进行过滤会造成额外消耗。在一些 无关紧要的场景(例如统计)下，也可以考虑 available;
- MongoDB<=3.6不支持对从节点使用{readConcern:"local"};
- 从主节点读取数据时默认readConcern是local，从从节点读取数据时默认 readConcern 是 available(向前兼容原因)。

### readConcern: majority的实现方式
节点上维护多个x版本，通过MVCC机制
MongoDB通过维护多个快照来链接不同的版本:
- 每个被大多数节点确认过的版本都将是一个快照; 
- 快照持续到没有人使用为止才被删除;

### readConcern: majority与脏读
MongoDB 中的回滚:
- 写操作到达大多数节点之前都是不安全的，一旦主节点崩溃，而从节还没复制到该 次操作，刚才的写操作就丢失了;
- 把一次写操作视为一个事务，从事务的角度，可以认为事务被回滚了。
 所以从分布式系统的角度来看，事务的提交被提升到了分布式集群的多个节点级别的
 “提交”，而不再是单个节点上的“提交”。
 在可能发生回滚的前提下考虑脏读问题:
- 如果在一次写操作到达大多数节点前读取了这个写操作，然后因为系统故障该操作 回滚了，则发生了脏读问题;
使用 {readConcern: “majority”} 可以有效避免脏读

### readConcern: 如何实现安全的读写分离
考虑如下场景:
 - 向主节点写入一条数据;
 - 立即从从节点读取这条数据。
 - 如何保证自己能够读到刚刚写入的数据?
```javascript
//下述方式有可能读不到刚写入的订单
db.orders.insert({ oid: 101, sku: ”kite", q: 1}) 
db.orders.find({oid:101}).readPref("secondary")
//使用 writeConcern + readConcern majority 来解决
db.orders.insert({ oid: 101, sku: "kiteboar", q: 1}, {writeConcern:{w: "majority”}}) 
db.orders.find({oid:101}).readPref(“secondary”).readConcern("majority")
```

### readConcern 主要关注读的隔离性,readCocnern: majority对应于事务中隔离级别中的 Read Committed

### MongoDB ACID 多文档事务支持
| 事务属性           | 支持程度                                                              |
| ------------------ | --------------------------------------------------------------------- |
| Atomocity 原子性   | 单表单文档 : 1.x 就支持 复制集多表多行:4.0 复制集 分片集群多表多行4.2 |
| Consistency 一致性 | writeConcern, readConcern (3.2)                                       |
| Isolation 隔离性   | readConcern (3.2)                                                     |
| Durability 持久性  | Journal and Replication                                               |

--- 

### 事务写机制
MongoDB 的事务错误处理机制不同于关系数据库:
- 当一个事务开始后，如果事务要修改的文档在事务外部被修改过，则事务修改这个 文档时会触发 Abort 错误，因为此时的修改冲突了;
- 这种情况下，只需要简单地重做事务就可以了;
- 如果一个事务已经开始修改一个文档，在事务以外尝试修改同一个文档，则事务以 外的修改会等待事务完成才能继续进行(write-wait.md实验)。

### $\color{red}{事务注意事项}$
- 可以实现和关系型数据库类似的事务场景
- 必须使用与MongoDB4.2兼容的驱动;
- 事务默认必须在60秒(可调)内完成，否则将被取消;
- 涉及事务的分片不能使用仲裁节点;
- 事务会影响chunk迁移效率。正在迁移的chunk也可能造成事务提交失败(重试 即可);
- 多文档事务中的读操作必须使用主节点读;
- readConcern只应该在事务级别设置，不能设置在每次读写操作上。

### Change Stream
Change Stream是MongoDB用于实现变更追踪的解决方案，类似于关系数据库的触发器，但原理不完全相同:
| -        | Change Stream        | 触发器         |
| -------- | -------------------- | -------------- |
| 触发方式 | 异步                 | 同步(事务保证) |
| 触发位置 | 应用回调事件         | 数据库触发器   |
| 触发次数 | 每个订阅事件的客户端 | 1次(触发器)    |
| 故障恢复 | 从上次断点重新触发   | 事务回滚       |
Change Stream的实现原理
Change Stream是基于oplog实现的。它在oplog上开启一个tailable cursor来追踪所有复制集上的变更操作，最终调用应用中定义的回调函数。被追踪的变更事件主要包括:
- insert/update/delete:插入、更新、删除
- drop:集合被删除
- rename:集合被重命名
- dropDatabase:数据库被删除
- invalidate:drop/rename/dropDatabase将导致invalidate被触发， 并关闭change stream

### Change Stream与可重复读
Change Stream只推送已经在大多数节点上提交的变更操作。即“可重复读”的变更。 
这个验证是通过 {readConcern: “majority”} 实现的。
- 未开启majorityreadConcern的集群无法使用ChangeStream;
- 当集群无法满足{w:“majority”}时，不会触发ChangeStream(例如PSA架构 中的 S 因故障宕机)。

### Change Stream变更过滤
 如果只对某些类型的变更事件感兴趣，可以使用使用聚合管道的过滤步骤过滤事件。
 例如:
 ```javascript
var cs = db.collection.watch([{
    $match: {
        operationType: {
            $in: ['insert', 'delete']
}}
}])
```

### $\color{red}{Change Stream注意事项}$
- ChangeStream依赖于oplog，因此中断时间不可超过oplog回收的最大时间窗; 
- 在执行update操作时，如果只更新了部分数据，那么ChangeStream通知的也是增量部分;
- 同理，删除数据时通知的仅是删除数据的_id。

### mongo连接url
```yaml
// 连接到复制集 
mongodb://节点1,节点2,节点3.../database?[options]
// 连接到分片集 
mongodb://mongos1,mongos2,mongos3.../database?[options]
```

### 常见连接字符串参数
- maxPoolSize 连接池大小
- MaxWaitTime 建议设置，自动杀掉太慢的查询
- WriteConcern 建议majority保证数据安全
- ReadConcern 对于数据一致性要求高的场景适当使用

### 连接字符串节点和地址
- 无论对于复制集或分片集，连接字符串中都应尽可能多地提供节点地址，建议全部 列出;
    - 复制集利用这些地址可以更有效地发现集群成员;
    - 分片集利用这些地址可以更有效地分散负载;
- 连接字符串中尽可能使用与复制集内部配置相同的域名或IP;

### 使用域名连接集群
在配置集群时使用域名可以为集群变更时提供一层额外的保护。例如需要将集群整体 迁移到新网段，直接修改域名解析即可。
另外，MongoDB提供的 mongodb+srv://协议可以提供额外一层的保护。该协议允许通过域名解析得到所有mongos或节点的地址，而不是写在连接字符串中。
```yaml
mongodb+srv://server.example.com/
```

### $\color{reed}{不要在mongos或复制集上层放置负载均衡器，让驱动处理负载均衡和自动故障恢复}$
基于url配置多节点，驱动已经知晓在不同的mongos之间实现负载均衡，而复制集则需要根据节点的角色来选择发送请求的目标。如果在mongos或复制集上层部署负载均衡：
- 驱动会无法探测具体哪个节点存活，从而无法完成自动故障恢复; 
- 驱动会无法判断游标是在哪个节点创建的，从而遍历游标时出错;

### 游标使用
如果一个游标已经遍历完，则会自动关闭;如果没有遍历完，则需要手动调用close()方法，否则该游标将在服务器上存在10分钟(默认值)后超时释放，造成不必要的资源浪费。 但是如果不能遍历完一个游标，通常意味着查询条件太宽泛，更应该考虑的问题是如何将条件收紧。

