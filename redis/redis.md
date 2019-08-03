redis分布式锁： 
    普通锁：
      ``` 
        - 获取锁（unique_value可以是UUID等）
        SET resource_name unique_value NX PX 30000
        - 释放锁（lua脚本中，一定要比较value，防止误解锁）
        if redis.call("get",KEYS[1]) == ARGV[1] then
            return redis.call("del",KEYS[1])
        else
            return 0
        end
      ```
      这种实现方式有3大要点（也是面试概率非常高的地方）：
        set命令要用set key value px milliseconds nx；
        value要具有唯一性；
        释放锁时要验证value值，不能误解锁；
      事实上这类琐最大的缺点就是它加锁时只作用在一个Redis节点上，即使Redis通过sentinel保证高可用，如果这个master节点由于某些原因发生了主从切换，那么就会出现锁丢失的情况：
        在Redis的master节点上拿到了锁；
        但是这个加锁的key还没有同步到slave节点；
        master故障，发生故障转移，slave节点升级为master节点；导致锁丢失。

  redLock:
      在Redis的分布式环境中，我们假设有N个Redis master。这些节点完全互相独立，不存在主从复制或者其他集群协调机制。我们确保将在N个实例上使用与在Redis单实例下相同方法获取和释放锁。现在我们假设有5个Redis master节点，同时我们需要在5台服务器上面运行这些Redis实例，这样保证他们不会同时都宕掉。
      为了取到锁，客户端应该执行以下操作:
      获取当前Unix时间，以毫秒为单位。
      依次尝试从5个实例，使用相同的key和具有唯一性的value（例如UUID）获取锁。当向Redis请求获取锁时，客户端应该设置一个网络连接和响应超时时间，这个超时时间应该小于锁的失效时间。例如你的锁自动失效时间为10秒，则超时时间应该在5-50毫秒之间。这样可以避免服务器端Redis已经挂掉的情况下，客户端还在死死地等待响应结果。如果服务器端没有在规定时间内响应，客户端应该尽快尝试去另外一个Redis实例请求获取锁。
      客户端使用当前时间减去开始获取锁时间（步骤1记录的时间）就得到获取锁使用的时间。当且仅当从大多数（N/2+1，这里是3个节点）的Redis节点都取到锁，并且使用的时间小于锁失效时间时，锁才算获取成功。
      如果取到了锁，key的真正有效时间等于有效时间减去获取锁所使用的时间（步骤3计算的结果）。
      如果因为某些原因，获取锁失败（没有在至少N/2+1个Redis实例取到锁或者取锁时间已经超过了有效时间），客户端应该在所有的Redis实例上进行解锁（即便某些Redis实例根本就没有加锁成功，防止某些节点获取到锁但是客户端没有得到响应而导致接下来的一段时间不能被重新获取锁）。


    加锁的流程：（lua：一堆命令保证原子性）
      判断lock键是否存在，不存在直接调用hset存储当前线程信息并且设置过期时间,返回nil，告诉客户端直接获取到锁。
      判断lock键是否存在，存在则将重入次数加1，并重新设置过期时间，返回nil，告诉客户端直接获取到锁。
      被其它线程已经锁定，返回锁有效期的剩余时间，告诉客户端需要等待。
    解锁的流程：
      解锁的流程看起来复杂些：
      如果lock键不存在，发消息说锁已经可用
      如果锁不是被当前线程锁定，则返回nil
      由于支持可重入，在解锁时将重入次数需要减1
      如果计算后的重入次数>0，则重新设置过期时间
      如果计算后的重入次数<=0，则发消息说锁已经可用
    
