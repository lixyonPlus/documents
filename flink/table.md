### 临时表（Temporary Table）和永久表（Permanent Table）
表可以是临时的，并与单个Flink会话（session）的生命周期关联，也可以是永久的，并且在多个Flink会话和群集（cluster）中可见。
- 永久表需要catalog（例如 Hive Metastore）以维护表的元数据。一旦永久表被创建，它将对任何连接到catalog的Flink会话可见且持续存在，直至被明确删除。
- 临时表通常保存于内存中并且仅在创建它们的Flink会话持续期间存在。这些表对于其它会话是不可见的。它们不与任何catalog或者数据库绑定但可以在一个命名空间（namespace）中创建。即使它们对应的数据库被删除，临时表也不会被删除。

### 屏蔽（Shadowing）
可以使用与已存在的永久表相同的标识符去注册临时表。临时表会屏蔽永久表，并且只要临时表存在，永久表就无法访问。所有使用该标识符的查询都将作用于临时表。
这可能对实验（experimentation）有用。它允许先对一个临时表进行完全相同的查询，例如只有一个子集的数据，或者数据是不确定的。一旦验证了查询的正确性，就可以对实际的生产表进行查询。

### 虚拟表
在SQL的术语中，Table API的对象对应于视图（虚拟表）。它封装了一个逻辑查询计划。它可以通过以下方法在catalog中创建

### 将Table转换为DataStream或者DataSet时，你需要指定生成的DataStream或者DataSet的数据类型，即Table的每行数据要转换成的数据类型。通常最方便的选择是转换成Row 。以下列表概述了不同选项的功能：
- Row: 字段按位置映射，字段数量任意，支持 null 值，无类型安全（type-safe）检查。
- POJO: 字段按名称映射（POJO 必须按Table 中字段名称命名），字段数量任意，支持 null 值，无类型安全检查。
- Case Class: 字段按位置映射，不支持 null 值，有类型安全检查。
- Tuple: 字段按位置映射，字段数量少于 22（Scala）或者 25（Java），不支持 null 值，无类型安全检查。
- Atomic Type: Table 必须有一个字段，不支持 null 值，有类型安全检查。

### 将Table转换为DataStream有两种模式：
- Append Mode: 仅当动态 Table 仅通过INSERT更改进行修改时，才可以使用此模式，即，它仅是追加操作，并且之前输出的结果永远不会更新。
- Retract Mode: 任何情形都可以使用此模式。它使用 boolean 值对 INSERT 和 DELETE 操作的数据进行标记。
```java
StreamTableEnvironment tableEnv = ...; // see "Create a TableEnvironment" section
Table table = ...
// convert the Table into an append DataStream of Row by specifying the class
DataStream<Row> dsRow = tableEnv.toAppendStream(table, Row.class);
// convert the Table into an append DataStream of Tuple2<String, Integer> 
//   via a TypeInformation
TupleTypeInfo<Tuple2<String, Integer>> tupleType = new TupleTypeInfo<>(
  Types.STRING(),
  Types.INT());
DataStream<Tuple2<String, Integer>> dsTuple = 
  tableEnv.toAppendStream(table, tupleType);
// convert the Table into a retract DataStream of Row.
//   A retract stream of type X is a DataStream<Tuple2<Boolean, X>>. 
//   The boolean field indicates the type of the change. 
//   True is INSERT, false is DELETE.
DataStream<Tuple2<Boolean, Row>> retractStream = 
  tableEnv.toRetractStream(table, Row.class);
```

### $\color{red}{一旦 Table 被转化为 DataStream，必须使用 StreamExecutionEnvironment 的 execute 方法执行该 DataStream 作业。}$

### 将表转换成DataSet
```java
// get BatchTableEnvironment
BatchTableEnvironment tableEnv = BatchTableEnvironment.create(env);
// Table with two fields (String name, Integer age)
Table table = ...
// convert the Table into a DataSet of Row by specifying a class
DataSet<Row> dsRow = tableEnv.toDataSet(table, Row.class);
// convert the Table into a DataSet of Tuple2<String, Integer> via a TypeInformation
TupleTypeInfo<Tuple2<String, Integer>> tupleType = new TupleTypeInfo<>(
  Types.STRING(),
  Types.INT());
DataSet<Tuple2<String, Integer>> dsTuple = ableEnv.toDataSet(table, tupleType);
```

### $\color{red}{一旦 Table 被转化为 DataSet，必须使用 ExecutionEnvironment 的 execute 方法执行该 DataSet 作业}$

### 数据类型到table schema的映射有两种方式：基于字段位置或基于字段名称。
```java
Table table = tableEnv.fromDataStream(stream, $("myLong"));

Table table = tableEnv.fromDataStream(stream, $("f1"));
```

### 原子类型
Flink将基础数据类型（Integer、Double、String）或者通用数据类型（不可再拆分的数据类型）视为原子类型。原子类型的DataStream或者DataSet会被转换成只有一条属性的 Table。属性的数据类型可以由原子类型推断出，还可以重新命名属性。

### Tuple类型（Scala 和 Java）和Case Class类型（仅 Scala）
Flink支持Scala的内置tuple类型并给Java提供自己的tuple类型。两种tuple的 DataStream 和 DataSet 都能被转换成表。可以通过提供所有字段名称来重命名字段（基于位置映射）。如果没有指明任何字段名称，则会使用默认的字段名称。如果引用了原始字段名称（对于Flink tuple 为f0、f1 … …，对于Scala tuple 为_1、_2 … …），则API会假定映射是基于名称的而不是基于位置的。基于名称的映射可以通过as对字段和投影进行重新排序。

