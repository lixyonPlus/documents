### MongoDB 创建数据库的语法格式如下：
  - use DATABASE_NAME //使用数据库
  - db //当前数据库
  - show dbs //查看所有数据库
  
### 注意: 在 MongoDB 中，集合只有在内容插入后才会创建! 就是说，创建集合(数据表)后要再插入一个文档(记录)，集合才会真正创建。MongoDB 中默认的数据库为 test，如果你没有创建新的数据库，集合将存放在test数据库中。

### 删除数据库的语法格式如下：
  - db.dropDatabase() //删除当前数据库，默认为test，你可以使用db命令查看当前数据库名。数据库相应文件也会被删除，磁盘空间将被释放
  
### 集合删除语法格式如下： 
  - db.name.drop()  //删除集合
  
### 显示所有集合
  - show tables，show collections //查看已有集合
  
### 集合创建语法格式如下：
  - db.createCollection(name, options) //创建集合
    - options 
      - capped布尔（可选）如果为true，则创建固定集合。固定集合是指有着固定大小的集合，当达到最大值时，它会自动覆盖最早的文档。
      - autoIndexId布尔（可选）如为true，自动在_id字段创建索引。默认为false。
      - size数值（可选）为固定集合指定一个最大值（以字节计）。如果capped为true，也需要指定该字段。
      - max数值（可选）指定固定集合中包含文档的最大数量。
    - 在插入文档时，MongoDB首先检查固定集合的size字段，然后检查max字段。
    
### 在MongoDB 中，你不需要创建集合。当你插入一些文档时，MongoDB 会自动创建集合。
 - db.name.insert({"name" : "菜鸟"})
 
### MongoDB 使用insert()或save()方法向集合中插入文档，语法如下：
 - db.collection.insert(document)
 - db.collection.insertOne({}):向指定集合中插入一条文档数据
 - db.collection.insertMany([{},{}]):向指定集合中插入多条文档数据
- 插入文档你也可以使用 db.collection.save(document) 命令。如果不指定_id字段save()方法类似于insert()方法。如果指定_id字段，则会更新该_id的数据。
 
### 更新已存在的文档[update/updateOne/updateMany]
 ```javascript
db.collection.update(
   <query>,
   <update>,
   {
     "upsert": <boolean>,
     "multi": <boolean>,
     "writeConcern": <document>
   }
)  
```
 - 参数说明：
  - query : update的查询条件，类似sql update查询内where后面的。
  - update : update的对象和一些更新的操作符（如$,$inc...）等，也可以理解为sql update查询内set后面的
  - upsert : 可选，这个参数的意思是，如果不存在update的记录，是否插入objNew,true为插入，默认是false，不插入。
  - multi : 可选，mongodb默认是false,只更新找到的第一条记录，如果这个参数为true,就把按条件查出来多条记录全部更新。
  - writeConcern :可选，抛出异常的级别。

### updateOne/updateMany方法要求更新条件部分必须具有以下之一，否则将报错: 
- $set/$unset
- $push/$pushAll/$pop
- $pull/$pullAll
- $addToSet

### 使用update更新数组
- $push: 增加一个对象到数组底部
- $pushAll: 增加多个对象到数组底部
- $pop: 从数组底部删除一个对象
- $pull: 如果匹配指定的值，从数组中删除相应的对象
- $pullAll: 如果匹配任意的值，从数据中删除相应的对象
- $addToSet: 如果不存在则增加一个值到数组

### 删除文档
  - db.inventory.deleteMany({}) 删除所有
  - db.inventory.deleteOne( { status: "D" } ) 删除 status 等于 D 的一个文档
  - db.inventory.deleteMany({ status : "A" }) 删除 status 等于 A 的全部文档
  - db.testcol.remove( { } ) // 删除所有记录 
  - db.testcol.remove() //报错
  - 注意remove()方法并不会真正释放空间。需要继续执行db.repairDatabase()来回收磁盘空间。
  - db.repairDatabase()或者 db.runCommand({repairDatabase: 1 })

### 查询文档
  - db.collection.find(query, projection)
    - query ：可选，使用查询操作符指定查询条件
      - 等于	{<key>:<value>}	db.col.find({"by":"菜鸟"}).pretty()	where by = '菜鸟'
      - 小于	{<key>:{$lt:<value>}}	db.col.find({"likes":{$lt:50}}).pretty()	where likes < 50
      - 小于或等于	{<key>:{$lte:<value>}}	db.col.find({"likes":{$lte:50}}).pretty()	where likes <= 50
      - 大于	{<key>:{$gt:<value>}}	db.col.find({"likes":{$gt:50}}).pretty()	where likes > 50
      - 大于或等于	{<key>:{$gte:<value>}}	db.col.find({"likes":{$gte:50}}).pretty()	where likes >= 50
      - 不等于	{<key>:{$ne:<value>}} db.col.find({"likes":{$ne:50}}).pretty()	where likes != 50
    - projection ：可选，使用投影操作符指定返回的键。查询时返回文档中所有键值， 只需省略该参数即可（默认省略）。
  - db.col.find().pretty() 以格式化的方式来显示所有文档。
  - MongoDB中条件操作符有：
    - (>) 大于 - $gt
    - (<) 小于 - $lt
    - (>=) 大于等于 - $gte
    - (<= ) 小于等于 - $lte
  - 若不指定 projection，则默认返回所有键，指定 projection 格式如下，有两种模式
    - db.collection.find(query, {title: 1, by: 1}) // inclusion模式 指定返回的键，不返回其他键
    - db.collection.find(query, {title: 0, by: 0}) // exclusion模式 指定不返回的键,返回其他键
      - 两种模式不可混用（因为这样的话无法推断其他键是否应返回）
      - db.collection.find(query, {title: 1, by: 0}) // 错误
      
### 除了可以使用limit()方法来读取指定数量的数据外，还可以使用skip()方法来跳过指定数量的数据，skip方法同样接受一个数字参数作为跳过的记录条数。
  - db.collection.find().limit(NUMBER).skip(NUMBER)

### MongoDB排序
  - db.collection.find().sort({KEY:1}) 在 MongoDB 中使用 sort() 方法对数据进行排序，sort() 方法可以通过参数指定排序的字段，并使用 1 和 -1 来指定排序的方式，其中 1 为升序排列，而 -1 是用于降序排列。

### 在数组中搜索子对象的多个字段时，如果使用 $elemMatch，它表示必须是同一个 子对象满足多个条件。考虑以下两个查询:
```javascript
db.getCollection('movies').find({
       "filming_locations.city": "Rome",
       "filming_locations.country": "USA"
      })
      db.getCollection('movies').find({
       "filming_locations": {
       $elemMatch:{"city":"Rome", "country": "USA"}
} })
```

### find查询时可以指定返回的字段[1:返回，0:不反悔，_id字段必须明确指明不返回否则默认返回]
```javascript
db.movies.find({"filming_locations.country": "USA"},{"_id":0, title:1})
```