zookeeper：
  实现方式:
    每个客户端对某个方法加锁时,在zookeeper上的与该方法对应的指定节点的目录下,生成-个
    唯一的临时有序节点。判断是否获取锁的方式很简单,只需要判断有序节点中序号最小的一个。
    当释放锁的时候,只需将这个临时节点删除即可。同时,其可以避免服务宕机导致的锁无法释放，而产生的死锁问题。
  功能：
    统一命名服务、状态同步服务、集群管理、分布式应用配置项的管理等。
  有四种类型的znode：
    1.PERSISTENT-持久化目录节点
      客户端与zookeeper断开连接后，该节点依旧存在
    2.PERSISTENT_SEQUENTIAL-持久化顺序编号目录节点
      客户端与zookeeper断开连接后，该节点依旧存在，只是Zookeeper给该节点名称进行顺序编号
    3.EPHEMERAL-临时目录节点
      客户端与zookeeper断开连接后，该节点被删除
    4.EPHEMERAL_SEQUENTIAL-临时顺序编号目录节点
     客户端与zookeeper断开连接后，该节点被删除，只是Zookeeper给该节点名称进行顺序编号

  Zookeeper角色：
    Zookeeper集群是一个基于主从复制的高可用集群，每个服务器承担如下三种角色中的一种 
    Leader： 
      1. 一个Zookeeper集群同一时间只会有一个实际工作的Leader，它会发起并维护与各Follwer及Observer间的心跳。 
      2. 所有的写操作必须要通过Leader完成再由Leader将写操作广播给其它服务器。只要有超过半数节点（不包括observeer节点）写入成功，该写请求就会被提交（类 2PC 协议）。 
    Follower：  
      1. 一个Zookeeper集群可能同时存在多个Follower，它会响应Leader的心跳， 
      2. Follower可直接处理并返回客户端的读请求，同时会将写请求转发给Leader处理， 
      3. 并且负责在Leader处理写请求时对请求进行投票。 
    Observer：  角色与Follower类似，但是无投票权。Zookeeper需保证高可用和强一致性，为了支持更多的客户端，需要增加更多Server；Server增多，投票阶段延迟增大，影响性能；引入Observer，Observer不参与投票； Observers接受客户端的连接，并将写请求转发给leader节点； 加入更多Observer节点，提高伸缩性，同时不影响吞吐率。
  ZAB:
    1. Leader election（选举阶段）：节点在一开始都处于选举阶段，只要有一个节点得到超半数节点的票数，它就可以当选准 leader。只有到达 广播阶段（broadcast） 准 leader 才会成为真正的 leader。这一阶段的目的是就是为了选出一个准 leader，然后进入下一个阶段。
    2.  Discovery（发现阶段）：在这个阶段，followers 跟准 leader 进行通信，同步 followers 最近接收的事务提议。这个一阶段的主要目的是发现当前大多数节点接收的最新提议，并且准 leader 生成新的 epoch，让 followers 接受，更新它们的 accepted Epoch 一个 follower 只会连接一个 leader，如果有一个节点 f 认为另一个 follower p 是 leader，f 在尝试连接 p 时会被拒绝，f 被拒绝之后，就会进入重新选举阶段。
    3.  Synchronization（同步阶段）：同步阶段主要是利用 leader 前一阶段获得的最新提议历史，同步集群中所有的副本。只有当 大多数节点都同步完成，准 leader 才会成为真正的 leader。follower 只会接收 zxid 比自己的 lastZxid 大的提议。 Broadcast（广播阶段-leader消息广播） 
    4.  Broadcast（广播阶段）：到了这个阶段，Zookeeper 集群才能正式对外提供事务服务，并且 leader 可以进行消息广播。同时如果有新的节点加入，还需要对新节点进行同步。 ZAB 提交事务并不像 2PC 一样需要全部 follower 都 ACK，只需要得到超过半数的节点的 ACK 就可以了。 
    
  Zookeeper工作原理
