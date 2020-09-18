### 离线迁移
离线迁移需要先停止老集群的写操作，将数据迁移完毕后在新集群上进行读写操作。适合于业务可以停服的场景。
- 离线迁移大概有以下几种方式：
elasticsearch-dump
snapshot
reindex
logstash
elasticsearch-dump
- 适用场景
适合数据量不大，迁移索引个数不多的场景
- 使用方式
elasticsearch-dump是一款开源的ES数据迁移工具，github地址: https://github.com/taskrabbit/elasticsearch-dump

---

- 安装elasticsearch-dump
elasticsearch-dump使用node.js开发，可使用npm包管理工具直接安装：
```
npm install elasticdump -g
```
```
主要参数说明
--input: 源地址，可为ES集群URL、文件或stdin,可指定索引，格式为：{protocol}://{host}:{port}/{index}
--input-index: 源ES集群中的索引
--output: 目标地址，可为ES集群地址URL、文件或stdout，可指定索引，格式为：{protocol}://{host}:{port}/{index}
--output-index: 目标ES集群的索引
--type: 迁移类型，默认为data,表明只迁移数据，可选settings, analyzer, data, mapping, alias
```
- 迁移单个索引
以下操作通过elasticdump命令将集群172.16.0.39中的companydatabase索引迁移至集群172.16.0.20。注意第一条命令先将索引的settings先迁移，如果直接迁移mapping或者data将失去原有集群中索引的配置信息如分片数量和副本数量等，当然也可以直接在目标集群中将索引创建完毕后再同步mapping与data
```
    elasticdump --input=http://172.16.0.39:9200/companydatabase --output=http://172.16.0.20:9200/companydatabase --type=settings
    elasticdump --input=http://172.16.0.39:9200/companydatabase --output=http://172.16.0.20:9200/companydatabase --type=mapping
    elasticdump --input=http://172.16.0.39:9200/companydatabase --output=http://172.16.0.20:9200/companydatabase --type=data
```

- 迁移所有索引：
以下操作通过elasticdump命令将将集群172.16.0.39中的所有索引迁移至集群172.16.0.20。 注意此操作并不能迁移索引的配置如分片数量和副本数量，必须对每个索引单独进行配置的迁移，或者直接在目标集群中将索引创建完毕后再迁移数据
```
 elasticdump --input=http://172.16.0.39:9200 --output=http://172.16.0.20:9200
 ```

### snapshot迁移索引
- 适用场景
适用数据量大的场景
- 使用方式
snapshot api是Elasticsearch用于对数据进行备份和恢复的一组api接口，可以通过snapshot api进行跨集群的数据迁移，原理就是从源ES集群创建数据快照，然后在目标ES集群中进行恢复。需要注意ES的版本问题：
```
目标ES集群的主版本号(如5.6.4中的5为主版本号)要大于等于源ES集群的主版本号;
1.x版本的集群创建的快照不能在5.x版本中恢复;
```
- 源ES集群中创建repository
创建快照前必须先创建repository仓库，一个repository仓库可以包含多份快照文件，repository主要有一下几种类型:
```
 fs: 共享文件系统，将快照文件存放于文件系统中
 url: 指定文件系统的URL路径，支持协议：http,https,ftp,file,jar
 s3: AWS S3对象存储,快照存放于S3中，以插件形式支持
 hdfs: 快照存放于hdfs中，以插件形式支持 cos: 快照存放于腾讯云COS对象存储中，以插件形式支持
```
如果需要从自建ES集群迁移至腾讯云的ES集群，可以直接使用fs类型仓库，注意需要在Elasticsearch配置文件elasticsearch.yml设置仓库路径：
```
path.repo: ["/usr/local/services/test"]
```
之后调用snapshot api创建repository：
```
 curl -XPUT http://172.16.0.39:9200/_snapshot/my_backup -H       'Content-Type: application/json' -d '{
     "type": "fs",     "settings": {         "location": "/usr/local/services/test" 
         "compress": true
     }
 }'
```
如果需要从其它云厂商的ES集群迁移至腾讯云ES集群，或者腾讯云内部的ES集群迁移，可以使用对应云厂商他提供的仓库类型，如AWS的S3, 阿里云的OSS，腾讯云的COS等
```
 curl -XPUT http://172.16.0.39:9200/_snapshot/my_s3_repository
 {     "type": "s3",     "settings": {     "bucket": "my_bucket_name",     "region": "us-west"
     }
 }
```
- 源ES集群中创建snapshot
调用snapshot api在创建好的仓库中创建快照
```
 curl -XPUT http://172.16.0.39:9200/_snapshot/my_backup/snapshot_1?wait_for_completion=true
```
创建快照可以指定索引，也可以指定快照中包含哪些内容，具体的api接口参数可以查阅官方文档
- 目标ES集群中创建repository
目标ES集群中创建仓库和在源ES集群中创建仓库类似，用户可在腾讯云上创建COS对象bucket， 将仓库将在COS的某个bucket下。
- 移动源ES集群snapshot至目标ES集群的仓库
把源ES集群创建好的snapshot上传至目标ES集群创建好的仓库中
- 从快照恢复
```
 curl -XPUT http://172.16.0.20:9200/_snapshot/my_backup/snapshot_1/_restore
```
- 查看快照恢复状态
```
 curl http://172.16.0.20:9200/_snapshot/_status
```
---

### reindex
reindex是Elasticsearch提供的一个api接口，可以把数据从源ES集群导入到当前的ES集群，同样实现了数据的迁移，限于腾讯云ES的实现方式，当前版本不支持reindex操作。简单介绍一下reindex接口的使用方式。
- 配置reindex.remote.whitelist参数
需要在目标ES集群中配置该参数，指明能够reindex的远程集群的白名单
- 调用reindex api
以下操作表示从源ES集群中查询名为test1的索引，查询条件为title字段为elasticsearch，将结果写入当前集群的test2索引
```
POST _reindex
{
  "source": {
    "remote": {
      "host": "http://172.16.0.39:9200"
    },
    "index": "test1",
    "query": {
      "match": {
        "title": "elasticsearch"
      }
    }
  },
  "dest": {
    "index": "test2"
  }
}
```
--- 

### logstash
logstash支持从一个ES集群中读取数据然后写入到另一个ES集群，因此可以使用logstash进行数据迁移，具体的配置文件如下：
```
    input {
        elasticsearch {
            hosts => ["http://172.16.0.39:9200"]
            index => "*"
            docinfo => true
        }
    }
    output {
        elasticsearch {
            hosts => ["http://172.16.0.20:9200"]
            index => "%{[@metadata][_index]}"
        }
    }
```
上述配置文件将源ES集群的所有索引同步到目标集群中，当然可以设置只同步指定的索引，logstash的更多功能可查阅logstash官方文档。

### 总结
elasticsearch-dump和logstash做跨集群数据迁移时，都要求用于执行迁移任务的机器可以同时访问到两个集群，不然网络无法连通的情况下就无法实现迁移。而使用snapshot的方式没有这个限制，因为snapshot方式是完全离线的。因此elasticsearch-dump和logstash迁移方式更适合于源ES集群和目标ES集群处于同一网络的情况下进行迁移，而需要跨云厂商的迁移，比如从阿里云ES集群迁移至腾讯云ES集群，可以选择使用snapshot的方式进行迁移，当然也可以通过打通网络实现集群互通，但是成本较高。
elasticsearchdump工具和mysql数据库用于做数据备份的工具mysqldump工具类似，都是逻辑备份，需要将数据一条一条导出后再执行导入，所以适合数据量小的场景下进行迁移；
snapshot的方式适合数据量大的场景下进行迁移。