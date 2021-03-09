### 集群架构
- JobManager: 每个集群至少一个，管理整个集群计算资源，Job管理与调度执行,以及Checkpoint协调。机器集群中至少要有一个 master，master 负责调度 task，协调 checkpoints 和容灾，高可用设置的话可以有多个 master，但要保证一个是 leader, 其他是 standby; Job Manager 包含 Actor system、Scheduler、Check pointing 三个重要的组件
  - checkpoint coordinator
  - jobGraph->Execution Graph
  - Task部署与调度
  - rpc通信
  - job接收
  - 集群资源管理
  - TaskManager注册与管理
- TaskManager:每个集群有多个TM,负责提供计算资源。从 Job Manager 处接收需要部署的 Task。Task Manager 是在 JVM 中的一个或多个线程中执行任务的工作节点。 任务执行的并行性由每个 Task Manager 上可用的任务槽决定。 每个任务代表分配给任务槽的一组资源。 例如，如果 Task Manager 有四个插槽，那么它将为每个插槽分配 25％ 的内存。 可以在任务槽中运行一个或多个线程。 同一插槽中的线程共享相同的 JVM。 同一 JVM 中的任务共享 TCP 连接和心跳消息。Task Manager 的一个 Slot 代表一个可用线程，该线程具有固定的内存，注意 Slot 只对内存隔离，没有对 CPU 隔离。默认情况下，Flink 允许子任务共享 Slot，即使它们是不同 task 的 subtask，只要它们来自相同的 job。这种共享可以有更好的资源利用率。
  - Task Execution
  - Network Manager
  - Shuffle Environment管理
  - rpc通信
  - Heartbeat with JobManager and RM
  - Data Exchange
  - Memory Management
  - Register To RM
  - offer slots to jobManager
- Client:本地执行应用main()方法解析JobGraph对象，并最终将JobGraph提交到JobManager运行，同时监控Job执行的状态。
  - Application main方法执行
  - JobGraph Generate
  - Execution Environment管理
  - Job提交与运行
  - DependenyJar Ship
  - Rpc with JobManager
  - 集群部署（Cluster deploy）

--- 

### JobGraph
  - 通过有向无环图(Dag)方式表达用户程序

---

# 集群类型
### Session Mode：共享jobManager和taskManager，提交的job在一个runtime中运行
  - 客户端需要上传依赖的jar包
  - 客户端需要生成JobGraph，并提交到管理节点
  - JobManager的生命周期不受提交的Job影响会长期运行
 优点：
  - 资源充分共享，提升资源利用率
  - Job在Flink Session集群中管理运维简单
 缺点：
   - 资源隔离相对较差
   - 非Native类型部署，TaskManager不易扩展，Slot计算资源伸缩性较差

### Pre-Job Mode：独享JobManager和TaskManager，为每个Job单独启动一个runtime
  - TaskManager中solt资源根据Job指定
  - 客户端需要上传依赖的jar包
  - 客户端需要生成JobGraph，并提交到管理节点
  - JobManager的生命周期和Job生命周期绑定
优点：
  - Job和Job之间资源隔离
  - 资源根据Job需要进行申请，TaskManager slot数量可以不同
缺点：
  - 资源相对浪费，JobManager需要消耗资源
  - Job管理完全交给ClusterManagement管理复杂

### Application Mode(1.11版本提出)：Application的main方法运行在cluster上而不在客户端，每个Application对应一个runtime，application可以包含多个job
  - 客户端无需将依赖包上传到JobManager，仅负责Job的提交与管理
  - main方法运行在JobManager中，将JobGraph的生成放在集群上运行，客户端压力降低
优点：
  - 有效降低带宽消耗和客户端负载
  - Application实现资源隔离，Application中资源共享
缺点：
  - 仅支持yarn和k8s
  
### Flink支持以下资源管理器部署集群
 - standalone
 - yarn
 - mesos
 - docker
 - k8s

### flink on yarn优势与劣势
优势：
  - 与现有大数据平台无缝对接
  - 部署集群与任务提交都简单
  - 资源管理统一通过yarn管理，提升整体资源利用率
  - 基于Native方式，TaskManager资源按需申请和启动，防止资源浪费
  - 容错保证借助于Handoop Yarn提供的自动failover机制，能保证JobManager、TaskManager节点异常恢复
