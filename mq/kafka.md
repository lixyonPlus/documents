# Kafka

## kafka命令

##### kafka-topic.sh

```shell
./kafka-topic.sh --zookeeper localhost:2181 --create --replication-factor 1 --partitions 1 --topic test
### 如果topic不存在时新建topic
./kafka-topic.sh --zookeeper localhost:2181 --create --if-not-exists --replication-factor 1 --partitions 1 --topic test
### 新增topic分区数量
./kafka-topic.sh --zookeeper localhost:2181 --alter --partitions 1 --topic test
### 删除topic分区数量
./kafka-topic.sh --zookeeper localhost:2181 --delete --topic test
### 查看所有topic
./kafka-topic.sh --zookeeper localhost:2181 --list
### 查看topic
./kafka-topic.sh --zookeeper localhost:2181 --describe --if-exists --topic test
### 查询包含不同步副本的分区
./kafka-topic.sh --zookeeper localhost:2181 --describe --under-replicated-partitions
### 查询没有leader副本的分区
./kafka-topic.sh --zookeeper localhost:2181 --describe --unavailable-partitions
```

##### Kafka-consumer-group.sh

```shell
### 查询所有消费者组
./kafka-consumer-group.sh --zookeeper localhost:2181 --list
### 查询消费组信息
./kafka-consumer-group.sh --zookeeper localhost:2181 --describe --group group.test
### 删除消费者组
./kafka-consumer-groups.sh --bootstrap-server localhost:9092 --delete --group group.test
### 把消费者组offset调整到分区当前最新offset
./kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group group.demo --reset-offsets --all-topics --to-latest --execute
### 把消费者组offset调整到分区当前最小offset
./kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group group.demo --reset-offsets --all-topics --to-earliest --execute
### 把消费者组offset调整到分区指定的offset（不能小于当前最小offset或大于当前最大offset）
./kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group group.demo --reset-offsets --all-topics --to-offset 191 --execute
```

##### kafka-configs.sh

```shell
### 修改topic默认配置，消息保留时间为1小时
./kafka-configs.sh --bootstrap-server localhost:9092 --alter --entity-type topics --entity-name first --add-config retention.ms=3600000
### 查询被覆盖的配置
./kafka-configs.sh --bootstrap-server localhost:9092 --describe --entity-type topics --entity-name first
### 移除被覆盖的配置
./kafka-configs.sh --bootstrap-server localhost:9092 --alter --entity-type topics --entity-name first --delete-config retention.ms
```

##### Kafka-preferred-replica-election.sh

```shell
### 启动首选副本选举
./kafka-preferred-replica-election.sh --bootstrap-server localhost:9092 
```

##### kafka-replica-verification.sh

```shell
### 副本验证
./kafka-replica-verification.sh --broker-list localhost:9092 --topic-white-list 'first'
```



##### 往topic发送消息

```shell
./kafka-console-producer.sh --broker-list localhost:9092 --topic test1
./kafka-console-producer.sh --bootstrap-server localhost:9092 --topic test1
```

##### 消费topic消息

```shell
### 从头开始消费
./kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test --from-beginning
### 实时消费
./kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test1
```

##### Kafka-verifiable-producer.sh

```shell

### 生产测试数据发送到指定topic,并将数据已json格式打印到控制台

### --max-messages: 最大消息数量，默认-1，一直生产消息
### --throughput: 设置吞吐量，默认-1
### --acks: 指定分区中必须有多少个副本收到这条消息，才算消息发送成功，默认-1
### --message-create-time: 设置消息创建的时间，时间戳
### --value-prefix: 设置消息前缀
### --repeating-keys: key从0开始，每次递增1，直到指定的值，然后再从0开始
./kafka-verifiable-producer.sh --bootstrap-server localhost:9092 --topic first --message-create-time 1527351382000 --value-prefix 1 --repeating-keys 10 --max-message 20

```

##### kafka-verifiable-consumer.sh

```shell
### 消费指定topic消息
### --topic: 要消费的topic
### --group-id: 消费组id
### --max-messages: 最大消费消息数量，默认-1，一直消费
### --session-timeout: 消费者会话超时时间，默认30000ms，服务端如果在该时间内没有接收到消费者的心跳，就会将该消费者从消费组中删除
### --enable-autocommit: 自动提交，默认false
### --reset-policy: 设置消费偏移量，earliest从头开始消费，latest从最近的开始消费，none抛出异常，默认earliest
### --assignment-strategy: 消费者的分区配置策略, 默认 RangeAssignor
./kafka-verifiable-consumer.sh --broker-list localhost:9092 --topic first --group-id group.demo --max-messages 2 --enable-autocommit --reset-policy earliest
```

##### kafka-log-dirs.sh

```shell
### 查看指定broker上日志目录使用情况
./kafka-log-dirs.sh --bootstrap-sever localhost:9092 --describe --topic-list test,first
```


### 分区
  