　　1. Zookeeper的核心是原子广播，这个机制保证了各个server之间的同步。实现这个机制的协议叫做Zab协议。Zab协议有两种模式，它们分别是恢复模式和广播模式。
　　　当服务启动或者在领导者崩溃后，Zab就进入了恢复模式，当领导者被选举出来，且大多数server的完成了和leader的状态同步以后，恢复模式就结束了。
　　　状态同步保证了leader和server具有相同的系统状态
　　2. 一旦leader已经和多数的follower进行了状态同步后，他就可以开始广播消息了，即进入广播状态。这时候当一个server加入zookeeper服务中，它会在恢复模式下启动，
　　　发现leader，并和leader进行状态同步。待到同步结束，它也参与消息广播。Zookeeper服务一直维持在Broadcast状态，直到leader崩溃了或者leader失去了大部分
　　　的followers支持。
　　3. 广播模式需要保证proposal被按顺序处理，因此zk采用了递增的事务id号(zxid)来保证。所有的提议(proposal)都在被提出的时候加上了zxid。
　　　实现中zxid是一个64为的数字，它高32位是epoch用来标识leader关系是否改变，每次一个leader被选出来，它都会有一个新的epoch。低32位是个递增计数。
　　4. 当leader崩溃或者leader失去大多数的follower，这时候zk进入恢复模式，恢复模式需要重新选举出一个新的leader，让所有的server都恢复到一个正确的状态。　
　　5. 每个Server启动以后都询问其它的Server它要投票给谁。
　　6.对于其他server的询问，server每次根据自己的状态都回复自己推荐的leader的id和上一次处理事务的zxid（系统启动时每个server都会推荐自己）
　　7. 收到所有Server回复以后，就计算出zxid最大的哪个Server，并将这个Server相关信息设置成下一次要投票的Server。
　　8. 计算这过程中获得票数最多的的sever为获胜者，如果获胜者的票数超过半数，则改server被选为leader。否则，继续这个过程，直到leader被选举出来　　
　　9. leader就会开始等待server连接
　　10. Follower连接leader，将最大的zxid发送给leader
　　11. Leader根据follower的zxid确定同步点
　　12 完成同步后通知follower 已经成为uptodate状态
　　13. Follower收到uptodate消息后，又可以重新接受client的请求进行服务了