### POJO类型（Java和Scala）
Flink支持POJO类型作为复合类型。确定POJO类型的规则记录在这里.
在不指定字段名称的情况下将POJO类型的DataStream或DataSet转换成Table时，将使用原始POJO类型字段的名称。名称映射需要原始名称，并且不能按位置进行。字段可以使用别名（带有as关键字）来重命名，重新排序和投影。

### Row类型
Row类型支持任意数量的字段以及具有null值的字段。字段名称可以通过RowTypeInfo指定，也可以在将Row的DataStream或DataSet转换为Table时指定。Row类型的字段映射支持基于名称和基于位置两种方式。字段可以通过提供所有字段的名称的方式重命名（基于位置映射）或者分别选择进行投影/排序/重命名（基于名称映射）。

### 执行计划
可以用TableEnvironment.explainSql()方法和TableEnvironment.executeSql()方法支持执行一个EXPLAIN语句获取逻辑和优化查询计划
```java
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
StreamTableEnvironment tEnv = StreamTableEnvironment.create(env);
DataStream<Tuple2<Integer, String>> stream1 = env.fromElements(new Tuple2<>(1, "hello"));
DataStream<Tuple2<Integer, String>> stream2 = env.fromElements(new Tuple2<>(1, "hello"));
// explain Table API
Table table1 = tEnv.fromDataStream(stream1, $("count"), $("word"));
Table table2 = tEnv.fromDataStream(stream2, $("count"), $("word"));
Table table = table1
  .where($("word").like("F%"))
  .unionAll(table2);
System.out.println(table.explain());
```

### 动态表&连续查询(Continuous Query)
动态表是Flink的支持流数据的Table API和SQL的核心概念。与表示批处理数据的静态表不同，动态表是随时间变化的。可以像查询静态批处理表一样查询它们。查询动态表将生成一个 连续查询。一个连续查询永远不会终止，结果会生成一个动态表。查询不断更新其(动态)结果表，以反映其(动态)输入表上的更改。本质上，动态表上的连续查询非常类似于定义物化视图的查询。

### 连续查询
1. 在动态表上计算一个连续查询，并生成一个新的动态表。与批处理查询不同，连续查询从不终止，并根据其输入表上的更新更新其结果表。在任何时候，连续查询的结果在语义上与以批处理模式在输入表快照上执行的相同查询的结果相同。
![](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/table-streaming/query-groupBy-cnt.png)
- 首先查询更新先前输出的结果，即定义结果表的changelog流包含INSERT和UPDATE操作。
2. 除了用户属性之外，还将clicks分组至每小时滚动窗口中，然后计算url数量(基于时间的计算，例如基于特定时间属性的窗口，后面会讨论)。同样该图显示了不同时间点的输入和输出，以可视化动态表的变化特性。
![](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/table-streaming/query-groupBy-window-cnt.png)
- 只附加到结果表，即结果表的changelog流只包含INSERT操作。

### Flink的Table API和SQL支持三种方式来编码一个动态表的变化:
- Append-only流： 仅通过INSERT操作修改的动态表可以通过输出插入的行转换为流。
- Retract流：retract流包含两种类型的message: add messages 和retract messages 。通过将INSERT操作编码为add message、将DELETE操作编码为retract message、将UPDATE操作编码为更新(先前)行的retract message和更新(新)行的add message，将动态表转换为retract流。下图显示了将动态表转换为retract 流的过程。
![](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/table-streaming/undo-redo-mode.png)
- Upsert 流: upsert 流包含两种类型的 message： upsert messages 和delete messages。转换为 upsert 流的动态表需要(可能是组合的)唯一键。通过将 INSERT 和 UPDATE 操作编码为 upsert message，将 DELETE 操作编码为 delete message ，将具有唯一键的动态表转换为流。消费流的算子需要知道唯一键的属性，以便正确地应用 message。与 retract 流的主要区别在于 UPDATE 操作是用单个 message 编码的，因此效率更高。下图显示了将动态表转换为 upsert 流的过程。

### $color\{red}{请注意，在将动态表转换为DataStream时，只支持append流和retract流}$

### 1.在创建表的DDL中定义处理时间(processtime)
处理时间属性可以在创建表的 DDL 中用计算列的方式定义，用 PROCTIME() 就可以定义处理时间。
```sql
CREATE TABLE user_actions (
  user_name STRING,
  data STRING,
  user_action_time AS PROCTIME() -- 声明一个额外的列作为处理时间属性
) WITH (
  ...
);

SELECT TUMBLE_START(user_action_time, INTERVAL '10' MINUTE), COUNT(DISTINCT user_name)
FROM user_actions
GROUP BY TUMBLE(user_action_time, INTERVAL '10' MINUTE);
```

### 2.在DataStream到Table转换时定义处理时间(processtime)
处理时间属性可以在schema定义的时候用.proctime 后缀来定义。时间属性一定不能定义在一个已有字段上，所以它只能定义在schem定义的最后。
```java
DataStream<Tuple2<String, String>> stream = ...;
// 声明一个额外的字段作为时间属性字段
Table table = tEnv.fromDataStream(stream, $("user_name"), $("data"), $("user_action_time").proctime());
WindowedTable windowedTable = table.window(
        Tumble.over(lit(10).minutes())
            .on($("user_action_time"))
            .as("userActionWindow"));
```

