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
