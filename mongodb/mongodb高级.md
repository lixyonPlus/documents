### MongoDB聚合
### 聚合运算的使用场景
● 聚合查询可以用于OLAP和OLTP场景。例如:
| OLTP | OLAP                                                      |
| ---- | --------------------------------------------------------- |
| 计算 | ● 分析一段时间内的销售总额、均值 ● 计算一段时间内的净利润 |
● 分析购买人的年龄分布
● 分析学生成绩分布
● 统计员工绩效 |

--- 

#### MongoDB中聚合(aggregate)主要用于处理数据(诸如统计平均值,求和等)，并返回计算后的数据结果。有点类似sql语句中的 count(*)。
### 常见步骤
| 步骤         | 作用     | SQL等价运算符   |
| ------------ | -------- | --------------- |
| $match       | 过滤     | WHERE           |
| $project     | 投影     | AS              |
| $sort        | 排序     | ORDER BY        |
| $group       | 分组     | GROUP BY        |
| $skip/$limit | 结果限制 | SKIP/LIMIT      |
| $lookup      | 左外连接 | LEFT OUTER JOIN |

---

### 常见步骤中的运算符
| $match                                                                                                                                                 | $project                                                    | $group |
| ------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------- | ------ |
| •$eq/$gt/$gte/$lt/$lte •$and/$or/$not/$in •$geoWithin/$intersect •......                                                                               |
| •选择需要的或排除不需要的字段 •$map/$reduce/$filter •$range •$multiply/$divide/$substract/$add •$year/$month/$dayOfMonth/$hour/$minute/$second •...... | •$sum/$avg •$push/$addToSet •$first/$last/$max/$min •...... |

--- 

### 常见步骤
| 步骤           | 作用     | SQL等价运算符 |
| -------------- | -------- | ------------- |
| $unwind        | 展开数组 | N/A           |
| $graphLookup   | 图搜索   | N/A           |
| $facet/$bucket | 分面搜索 | N/A           |

---

### db.COLLECTION_NAME.aggregate(AGGREGATE_OPERATION)
  - $sum计算总和
    - db.mycol.aggregate([{$group : {_id : "$by_user", num_tutorial : {$sum : "$likes"}}}])
  - $avg计算平均值
    - db.mycol.aggregate([{$group : {_id : "$by_user", num_tutorial : {$avg : "$likes"}}}])
  - $min获取集合中所有文档对应值得最小值
    - db.mycol.aggregate([{$group : {_id : "$by_user", num_tutorial : {$min : "$likes"}}}])
  - $max获取集合中所有文档对应值得最大值
    - db.mycol.aggregate([{$group : {_id : "$by_user", num_tutorial : {$max : "$likes"}}}])
  - $push在结果文档中插入值到一个数组中
    - db.mycol.aggregate([{$group : {_id : "$by_user", url : {$push: "$url"}}}])
  - $addToSet在结果文档中插入值到一个数组中，但不创建副本
    - db.mycol.aggregate([{$group : {_id : "$by_user", url : {$addToSet : "$url"}}}])
  - $first根据资源文档的排序获取第一个文档数据
   - db.mycol.aggregate([{$group : {_id : "$by_user", first_url : {$first : "$url"}}}])
  - $last根据资源文档的排序获取最后一个文档数据	
    - db.mycol.aggregate([{$group : {_id : "$by_user", last_url : {$last : "$url"}}}])
  
### 计算到目前为止的所有订单的总销售额
```javascript
db.orders.aggregate([
{$group: {
      _id: null,
	    total: {$sum: "$total"}
	}
}]
)
```

### 查询2019年第一季度(1月1日~3月31日)已完成订单(completed)的订单总金 额和订单总数
```javascript
db.orders.aggregate([ 
// 步骤1:匹配条件
 { $match: { status: "completed", 
     orderDate: {
       $gte: ISODate("2019-01-01"),
       $lt: ISODate("2019-04-01") } 
       } 
 }, 
// 步骤二:聚合订单总金额、总运费、总数量
{ $group: {
    _id: null,
    total: { $sum: "$total" },
    shippingFee: { $sum: "$shippingFee" },
    count: { $sum: 1 }  
    } 
},
{ $project: {
// 计算总金额
  grandTotal: { $add: ["$total", "$shippingFee"] }, count: 1, _id: 0 } 
 }
])
```

### 管道的概念
  - MongoDB的聚合管道将MongoDB文档在一个管道处理完毕后将结果传递给下一个管道处理。管道操作是可以重复的。
    - $project：修改输入文档的结构。可以用来重命名、增加或删除域，也可以用于创建计算结果以及嵌套文档。
    - $match：用于过滤数据，只输出符合条件的文档。$match使用MongoDB的标准查询操作。
    - $limit：用来限制MongoDB聚合管道返回的文档数。
    - $skip：在聚合管道中跳过指定数量的文档，并返回余下的文档。
    - $unwind：将文档中的某一个数组类型字段拆分成多条，每条包含数组中的一个值。
    - $group：将集合中的文档分组，可用于统计结果。
    - $sort：将输入文档排序后输出。
    - $geoNear：输出接近某一地理位置的有序文档。
  - 1、$project实例
  ```json
  db.article.aggregate(
    { $project : {
        title : 1 ,
        author : 1 ,
    }}
 )
  ```
  这样的话结果中就只还有_id,tilte和author三个字段了，默认情况下_id字段是被包含。
  ```json
  db.articles.aggregate( [
                        { $match : { score : { $gt : 70, $lte : 90 } } },
                        { $group: { _id: null, count: { $sum: 1 } } }
                       ] );
  ```
  $match用于获取分数大于70小于或等于90记录，然后将符合条件的记录送到下一阶段$group管道操作符进行处理。
  
时间关键字如下：
 - $dayOfYear: 返回该日期是这一年的第几天（全年 366 天）。
 - $dayOfMonth: 返回该日期是这一个月的第几天（1到31）。
 - $dayOfWeek: 返回的是这个周的星期几（1：星期日，7：星期六）。
 - $year: 返回该日期的年份部分。
 - $month： 返回该日期的月份部分（ 1 到 12）。
 - $week： 返回该日期是所在年的第几个星期（ 0 到 53）。
 - $hour： 返回该日期的小时部分。
 - $minute: 返回该日期的分钟部分。
 - $second: 返回该日期的秒部分（以0到59之间的数字形式返回日期的第二部分，但可以是60来计算闰秒）。
 - $millisecond：返回该日期的毫秒部分（ 0 到 999）。
 - $dateToString： { $dateToString: { format: , date: } }。