### 3.使用TableSource定义处理时间(processtime)
处理时间属性可以在实现了DefinedProctimeAttribute的TableSource中定义。逻辑的时间属性会放在TableSource已有物理字段的最后
```java
// 定义一个由处理时间属性的 table source
public class UserActionSource implements StreamTableSource<Row>, DefinedProctimeAttribute {
	@Override
	public TypeInformation<Row> getReturnType() {
		String[] names = new String[] {"user_name" , "data"};
		TypeInformation[] types = new TypeInformation[] {Types.STRING(), Types.STRING()};
		return Types.ROW(names, types);
	}
	@Override
	public DataStream<Row> getDataStream(StreamExecutionEnvironment execEnv) {
		// create stream
		DataStream<Row> stream = ...;
		return stream;
	}
	@Override
	public String getProctimeAttribute() {
		// 这个名字的列会被追加到最后，作为第三列
		return "user_action_time";
	}
}
// register table source
tEnv.registerTableSource("user_actions", new UserActionSource());
WindowedTable windowedTable = tEnv
	.from("user_actions")
	.window(Tumble
	    .over(lit(10).minutes())
	    .on($("user_action_time"))
	    .as("userActionWindow"));
```

### 1.在DDL中定义事件时间(event time)
事件时间属性可以用 WATERMARK 语句在 CREATE TABLE DDL 中进行定义。WATERMARK 语句在一个已有字段上定义一个 watermark 生成表达式，同时标记这个已有字段为时间属性字段。
```sql
CREATE TABLE user_actions (
  user_name STRING,
  data STRING,
  user_action_time TIMESTAMP(3),
  -- 声明 user_action_time 是事件时间属性，并且用 延迟 5 秒的策略来生成 watermark
  WATERMARK FOR user_action_time AS user_action_time - INTERVAL '5' SECOND
) WITH (
  ...
);

SELECT TUMBLE_START(user_action_time, INTERVAL '10' MINUTE), COUNT(DISTINCT user_name)
FROM user_actions
GROUP BY TUMBLE(user_action_time, INTERVAL '10' MINUTE);
```

### 2.在DataStream到Table转换时定义事件时间(event time)
事件时间属性可以用.rowtime后缀在定义DataStream schema的时候来定义。$color{red}{时间戳和watermark在这之前一定是在DataStream上已经定义好了}$。在从DataStream到Table转换时定义事件时间属性有两种方式。取决于用.rowtime后缀修饰的字段名字是否是已有字段，事件时间字段可以是：
  - 在schema的结尾追加一个新的字段
  - 替换一个已经存在的字段。
```java
// Option 1,基于stream中的事件产生时间戳和watermark
DataStream<Tuple2<String, String>> stream = inputStream.assignTimestampsAndWatermarks(...);
// 声明一个额外的逻辑字段作为事件时间属性
Table table = tEnv.fromDataStream(stream, $("user_name"), $("data"), $("user_action_time").rowtime()");
// Option 2,从第一个字段获取事件时间，并且产生watermark
DataStream<Tuple3<Long, String, String>> stream = inputStream.assignTimestampsAndWatermarks(...);
// 第一个字段已经用作事件时间抽取了，不用再用一个新字段来表示事件时间了
Table table = tEnv.fromDataStream(stream, $("user_action_time").rowtime(), $("user_name"), $("data"));

// Usage:
WindowedTable windowedTable = table.window(Tumble
       .over(lit(10).minutes())
       .on($("user_action_time"))
       .as("userActionWindow"));
```

### 3.使用TableSource定义事件时间(event time)
事件时间属性可以在实现了DefinedRowTimeAttributes的TableSource中定义。getRowtimeAttributeDescriptors()方法返回RowtimeAttributeDescriptor的列表，包含了描述事件时间属性的字段名字、如何计算事件时间、以及watermark生成策略等信息。
同时需要确保getDataStream返回的DataStream已经定义好了时间属性。 只有在定义了StreamRecordTimestamp时间戳分配器的时候，才认为DataStream是有时间戳信息的。 只有定义了PreserveWatermarks watermark生成策略的DataStream的watermark才会被保留。反之，则只有时间字段的值是生效的。
```java
// 定义一个有事件时间属性的 table source
public class UserActionSource implements StreamTableSource<Row>, DefinedRowtimeAttributes {
	@Override
	public TypeInformation<Row> getReturnType() {
		String[] names = new String[] {"user_name", "data", "user_action_time"};
		TypeInformation[] types =
		    new TypeInformation[] {Types.STRING(), Types.STRING(), Types.LONG()};
		return Types.ROW(names, types);
	}

	@Override
	public DataStream<Row> getDataStream(StreamExecutionEnvironment execEnv) {
		// 构造 DataStream
		// ...
		// 基于 "user_action_time" 定义 watermark
		DataStream<Row> stream = inputStream.assignTimestampsAndWatermarks(...);
		return stream;
	}

	@Override
	public List<RowtimeAttributeDescriptor> getRowtimeAttributeDescriptors() {
		// 标记 "user_action_time" 字段是事件时间字段
		// 给 "user_action_time" 构造一个时间属性描述符
		RowtimeAttributeDescriptor rowtimeAttrDescr = new RowtimeAttributeDescriptor(
			"user_action_time",
			new ExistingField("user_action_time"),
			new AscendingTimestamps());
		List<RowtimeAttributeDescriptor> listRowtimeAttrDescr = Collections.singletonList(rowtimeAttrDescr);
		return listRowtimeAttrDescr;
	}
}
// register the table source
tEnv.registerTableSource("user_actions", new UserActionSource());

WindowedTable windowedTable = tEnv
	.from("user_actions")
	.window(Tumble.over(lit(10).minutes()).on($("user_action_time")).as("userActionWindow"));
```

