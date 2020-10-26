![Flink基石](https://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/images/sMDTgD.jpg)
![](https://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/images/p92UrK.jpg)


### 流计算与批计算比较
- 数据时效性不同:
  - 流式计算实时、低延迟。
  - 批处理非实时、高延迟。
- 数据特征不同:
  - 流式计算的数据一般是动态的、没有边界的。
  - 批处理的数据一般则是静态数据。
- 应用场景不同:
  - 流式计算应用在实时场景，时效性要求比较高的场景，如实时推荐、业务监控。
  - 批处理，应用在实时性要求不高、离线计算的场景下，数据分析、离线报表等。
- 运行方式不同:
  - 流式计算的任务持续进行的。
  - 批量计算的任务则一次性完成。
  
### 状态
![状态类型分类](https://s1.ax1x.com/2020/10/16/0HhBbF.md.png)

### Keyed State & Operator State
![](https://s1.ax1x.com/2020/10/16/0H4PGn.png)

### Keyed State 内部关系
![](https://s1.ax1x.com/2020/10/16/0H4Ki9.md.png)

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

### DataStream/DataSet API是Flink提供的核心API ，DataSet处理有界的数据集，DataStream处理有界或者无界的数据流。用户可以通过各种方法（map/flatmap/window/ keyby/sum/max/min/avg/join 等）将数据进行转换/计算。

### Table API是以表为中心的声明式DSL，其中表可能会动态变化（在表达流数据时）。Table API 提供了例如select、project、join、group-by、aggregate等操作，使用起来却更加简洁（代码量更少）。

### Source: 数据源，Flink在流处理和批处理上的source大概有 4 类：基于本地集合的source、基于文件的source、基于网络套接字的 source、自定义的source。自定义的 source 常见的有 Apache kafka、Amazon Kinesis Streams、RabbitMQ、Twitter Streaming API、Apache NiFi 等，当然你也可以定义自己的 source。

### Transformation：数据转换的各种操作，有Map/FlatMap/Filter/KeyBy/Reduce/Fold/Aggregations/Window/WindowAll/Union/Window join/Split/Select/Project等，操作很多，可以将数据转换计算成你想要的数据。

### Sink：接收器，Flink将转换计算后的数据发送的地点 ，你可能需要存储下来，Flink 常见的Sink大概有如下几类：写入文件、打印出来、写入 socket 、自定义的 sink 。自定义的 sink 常见的有Apache kafka、RabbitMQ、MySQL、ElasticSearch、Apache Cassandra、Hadoop FileSystem 等，同理你也可以定义自己的sink。

### Flink的程序内在是并行和分布式的，数据流可以被分区成 stream partitions，operators 被划分为operator subtasks; 这些 subtasks 在不同的机器或容器中分不同的线程独立运行；operator subtasks 的数量在具体的 operator 就是并行计算数，程序不同的 operator 阶段可能有不同的并行数；如下图所示，source operator 的并行数为 2，但最后的sink operator 为1
![](https://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/images/ggMHCK.jpg)

### Flink在JVM中提供了自己的内存管理，使其独立于Java的默认垃圾收集器。它通过使用散列、索引、缓存和排序有效地进行内存管理。

### Apache Flink自2017年12月发布的1.4.0版本开始，为流计算引入了一个重要的里程碑特性：TwoPhaseCommitSinkFunction（两阶段提交接收函数）它提取了两阶段提交协议的通用逻辑，使得通过Flink来构建端到端的Exactly-Once(就一次)程序成为可能。

### Flink已经提供了若干实现好了的Source Functions，当然你也可以通过实现SourceFunction来自定义非并行的Source或者实现ParallelSourceFunction接口或者扩展 RichParallelSourceFunction来自定义并行的Source

### readFile(fileInputFormat, path, watchType, interval, pathFilter, typeInfo)
- 它根据给定的 fileInputFormat 和读取路径读取文件。根据提供的 watchType，这个 source 可以定期（每隔 interval 毫秒）监测给定路径的新数据（FileProcessingMode.PROCESS_CONTINUOUSLY），或者处理一次路径对应文件的数据并退出（FileProcessingMode.PROCESS_ONCE）。你可以通过 pathFilter 进一步排除掉需要处理的文件。
- 在具体实现上，Flink 把文件读取过程分为两个子任务，即目录监控和数据读取。每个子任务都由单独的实体实现。目录监控由单个非并行（并行度为1）的任务执行，而数据读取由并行运行的多个任务执行。后者的并行性等于作业的并行性。单个目录监控任务的作用是扫描目录（根据 watchType 定期扫描或仅扫描一次），查找要处理的文件并把文件分割成切分片（splits），然后将这些切分片分配给下游 reader。reader 负责读取数据。每个切分片只能由一个 reader 读取，但一个 reader 可以逐个读取多个切分片。
$\color{red}{注意:如果 watchType 设置为 FileProcessingMode.PROCESS_CONTINUOUSLY，则当文件被修改时，其内容将被重新处理。这会打破“exactly-once”语义，因为在文件末尾附加数据将导致其所有内容被重新处理。如果 watchType 设置为 FileProcessingMode.PROCESS_ONCE，则 source 仅扫描路径一次然后退出，而不等待 reader 完成文件内容的读取。当然 reader 会继续阅读，直到读取所有的文件内容。关闭 source 后就不会再有检查点。这可能导致节点故障后的恢复速度较慢，因为该作业将从最后一个检查点恢复读取。}$


### RichSourceFunction
- MessageAcknowledgingSourceBase:它针对的是数据源是消息队列的场景并且提供了基于 ID 的应答机制。
- MultipleIdsMessageAcknowledgingSourceBase:在 MessageAcknowledgingSourceBase 的基础上针对 ID 应答机制进行了更为细分的处理，支持两种 ID 应答模型：session id和unique message id。
- ContinuousFileMonitoringFunction:这是单个（非并行）监视任务，它接受 FileInputFormat，并且根据 FileProcessingMode 和 FilePathFilter，它负责监视用户提供的路径；决定应该进一步读取和处理哪些文件；创建与这些文件对应的 FileInputSplit 拆分，将它们分配给下游任务以进行进一步处理。

### Flink Data的常用转换方式：Map、FlatMap、Filter、KeyBy、Reduce、Fold、Aggregations、Window、WindowAll、Union、Window Join、Split、Select、Project

--- 

### Window就是用来对一个无限的流设置一个有限的集合，在有界的数据集上进行操作的一种机制。window 又可以分为基于时间（Time-based）的window以及基于数量（Count-based）的window,Flink DataStream API提供了Time和Count的window，同时增加了基于Session的window。同时由于某些特殊的需要，DataStream API也提供了定制化的window操作，供用户自定义window

### Time Windows: 如果时间窗口设置的为100,将计算100单位时间内的数据

### 无重叠数据的时间窗口 tumbling time window 
```java
timeWindowAll(Time.seconds(5))
```

### 有重叠数据的时间窗口 slidings time window
```java
timeWindowAll(Time.seconds(5), Time.seconds(3))
```

### Count Windows: 如果计数窗口设置的为100 ，那么将会在窗口中收集100个事件，并在添加第100个元素时计算窗口的值。

### 无重叠数据的统计窗口 tumbling count window
```java
countWindowAll(100) //统计每100个元素的数量之和
```

### 有重叠数据的统计窗口 sliding count window
```java
countWindowAll(100, 10) //每10个元素统计过去100个元素的数量之和
```

### Window Assigner:负责将元素分配到不同的 window,Window API提供了自定义的WindowAssigner接口，我们可以实现WindowAssigner的方法。对于基于Count的window而言，默认采用了GlobalWindow的window assigner,例如：
```java
windowAll(GlobalWindows.create())
```

### 会话窗口(Session Window)
![](https://s1.ax1x.com/2020/10/26/BnDikD.md.png)
用户的行为有时是一连串的，形成的数据流也是一连串的,我们把每一串称为一个session，不同的用户的session划分结果是不一样的。我们把这种window称作SessionWindow
```java
//event time
EventTimeSessionWindows.withGap(Time.minutes(10))
//process time
ProcessingTimeSessionWindows.withGap(Time.minutes(10))
```

### 会话窗口gap
![](https://s1.ax1x.com/2020/10/26/BnD1hQ.png)
Session window中的Gap是一个非常重要的概念，它指的是session之间的间隔。如果session之间的间隔大于指定的间隔，数据将会被划分到不同的session中。比如设定5秒的间隔，0-5属于一个session，5-10属于另一个session

### 全局窗口(Global Windows)
![](https://img-blog.csdn.net/20171122093233985?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvbGlndW9odWFCaWdkYXRh/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)
该窗口仅在有一个自定义trigger时才有用。否则由于global window没有触发条件，永远不会发生计算任务。
```
GlobalWindows.create()
```

### 翻滚窗口(Tumbling Windows)
![](https://img-blog.csdn.net/20171122093333779?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvbGlndW9odWFCaWdkYXRh/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)
如果我们用原来的tumbling-window对stream进行窗口划分，也就是用统一的时间去划分window，会发现，用户的连续行为划分的不自然。因为有多个用户，你只用一共时间去划分，这种划分方法会造成本来一连串的操作被划分到不同的window中去了,如果定义window size为5分钟，window function每次调用都会得到5分钟的统计信息。
```java
//event time
TumblingEventTimeWindows.of(Time.seconds(5))
//process time
TumblingProcessingTimeWindows.of(Time.seconds(5))
```

### 滑动窗口（Sliding Windows）
![](https://img-blog.csdn.net/20171122093403811?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvbGlndW9odWFCaWdkYXRh/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)
滑动窗口的数据是有重叠的
```java
//event time
SlidingEventTimeWindows.of(Time.seconds(10), Time.seconds(5))
//process time
SlidingProcessingTimeWindows.of(Time.seconds(10), Time.seconds(5))
```

###   数据是否重叠或遗漏
 - 如果size = interval,那么就会形成tumbling-window(无重叠数据)
 - 如果size > interval,那么就会形成sliding-window(有重叠数据)
 - 如果size < interval,那么这种窗口将会丢失数据。比如每5秒钟，统计过去3秒的通过路口汽车的数据，将会漏掉2秒钟的数据。

---

# Apache Flink 具有三个不同的时间概念，即处理时间(processing time), 事件时间(event time)和进入时间(ingestion time)
![](https://note.youdao.com/yws/public/resource/5493c5d21690866a5e247cc21655ae14/xmlnote/EB1962BA1C60479C97CDF726DDFA5CE2/109725)

- 处理时间(processing time)：处理时间是指执行相应操作的机器的系统时间。当流处理程序基于处理时间运行时，所有基于时间的操作（如时间窗口）将使用运行相应运算符的机器的系统时钟。 每小时处理时间窗口将包括在系统时钟指示整个小时之间到达特定运算符的所有记录。 例如，如果应用程序在上午9:15开始运行，则第一个每小时处理时间窗口将包括在上午9:15到10:00之间处理的事件，下一个窗口将包括在上午10:00到11:00之间处理的事件，以此类推。 处理时间是最简单的时间概念，不需要流和机器之间的协调。 它提供最佳性能和最低延迟。 但是，在分布式和异步环境中，处理时间不提供确定性，因为它容易受到记录到达系统的速度（例如从消息队列），记录在系统内的运算符之间流动的速度的影响，以及停电（计划或其他）。以实际的operator的systemTime为标准

- 事件时间(event time)：事件时间是每个事件在其生产设备上发生的时间。此时间通常在进入Flink之前嵌入记录中，并且可以从每个记录中提取该事件时间戳。 在事件时间，时间的进展取决于数据，而不是任何时钟。 事件时间程序必须指定如何生成事件时间水印，这是表示事件时间进度的机制。 消息本身就应该携带EventTime

- 进入时间(Ingestion time): 进入时间是事件进入Flink的时间。 在源运算符处，每个记录将源的当前时间作为时间戳，并且基于时间的操作（如时间窗口）引用该时间戳。进入时间在概念上位于事件时间和处理时间之间。与处理时间相比，它代价稍高，但可以提供更可预测的结果。 因为进入时间使用稳定的时间戳（在源处分配一次），所以对记录的不同窗口操作将引用相同的时间戳，而在处理时间中，每个窗口操作符可以将记录分配给不同的窗口（基于本地系统时钟和 任何传输延误）。与事件时间相比，进入时间程序无法处理任何无序事件或延迟数据，但程序不必指定如何生成水印。在内部，摄取时间与事件时间非常相似，但具有自动分配时间戳和自动生成水印功能。以source的systemTime为准

---

### Trigger:即触发器，定义何时或什么情况下移除window,我们可以指定触发器来覆盖WindowAssigner提供的默认触发器。请注意指定的触发器不会添加其他触发条件，但会替换当前触发器。

### Evictor(可选):驱逐者，即保留上一window留下的某些元素

### 通过apply WindowFunction来返回DataStream类型数据,利用Flink的内部窗口机制和DataStream API可以实现自定义的窗口逻辑例如session window。

# Parallelism和Slot
- slot是静态的概念，是指taskmanager具有的并发执行能力,parallelism是动态的概念，是指程序运行时实际使用的并发能力

### Task Manager是从Job Manager处接收需要部署的Task，任务的并行性由每个Task Manager上可用的slot决定。每个任务代表分配给任务槽的一组资源，slot在Flink里面可以认为是资源组，Flink将每个任务分成子任务并且将这些子任务分配到slot来并行执行程序,如果Task Manager有四个slot，那么它将为每个slot分配25％ 的内存。 可以在一个 slot 中运行一个或多个线程。 同一slot中的线程共享相同的JVM。 同一JVM中的任务共享TCP 连接和心跳消息。Task Manager的一个Slot代表一个可用线程，该线程具有固定的内存，注意 Slot只对内存隔离，没有对CPU隔离。默认情况下，Flink允许子任务共享Slot，即使它们是不同task的subtask，只要它们来自相同的job。这种共享可以有更好的资源利用率,有两个Task Manager，每个Task Manager有三个slot，这样我们的算子最大并行度那么就可以达到6个，在同一个slot里面可以执行1至多个子任务。
- parallelism = Task Manager * num * slot

### RabbitMQ-Connector，RMQSource类去消费RabbitMQ Queue中的消息和确认checkpoints上的消息，它提供了三种不一样的保证：
- Exactly-once(只消费一次): 前提条件有，1是要开启 checkpoint，因为只有在checkpoint完成后，才会返回确认消息给RabbitMQ（这时消息才会在RabbitMQ队列中删除)；2 是要使用Correlation ID，在将消息发往RabbitMQ时，必须在消息属性中设置Correlation ID。数据源根据Correlation ID把从checkpoint恢复的数据进行去重；3是数据源不能并行，这种限制主要是由于RabbitMQ将消息从单个队列分派给多个消费者。
- At-least-once(至少消费一次): 开启了checkpoint，但未使用相Correlation ID或数据源是并行的时候，那么就只能保证数据至少消费一次了
- No guarantees(无法保证): Flink接收到数据就返回确认消息给RabbitMQ

### Flink WebUI上传的jar存储位置:
- 通过web.upload.dir配置
- 默认使用临时目录(web.tmpdir= java.io.tmpdir + “flink-web-” + UUID 组成的)

### 如果你需要将大量变量传递给函数，那么这些方法就会变得非常烦人了。 为了解决这个问题，Flink 提供了 withParameters 方法。 要使用它，你需要实现那些 Rich 函数，比如你不必实现 MapFunction 接口，而是实现 RichMapFunction。Rich 函数允许你使用 withParameters 方法传递许多参数：
```java
// Configuration 类来存储参数
Configuration configuration = new Configuration();
configuration.setString("genre", "Action");

lines.filter(new FilterGenreWithParameters())
        // 将参数传递给函数
        .withParameters(configuration)
        .print();
// FilterGenreWithParameters
class FilterGenreWithParameters extends RichFilterFunction<Row> {

    String genre;

    @Override
    public void open(Configuration parameters) throws Exception {
        //读取配置
        genre = parameters.getString("genre", "");
    }

    @Override
    public boolean filter(Row row) throws Exception {
        String[] genres = row.getField(1).split("\\|");

        return Stream.of(genres).anyMatch(g -> g.equals(genre));
    }
}

```

### 如果需要为多个函数设置相同的参数，则可能会很繁琐。在 Flink 中要处理此种情况， 你可以设置所有 TaskManager 都可以访问的全局环境变量,为此首先需要使用 ParameterTool.fromArgs 从命令行读取参数：
```java
//读取命令行参数
ParameterTool parameterTool = ParameterTool.fromArgs(args);
// 然后使用 setGlobalJobParameters 设置全局作业参数:
final ExecutionEnvironment env = ExecutionEnvironment.getExecutionEnvironment();
env.getConfig().setGlobalJobParameters(parameterTool);

//该函数将能够读取这些全局参数
lines.filter(new FilterGenreWithGlobalEnv()) //这个函数是自己定义的
                .print();

 class FilterGenreWithGlobalEnv extends RichFilterFunction<Row> {

    @Override
    public boolean filter(Row row) throws Exception {
        String[] genres = row.getField(1).split("\\|");
        //获取全局的配置
        ParameterTool parameterTool = (ParameterTool) getRuntimeContext().getExecutionConfig().getGlobalJobParameters();
        //读取配置
        String genre = parameterTool.get("genre");
        return Stream.of(genres).anyMatch(g -> g.equals(genre));
    }
}               
```


# 广播与分布式缓存

### 如果想将数据从客户端发送到TaskManager，如果数据以数据集的形式存在于TaskManager中该怎么办？在这种情况下，最好使用Flink中的另一个功能——广播变量。它只允许将数据集发送给那些执行你Job里面函数的任务管理器。
```java
 dataStreamSource.map().broadcast()

 ParameterTool.fromArgs("")
```

### 如果要向每个 TaskManager 发送更多数据并且不希望将这些数据存储在内存中，可以使用 Flink 的分布式缓存向 TaskManager 发送静态文件。 要使用 Flink 的分布式缓存，你首先需要将文件存储在一个分布式文件系统（如 HDFS）中，然后在缓存中注册该文件：
```java
 env.registerCachedFile();
```

---

### Flink 中不支持连续的Split/Select 分流操作，要实现连续分流也可以通过其他的方式（split + filter或者side output）来实现

### 使用 side output连续分流
```java
//要使用 Side Output 的话，你首先需要做的是定义一个 OutputTag 来标识 Side Output，代表这个 Tag 是要收集哪种类型的数据，如果是要收集多种不一样类型的数据，那么你就需要定义多种 OutputTag
private static final OutputTag<AlertEvent> middleware = new OutputTag<AlertEvent>("MIDDLEWARE") {};
private static final OutputTag<AlertEvent> machine = new OutputTag<AlertEvent>("MACHINE") {};
private static final OutputTag<AlertEvent> docker = new OutputTag<AlertEvent>("DOCKER") {};
//然后呢，你可以使用下面几种函数来处理数据，在处理数据的过程中，进行判断将不同种类型的数据存到不同的OutputTag中去。
//ProcessFunction/KeyedProcessFunction/CoProcessFunction/ProcessWindowFunction/ProcessAllWindowFunction

//dataStream 是总的数据流
SingleOutputStreamOperator<AlertEvent, AlertEvent> outputStream = dataStream.process(new ProcessFunction<AlertEvent, AlertEvent>() {
    @Override
    public void processElement(AlertEvent value, Context ctx, Collector<AlertEvent> out) throws Exception {
        if ("MACHINE".equals(value.type)) {
            ctx.output(machine, value);
        } else if ("DOCKER".equals(value.type)) {
            ctx.output(docker, value);
        } else if ("MIDDLEWARE".equals(value.type)) {
            ctx.output(middleware, value);
        } else {
            //其他的业务逻辑
            out.collect(value);
        }
    }
})

//上面我们已经将不同类型的数据进行放到不同的OutputTag里面了，可以使用getSideOutput方法来获取不同OutputTag的数据，比如：

//机器相关的告警&恢复数据
outputStream.getSideOutput(machine).print();
//容器相关的告警&恢复数据
outputStream.getSideOutput(docker).print();
//中间件相关的告警&恢复数据
outputStream.getSideOutput(middleware).print();

```

---

### Keyed States
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093014.jpg)
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-092959.jpg)
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093029.jpg)

### Operator State
!{}(http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093055.jpg)
![](http://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/img/2019-07-07-093120.jpg)

### Operator States的动态扩展是非常灵活的，现提供了3种扩展，下面分别介绍：
- ListState:并发度在改变的时候，会将并发上的每个List都取出，然后把这些List合并到一个新的List,然后根据元素的个数在均匀分配给新的Task;
- UnionListState:相比于ListState更加灵活，把划分的方式交给用户去做，当改变并发的时候，会将原来的List拼接起来。然后不做划分，直接交给用户；
- BroadcastState:如大表和小表做Join时，小表可以直接广播给大表的分区，在每个并发上的数据都是完全一致的。做的更新也相同，当改变并发的时候，把这些数据COPY到新的Task即可；

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