高可用方案：
  1.主从复制：（缺点：master宕机无法只能主动切换salve）
    Redis的主从复制功能分为两种数据同步模式：全量数据同步和增量数据同步。
    当Slave节点给定的run_id和Master的run_id不一致时，或者Slave给定的上一次增量同步的offset的位置在Master的环形内存中无法定位时（后文会提到），Master就会对Slave发起全量同步操作。
    这时无论您是否在Master打开了RDB快照功能，它和Slave节点的每一次全量同步操作过程都会更新/创建Master上的RDB文件。在Slave连接到Master，并完成第一次全量数据同步后，接下来Master到Slave的数据同步过程一般就是增量同步形式了（也称为部分同步）。增量同步过程不再主要依赖RDB文件，Master会将新产生的数据变化操作存放在一个内存区域，这个内存区域采用环形构造。

    全量同步：
      master启动运行
      slave启动，连接master，发送第一个ping命令，master回应pong，slave收到master回应pong，发送第一次全量同步命令，master接收到同步命令，执行bgsave命令，异步发送完整的rdb文件给slave，salve接收到rdb文件，加载到内存，通知master收到完成通知。
    增量同步：
      salve启动，连接master，发送ping命令，master回复pong，salve收到master回应pong，发送同步命令，（根据run_id或offset判断）确定可进行增量更新，从环形内存中取得增量，发送给slave，salve更新内存，更新rdb或aof（如果需要），收到一个数据更新操作，写aof（如果需要），更新到环形内存，主动更新slave，slave收到更新数据，更新内存，（跟新rdb或aof（如果需要））
      增量更新时，不依赖rdb文件，所以master和slave是否开启rdb功能或者aof不重要。

    为什么在Master上新增的数据除了根据Master节点上RDB或者AOF的设置进行日志文件更新外，还会同时将数据变化写入一个环形内存结构，并以后者为依据进行Slave节点的增量更新呢？主要原因有以下几个：

    1.由于网络环境的不稳定，网络抖动/延迟都可能造成Slave和Master暂时断开连接，这种情况要远远多于新的Slave连接到Master的情况。如果以上所有情况都使用全量更新，就会大大增加Master的负载压力——写RDB文件是有大量I/O过程的，虽然Linux Page Cahe特性会减少性能消耗。
    2.另外在数据量达到一定规模的情况下，使用全量更新进行和Slave的第一次同步是一个不得已的选择——因为要尽快减少Slave节点和Master节点的数据差异。所以只能占用Master节点的资源和网络带宽资源。
    3.使用内存记录数据增量操作，可以有效减少Master节点在这方面付出的I/O代价。而做成环形内存的原因，是为了保证在满足数据记录需求的情况下尽可能减少内存的占用量。这个环形内存的大小，可以通过repl-backlog-size参数进行设置。
    Slave重连后会向Master发送之前接收到的Master run_id信息和上一次完成部分同步的offset的位置信息。如果Master能够确定这个run_id和自己的run_id一致且能够在环形内存中找到这个offset的位置，Master就会发送从offset的位置开始向Slave发送增量数据。那么连接正常的各个Slave节点如何接受新数据呢？连接正常的Slave节点将会在Master节点将数据写入环形内存后，主动接收到来自Master的数据复制信息。
  2.哨兵机制：
    有了主从复制以后，如果想对主服务器进行监控，可以使用哨兵机制。
     a.（监控）监控所有节点数据库是否正常运行。
     b.（自动故障迁移）master故障时，可以通过投票机制，从slave节点中选举新的master。
     c.（提醒）当某个redis出现问题，可以通过api提醒用户。
     1.监控
          sentinel会每秒一次的频率与之前创建了命令连接的实例发送PING，包括主服务器、从服务器和sentinel实例，以此来判断当前实例的状态。down-after-milliseconds时间内PING连接无效，则将该实例视为主观下线。之后该sentinel会向其他监控同一主服务器的sentinel实例询问是否也将该服务器视为主观下线状态，当超过某quorum后将其视为客观下线状态。
          当一个主服务器被某sentinel视为客观下线状态后，该sentinel会与其他sentinel协商选出零头sentinel进行故障转移工作。每个发现主服务器进入客观下线的sentinel都可以要求其他sentinel选自己为领头sentinel，选举是先到先得。同时每个sentinel每次选举都会自增配置纪元，每个纪元中只会选择一个领头sentinel。如果所有超过一半的sentinel选举某sentinel领头sentinel。之后该sentinel进行故障转移操作。
          如果一个Sentinel为了指定的主服务器故障转移而投票给另一个Sentinel，将会等待一段时间后试图再次故障转移这台主服务器。如果该次失败另一个将尝试，Redis Sentinel保证第一个活性(liveness)属性，如果大多数Sentinel能够对话，如果主服务器下线，最后只会有一个被授权来故障转移。 同时Redis Sentinel也保证安全(safety)属性，每个Sentinel将会使用不同的配置纪元来故障转移同一台主服务器。
      2.故障迁移
          首先是从主服务器的从服务器中选出一个从服务器作为新的主服务器。选点的依据依次是：网络连接正常->5秒内回复过INFO命令->10*down-after-milliseconds内与主连接过的->从服务器优先级->复制偏移量->运行id较小的。选出之后通过slaveif no ont将该从服务器升为新主服务器。
          通过slaveof ip port命令让其他从服务器复制该信主服务器。
          最后当旧主重新连接后将其变为新主的从服务器。注意如果客户端与就主服务器分隔在一起，写入的数据在恢复后由于旧主会复制新主的数据会造成数据丢失。
          故障转移成功后会通过发布订阅连接广播新的配置信息，其他sentinel收到后依据配置纪元更大来更新主服务器信息。Sentinel保证第二个活性属性：一个可以相互通信的Sentinel集合会统一到一个拥有更高版本号的相同配置上。    
      缺点：
      　　1.主从服务器的数据要经常进行主从复制，这样造成性能下降。
      　　2.当主服务器宕机后，从服务器切换成主服务器的那段时间，服务是不能用的。
    Redis Cluster：
        Redis集群是一个分布式（distributed）、容错（fault-tolerant）的 Redis内存K/V服务， 集群可以使用的功能是普通单机 Redis 所能使用的功能的一个子集（subset），比如Redis集群并不支持处理多个keys的命令,因为这需要在不同的节点间移动数据,从而达不到像Redis那样的性能,在高负载的情况下可能会导致不可预料的错误。
      Redis集群的几个重要特征：
    　　(1). Redis 集群的分片特征在于将键空间分拆了16384个槽位，每一个节点负责其中一些槽位。
    　　(2). Redis提供一定程度的可用性,可以在某个节点宕机或者不可达的情况下继续处理命令.
    　　(3). Redis 集群中不存在中心（central）节点或者代理（proxy）节点， 集群的其中一个主要设计目标是达到线性可扩展性（linear scalability）。
      Redis Cluster特点如下：
        所有的节点相互连接；
        集群消息通信通过集群总线通信，，集群总线端口大小为客户端服务端口+10000，这个10000是固定值；
        节点与节点之间通过二进制协议进行通信；
        客户端和集群节点之间通信和通常一样，通过文本协议进行；
        集群节点不会代理查询；
       分区实现原理
        1、槽（slot）概念
        　　Redis Cluster中有一个16384长度的槽的概念，他们的编号为0、1、2、3……16382、16383。这个槽是一个虚拟的槽，并不是真正存在的。正常工作的时候，Redis Cluster中的每个Master节点都会负责一部分的槽，当有某个key被映射到某个Master负责的槽，那么这个Master负责为这个key提供服务，至于哪个Master节点负责哪个槽，这是可以由用户指定的，也可以在初始化的时候自动生成（redis-trib.rb脚本）。这里值得一提的是，在Redis Cluster中，只有Master才拥有槽的所有权，如果是某个Master的slave，这个slave只负责槽的使用，但是没有所有权。Redis Cluster怎么知道哪些槽是由哪些节点负责的呢？某个Master又怎么知道某个槽自己是不是拥有呢？
        2、位序列结构