### 时态表（Temporal Tables）
时态表（Temporal Table）代表基于表的（参数化）视图概念，该表记录变更历史，该视图返回表在某个特定时间点的内容。
变更表可以是跟踪变化的历史记录表（例如数据库变更日志），也可以是有具体更改的维表（例如数据库表）。
对于记录变更历史的表，Flink可以追踪这些变化，并且允许查询这张表在某个特定时间点的内容。在Flink中，这类表由时态表函数（Temporal Table Function）表示。
```sql
SELECT * FROM RatesHistory;

rowtime currency   rate
======= ======== ======
09:00   US Dollar   102
09:00   Euro        114
09:00   Yen           1
10:45   Euro        116
11:15   Euro        119
11:49   Pounds      108

-- RatesHistory 代表一个兑换日元货币汇率表（日元汇率为1），该表是不断增长的 append-only 表。例如，欧元兑日元从 09:00 到 10:45 的汇率为 114。从 10:45 到 11:15，汇率为 116。
-- 假设我们要输出 10:58 的所有当前汇率，则需要以下 SQL 查询来计算结果表：

SELECT *
FROM RatesHistory AS r
WHERE r.rowtime = (
  SELECT MAX(rowtime)
  FROM RatesHistory AS r2
  WHERE r2.currency = r.currency
  AND r2.rowtime <= TIME '10:58');
-- 子查询确定对应货币的最大时间小于或等于所需时间。外部查询列出具有最大时间戳的汇率。

```

### 时态表函数
为了访问时态表中的数据，必须传递一个时间属性，该属性确定将要返回的表的版本。 Flink 使用表函数的 SQL 语法提供一种表达它的方法。定义后，时态表函数将使用单个时间参数 timeAttribute 并返回一个行集合。 该集合包含相对于给定时间属性的所有现有主键的行的最新版本。
```java
// 获取 stream 和 table 环境
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
StreamTableEnvironment tEnv = StreamTableEnvironment.create(env);
// 提供一个汇率历史记录表静态数据集
List<Tuple2<String, Long>> ratesHistoryData = new ArrayList<>();
ratesHistoryData.add(Tuple2.of("US Dollar", 102L));
ratesHistoryData.add(Tuple2.of("Euro", 114L));
ratesHistoryData.add(Tuple2.of("Yen", 1L));
ratesHistoryData.add(Tuple2.of("Euro", 116L));
ratesHistoryData.add(Tuple2.of("Euro", 119L));

// 用上面的数据集创建并注册一个示例表
// 在实际设置中，应使用自己的表替换它
DataStream<Tuple2<String, Long>> ratesHistoryStream = env.fromCollection(ratesHistoryData);
Table ratesHistory = tEnv.fromDataStream(ratesHistoryStream, $("r_currency"), $("r_rate"), $("r_proctime").proctime());
tEnv.createTemporaryView("RatesHistory", ratesHistory);
// 创建和注册时态表函数,这使我们可以在 Table API 中使用 rates 函数。
// 指定 "r_proctime" 为时间属性，指定 "r_currency" 为主键
TemporalTableFunction rates = ratesHistory.createTemporalTableFunction("r_proctime", "r_currency");
//在表环境中注册名称为Rates的函数，这使我们可以在SQL中使用Rates函数。
tEnv.registerFunction("Rates", rates);
```

### 时态表$color\{red}{仅Blink planner支持此功能}$
为了访问时态表中的数据，当前必须使用LookupableTableSource定义一个TableSource。Flink使用SQL:2011中提出的FOR SYSTEM_TIME AS OF的SQL语法查询时态表。
$color\{red}{注意：当前，Flink 不支持以固定时间直接查询时态表。目前，时态表只能在 join 中使用。}$
```java
// 获取 stream 和 table 环境
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
EnvironmentSettings settings = EnvironmentSettings.newInstance().build();
StreamTableEnvironment tEnv = StreamTableEnvironment.create(env, settings);
// or TableEnvironment tEnv = TableEnvironment.create(settings);

// 用 DDL 定义一张 HBase 表，然后我们可以在 SQL 中将其当作一张时态表使用
// 'currency' 列是 HBase 表中的 rowKey
tEnv.executeSql(
    "CREATE TABLE LatestRates (" +
    "   currency STRING," +
    "   fam1 ROW<rate DOUBLE>" +
    ") WITH (" +
    "   'connector' = 'hbase-1.4'," +
    "   'table-name' = 'Rates'," +
    "   'zookeeper.quorum' = 'localhost:2181'" +
    ")");
```

