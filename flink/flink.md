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


### Table API是以表为中心的声明式DSL，其中表可能会动态变化（在表达流数据时）。Table API 提供了例如select、project、join、group-by、aggregate等操作，使用起来却更加简洁（代码量更少）。

### Source: 数据源，Flink在流处理和批处理上的source大概有 4 类：基于本地集合的source、基于文件的source、基于网络套接字的 source、自定义的source。自定义的 source 常见的有 Apache kafka、Amazon Kinesis Streams、RabbitMQ、Twitter Streaming API、Apache NiFi 等，当然你也可以定义自己的 source。

### Transformation：数据转换的各种操作，有Map/FlatMap/Filter/KeyBy/Reduce/Fold/Aggregations/Window/WindowAll/Union/Window join/Split/Select/Project等，操作很多，可以将数据转换计算成你想要的数据。
- Keyby 不能为key的清空：pojo需要重写hashcode/数组


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

### 数据是否重叠或遗漏
 - 如果size = interval,那么就会形成tumbling-window(无重叠数据)
 - 如果size > interval,那么就会形成sliding-window(有重叠数据)
 - 如果size < interval,那么这种窗口将会丢失数据。比如每5秒钟，统计过去3秒的通过路口汽车的数据，将会漏掉2秒钟的数据。

### Window与WindowAll的区别:
 - Window在已经分区的KeyedStreams上定义,WindowAll在DataStreams上定义
 - WindowAll将所有流事件分组,这是非并行转换。所有记录将被收集在windowAll运算符的一项任务中


