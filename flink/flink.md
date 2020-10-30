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