### kafka生产者发送消息分区策略
- 使用默认分区，如果message存在的key的话，则取key的hash值（使用的是murmur2这种高效率低碰撞的Hash算法），然后与partition总数取模，得到目标partition编号，这样可以保证同一key的message进入同一partition。
- 使用默认分区，如果message没有key，则通过StickyPartitionCache.partition() 方法计算目标partition。 
 - StickyPartitionCache主要实现的是”黏性选择”，就是尽可能的先往一个partition发送message，让发往这个partition的缓冲区快速填满，这样的话，就可以降低message的发送延迟。我们不用担心出现partition数据量不均衡的情况，因为只要业务运行时间足够长，message还是会均匀的发送到每个 partition上的。 StickyPartitionCache会先从indexCache字段中获取黏住的partition，如果没有，则调用nextPartition() 方法向indexCache中写入一个(会先获取目标topic中可用的partition，并从中随机选择一个写入indexCache)
- 可以实现Partitioner接口，自定义分区策略。


##### 消费者分配分区过程
`当消费者要加入群组时，会向群组协调器发送一个joinGroup请求，第一个加入群组的消费者为群主，群主从协调器那里获得群组的成员列表（列表包含最近发送过心跳的消费者，它们被认为是活跃的），并负责给每一个消费者分配分区。他使用了一个实现了PartitionAssignor接口的类来决定分区应该分配给哪些消费者。kafka内置了两种分配策略，分配完毕之后，群主把分配情况列表发送给群主协调器，协调器再把这些信息发送给所有消费者。每个消费者只能看到自己的分配信息，只有群主知道所有消费者的分配信息，这个过程会在每次rebalance时重复发生。`

##### Kafka消费者分区分配策略
- Range(默认): 该策略会把主题的若干个连续的分区分配给消费者。假设消费者C1和消费者C2同时订阅了主题T1和主题T2，井且每个主题有3个分区。那么消费者C1有可能分配到两个主题的分区0和分区1，而消费者C2分配到这两个主题的分区2。因为每个主题拥有奇数个分区，而分配是在主题内独立完成的，第一个消费者最后分配到比第二个消费者更多的分区。只要使用了Range策略，而且分区数量无怯被消费者数量整除，就会出现这种情况。默认使用的是org.apache.kafka.clients.consumer.RangeAssignor
- RoundRobin: 该策略把主题的所有分区逐个分配给消费者。如果使用RoundRobin策略来给消费者C1和消费者C2分配分区，那么消费者C1将分到主题T1的分区0和分区2以及主题T2的分区1，消费者C2将分配到主题T1的分区1以及主题T2的分区0和分区2。一般来说，如果所有消费者都订阅相同的主题(这种情况很常见), RoundRobin策略会给所有消费者分配相同数量的分区(或最多就差一个分区)。

#### zookeeper

Kafka使用Zookeeper的临时节点来选举控制器，并在节点加入集群或退出集群时通知控制器。控制器负责在节点加入或离开集群时进行分区首领选举。控制器使用epoch来避免“脑裂” 。“脑裂”是指两个节点同时认为自己是当前的控制器。

##### 高水位

