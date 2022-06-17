
### 索引不能被以下的查询使用：
  - 正则表达式及非操作符，如 $nin, $not, 等。
  - 算术运算符，如 $mod, 等。
  - $where 子句
  
索引类型：
    1._id唯一性索引
    2.单键索引
    3.多健索引
    4.复合索引
    5.过期索引
    6.全文索引
    7.地理位置索引

explain（）查询语句执行计划。
explain三种模式：
    queryPlanner，executionStats，allPlansExecution
stage：
    COLLSCAN：全表扫描
    IXSCAN：索引扫描
    FETCH：根据索引去检索指定document
    SHARD_MERGE：将各个分片返回数据进行merge
    SORT：表明在内存中进行了排序
    LIMIT：使用limit限制返回数
    SKIP：使用skip进行跳过
    IDHACK：针对_id进行查询

- 索引最大范围
  - 集合中索引不能超过64个
  - 索引名的长度不能超过128个字符
  - 一个复合索引最多可以有31个字段
  - 如果文档的索引字段值超过了索引键的限制，MongoDB不会将任何文档转换成索引的集合。

- ObjectId 是一个12字节（24位） BSON 类型数据，有以下格式：
  - 前4个字节表示时间戳
  - 接下来的3个字节是机器标识码
  - 接的两个字节由进程id组成（PID）
  - 最后三个字节是随机数。

一次查询中只能使用一个索引,$or特殊,可以在每个分支条件上使用一个索引。