缺点：
  - 资源隔离问题不够完善
  - 离线和实时作业同时运行相互干扰
  - Kerberos认证超期导致checkpoint无法持久化

### flink on k8s优势与劣势
优势：
  - 资源管理统一通过k8s管理，提升整体资源利用率
  - 基于Native方式，TaskManager资源按需申请和启动，防止资源浪费
  - k8s副本和重启机制保证JobManger和TaskManager自动恢复
缺点：
  - Native模式还需要增强，包括支持节点选择等高级特性

### flink集群高可用基于zookeeper实现
```yaml
# flink-conf.yaml
# zookeeper高可用配置
high-availability: zookeeper
# zookeeper地址配置
high-availability.zookeeper.quorum: ip1:2181,ip2:2181
# 元数据保存地址
high-availability.storageDir: hdfs:///flink/ha/
# job manager选一个随机端口作为进程通信端口
high-availability.jobmanager.port:50010 
# 如果程序启动失败，YARN会再重试9次（9次重试+1次启动），如果启动10次作业还失败，yarn才会将该任务的状态置为失败。如果因为节点硬件故障或重启，NodeManager重新同步等操作，需要YARN继续尝试启动应用。这些重启尝试不计入yarn.application-attempts个数中。
yarn.application-attempts: 10

# zoo.cfg
# masters文件包含启动 JobManagers 的所有主机以及Web用户界面绑定的端口
localhost:8081
```

### flink on yarn高可用集群
```xml
# yarn-site.xml,配置application master的最大重试次数
<property>
  <name>yarn.resourcemanager.am.max-attempts</name>
  <value>4</value>
  <description>
    The maximum number of application master execution attempts.
  </description>
</property>
```

---

### Flink WebUI上传的jar存储位置:
- 通过web.upload.dir配置
- 默认使用临时目录(web.tmpdir= java.io.tmpdir + “flink-web-” + UUID 组成的)

---

### 使用Checkpoint提高程序的可靠性
用户可以根据的程序里面的配置将checkpoint打开，给定一个时间间隔后，框架会按照时间间隔给程序的状态进行备份。当发生故障时，Flink会将所有Task的状态一起恢复到Checkpoint的状态。从哪个位置开始重新执行。
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093152.jpg)
- 备份为保存在State中的程序状态数据
- Flink也提供了一套机制，允许把这些状态放到内存当中。做Checkpoint的时候，由Flink去完成恢复。
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093217.jpg)

### Checkpoint的执行流程
Checkpoint的执行流程是按照Chandy-Lamport算法实现的
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093412.jpg)

### Checkpoint Barrier的对齐
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093428.jpg)

### 全量Checkpoint
全量Checkpoint会在每个节点做备份数据时，只需要将数据都便利一遍，然后写到外部存储中，这种情况会影响备份性能。在此基础上做了优化。
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093447.jpg)

### RockDB的增量Checkpoint
RockDB的数据会更新到内存，当内存满时，会写入到磁盘中。增量的机制会将新产生的文件COPY持久化中，而之前产生的文件就不需要COPY到持久化中去了。通过这种方式减少COPY的数据量，并提高性能。
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093511.jpg)

---

### 当组件升级的时候，需要停止当前作业。这个时候需要从之前停止的作业当中恢复，Flink提供了2种机制恢复作业:
- Savepoint:是一种特殊的checkpoint，只不过不像checkpoint定期的从系统中去触发的，它是用户通过命令触发，存储格式和checkpoint也是不相同的，会将数据按照一个标准的格式存储，不管配置什么样，Flink都会从这个checkpoint恢复，是用来做版本升级一个非常好的工具；
- External Checkpoint：对已有checkpoint的一种扩展，就是说做完一次内部的一次Checkpoint后，还会在用户给定的一个目录中，多存储一份checkpoint的数据；

---

# 状态管理和容错机制实现