- 定义消息可见性，用来标识分区下的哪些消息是可以被消费者消费的
- 帮助kafka完成副本同步
- ![image.png](https://segmentfault.com/img/bVbHUZ7)
- 在分区高水位以下的消息就被认为是已提交消息，反之就是未提交消息
- 消费者只能消费已提交消息，即位移值小于8的消息。
- 这里不存在kafka的事务，因为事务机制会影响消息者所能看到的消息的范围，他不只是简单依赖高水位来判断，是依赖于一个名为LSO的位移值来判断事务性消费者的可见性
- 位移值等于高水位的消息也属于为未提交消息。即高水位的消息也是不能被消费者消费的
- LEO表示副本写入下一条消息的位移值。同一个副本对象，起高水位值不会超过LEO

##### Leader Epoch

- Epoch。一个单调递增的版本号。每当副本领导权发生变更时，都会增加该版本号。小版本号的Leader被认为是过期的Leader，不能再行使Leader的权力。
- 起始位移（Start Offset）。Leader副本在该Epoch上写入的首条消息的位移。
- Leader Epoch<0,0>和<1,100>。第一个Epoch指的是0版本，位移0开始保存消息，一共保存100条消息。之后Leader发生了变更，版本号增加到1，新版本起始位移为100.
- Kafka Broker会在内存中为每个分区都缓存Leader Epoch数据，同时它还会定期的将这信息持久化一个checkpoint文件中。当Leader副本写入消息到磁盘时，Broker会尝试更新这部分缓存，如果该Leader是首次写入消息，那么Broker会向缓存中增加一个Leader Epoch条目，否则就不做更新。

##### Leader Epoch是怎样防止数据丢失的呢？

![image.png](https://segmentfault.com/img/bVbHU0D)

单纯依赖高水位是怎么造成数据丢失的。开始时，副本A和副本B都处于正常状态，A是Leader副本，B是Follower副本。当生产者使用ack=1（默认）往Leader副本A中发送两条消息。且A全部写入成功，此时Kafka会通知生产者说这两条消息写入成功。现在假设A,B都写入了这两条消息，而且Leader副本的高水位也已经更新了，但Follower副本高水位还未更新。因为Follower端高水位的更新与Leader端有时间错配。假如现在副本B所在Broker宕机了，那么当它重启回来后，副本B就会执行日志截断操作，将LEO值调整为之前的高水位值，也就是1.所以副本B当中位移值为1的消息就丢失了。副本B中只保留了位移值0的消息。当执行完截断操作之后，副本B开始从A中拉取消息，执行正常的消息同步。假如此时副本A所在的Broker也宕机了。那么kafka只能让副本B成为新的Leader，然后副本A重启回来之后，也需要执行日志截断操作，即调整高水位为与B相同的值，也就是1。这样操作之后，位移值为1的那条消息就永远丢失了。

##### Leader Epoch机制如何规避这种数据丢失现象呢？

![image.png](https://segmentfault.com/img/bVbHU0E)

引用了Leader Epoch机制之后，Follower副本B重启回来后，需要向A发送一个特殊的请求去获取Leader的LEO值，该例子中为2。当知道Leader LEO为2时，B发现该LEO值不必自己的LEO值小，而且缓存中也没有保存任何起始位移值>2的Epoch条目，因此B无需执行日志截断操作。这是对高水位机制的一次明显改进，即不是依赖于高水位判断是否进行日志截断操作。现在副本A宕机了，B成立新Leader。同样的，在A重启回来后，执行与B逻辑相同的判断，也不需要执行日志截断操作，所以位移值为1的那条消息就全部得以保存。后面当生产者程序向 B 写入新消息时，副本 B 所在的 Broker 缓存中，会生成新的 Leader Epoch 条目：[Epoch=1, Offset=2]。之后，副本 B 会使用这个条目帮助判断后续是否执行日志截断操作。这样，kafka就规避掉了数据丢失的场景。

#### 配置信息

- session.timeout.ms 该属性指定了消费者在被认为死亡之前可以与服务器断开连接的时间，默认是3s。如 果消费者没有在session.timeout.ms指定的时间内发送心跳给群组协调器，就被认为已经死亡，协调器就会触发再均衡，把它的分区分配给群组里的其他消费者。该属性与 heartbeat.interval.ms紧密相关。heartbeat.interval.ms指定了poll()方法向协调器发送心跳的频率，session.timeout.ms则指定了消费者可以多久不发送心跳。所以， 一般需要同时修改这两个属性， heartbeat.interval.ms 必须比 session.timeout.ms 小， 一般是session.timeout.ms的三分之一。如果session.timeout.ms是 3s，那么heartbeat.interval.ms应该是ls。 把session.timeout.ms值设得比默认值小，可以更快地检测和恢复崩愤的节点，不过长时间的轮询或垃圾收集可能导致非预期的再均衡。把该属性的值设置得大一些，可以减少意外的再均衡 ，不过检测节点崩愤需要更长的时间。
- auto.offset.reset 该属性指定了消费者在读取一个没有偏移量的分区或者偏移量无效的情况下(因消费者长时间失效，包含偏移量的记录已经过时井被删除)该作何处理。它的默认值是latest， 意思是说，在偏移量无效的情况下，消费者将从最新的记录开始读取数据(在消费者启动之后生成的记录)。另一个值是 earliest，意思是说，在偏移量无效的情况下，消费者将从起始位置读取分区的记录。

#### 生产者发送确认

- acks=0 意味着如果生产者能够通过网络把消息发送出去，那么就认为消息已成功写入Kafka。在这种情况下还是有可能发生错误，比如发送的对象无能被序列化或者网卡发生故障，但如果是分区离线或整个集群长时间不可用，那就不会收到任何错误。即使是在发生完全首领选举的情况下，这种模式仍然会丢失消息，因为在新首领选举过程中它并不知道首领已经不可用了。在acks=0模式下的运行速度是非常快的(这就是为什么很多基准测试都是基于这个模式)，你可以得到惊人的吞吐量和带宽利用率 ，不过如果选择了这种模式， 一定会丢失一些消息。
- acks=1 意味着首领在收到消息并把它写入到分区数据文件(不一定同步到磁盘上)时会返回确认或错误响应。在这个模式下，如果发生正常的首领选举，生产者会在选举时收到一个LeaderNotAvailableException异常，如果生产者能恰当地处理这个错误,它会重试发送悄息，最终消息会安全到达新的首领那里。不过在这个模式下仍然有可能丢失数据，比如消息已经成功写入首领，但在消息被复制到跟随者副本之前首领发生崩愤。
- acks=all 意味着首领在返回确认或错误响应之前，会等待所有同步副本都收到悄 息。如 果和 l'li.『1.i.nsync.「epli.cas 参数结合起来，就可以决定在返回确认前至少有多少个副本 能够收到悄息 。 这是最保险的做也一一生产者会一直重试直到消息被成功提交。不过这 也是最慢的做毡，生产者在继续发送其他消息之前需要等待所有副本都收到 当前的消息。 可以通过使用异步模式和更大的批次来加快速度，但这样做通常会降低吞吐量。