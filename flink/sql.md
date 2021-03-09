### join
- Regular Joins: regular join是最通用的join类型，不支持时间窗口以及时间属性，任何一侧数据流有更改都是可见的，直接影响整个join结果。如果有一侧数据流增加一个新纪录，那么它将会把另一侧的所有的过去和将来的数据合并在一起，因为regular join没有剔除策略，这就影响最新输出的结果; 正因为历史数据不会被清理，所以regular join支持数据流的任何更新操作。对于regular join来说，更适合用于离线场景和小数据量场景。
- Interval Joins: 相对于regular join，interval Join则利用窗口的给两个输入表设定一个Join的时间界限，超出时间范围的数据则对join不可见并可以被清理掉，这样就能修正regular join因为没有剔除数据策略带来join结果的误差以及需要大量的资源。但是使用interval join，需要定义好时间属性字段，可以是计算发生的Processing Time，也可以是根据数据本身提取的Event Time；如果是定义的是Processing Time，则Flink框架本身根据系统划分的时间窗口定时清理数据；如果定义的是Event Time，Flink框架分配Event Time窗口并根据设置的watermark来清理数据。interval join只需要缓存时间边界内的数据，存储空间占用小，计算更为准确的实时 join 结果,使用场景：双流join场景。
```
--写法1
SELECT columns
FROM t1  [AS <alias1>]
[LEFT/INNER/FULL OUTER] JOIN t2
ON t1.column1 = t2.key-name1 AND t1.timestamp BETWEEN t2.timestamp  AND t2.timestamp + INTERVAL '10' MINUTE;

--写法2
SELECT columns
FROM t1  [AS <alias1>]
[LEFT/INNER/FULL OUTER] JOIN t2
ON t1.column1 = t2.key-name1 AND t2.timestamp <= t1.timestamp and t1.timestamp <= t2.timestamp + INTERVAL ’10' MINUTE ;

```
- interval Join提供了剔除数据的策略，解决资源问题以及计算更加准确，这有个前提：join的两个流需要时间属性，需要明确时间的下界，来方便剔除数据；显然，这种场景不适合维度表的join，因为维度表没有时间界限，对于这种场景，Flink提供了temproal table join来覆盖此类场景。在regular join和interval join中，join两侧的表是平等的，任意的一个表的更新，都会去和另外的历史纪录进行匹配，temproal table的更新对另一表在该时间节点以前的记录是不可见的。而在temproal table join中，比较明显的使用场景之一就是点击流去join广告位的维度表，引入广告位的中文名称,使用场景：维度表join。
```
SELECT columns
FROM t1  [AS <alias1>]
[LEFT] JOIN t2 FOR SYSTEM_TIME AS OF t1.proctime [AS <alias2>]
ON t1.column1 = t2.key-name1
```


Join with a Temporal Table Function
Usage
Processing-time Temporal Joins
Event-time Temporal Joins
Join with a Temporal Table
Usage