# 表中的模式检测(MATCH_RECOGNIZE)
$color\{red}{注意 目前，MATCH_RECOGNIZE 子句只能应用于追加表。此外，它也总是生成一个追加表}$
- PARTITION BY - 定义表的逻辑分区；类似于GROUP BY操作。
- ORDER BY - 指定传入行的排序方式；这是必须的，因为模式依赖于顺序。
- MEASURES - 定义子句的输出；类似于SELECT子句。
- ONE ROW PER MATCH - 输出方式，定义每个匹配项应产生多少行。
- AFTER MATCH SKIP - 指定下一个匹配的开始位置；这也是控制单个事件可以属于多少个不同匹配项的方法。
- PATTERN - 允许使用类似于正则表达式的语法构造搜索的模式。
- DEFINE - 本部分定义了模式变量必须满足的条件。

```txt
// 一张表的schema如下：
Ticker
     |-- symbol: String                           # 股票的代号
     |-- price: Long                              # 股票的价格
     |-- tax: Long                                # 股票应纳税额
     |-- rowtime: TimeIndicatorTypeInfo(rowtime)  # 更改这些值的时间点

// 找出一个单一股票价格不断下降的时期
SELECT *
FROM Ticker
    MATCH_RECOGNIZE (
        PARTITION BY symbol
        ORDER BY rowtime
        MEASURES
            START_ROW.rowtime AS start_tstamp,
            LAST(PRICE_DOWN.rowtime) AS bottom_tstamp,
            LAST(PRICE_UP.rowtime) AS end_tstamp
        ONE ROW PER MATCH
        AFTER MATCH SKIP TO LAST PRICE_UP
        PATTERN (START_ROW PRICE_DOWN+ PRICE_UP)
        DEFINE
            PRICE_DOWN AS
                (LAST(PRICE_DOWN.price, 1) IS NULL AND PRICE_DOWN.price < START_ROW.price) OR
                    PRICE_DOWN.price < LAST(PRICE_DOWN.price, 1),
            PRICE_UP AS
                PRICE_UP.price > LAST(PRICE_DOWN.price, 1)
    ) MR;

1.此查询将 Ticker 表按照 symbol 列进行分区并按照 rowtime 属性进行排序。
2.PATTERN 子句指定我们对以下模式感兴趣：该模式具有开始事件 START_ROW，然后是一个或多个 PRICE_DOWN 事件，并以 PRICE_UP 事件结束。如果可以找到这样的模式，如 3.3.AFTER MATCH SKIP TO LAST 子句所示，则从最后一个 PRICE_UP 事件开始寻找下一个模式匹配。
4.DEFINE 子句指定 PRICE_DOWN 和 PRICE_UP 事件需要满足的条件。尽管不存在 START_ROW 模式变量，但它具有一个始终被评估为 TRUE 隐式条件。
5.模式变量 PRICE_DOWN 定义为价格小于满足 PRICE_DOWN 条件的最后一行。对于初始情况或没有满足 PRICE_DOWN 条件的最后一行时，该行的价格应小于该模式中前一行（由 START_ROW 引用）的价格。
6.模式变量 PRICE_UP 定义为价格大于满足 PRICE_DOWN 条件的最后一行。
```

### $color\{red}{注意Aggregation可以应用于表达式，但前提是它们引用单个模式变量。因此SUM(A.price * A.tax)是有效的，而AVG(A.price * B.tax)则是无效的,不支持 DISTINCT aggregation}$


# Scan, Projection, and Filter

### from
```
类似于SQL查询中的FROM子句。扫描已注册的
Table orders = tableEnv.from
```

### Values
```
与SQL查询中的VALUES子句相似。从提供的行中产生一个内联表。可以使用`row（...）`表达式来创建复合行
Table table = tEnv.fromValues(row(1, "ABC"),row(2L, "ABCDE"))
Table table = tEnv.fromValues(
    DataTypes.ROW(
        DataTypes.FIELD("id", DataTypes.DECIMAL(10, 2)),
        DataTypes.FIELD("name", DataTypes.STRING())
    ),
    row(1, "ABC"),
    row(2L, "ABCDE")
)
```

### select
```
Table orders = tableEnv.from("Orders");
Table result = orders.select($("a"), $("c").as("d"));
Table result = orders.select($("*")); //选择所有列
```

### as
```
重命名字段
Table orders = tableEnv.from("Orders");
Table result = orders.as("x, y, z, t");
```

### filter
```
// 1
Table orders = tableEnv.from("Orders");
Table result = orders.where($("b").isEqual("red"));
// 2
Table orders = tableEnv.from("Orders");
Table result = orders.filter($("a").mod(2).isEqual(0));

```

### AddColumns
```
执行字段添加操作。如果添加的字段已经存在，它将引发异常。
Table orders = tableEnv.from("Orders");
Table result = orders.addColumns(concat($("c"), "sunny"));
```

### AddOrReplaceColumns
```
执行字段添加操作。如果添加列名称与现有列名称相同，则现有字段将被替换。此外，如果添加的字段具有重复的字段名称，则使用最后一个。
Table orders = tableEnv.from("Orders");
Table result = orders.addOrReplaceColumns(concat($("c"), "sunny").as("desc"));
```

### DropColumns
```
执行字段删除操作。字段表达式应该是字段引用表达式，并且只能删除现有字段。
Table orders = tableEnv.from("Orders");
Table result = orders.dropColumns($("b"), $("c"));
```