### Flink提供了3种不同的StateBackend
用户可以根据自己的需求选择，如果数据量较小，可以存放到MemoryStateBackend和FsStateBackend中，如果数据量较大，可以放到RockDB中。
- MemoryStateBackend
- FsStateBackend
- RockDBStateBackend
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093258.jpg)

### HeapKeyedStateBackend
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093320.jpg)

### RockDBKeyedStateBackend
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093345.jpg)

### 如何使用TwoPhaseCommitSinkFunction?用户只需要实现四个函数，就能为数据输出端实现 Exactly-Once语义
- beginTransaction - 在事务开始前，我们在目标文件系统的临时目录中创建一个临时文件。随后，我们可以在处理数据时将数据写入此文件。
- preCommit - 在预提交阶段，我们刷新文件到存储，关闭文件，不再重新写入。我们还将为属于下一个 checkpoint 的任何后续文件写入启动一个新的事务。
- commit - 在提交阶段，我们将预提交阶段的文件原子地移动到真正的目标目录。需要注意的是，这会增加输出数据可见性的延迟。
- abort - 在中止阶段，我们删除临时文件。
如果发生任何故障，Flink会将应用程序的状态恢复到最新的一次checkpoint 点。一种极端的情况是，预提交成功了，但在这次commit的通知到达operator之前发生了故障。在这种情况下，Flink会将operator的状态恢复到已经预提交，但尚未真正提交的状态。我们需要在预提交阶段保存足够多的信息到checkpoint状态中，以便在重启后能正确的中止或提交事务。在这个例子中，这些信息是临时文件和目标目录的路径。TwoPhaseCommitSinkFunction已经把这种情况考虑在内了，并且在从checkpoint点恢复状态时，会优先发出一个commit。我们需要以幂等方式实现提交.

---

### flink与hadoop
1. flink作为大数据生态圈的一员，它和Hadoop的hdfs是兼容的。
2. 一般将namenode和jobmanager部署到一起，将datanode和taskmanager部署到一起。
3. flink也能照顾到数据的本地行，移动计算而不是移动数据。


### spark与flink比较
- spark的本质是批处理，它将流处理看出无边界的批处理
- flink的本质是流处理，它将批处理看出有边界的流处理

### flink在JVM的heap内有自己的内存管理空间
- 在flink中内存被分为三个部分，分别是Unmanaged区域，Managed区域，Network-Buffer区域
- Unmanaged区域是指flink不管理这部分区域，它的管理由JVM管理，用于存放User Code
- Managed区域是指flink管理这部分区域，它不受jvm管理不存在GC问题，用于存放Hashing,Sorting,Caching等数据
- Network-Buffer区域是指flink在进行计算时需要通过网络进行交换数据的区域。用于存放Shuffles，Broadcasts数据。

### 为了解决大量对象在JVM的heap上创建会带来OOM和GC的问题，flink将大量使用的内存存放到堆外.
- flink在堆外有一块预分配的固定大小的内存块MemorySegment，flink会将对象高效的序列化到这块内存中。
- MemorySegment由许多小的内存cell组成，每个cell大小32kb，这也是flink分配内存的最小单位。你可以把MemorySegment想象成是为Flink定制的java.nio.ByteBuffer。它的底层可以是一个普通的Java字节数组（byte[]），也可以是一个申请在堆外的ByteBuffer。每条记录都会以序列化的形式存储在一个或多个MemorySegment中。
- 如果MemorySegment中依然放不小所有的数据，flink会将数据写入磁盘，需要的时候再冲磁盘读出来。

### 使用堆外内存获得的好处：
1. 有效防止OOM
- 由于MemorySegment大小固定，操作高效。如果MemorySegment不足写出到磁盘，内存中的数据不多，一般不会发生OOM.
2. 大幅度减轻GC压力
- 少量长期使用的数据以二进制形式存储在内存，大量临时使用的对象被序列化到磁盘。对象数量就会大量减少，GC压力减轻。
3. 节省内存空间
- Java对象的存储密度低，现在大量数据都是二进制的表示形式，存储密度提高了，内存利用率提高了！
4. 二进制操作更高效,缓存操作更友好
- 二进制数据以定义好的格式存储，可以高效地比较与操作。另外，该二进制形式可以把相关的值，以及hash值，键值和指针等相邻地放进内存中。这使得数据结构可以对高速缓存更友好，可以从 L1/L2/L3 缓存获得性能的提升

