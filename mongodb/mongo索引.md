# MongoDB 索引  
### MongoDB索引类型
- 单键索引
- 组合索引
- 多值索引
- 地理位置索引 
- 全文索引
- TTL索引 
- 部分索引 
- 哈希索引

![索引执行计划](https://s1.ax1x.com/2020/10/12/02LttP.png)
![查看执行计划explain()](https://s1.ax1x.com/2020/10/12/02Ljje.png)

- 组合索引 – Compound Index
   组合索引的最佳方式:ESR原则
    - 精确(Equal)匹配的字段放最前面
    - 排序(Sort)条件放中间
    - 范围(Range)匹配的字段放最后面
    同样适用: ES, ER

- 地理位置索引
```javascript
//创建索引
db.geo_col.createIndex(
    {"location": “2d”} ,
    {min:-20, max: 20 , bits: 10}, 
    {collation:{locale: "simple"} }
)
// 查询 
db.geo_col.find(
    {"location" :{ $geoWithin :
        { $box : [[1,1],[3,3]]}}}
)
```

- 全文索引
```javascript
//创建全文索引
db.<collection_name>.createIndex(
    {‘content’ : “text” }
)
//查询
db.<collection_name>.find({$text:{$search : "xxxxx"}})
// 查询排序
db.<collection_name>.find(
    {$text : {$search : "coffee" }},
    { textScore: { $meta : "textScore" }})
    .sort({ textScore: { $meta: "textScore" }})
```

- 部分索引 
```javascript
//创建部分索引
 db.<collection_name>.createIndex( 
    {"a": 1 },
    { partialFilterExpression:{a:{$gte:5}}}
)
//只对有wechat字段的建索引
db.<collection_name>.createIndex(
    {"wechat": 1 },
    {partialFilterExpression: {wechat:{$exists:true}}}
    )
// 后台创建索引
db.<collection_name>.createIndex( { city: 1}, {background: true} )
```