### RenameColumns
```
执行字段重命名操作。字段表达式应为别名表达式，并且仅现有字段可以重命名。
Table orders = tableEnv.from("Orders");
Table result = orders.renameColumns($("b").as("b2"), $("c").as("c2"));
```

### GroupBy
```
类似于SQL GROUP BY子句。使用以下正在运行的聚合运算符将分组键上的行分组，以逐组聚合行。
Table orders = tableEnv.from("Orders");
Table result = orders.groupBy($("a")).select($("a"), $("b").sum().as("d"));   
$color\{red}{注意：对于流式查询，根据聚合类型和不同分组关键字的数量，计算查询结果所需的状态可能会无限增长。请提供具有有效保留间隔的查询配置，以防止出现过多的状态。}$
```

### GroupBy Window
```
将表和可能的一个或多个分组键分组并聚集到一个组窗口中。
Table orders = tableEnv.from("Orders");
Table result = orders
    .window(Tumble.over(lit(5).minutes()).on($("rowtime")).as("w")) // define window
    .groupBy($("a"), $("w")) // group by key and window
    // access window properties and aggregate
    .select(
        $("a"),
        $("w").start(),
        $("w").end(),
        $("w").rowtime(),
        $("b").sum().as("d")
    );

```

### windows 窗口聚合(stream)
```
类似于SQL OVER子句。基于前一行和后一行的窗口（范围），为每一行计算窗口聚合。
Table orders = tableEnv.from("Orders");
Table result = orders
    // define window
    .window(
        Over
          .partitionBy($("a"))
          .orderBy($("rowtime"))
          .preceding(UNBOUNDED_RANGE)
          .following(CURRENT_RANGE)
          .as("w"))
    // sliding aggregate
    .select(
        $("a"),
        $("b").avg().over($("w")),
        $("b").max().over($("w")),
        $("b").min().over($("w"))
    );

$color\{red}{注意：必须在同一窗口中定义所有聚合，即，相同的分区，排序和范围。当前，仅支持具有PRECEDING（未绑定和有界）到CURRENT ROW范围的窗口。目前尚不支持带有FOLLOWING的范围。必须在单个时间属性上指定ORDER BY}$
```

### Distinct Aggregation
```
与SQL DISTINCT聚合子句类似，例如COUNT（DISTINCT a）。不同的聚合声明聚合函数（内置或用户定义的）仅应用于不同的输入值。可以将不同应用于GroupBy聚合，GroupBy窗口聚合和Over Window聚合。

Table orders = tableEnv.from("Orders");
// Distinct aggregation on group by
Table groupByDistinctResult = orders
    .groupBy($("a"))
    .select($("a"), $("b").sum().distinct().as("d"));
// Distinct aggregation on time window group by
Table groupByWindowDistinctResult = orders
    .window(Tumble
            .over(lit(5).minutes())
            .on($("rowtime"))
            .as("w")
    )
    .groupBy($("a"), $("w"))
    .select($("a"), $("b").sum().distinct().as("d"));
// Distinct aggregation on over window
Table result = orders
    .window(Over
        .partitionBy($("a"))
        .orderBy($("rowtime"))
        .preceding(UNBOUNDED_RANGE)
        .as("w"))
    .select(
        $("a"), $("b").avg().distinct().over($("w")),
        $("b").max().over($("w")),
        $("b").min().over($("w"))
    );

用户定义的聚合函数也可以与DISTINCT修饰符一起使用。要仅针对不同的值计算聚合结果，只需向聚合函数添加distinct修饰符即可。

Table orders = tEnv.from("Orders");
// Use distinct aggregation for user-defined aggregate functions
tEnv.registerFunction("myUdagg", new MyUdagg());
orders.groupBy("users")
    .select(
        $("users"),
        call("myUdagg", $("points")).distinct().as("myDistinctResult")
    );
$color\{red}{注意：对于流查询，根据查询字段的数量，计算查询结果所需的状态可能会无限增长。请提供具有有效保留间隔的查询配置，以防止出现过多的状态。}$
```

### DISTINCT
```
类似于SQL DISTINCT子句。返回具有不同值组合的记录。

Table orders = tableEnv.from("Orders");
Table result = orders.distinct();
```
$color\{red}{注意：对于流查询，根据查询字段的数量，计算查询结果所需的状态可能会无限增长。请提供具有有效保留间隔的查询配置，以防止出现过多的状态。如果启用了状态清除功能，那么distinct必须发出消息以防止下游操作员过早地将状态逐出，从而使distinct包含结果更新。}$

###  Inner Join
```java
//类似于SQL JOIN子句。连接两个表。两个表必须具有不同的字段名，并且至少一个相等的联接谓词必须通过联接运算符或使用where或filter运算符进行定义。
Table left = tableEnv.fromDataSet(ds1, "a, b, c");
Table right = tableEnv.fromDataSet(ds2, "d, e, f");
Table result = left.join(right)
    .where($("a").isEqual($("d")))
    .select($("a"), $("b"), $("e"));
```