　　      Master节点维护着一个16384/8字节的位序列，Master节点用bit来标识对于某个槽自己是否拥有。比如对于编号为1的槽，Master只要判断序列的第二位（索引从0开始）是不是为1即可。
        3、故障容忍度
      　　(1)心跳和gossip消息
        　　Redis Cluster持续的交换PING和PONG数据包。这两种数据包的数据结构相同，都包含重要的配置信息，唯一的不同是消息类型字段。PING和PONG数据包统称为心跳数据包。
        　　每个节点在每一秒钟都向一定数量的其它节点发送PING消息，这些节点应该向发送PING的节点回复一个PONG消息。节点会尽可能确保拥有每个其它节点在NOTE_TIMEOUT/2秒时间内的最新信息，否则会发送一个PING消息，以确定与该节点的连接是否正常。
        　　假定一个Cluster有301个节点，NOTE_TIMEOUT为60秒，那么每30秒每个节点至少发送300个PING，即每秒10个PING， 整个Cluster每秒发送10x301=3010个PING。这个数量级的流量不应该会造成网络负担。
      　　(2)故障检测。
            Redis Cluster的故障检测用于检测一个master节点何时变得不再有效，即不能提供服务，从而应该让slave节点提升为master节点。如果提升失败，则整个Cluster失效，不再接受客户端的服务请求。当一个节点A向另外一个节点B发送了PING消息之后，经过NODE_TIMEOUT秒时间之后仍然没有收到PONG应答，则节点A认为节点B失效，节点A将为该节点B设置PFAIL标志。在 NODE_TIMEOUT * FAIL_REPORT_VALIDITY_MULT时间内，当Cluster中大多数节点认为节点B失效，即设置PFAIL标志时，这个Cluster认为节点B真的失效了，此时节点A将为节点B设置FAIL标志，并向所有节点发送FAIL消息。在一些特定情况下，拥有FAIL标志的节点，也可以清除掉FAIL标志。
 　　       Redis Cluster故障检测机制最终应该让所有节点都一致同意某个节点处于某个确定的状态。如果发生这样的情况少数节点确信某个节点为FAIL，同时有少数节点确认某个节点为非FAIL，则Redis Cluster最终会处于一个确定的状态：
        　　情况1：最终大多数节点认为该节点FAIL，该节点最终实际为FAIL。
        　　情况2：最终在N x NODE_TIMEOUT时间内，仍然只有少数节点将给节点标记为FAIL，此时最终会清除这个节点的FAIL标志。
          4、重定向客户端
　　          Redis Cluster并不会代理查询，那么如果客户端访问了一个key并不存在的节点，这个节点是怎么处理的呢？比如我想获取key为msg的值，msg计算出来的槽编号为254，当前节点正好不负责编号为254的槽，那么就会返回客户端下面信息：
 　　         表示客户端想要的254槽由运行在IP为127.0.0.1，端口为6381的Master实例服务。如果根据key计算得出的槽恰好由当前节点负责，则当期节点会立即返回结果。这里明确一下，没有代理的Redis Cluster可能会导致客户端两次连接急群中的节点才能找到正确的服务，推荐客户端缓存连接，这样最坏的情况是两次往返通信。
          5、 slots配置传播