# Join
### Window Join :Window Join 的一个局限是关联的两个数据流必须在同样的时间窗口中
![](https://img-blog.csdnimg.cn/20200609192608156.png)
- Tumbling（滚动） Window Join：这就像一个内链接，在滚动窗口中没有来自另一个流的元素的流的元素不会被输出
- Sliding（滑动） Window Join：窗口直接可以重合
- Session（会话） Window Join: 在执行会话窗口连接时，具有相同键的所有元素(当“组合”时满足会话条件)都以成对的组合进行连接，并传递给JoinFunction或FlatJoinFunction。再次执行内部连接，因此如果会话窗口只包含来自一个流的元素，则不会发出任何输出!
### Interval Join
在流与流的join中，与window join相比，window中的关联通常是两个流中对应的window中的消息可以发生关联，不能跨window，Interval Join则没有window的概念，直接用时间戳作为关联的条件，更具表达力。
```
1. 等值条件如 a.id = b.id
2. 时间戳范围条件 ： a.timestamp ∈ [b.timestamp + lowerBound; b.timestamp + upperBound]  b.timestamp + lowerBound <= a.timestamp and a.timestamp <= b.timestamp + upperBound
```
---

# Apache Flink 具有三个不同的时间概念，即处理时间(processing time), 事件时间(event time)和进入时间(ingestion time)
![](https://note.youdao.com/yws/public/resource/5493c5d21690866a5e247cc21655ae14/xmlnote/EB1962BA1C60479C97CDF726DDFA5CE2/109725)

### 处理时间(processing time)：处理时间是指执行相应操作的机器的系统时间。当流处理程序基于处理时间运行时，所有基于时间的操作（如时间窗口）将使用运行相应运算符的机器的系统时钟。 每小时处理时间窗口将包括在系统时钟指示整个小时之间到达特定运算符的所有记录。 例如，如果应用程序在上午9:15开始运行，则第一个每小时处理时间窗口将包括在上午9:15到10:00之间处理的事件，下一个窗口将包括在上午10:00到11:00之间处理的事件，以此类推。 处理时间是最简单的时间概念，不需要流和机器之间的协调。 它提供最佳性能和最低延迟。 但是，在分布式和异步环境中，处理时间不提供确定性，因为它容易受到记录到达系统的速度（例如从消息队列），记录在系统内的运算符之间流动的速度的影响，以及停电（计划或其他）。以实际的operator的systemTime为标准，默认情况下，Flink将使用处理时间。基于时间的窗口分配器（包括会话窗口）具有事件时间和处理时间两种风格。这两种类型的时间窗口之间存在重大折衷。使用处理时间窗，您必须接受以下限制：
  - 无法正确处理历史数据
  - 无法正确处理乱序数据
  - 结果将是不确定的
  - 但具有较低延迟的优势。

### 事件时间(event time)：事件时间是每个事件在其生产设备上发生的时间。此时间通常在进入Flink之前嵌入记录中，并且可以从每个记录中提取该事件时间戳。 在事件时间，时间的进展取决于数据，而不是任何时钟。 事件时间程序必须指定如何生成事件时间水印，这是表示事件时间进度的机制。 消息本身就应该携带EventTime
  - 默认情况下，使用事件时间窗口时将删除较晚的事件。窗口API的两个可选部分使您可以对此进行更多控制。可以使用称为Side Outputs的机制安排将要删除的事件收集到备用输出流中
```java
OutputTag<Event> lateTag = new OutputTag<Event>("late"){};
SingleOutputStreamOperator<Event> result = stream.
    .keyBy(...)
    .window(...)
    .sideOutputLateData(lateTag)
    .process(...);
DataStream<Event> lateStream = result.getSideOutput(lateTag);
```
  - 还可以指定允许延迟的时间间隔，在此间隔内，延迟事件将继续分配给适当的窗口（其状态将被保留）。默认情况下，每个延迟事件都会导致再次调用window函数（有时称为延迟触发）。默认情况下，允许的延迟为0。换句话说，水印后面的元素将被删除（或发送到侧面输出）。
```java
stream.
    .keyBy(...)
    .window(...)
    .allowedLateness(Time.seconds(10))
    .process(...);
//当允许的延迟大于零时，只有那些太晚以至于将被丢弃的事件才被发送到侧面输出（如果已配置）。
```

### 进入时间(Ingestion time): 进入时间是事件进入Flink的时间。 在源运算符处，每个记录将源的当前时间作为时间戳，并且基于时间的操作（如时间窗口）引用该时间戳。进入时间在概念上位于事件时间和处理时间之间。与处理时间相比，它代价稍高，但可以提供更可预测的结果。 因为进入时间使用稳定的时间戳（在源处分配一次），所以对记录的不同窗口操作将引用相同的时间戳，而在处理时间中，每个窗口操作符可以将记录分配给不同的窗口（基于本地系统时钟和 任何传输延误）。与事件时间相比，进入时间程序无法处理任何无序事件或延迟数据，但程序不必指定如何生成水印。在内部，摄取时间与事件时间非常相似，但具有自动分配时间戳和自动生成水印功能。以source的systemTime为准

- 水印(Watermake):定义何时停止等待早期事件
```java
WatermarkStrategy<Event> strategy = WatermarkStrategy
        .<Event>forBoundedOutOfOrderness(Duration.ofSeconds(20))
        .withTimestampAssigner((event, timestamp) -> event.timestamp);
```
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

### 使用旁路输出(side output)连续分流
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














### 为了保证同一个task处理同一个key的所有数据，可以使用DataStream#keyBy对流进行分区。 process()函数对流绑定了一个操作，这个操作将会对流上的每一个消息调用所定义好的函数。通常，一个操作会紧跟着keyBy被调用，在这个例子中，这个操作是FraudDetector，该操作是在一个keyed context上执行的。
```java
DataStream<Alert> alerts = transactions
    .keyBy(Transaction::getAccountId)
    .process(new FraudDetector())
    .name("fraud-detector");
```

### ValueState是一个包装类，类似于Java标准库里边的AtomicReference和AtomicLong。 它提供了三个用于交互的方法。update用于更新状态，value用于获取状态值，还有 clear用于清空状态。 如果一个key还没有状态，例如当程序刚启动或者调用过ValueState#clear方法时，ValueState#value将会返回null。 如果需要更新状态，需要调用 ValueState#update方法，直接更改ValueState#value的返回值可能不会被系统识别。 容错处理将在Flink后台自动管理，你可以像与常规变量那样与状态变量进行交互。

### KeyedProcessFunction#processElement需要使用提供了定时器服务的Context来调用。 定时器服务可以用于查询当前时间、注册定时器和删除定时器。使用它，你可以在标记状态被设置时，也设置一个当前时间一分钟后触发的定时器，同时将触发时间保存到timerState状态中
```java
// set the flag to true
flagState.update(true);
// set the timer and timer state
long timer = context.timerService().currentProcessingTime() + ONE_MINUTE;
context.timerService().registerProcessingTimeTimer(timer);
timerState.update(timer);
```
### 当定时器触发时，将会调用 KeyedProcessFunction#onTimer 方法。 通过重写这个方法来实现一个你自己的重置状态的回调逻辑。
```java
@Override
public void onTimer(long timestamp, OnTimerContext ctx, Collector<Alert> out) {
    // remove flag after 1 minute
    timerState.clear();
    flagState.clear();
}
```
### 最后如果要取消定时器，你需要删除已经注册的定时器，并同时清空保存定时器的状态。 你可以把这些逻辑封装到一个助手函数中，而不是直接调用 flagState.clear()
```java
private void cleanUp(Context ctx) throws Exception {
    // delete timer
    Long timer = timerState.value();
    ctx.timerService().deleteProcessingTimeTimer(timer);

    // clean up all state
    timerState.clear();
    flagState.clear();
}
```

### MapFunction只适用于一对一的转换：对每个进入算子的流元素，map()将仅输出一个转换后的元素。

### FlatMapFunction 可以输出你想要的任意数量的元素，也可以一个都不发。

### AggregateFunction是一个基于中间计算结果状态进行增量计算的函数。由于是迭代计算方式，所以，在窗口处理过程中，不用缓存整个窗口的数据执行效率比较高。

### Window Function分为两类: 增量聚合和全量聚合
- 增量聚合: 窗口不维护原始数据，只维护中间结果，每次基于中间结果和增量数据进行聚合,如: ReduceFunction、AggregateFunction
- 全量聚合: 窗口需要维护全部原始数据，窗口触发进行全量聚合,如:ProcessWindowFunction、WindowFunction




# Keyed Streams

### keyBy()将一个流根据其中的一些属性来进行分区，这样我们可以使所有具有相同属性的事件分到相同的组里。按SQL查询的方式来考虑,相当于GROUP BY,每个keyBy会通过shuffle来为数据流进行重新分区。总体来说这个开销是很大的，它涉及网络通信、序列化和反序列化。KeySelector不仅限于从事件中抽取键。你也可以按想要的方式计算得到键值，只要最终结果是确定的，并且实现了 hashCode() 和 equals()。
```java
//这种选择键的方式有个缺点，就是编译器无法推断用作键的字段的类型，所以 Flink 会将键值作为元组传递，这有时候会比较难处理。所以最好还是使用一个合适的KeySelector
keyBy(value -> value.startCell)

keyBy(new KeySelector<EnrichedRide,int>(){
        @Override
        public int getKey(EnrichedRide enrichedRide) throws Exception {
                return enrichedRide.startCell;
            }
        })
//也可以使用更简洁的lambda表达式：
keyBy(enrichedRide -> enrichedRide.startCell)
//使用Tuple2对象的例子中，用字段在元组中的序号（从0开始）来指定键。
keyBy(value -> value.f0)
```

### reduce聚合:maxBy()只是Flink中KeyedStream上众多聚合函数中的一个。还有一个更通用的reduce()函数可以用来实现你的自定义聚合。

### Flink状态管理
- 本地性: Flink状态是存储在使用它的机器本地的，并且可以以内存访问速度来获取
- 持久性: Flink状态是容错的，例如，它可以自动按一定的时间间隔产生checkpoint，并且在任务失败后进行恢复
- 纵向可扩展性: Flink状态可以存储在集成的RocksDB实例中，这种方式下可以通过增加本地磁盘来扩展空间
- 横向可扩展性: Flink状态可以随着集群的扩缩容重新分布
- 可查询性: Flink状态可以通过使用状态查询API从外部进行查询。

### 对其中的每一个接口，Flink同样提供了一个所谓“rich”的变体，继承AbstractRichFunction的类（RichFlatMapFunction/RichMapFunction）
- open(Configuration c):仅在算子初始化时调用一次。可以用来加载一些静态数据，或者建立外部服务的链接等。
- close()
- getRuntimeContext():为整套潜在有趣的东西提供了一个访问途径，最明显的，它是你创建和访问Flink状态的途径。
  
### ValueState:对于每个键,Flink将存储一个单一的对象,open()方法通过定义ValueStateDescriptor<Boolean>建立了管理状态的使用。构造器的参数定义了这个状态的名字，并且为如何序列化这些对象提供了信息,Flink提供了为RocksDB优化的MapState和ListState类型。 相对于ValueState，更建议使用MapState和ListState，因为使用 RocksDBStateBackend的情况下，MapState 和 ListState 比 ValueState 性能更好。 RocksDBStateBackend可以附加到ListState，而无需进行（反）序列化，对于 MapState，每个key/value都是一个单独的 RocksDB 对象，因此可以有效地访问和更新MapState。

  ```java
//有一个要去重的事件数据流，对每个键只保留第一个事件
new RichFlatMapFunction<Event, Event> {
    ValueState<Boolean> keyHasBeenSeen;
    @Override
    public void open(Configuration conf) {
        ValueStateDescriptor<Boolean> desc = new ValueStateDescriptor<>("keyHasBeenSeen", Types.BOOLEAN);
        keyHasBeenSeen = getRuntimeContext().getState(desc);
    }

    @Override
    public void flatMap(Event event, Collector<Event> out) throws Exception {
        if (keyHasBeenSeen.value() == null) {
            out.collect(event);
            keyHasBeenSeen.update(true);
        }
    }
}
  ```

### RichCoFlatMapFunction是一种可以被用于一对连接流的FlatMapFunction，并且它可以调用rich function的接口。这意味着它可以是有状态的。
```java
DataStream<String> control = env.fromElements("DROP", "IGNORE").keyBy(x -> x);
DataStream<String> streamOfWords = env.fromElements("Apache", "DROP", "Flink", "IGNORE").keyBy(x -> x);
control.connect(streamOfWords)
       .flatMap(new RichCoFlatMapFunction<String, String, String>() {
                    private ValueState<Boolean> blocked;

                    @Override
                    public void close() throws Exception {
                        super.close();
                        System.out.println("close");
                    }

                    @Override
                    public void open(Configuration config) {
                        blocked = getRuntimeContext().getState(new ValueStateDescriptor<>("blocked", Boolean.class));
                        System.out.println("open");
                    }

                    @Override
                    public void flatMap1(String control_value, Collector<String> collector) throws Exception {
                        blocked.update(Boolean.TRUE);
                        System.out.println("flatMap1");
                    }

                    @Override
                    public void flatMap2(String data_value, Collector<String> collector) throws Exception {
                        System.out.println("flatMap2-1");
                        if (blocked.value() == null) {
                            collector.collect(data_value);
                            System.out.println("flatMap2-2");
                        }
                    }
        }).print();

//control流中的元素会进入flatMap1，streamOfWords中的元素会进入flatMap2。这是由两个流连接的顺序决定的
```
$\color{red}{在RichCoFlatMapFunction实现类中，flatMap1和flatMap2的调用顺序是无法控制的,可以使用自定义的算子实现InputSelectable接口，在两输入算子消费它的输入流时增加一些顺序上的限制。}$

### 在1分钟的事件时间窗口内从每个传感器中找到峰值，并生成包含的元组流(key, end-of-window-timestamp, max_value)。
```java
input
    .keyBy(x -> x.key)
    .window(TumblingEventTimeWindows.of(Time.minutes(1)))
    .process(new MyWastefulMax());

public static class MyWastefulMax extends ProcessWindowFunction<
        SensorReading,                  // input type
        Tuple3<String, Long, Integer>,  // output type
        String,                         // key type
        TimeWindow> {                   // window type
    @Override
    public void process(
            String key,
            Context context, 
            Iterable<SensorReading> events,
            Collector<Tuple3<String, Long, Integer>> out) {
        int max = 0;
        for (SensorReading event : events) {
            max = Math.max(event.value, max);
        }
        out.collect(Tuple3.of(key, context.window().getEnd(), max));
    }
}
//context 对象中的 windowState和 globalState是可以存储该键的所有窗口的每个键，每个窗口或全局每个键信息的地方。例如，如果您想记录有关当前窗口的内容并在处理后续窗口时使用它，这可能会很有用。

```

### ProcessFunction将事件处理与Timer，State结合在一起，使其成为流处理应用的强大构建模块。 这是使用Flink创建事件驱动应用程序的基础。它和RichFlatMapFunction十分相似， 但是增加了Timer。ProcessFunction不仅包括KeyedProcessFunction，还包括CoProcessFunction、BroadcastProcessFunction等.
```java
// 使用 KeyedProcessFunction计算每个司机每小时的小费总和
DataStream<Tuple3<Long, Long, Float>> hourlyTips = fares
        .keyBy((TaxiFare fare) -> fare.driverId)
        .process(new PseudoWindow(Time.hours(1)));

// 在时长跨度为一小时的窗口中计算每个司机的小费总和。
// 司机ID作为 key。
public static class PseudoWindow extends 
        KeyedProcessFunction<Long, TaxiFare, Tuple3<Long, Long, Float>> {

    private final long durationMsec;

    // 每个窗口都持有托管的 Keyed state 的入口，并且根据窗口的结束时间执行 keyed 策略。
    // 每个司机都有一个单独的MapState对象。
    private transient MapState<Long, Float> sumOfTips;

    public PseudoWindow(Time duration) {
        this.durationMsec = duration.toMilliseconds();
    }

    @Override
    // 在初始化期间调用一次。
    public void open(Configuration conf) {
        MapStateDescriptor<Long, Float> sumDesc = new MapStateDescriptor<>("sumOfTips", Long.class, Float.class);
        sumOfTips = getRuntimeContext().getMapState(sumDesc);
    }

    @Override
    // 每个票价事件（TaxiFare-Event）输入（到达）时调用，以处理输入的票价事件。
    public void processElement(
            TaxiFare fare,
            Context ctx,
            Collector<Tuple3<Long, Long, Float>> out) throws Exception {
        long eventTime = fare.getEventTime();
        TimerService timerService = ctx.timerService();
        if (eventTime <= timerService.currentWatermark()) {
            // 事件延迟；其对应的窗口已经触发。
        } else {
            // 将 eventTime 向上取值并将结果赋值到包含当前事件的窗口的末尾时间点。
            long endOfWindow = (eventTime - (eventTime % durationMsec) + durationMsec - 1);
            // 在窗口完成时将启用回调
            timerService.registerEventTimeTimer(endOfWindow);
            // 将此票价的小费添加到该窗口的总计中。
            Float sum = sumOfTips.get(endOfWindow);
            if (sum == null) {
                sum = 0.0F;
            }
            sum += fare.tip;
            sumOfTips.put(endOfWindow, sum);
        }
    }
    //当计时器触发时调用 onTimer。它们可以是基于事件时间（event time）的 timer，也可以是基于处理时间（processing time）的 timer。
    @Override
    // 当当前水印（watermark）表明窗口现在需要完成的时候调用。
    public void onTimer(long timestamp, 
            OnTimerContext context, 
            Collector<Tuple3<Long, Long, Float>> out) throws Exception {
         long driverId = context.getCurrentKey();
        // 查找刚结束的一小时结果。
        Float sumOfTips = this.sumOfTips.get(timestamp);
        Tuple3<Long, Long, Float> result = Tuple3.of(driverId, timestamp, sumOfTips);
        out.collect(result);
        this.sumOfTips.remove(timestamp);
    }
}

```
