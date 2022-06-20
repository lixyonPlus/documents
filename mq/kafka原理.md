### 概念
- Broker （节点）：Kafka服务节点，简单来说一个 Broker 就是一台Kafka服务器，一个物理节点。
- Topic （主题）：在Kafka中消息以主题为单位进行归类，每个主题都有一个 Topic Name ，生产者根据Topic Name将消息发送到特定的Topic，消费者则同样根据Topic Name从对应的Topic进行消费。
- Partition （分区）：Topic （主题）是消息归类的一个单位，但每一个主题还能再细分为一个或多个 Partition （分区），一个分区只能属于一个主题。主题和分区都是逻辑上的概念，举个例子，消息1和消息2都发送到主题1，它们可能进入同一个分区也可能进入不同的分区（所以同一个主题下的不同分区包含的消息是不同的），之后便会发送到分区对应的Broker节点上。
- Offset （偏移量）：分区可以看作是一个只进不出的队列（Kafka只保证一个分区内的消息是有序的），消息会往这个队列的尾部追加，每个消息进入分区后都会有一个偏移量，标识该消息在该分区中的位置，消费者要消费该消息就是通过偏移量来识别。


### kafka分区多副本冗余机制
- 副本是以 Topic 中每个 Partition的数据为单位，每个Partition的数据会同步到其他物理节点上，形成多个副本。
每个 Partition 的副本都包括一个 Leader 副本和多个 Follower副本，Leader由所有的副本共同选举得出，其他副本则都为Follower副本。在生产者写或者消费者读的时候，都只会与Leader打交道，在写入数据后Follower就会来拉取数据进行数据同步。当某个 Broker 挂掉了，甭担心，这个 Broker 上的 Partition 在其他 Broker 节点上还有副本。你说如果挂掉的是 Leader 怎么办？那就在 Follower中在选举出一个 Leader 即可，生产者和消费者又可以和新的 Leader 愉快地玩耍了，这就是高可用。
![](https://mmbiz.qpic.cn/mmbiz_png/JdLkEI9sZfcHSNliaR9fn3bbAwg31zdQJiaiaQTFAasYW2YGGrdTyxVSySMB8oWdIEADfpzsjCp2ATb8vaag881vQ/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)


### 多少个副本才算够用？
- 副本肯定越多越能保证Kafka的高可用，但越多的副本意味着网络、磁盘资源的消耗更多，性能会有所下降，通常来说副本数为3即可保证高可用，极端情况下将 replication-factor 参数调大即可。

### Follower和Lead之间没有完全同步怎么办？
- Follower和Leader之间并不是完全同步，但也不是完全异步，而是采用一种 ISR机制（ In-Sync Replica）。每个Leader会动态维护一个ISR列表，该列表里存储的是和Leader基本同步的Follower。如果有Follower由于网络、GC等原因而没有向Leader发起拉取数据请求，此时Follower相对于Leader是不同步的，则会被踢出ISR列表。所以说，ISR列表中的Follower都是跟得上Leader的副本。

### 一个节点宕机后Leader的选举规则是什么？
- Kafka的Leader选举思路很简单，基于ISR列表，当宕机后会从所有副本中顺序查找，如果查找到的副本在ISR列表中，则当选为Leader。另外还要保证前任Leader已经是退位状态了，否则会出现脑裂情况（有两个Leader）。怎么保证？Kafka通过设置了一个controller来保证只有一个Leader。


### __consumer_offset
- __consumer_offset 是一个Kafka自动创建的 Topic，用来存储消费者消费的 offset （偏移量）信息，默认 Partition数为50。而就是这个Topic，它的默认副本数为1。如果所有的 Partition 都存在于同一台机器上，那就是很明显的单点故障了！当将存储 __consumer_offset 的Partition的Broker给Kill后，会发现所有的消费者都停止消费了。这个问题怎么解决？
 - 第一点 ，需要将 __consumer_offset 删除，注意这个Topic时Kafka内置的Topic，无法用命令删除，我是通过将 logs 删了来实现删除。
 - 第二点 ，需要通过设置 offsets.topic.replication.factor 为3来将 __consumer_offset 的副本数改为3。通过将 __consumer_offset 也做副本冗余后来解决某个节点宕机后消费者的消费问题。


---

### 分区
  
### kafka生产者发送消息到broker分区策略
- 使用默认分区，如果message存在的key的话，则取key的hash值（使用的是murmur2这种高效率低碰撞的Hash算法），然后与partition总数取模，得到目标partition编号，这样可以保证同一key的message进入同一partition。
- 使用默认分区，如果message没有key，则通过StickyPartitionCache.partition() 方法计算目标partition。 
 - StickyPartitionCache主要实现的是”黏性选择”，就是尽可能的先往一个partition发送message，让发往这个partition的缓冲区快速填满，这样的话，就可以降低message的发送延迟。我们不用担心出现partition数据量不均衡的情况，因为只要业务运行时间足够长，message还是会均匀的发送到每个 partition上的。 StickyPartitionCache会先从indexCache字段中获取黏住的partition，如果没有，则调用nextPartition() 方法向indexCache中写入一个(会先获取目标topic中可用的partition，并从中随机选择一个写入indexCache)
- 可以实现Partitioner接口，自定义分区策略。


##### kafka给消费者分配分区过程
`当消费者要加入群组时，会向群组协调器发送一个joinGroup请求，第一个加入群组的消费者为群主，群主从协调器那里获得群组的成员列表（列表包含最近发送过心跳的消费者，它们被认为是活跃的），并负责给每一个消费者分配分区。他使用了一个实现了PartitionAssignor接口的类来决定分区应该分配给哪些消费者。kafka内置了两种分配策略，分配完毕之后，群主把分配情况列表发送给群主协调器，协调器再把这些信息发送给所有消费者。每个消费者只能看到自己的分配信息，只有群主知道所有消费者的分配信息，这个过程会在每次rebalance时重复发生。`


##### Kafka消费者分区分配策略
- Range(默认): 该策略会把主题的若干个连续的分区分配给消费者。假设消费者C1和消费者C2同时订阅了主题T1和主题T2，井且每个主题有3个分区。那么消费者C1有可能分配到两个主题的分区0和分区1，而消费者C2分配到这两个主题的分区2。因为每个主题拥有奇数个分区，而分配是在主题内独立完成的，第一个消费者最后分配到比第二个消费者更多的分区。只要使用了Range策略，而且分区数量无怯被消费者数量整除，就会出现这种情况。默认使用的是org.apache.kafka.clients.consumer.RangeAssignor
- RoundRobin: 该策略把主题的所有分区逐个分配给消费者。如果使用RoundRobin策略来给消费者C1和消费者C2分配分区，那么消费者C1将分到主题T1的分区0和分区2以及主题T2的分区1，消费者C2将分配到主题T1的分区1以及主题T2的分区0和分区2。一般来说，如果所有消费者都订阅相同的主题(这种情况很常见), RoundRobin策略会给所有消费者分配相同数量的分区(或最多就差一个分区)。

#### kafka使用zookeeper实现一致性选举

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