---

### flink提供大量的api,有些sql-api或sort，group，join等操作牵涉到大量的数据，使用大量内存。这些操作都是基于flink的数据内存和引用内存分开存储的方式进行操作的。

### 以sort为例：
![](https://s1.ax1x.com/2020/10/24/BVxRBV.png)
![](https://s1.ax1x.com/2020/10/24/BZC6eI.png)
1. Flink从MemoryManager申请一批MemorySegment，作为sort-buffer，用来存放排序的数据。
2. sort-buffer分成两块
  - 一块用来存放所有对象完整的二进制数据。
  - 一块用来存放指向完整二进制数据的引用。
  - 引用由指针(pointer)定长的序列化后的键（key）组成，ref=point+key,将key和point分开存储的动机是：
      - a.ref.point指向真实数据块，
      - b.ref.key用来做基于key的诸如compare等操作，
      - c.ref.key是连续存储的，这样能提高cpu的缓存命中率，加快CPU访问数据。
3. 当一个对象要加到 sort-buffer时，它的binary-data会被加到第一个区域，ref=(piont+key)会被加到第二个区域。
4. 执行比较时，如果有binary-key直接通过偏移量操作binary-key.如果没有binary-key那只能序列化整个对象再进行比较。
5. 执行交互时，只需交互ref,不需要交互binary-data
6. 访问数据时，只需沿着排好序的ref区域顺序访问，通过ref.pointer找到对应的真实数据.

---

### flink运行状态
![](https://img-blog.csdn.net/20171118165325939?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvbGlndW9odWFCaWdkYXRh/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)
- 最正常的状态是created->running->finished
- running的job还可能被取消，运行失败，挂起运行等，这样job就会切换到相应的状态

# 数据传输模式
### Stream在transform过程中有两种传输模式,Forwarding模式和Redistributing模式。
- Forwarding模式是指Stream-Partition之间一对一(One-to-One)传输。子stream保留父stream的分区个数和元素的顺序。
  Source向map传输stream-partition就在这种情况，分区个数，元素顺序都能保持不变，这里可以进行优化。可以把source和
  map做成一个TaskChain,用一个thread去执行一个source-subtask和map-subtask.原本4个thread处理的任务，
  优化后2个thread就能完成了，因为减少了不必要的thread开销，效率还能提升。
- Redistributing模式是指Stream-Partition之间是多对多的传输。stream转化过程中partition之间进行了shuffer操作,
  这会把分区个数和元素顺序全部打乱，可能会牵涉到数据的夸节点传输。因为数据可能夸节点传输，无法确定应该在哪个节点上启动
  一个thread去处理在两个节点上的数据，因此无法将Redistributing模式下的task做成一个task-chain。
  Map-KeyBy/Window和KeyBy/Window-sink直接就是Redistributing模式。

### 任务以及操作链(Task & Operator Chains)
1. 为了减少不必要的thread通信和缓冲等开销，可以将Forwarding模式下的多个subtask做成一个subtask-chain
2. 将一个thread对应一个subtask优化为一个thread对应一个subtask-chain中的多个subtask。
  可提高总体吞吐量（throughput）并降低延迟（latency）。
3. 如果说stream-partition对数据分区是为了通过提高并发度，来提高程序的运行效率。那么subtask-chain就是在程序的运行
  过程中合并不必要的thread来提高程序的运行效率。

### flink在批处理中常见的source主要有两大类。
1. 基于本地集合的source（Collection-based-source）
2. 基于文件的source（File-based-source）

### flink在批处理中常见的sink
1. 基于本地集合的sink（Collection-based-sink）
2. 基于文件的sink（File-based-sink）

### flink中的容错设置
flink支持容错设置,当操作失败了，可以在指定重试的启动时间和重试的次数.有两种设置方式
1. 通过配置文件，进行全局的默认设定
2. 通过程序的api进行设定
```java
//通过配置文件
//设定出错重试3次
execution-retries.default: 3
//设定重试间隔时间5秒
execution-retries.delay: 5s
```
```java
//程序的api进行容错设定
//失败重试3次
env.setNumberOfExecutionRetries(3)
//重试时延 5000 milliseconds
env.getConfig.setExecutionRetryDelay(5000)
```

---


### flink中的背压的处理原理
流系统中消息的处理速度跟不上消息的发送速度，导致消息的堆积。如果系统能感知消息堆积，并调整消息发送的速度。使消息的处理速度和发送速度相协调就是有背压感知的系统。背压如果不能得到正确地处理，可能会导致资源被耗尽甚至出现更糟的情况导致数据丢失。flink就是一个有背压感知的基于流的分布式消息处理系统。
![](https://img-blog.csdn.net/20171122093814752?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvbGlndW9odWFCaWdkYXRh/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)
$\color{red}{正常情况：消息处理速度>=消息的发送速度，不发生消息拥堵，系统运行流畅}$
![](https://img-blog.csdn.net/20171122093928861?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvbGlndW9odWFCaWdkYXRh/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)
$\color{red}{异常情况：消息处理速度< 消息的发送速度，发生了消息拥堵，系统运行不畅}$
![](https://img-blog.csdn.net/20171122094000061?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvbGlndW9odWFCaWdkYXRh/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)

### flink消息拥堵可以采取两种方案
1. 将拥堵的消息直接删除，将会导致数据丢失，在精确到要求高的场景非常不合适
2. 将拥堵的消息缓存起来，并告知消息发送者减缓消息发送的速度。
    - 处理方法：将缓冲区持久化，以方便在处理失败的情况下进行数据重放。有些source本身提供持久化保证，可以优先考虑。例如： Apache Kafka是一个很不错的选择，可以背压从sink到source的整个pipeline,同时对source进行限流来适配整个pipeline中最慢组件的速度，从而获得系统的稳定状态。

### flink背压的两种场景
1. 本地传输
![](https://img-blog.csdn.net/20171122094753097?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvbGlndW9odWFCaWdkYXRh/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)
   - 如果task1和task2都运行在同一个工作节点（TaskManager），缓冲区可以被直接共享给下一个task，一旦task2消费了数据它会被回收。如果task2比task1慢，buffer会以比task 1填充的速度更慢的速度进行回收从而迫使task1降速。
2. 网络传输
![](https://img-blog.csdn.net/20171122094859666?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvbGlndW9odWFCaWdkYXRh/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)
  - 如果task 1和task 2运行在不同的工作节点上。一旦缓冲区内的数据被发送出去(TCP Channel)，它就会被回收。在接收端，数据被拷贝到输入缓冲池的缓冲区中，如果没有缓冲区可用，从TCP连接中的数据读取动作将会被中断。输出端通常以watermark机制来保证不会有太多的数据在传输途中。如果有足够的数据已经进入可发送状态，会等到情况稳定到阈值以下才会进行发送。这可以保证没有太多的数据在路上。如果新的数据在消费端没有被消费（因为没有可用的缓冲区），这种情况会降低发送者发送数据的速度。

### 累加器和计数器
Flink 目前有如下内置累加器。它们每一个都实现了Accumulator接口。每个作业的所有累加器共享一个命名空间。 这样你就可以在作业的不同算子函数中使用相同的累加器。Flink 会在内部合并所有同名累加器。目前，累加器的结果只有在整个作业结束以后才可用.
- IntCounter, LongCounter 和 DoubleCounter
- Histogram: 离散数量桶的直方图实现。在内部，它只是一个从整数到整数的映射。你可以用它计算值的分布，例如一个词频统计程序中每行词频的分布。
```java
//定义累加器
private IntCounter numLines = new IntCounter();
//注册累加器对象，通常在富函数的 open() 方法中
getRuntimeContext().addAccumulator("num-lines", this.numLines);
//结果将存储在 JobExecutionResult 对象中，该对象是从执行环境的 execute() 方法返回的
myJobExecutionResult.getAccumulatorResult("num-lines");
```
