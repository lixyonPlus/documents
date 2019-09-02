MongoDB 聚合
  - MongoDB中聚合(aggregate)主要用于处理数据(诸如统计平均值,求和等)，并返回计算后的数据结果。有点类似sql语句中的 count(*)。
  - db.COLLECTION_NAME.aggregate(AGGREGATE_OPERATION)
    - $sum	计算总和。	db.mycol.aggregate([{$group : {_id : "$by_user", num_tutorial : {$sum : "$likes"}}}])
    - $avg	计算平均值	db.mycol.aggregate([{$group : {_id : "$by_user", num_tutorial : {$avg : "$likes"}}}])
    - $min	获取集合中所有文档对应值得最小值。	db.mycol.aggregate([{$group : {_id : "$by_user", num_tutorial : {$min : "$likes"}}}])
    - $max	获取集合中所有文档对应值得最大值。	db.mycol.aggregate([{$group : {_id : "$by_user", num_tutorial : {$max : "$likes"}}}])
    - $push	在结果文档中插入值到一个数组中。	db.mycol.aggregate([{$group : {_id : "$by_user", url : {$push: "$url"}}}])
    - $addToSet	在结果文档中插入值到一个数组中，但不创建副本。	db.mycol.aggregate([{$group : {_id : "$by_user", url : {$addToSet : "$url"}}}])
    - $first	根据资源文档的排序获取第一个文档数据。	db.mycol.aggregate([{$group : {_id : "$by_user", first_url : {$first : "$url"}}}])
    - $last	根据资源文档的排序获取最后一个文档数据	db.mycol.aggregate([{$group : {_id : "$by_user", last_url : {$last : "$url"}}}])
  
 管道的概念
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


    