　　          Redis Cluster采用两种方式进行各个master节点的slots配置信息的传播。所谓slots配置信息，即master负责存储哪几个slots。
          架构细节:
          (1)所有的redis节点彼此互联(PING-PONG机制),内部使用二进制协议优化传输速度和带宽.
          (2)节点的fail是通过集群中超过半数的节点检测失效时才生效.
          (3)客户端与redis节点直连,不需要中间proxy层.客户端不需要连接集群所有节点,连接集群中任何一个可用节点即可
          (4)redis-cluster把所有的物理节点映射到[0-16383]slot上,cluster 负责维护node<->slot<->value
          Redis 集群中内置了 16384 个哈希槽，当需要在 Redis 集群中放置一个 key-value 时，redis 先对 key 使用 crc16 算法算出一个结果，然后把结果对 16384 求余数，这样每个 key 都会对应一个编号在 0-16383 之间的哈希槽，redis 会根据节点数量大致均等的将哈希槽映射到不同的节点
      codis：
        codis由3大组件构成：
          codis-server：修改过源码的redis，支持slot、扩容迁移等
          codis-proxy：支持多线程，go语言实现的内核
          codis Dashboard：集群管理工具
        codis提供web图形界面管理集群。
        集群元数据存在在zookeeper或etcd。
        提供独立的组件codis-ha负责redis节点主备切换。
        基于proxy的codis，客户端对路由表变化无感知。客户端需要从codis dashhoard调用list proxy命令获取所有proxy列表，并根据自身的轮询策略决定访问哪个proxy节点以实现负载均衡。

  限流算法：

  令牌桶和漏桶对比：
    令牌桶是按照固定速率往桶中添加令牌，请求是否被处理需要看桶中令牌是否足够，当令牌数减为零时则拒绝新的请求；
    漏桶则是按照常量固定速率流出请求，流入请求速率任意，当流入的请求数累积到漏桶容量时，则新流入的请求被拒绝；
    令牌桶限制的是平均流入速率，允许突发请求，只要有令牌就可以处理，支持一次拿3个令牌，4个令牌；漏桶限制的是常量流出速率，即流出速率是一个固定常量值，比如都是1的速率流出，而不能一次是1，下次又是2，从而平滑突发流入速率；
  令牌桶允许一定程度的突发，而漏桶主要目的是平滑流出速率；
    Guava的RateLimiter提供了令牌桶算法实现：平滑突发限流(SmoothBursty)和平滑预热限流(SmoothWarmingUp)实现。
    RateLimiter使用令牌桶算法，会进行令牌的累积，如果获取令牌的频率比较低，则不会导致等待，直接获取令牌。由于会累积令牌，所以可以应对突发流量。
    在没有足够令牌发放时，采用滞后处理的方式，也就是前一个请求获取令牌所需等待的时间由下一次请求来承受，也就是代替前一个请求进行等待。
    SmoothWarmingUp实现预热缓冲的关键在于其分发令牌的速率会随时间和令牌数而改变，速率会先慢后快。
        //SmoothRateLimiter.java
        //当前存储令牌数
        double storedPermits;
        //最大存储令牌数
        double maxPermits;
        //添加令牌时间间隔
        double stableIntervalMicros;
        /**
        * 下一次请求可以获取令牌的起始时间
        * 由于RateLimiter允许预消费，上次请求预消费令牌后
        * 下次请求需要等待相应的时间到nextFreeTicketMicros时刻才可以获取令牌
        */
        private long nextFreeTicketMicros = 0L;


Bloom Filter 概念
  布隆过滤器实际上是一个很长的二进制向量和一系列随机映射函数。布隆过滤器可以用于检索一个元素是否在一个集合中。
  它的优点是空间效率和查询时间都远远超过一般的算法，缺点是有一定的误识别率和删除困难。

原理：
  布隆过滤器的原理是，当一个元素被加入集合时，通过K个散列函数将这个元素映射成一个位数组中的K个点，把它们置为1。检索时，我们只要看看这些点是不是都是1就（大约）知道集合中有没有它了：如果这些点有任何一个0，则被检元素一定不在；如果都是1，则被检元素很可能在。这就是布隆过滤器的基本思想。