### Out Join
```java
//类似于SQL LEFT/RIGHT/FULL OUTER JOIN子句。连接两个表。两个表必须具有不同的字段名称，并且必须至少定义一个相等联接谓词。
Table left = tableEnv.fromDataSet(ds1, "a, b, c");
Table right = tableEnv.fromDataSet(ds2, "d, e, f");

Table leftOuterResult = left.leftOuterJoin(right, $("a").isEqual($("d")))
                            .select($("a"), $("b"), $("e"));
Table rightOuterResult = left.rightOuterJoin(right, $("a").isEqual($("d")))
                            .select($("a"), $("b"), $("e"));
Table fullOuterResult = left.fullOuterJoin(right, $("a").isEqual($("d")))
                            .select($("a"), $("b"), $("e"));
```

### Interval Join
```java
//间隔联接需要至少一个等联接谓词和在两侧限制时间的联接条件。可以通过<, <=, >=, >比较两个输入表的相同类型的时间属性（即处理时间或事件时间）的两个适当的范围谓词（）或单个相等谓词来定义这种条件。
Table left = tableEnv.fromDataSet(ds1, $("a"), $("b"), $("c"), $("ltime").rowtime());
Table right = tableEnv.fromDataSet(ds2, $("d"), $("e"), $("f"), $("rtime").rowtime()));
Table result = left.join(right)
  .where(
    and(
        $("a").isEqual($("d")),
        $("ltime").isGreaterEqual($("rtime").minus(lit(5).minutes())),
        $("ltime").isLess($("rtime").plus(lit(10).minutes()))
    ))
  .select($("a"), $("b"), $("e"), $("ltime"));
```

### 内联表函数 Inner Join with Table Function (UDTF)
```java
//用表函数的结果联接表。左（外）表的每一行都与表函数的相应调用产生的所有行连接在一起。如果左侧（外部）表的表函数调用返回空结果，则该行将被删除。
// register User-Defined Table Function
TableFunction<String> split = new MySplitUDTF();
tableEnv.registerFunction("split", split);

// join
Table orders = tableEnv.from("Orders");
Table result = orders
    .joinLateral(call("split", $("c")).as("s", "t", "v"))
    .select($("a"), $("b"), $("s"), $("t"), $("v"));
```

### 左外联接与表函数Left Outer Join with Table Function (UDTF)
```java
//用表函数的结果联接表。左（外）表的每一行都与表函数的相应调用产生的所有行连接在一起。如果表函数调用返回空结果，则保留对应的外部行，并用空值填充结果。注意：当前，左外部联接的表函数的谓词只能为空或文字true。
// register User-Defined Table Function
TableFunction<String> split = new MySplitUDTF();
tableEnv.registerFunction("split", split);

// join
Table orders = tableEnv.from("Orders");
Table result = orders
    .leftOuterJoinLateral(call("split", $("c")).as("s", "t", "v"))
    .select($("a"), $("b"), $("s"), $("t"), $("v"));

```

### 时态表Join with Temporal Table (stream)
```
临时表是跟踪随时间变化的表。时态表功能提供对特定时间点时态表状态的访问。使用临时表函数联接表的语法与使用表函数进行内部联接的语法相同。当前仅支持使用临时表的内部联接。

Table ratesHistory = tableEnv.from("RatesHistory");
// register temporal table function with a time attribute and primary key
TemporalTableFunction rates = ratesHistory.createTemporalTableFunction(
    "r_proctime",
    "r_currency");
tableEnv.registerFunction("rates", rates);
// join with "Orders" based on the time attribute and key
Table orders = tableEnv.from("Orders");
Table result = orders
    .joinLateral(call("rates", $("o_proctime")), $("o_currency").isEqual($("r_currency")))

```

### union (batch)
```java
//类似于SQL UNION子句。合并两个已删除重复记录的表。两个表必须具有相同的字段类型。
Table left = tableEnv.fromDataSet(ds1, "a, b, c");
Table right = tableEnv.fromDataSet(ds2, "a, b, c");
Table result = left.union(right);
```

### union all
```java
//类似于SQL UNION ALL子句。合并两个表。两个表必须具有相同的字段类型。
Table left = tableEnv.fromDataSet(ds1, "a, b, c");
Table right = tableEnv.fromDataSet(ds2, "a, b, c");
Table result = left.unionAll(right);
```

### 相交 INTERSECT (batch)
```java
//类似于SQL INTERSECT子句。相交返回两个表中都存在的记录。如果一个记录在一个或两个表中存在一次以上，则仅返回一次，即结果表中没有重复的记录。两个表必须具有相同的字段类型。
Table left = tableEnv.fromDataSet(ds1, "a, b, c");
Table right = tableEnv.fromDataSet(ds2, "d, e, f");
Table result = left.intersect(right);
```

### 所有相交 INTERSECT ALL (batch)
```java
//类似于SQL INTERSECT ALL子句。IntersectAll返回两个表中都存在的记录。如果一个记录在两个表中都多次出现，则返回的次数与在两个表中都多次出现一样，即结果表可能有重复的记录。两个表必须具有相同的字段类型。
Table left = tableEnv.fromDataSet(ds1, "a, b, c");
Table right = tableEnv.fromDataSet(ds2, "d, e, f");
Table result = left.intersectAll(right);
```

### 减 minus(batch)
```java
//类似于SQL EXCEPT子句。减号从左表返回不存在于右表中的记录。左表中的重复记录仅返回一次，即删除了重复项。两个表必须具有相同的字段类型。
Table left = tableEnv.fromDataSet(ds1, "a, b, c");
Table right = tableEnv.fromDataSet(ds2, "a, b, c");
Table result = left.minus(right);
```

