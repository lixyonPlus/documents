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

---

### DataStream/DataSet API是Flink提供的核心API ，DataSet处理有界的数据集，DataStream处理有界或者无界的数据流。用户可以通过各种方法（map/flatmap/window/ keyby/sum/max/min/avg/join 等）将数据进行转换/计算。

### Table API是以表为中心的声明式DSL，其中表可能会动态变化（在表达流数据时）。Table API 提供了例如select、project、join、group-by、aggregate等操作，使用起来却更加简洁（代码量更少）。

### Source: 数据源，Flink在流处理和批处理上的source大概有 4 类：基于本地集合的source、基于文件的source、基于网络套接字的 source、自定义的source。自定义的 source 常见的有 Apache kafka、Amazon Kinesis Streams、RabbitMQ、Twitter Streaming API、Apache NiFi 等，当然你也可以定义自己的 source。

### Transformation：数据转换的各种操作，有Map/FlatMap/Filter/KeyBy/Reduce/Fold/Aggregations/Window/WindowAll/Union/Window join/Split/Select/Project等，操作很多，可以将数据转换计算成你想要的数据。

### Sink：接收器，Flink 将转换计算后的数据发送的地点 ，你可能需要存储下来，Flink 常见的Sink大概有如下几类：写入文件、打印出来、写入 socket 、自定义的 sink 。自定义的 sink 常见的有Apache kafka、RabbitMQ、MySQL、ElasticSearch、Apache Cassandra、Hadoop FileSystem 等，同理你也可以定义自己的sink。

### Flink 的程序内在是并行和分布式的，数据流可以被分区成 stream partitions，operators 被划分为operator subtasks; 这些 subtasks 在不同的机器或容器中分不同的线程独立运行；operator subtasks 的数量在具体的 operator 就是并行计算数，程序不同的 operator 阶段可能有不同的并行数；如下图所示，source operator 的并行数为 2，但最后的 sink operator 为1
![](https://zhisheng-blog.oss-cn-hangzhou.aliyuncs.com/images/ggMHCK.jpg)

### Flink在JVM中提供了自己的内存管理，使其独立于Java的默认垃圾收集器。它通过使用散列、索引、缓存和排序有效地进行内存管理。

### Flink已经提供了若干实现好了的Source Functions，当然你也可以通过实现SourceFunction来自定义非并行的Source或者实现ParallelSourceFunction接口或者扩展 RichParallelSourceFunction来自定义并行的Source

### readFile(fileInputFormat, path, watchType, interval, pathFilter, typeInfo)
- 它根据给定的 fileInputFormat 和读取路径读取文件。根据提供的 watchType，这个 source 可以定期（每隔 interval 毫秒）监测给定路径的新数据（FileProcessingMode.PROCESS_CONTINUOUSLY），或者处理一次路径对应文件的数据并退出（FileProcessingMode.PROCESS_ONCE）。你可以通过 pathFilter 进一步排除掉需要处理的文件。
- 在具体实现上，Flink 把文件读取过程分为两个子任务，即目录监控和数据读取。每个子任务都由单独的实体实现。目录监控由单个非并行（并行度为1）的任务执行，而数据读取由并行运行的多个任务执行。后者的并行性等于作业的并行性。单个目录监控任务的作用是扫描目录（根据 watchType 定期扫描或仅扫描一次），查找要处理的文件并把文件分割成切分片（splits），然后将这些切分片分配给下游 reader。reader 负责读取数据。每个切分片只能由一个 reader 读取，但一个 reader 可以逐个读取多个切分片。
$\color{red}{注意:如果 watchType 设置为 FileProcessingMode.PROCESS_CONTINUOUSLY，则当文件被修改时，其内容将被重新处理。这会打破“exactly-once”语义，因为在文件末尾附加数据将导致其所有内容被重新处理。如果 watchType 设置为 FileProcessingMode.PROCESS_ONCE，则 source 仅扫描路径一次然后退出，而不等待 reader 完成文件内容的读取。当然 reader 会继续阅读，直到读取所有的文件内容。关闭 source 后就不会再有检查点。这可能导致节点故障后的恢复速度较慢，因为该作业将从最后一个检查点恢复读取。}$


### RichSourceFunction
- MessageAcknowledgingSourceBase:它针对的是数据源是消息队列的场景并且提供了基于 ID 的应答机制。
- MultipleIdsMessageAcknowledgingSourceBase:在 MessageAcknowledgingSourceBase 的基础上针对 ID 应答机制进行了更为细分的处理，支持两种 ID 应答模型：session id和unique message id。
- ContinuousFileMonitoringFunction:这是单个（非并行）监视任务，它接受 FileInputFormat，并且根据 FileProcessingMode 和 FilePathFilter，它负责监视用户提供的路径；决定应该进一步读取和处理哪些文件；创建与这些文件对应的 FileInputSplit 拆分，将它们分配给下游任务以进行进一步处理。