缺点：
  bloom filter之所以能做到在时间和空间上的效率比较高，是因为牺牲了判断的准确率、删除的便利性
存在误判，可能要查到的元素并没有在容器中，但是hash之后得到的k个位置上值都是1。如果bloom filter中存储的是黑名单，那么可以通过建立一个白名单来存储可能会误判的元素。
删除困难。一个放入容器的元素映射到bit数组的k个位置上是1，删除的时候不能简单的直接置为0，可能会影响其他元素的判断。可以采用Counting Bloom Filter，建立白名单存错误信息。

bitmap：
  应用场景：
    统计上亿的日活跃用户
      1.为了统计今日登录的用户数，我们建立了一个bitmap,每一位标识一个用户ID。当某个用户访问我们的网页或执行了某个操作，就在bitmap中把标识此用户的位置为1。在Redis中获取此bitmap的key值是通过用户执行操作的类型和时间戳获得的。
      2.这个简单的例子中，每次用户登录时会执行一次redis.setbit(daily_active_users, user_id, 1)。将bitmap中对应位置的位置为1，时间复杂度是O(1)。统计bitmap结果显示有今天有9个用户登录。Bitmap的key是daily_active_users，它的值是1011110100100101。
      3.因为日活跃用户每天都变化，所以需要每天创建一个新的bitmap。我们简单地把日期添加到key后面，实现了这个功能。例如，要统计某一天有多少个用户至少听了一个音乐app中的一首歌曲，可以把这个bitmap的redis key设计为play:yyyy-mm-dd-hh。当用户听了一首歌曲，我们只是简单地在bitmap中把标识这个用户的位置为1，时间复杂度是O(1)。


秒杀活动存储过程：
  -- 秒杀执行储存过程
```
DELIMITER
$$
-- 定义储存过程
-- 参数: in 参数,out输出参数
-- row_count() 返回上一条修改类型sql(delete,insert,update)的影响行数
-- row_count:0:未修改数据, >0:表示修改的行数, <0:sql错误
CREATE PROCEDURE `seckill`.`execute_seckill`
  (IN v_seckill_id BIGINT, IN v_phone BIGINT,IN v_kill_time  TIMESTAMP, OUT r_result INT)
  BEGIN
    -- 定义一个变量为insert_count，记录插入数量
    DECLARE insert_count INT DEFAULT 0;
    -- 开始事务
    START TRANSACTION;
    -- 插入秒杀成功信息
    INSERT IGNORE INTO success_killed
    (seckill_id, user_phone, create_time)
    VALUES (v_seckill_id, v_phone, v_kill_time);
    -- 查询影响行数
    SELECT row_count()
    -- 将影响行数赋值给insert_count
    INTO insert_count;
    -- 判断执行状态
    IF (insert_count = 0)
    -- 如果=0未修改数据，事务回滚，并设置返回结果
    THEN
      ROLLBACK;
      SET r_result = -1;
    ELSEIF (insert_count < 0)
    -- 如果<0sql报错，事务回滚，并设置返回结果
      THEN
        ROLLBACK;
        SET r_result = -2;
    ELSE
    -- 如果大于0，执行成功，更改秒杀数量
      UPDATE seckill
      SET number = number - 1
      WHERE seckill_id = v_seckill_id
            AND end_time > v_kill_time
            AND start_time < v_kill_time
            AND number > 0;
      -- 查询更改秒杀数量结果
      SELECT row_count()
      -- 将秒杀数量结果赋值给insert_count
      INTO insert_count;
      -- 判断修改秒杀数量执行结果
      IF (insert_count = 0)
      -- 如果=0sql未修改记录，回滚事务，并设置返回结果
      THEN
        ROLLBACK;
        SET r_result = 0;
      ELSEIF (insert_count < 0)
      -- 如果<0sql报错，回滚事务，并设置返回结果
        THEN
          ROLLBACK;
          SET r_result = -2;
      ELSE
      -- 如果>0修改秒杀数量成功，提交事务，并设置返回结果
        COMMIT;
        SET r_result = 1;

      END IF;
    END IF;
  END;
$$
--  储存过程定义结束
DELIMITER ;
SET @r_result = -3;
--  执行储存过程
CALL execute_seckill(1003, 13502178891, now(), @r_result);
-- 获取结果
SELECT @r_result;
```