### 减所有 Minus All(batch)
```java
//类似于SQL EXCEPT ALL子句。MinusAll返回右表中不存在的记录。将返回（n-m）次在左表中出现n次且在右表中出现m次的记录，即，删除与右表中存在的重复项一样多的记录。两个表必须具有相同的字段类型。
Table left = tableEnv.fromDataSet(ds1, "a, b, c");
Table right = tableEnv.fromDataSet(ds2, "a, b, c");
Table result = left.minusAll(right);
```

### in
```java
//类似于SQL IN子句。如果给定的子表查询中存在表达式，则In返回true。子查询表必须由一列组成。该列必须具有与表达式相同的数据类型。
Table left = ds1.toTable(tableEnv, "a, b, c");
Table right = ds2.toTable(tableEnv, "a");
Table result = left.select($("a"), $("b"), $("c")).where($("a").in(right));

//注意：对于流查询，该操作将在联接和组操作中重写。根据不同输入行的数量，计算查询结果所需的状态可能会无限增长。
//请提供具有有效保留间隔的查询配置，以防止出现过多的状态。
```

### OFFSET和FETCH (batch)
```java
//与SQL OFFSET和FETCH子句类似。偏移量和提取限制从排序结果返回的记录数。偏移和提取在技术上是Order By运算符的一部分，因此必须在其之前。

Table in = tableEnv.fromDataSet(ds, "a, b, c");
// 返回排序后的前5条数据
Table result1 = in.orderBy($("a").asc()).fetch(5);
// 跳过前3条记录并从排序结果返回所有后续记录
Table result2 = in.orderBy($("a").asc()).offset(3);
// 跳过前10条记录，从排序结果中返回后5条记录
Table result3 = in.orderBy($("a").asc()).offset(10).fetch(5);

```

### insert
```java
//与SQL查询中的“ INSERT INTO”子句类似，该方法在已注册的输出表中执行插入操作。ʻexecuteInsert（）`方法将立即提交Flink作业，该作业将执行插入操作。输出表必须在TableEnvironment中注册（请参阅注册TableSink）。此外，已注册表的架构必须与查询的架构匹配。
Table orders = tableEnv.from("Orders");
orders.executeInsert("OutOrders");
```

### Group Window
```java
//“组”窗口根据时间或行计数间隔将组行聚合为有限的组，并每组评估一次聚合函数。对于批处理表，窗口是方便按时间间隔对记录进行分组的快捷方式。
Table table = input
  .window([GroupWindow w].as("w"))  // define window with alias w
  .groupBy($("w"))  // group the table by window w
  .select($("b").sum());  // aggregate

```

### tumble (滚动窗口)
滚动窗口将行分配给固定长度的不重叠的连续窗口。例如，5分钟的滚动窗口以5分钟为间隔对行进行分组。可以在事件时间，处理时间或行数上定义滚动窗口。
- over:定义窗口的长度，可以是时间间隔，也可以是行计数间隔。
- on:用于分组（时间间隔）或排序（行计数）的时间属性。对于批查询，它可以是任何Long或Timestamp属性。对于流查询，它必须是声明的event-time或processing-time time属性。
- as:为窗口分配别名。别名用于在以下groupBy()子句中引用窗口，并可以选择在子句中选择窗口属性，例如窗口开始，结束或行时间时间戳select()。
```java
// Tumbling Event-time Window
.window(Tumble.over(lit(10).minutes()).on($("rowtime")).as("w"));
// Tumbling Processing-time Window (assuming a processing-time attribute "proctime")
.window(Tumble.over(lit(10).minutes()).on($("proctime")).as("w"));
// Tumbling Row-count Window (assuming a processing-time attribute "proctime")
.window(Tumble.over(rowInterval(10)).on($("proctime")).as("w"));
```

### slide（滑动窗口）
滑动窗口的大小固定，并以指定的滑动间隔滑动。如果滑动间隔小于窗口大小，则滑动窗口重叠。因此，可以将行分配给多个窗口。例如，一个15分钟大小的滑动窗口和5分钟滑动间隔将每行分配给3个15分钟大小的不同窗口，它们以5分钟的间隔进行评估。可以在事件时间，处理时间或行数上定义滑动窗口。滑动窗口是通过使用以下Slide类来定义的：
- over:将窗口的长度定义为时间或行计数间隔。
- every:将幻灯片间隔定义为时间间隔或行计数间隔。滑动间隔必须与尺寸间隔具有相同的类型。
- on:用于分组（时间间隔）或排序（行计数）的时间属性。对于批查询，它可以是任何Long或Timestamp属性。对于流查询，它必须是声明的event-time或processing-time time属性。
- as:为窗口分配别名。别名用于在以下groupBy()子句中引用窗口，并可以选择在子句中选择窗口属性，例如窗口开始，结束或行时间时间戳select()。
```java
// Sliding Event-time Window
.window(Slide.over(lit(10).minutes())
            .every(lit(5).minutes())
            .on($("rowtime"))
            .as("w"));
// Sliding Processing-time window (assuming a processing-time attribute "proctime")
.window(Slide.over(lit(10).minutes())
            .every(lit(5).minutes())
            .on($("proctime"))
            .as("w"));
// Sliding Row-count window (assuming a processing-time attribute "proctime")
.window(Slide.over(rowInterval(10)).every(rowInterval(5)).on($("proctime")).as("w"));
```

### 