redis：
应用场景： 数据缓存，分布式session，分布式锁。

常用的淘汰算法：
FIFO：First In First Out，先进先出。判断被存储的时间，离目前最远的数据优先被淘汰。
LRU：Least Recently Used，最近最少使用。判断最近被使用的时间，目前最远的数据优先被淘汰。
LFU：Least Frequently Used，最不经常使用。在一段时间内，数据被使用次数最少的，优先被淘汰。

Redis提供的淘汰策略：
noeviction：达到内存限额后返回错误，客户尝试可以导致更多内存使用的命令（大部分写命令，但DEL和一些例外）
allkeys-lru：为了给新增加的数据腾出空间，驱逐键先试图移除一部分最近使用较少的（LRC）。
volatile-lru：为了给新增加的数据腾出空间，驱逐键先试图移除一部分最近使用较少的（LRC），但只限于过期设置键。
allkeys-random: 为了给新增加的数据腾出空间，驱逐任意键
volatile-random: 为了给新增加的数据腾出空间，驱逐任意键，但只限于有过期设置的驱逐键。
volatile-ttl: 只限于设置了 expire 的部分; 优先删除剩余时间(time to live,TTL) 短的key。

redis持久化：
1. Redis 默认开启RDB持久化方式，在指定的时间间隔内，执行指定次数的写操作，则将内存中的数据写入到磁盘中。
2. RDB 持久化适合大规模的数据恢复但它的数据一致性和完整性较差。
3. Redis 需要手动开启AOF持久化方式，默认是每秒将写操作日志追加到AOF文件中。
4. AOF 的数据完整性比RDB高，但记录内容多了，会影响数据恢复的效率。
5. Redis 针对 AOF文件大的问题，提供重写的瘦身机制。
6. 若只打算用Redis 做缓存，可以关闭持久化。
7. 若打算使用Redis 的持久化。建议RDB和AOF都开启。其实RDB更适合做数据的备份，留一后手。AOF出问题了，还有RDB。

负载均衡算法：
    1、轮询（Round Robin）法
    轮询很容易实现，将请求按顺序轮流分配到后台服务器上，均衡的对待每一台服务器，而不关心服务器实际的连接数和当前的系统负载。使用轮询策略的目的是，希望做到请求转移的绝对均衡，但付出的代价性能也是相当大的。为了保证pos变量的并发互斥，引入了重量级悲观锁synchronized，将会导致该轮询代码的并发吞吐量明显下降。 
    轮询法适用于机器性能相同的服务，一旦某台机器性能不好，极有可能产生木桶效应，性能差的机器扛不住更多的流量。
    2、随机法
    通过系统随机函数，根据后台服务器列表的大小值来随机选取其中一台进行访问。由概率概率统计理论可以得知，随着调用量的增大，其实际效果越来越接近于平均分配流量到后台的每一台服务器，也就是轮询法的效果。 
    同样地，它也不适用于机器性能有差异的分布式系统。
    3、随机轮询法
    所谓随机轮询，就是将随机法和轮询法结合起来，在轮询节点时，随机选择一个节点作为开始位置index，此后每次选择下一个节点来处理请求，即（index+1）%size。 
    这种方式只是在选择第一个节点用了随机方法，其他与轮询法无异，缺点跟轮询一样。
    4、源地址哈希法
    源地址哈希法的思想是根据服务消费者请求客户端的IP地址，通过哈希函数计算得到一个哈希值，将此哈希值和服务器列表的大小进行取模运算，得到的结果便是要访问的服务器地址的序号。采用源地址哈希法进行负载均衡，相同的IP客户端，如果服务器列表不变，将映射到同一个后台服务器进行访问。该方法适合访问缓存系统，如果为了增强缓存的命中率和单调性，可以用一致性哈希算法
    5、加权轮询（Weight Round Robin）法
    不同的后台服务器可能机器的配置和当前系统的负载并不相同，因此它们的抗压能力也不一样。跟配置高、负载低的机器分配更高的权重，使其能处理更多的请求，而配置低、负载高的机器，则给其分配较低的权重，降低其系统负载，加权轮询很好的处理了这一问题，并将请求按照顺序且根据权重分配给后端。Nginx的负载均衡默认算法是加权轮询算法。