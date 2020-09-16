# 

### Mapping中的字段一旦设定后，禁止直接修改。因为倒排索引生成后不允许直接修改。需要重新建立新的索引，做reindex操作。
- 类似数据库中的表结构定义，主要作用
- 定义索引下的字段名字
- 定义字段的类型
- 定义倒排索引相关的配置（是否被索引？采用的Analyzer）

### Dynamic Mapping
- 在写入文档的时候，如果索引不存在，会自动创建索引
- Dynamic Mapping 的机制，使得我们无需手动定义 Mappings。Elasticsearch 会自动根据文档信息，推算出字段的类型
- 但是会有时候推算不对。例如地理位置信息
- 当类型如果设置不对时，会导致一些功能无法正常运行，例如 Range 查询

### 类型的自动识别
| JSON 类型 | Elasticsearch 类型                               |
| --------- | ------------------------------------------------ |
| 字符串    | 1 匹配日期格式设置成 Date                        |
|           | 2 设置数字设置为 float 或者 long，该选项默认关闭 |
|           | 3 设置为 Text, 并增加 keyword 子字段             |
| 布尔值    | boolean                                          |
| 浮点数    | float                                            |
| 整数      | long                                             |
| 对象      | Object                                           |
| 数组      | 由第一个非空数值的类型所决定                     |
| 空值      | 忽略                                             |


### 字段的数据类型
- 简单类型
    Text / Keyword
    Date
    Integer / Floating
    Boolean
    IPv4 & IPv6
- 复杂类型 - 对象和嵌套对象
- 对象类型 / 嵌套类型
- 特殊类型
    geo_point & geo_shape / percolator
- Elasticsearch 中不提供专门的数组类型。但是任何字段，都可以包含多个相同类型的数值

### 能否更改 Mapping 的字段类型
- 两种情况
- 新增字段
    Dynamic 设置为 true 时，一定有新增字段的文档写入，Mapping 也同时被更新
    Dynamic 设为 false，Mapping 不会被更新，自增字段的数据无法被索引，但是信息会出现在_source 中
    Dynamic 设置成 Strict 文档写入失败
- 对已有字段，一旦已经有数据写入，就不在支持修改字段定义
  Luene 实现的倒排索引，一旦生成后，就不允许修改
- 如果希望改变字段类型，必须 Reindex API，重建索引
- 原因
    如果修改了字段的数据类型，会导致已被索引的属于无法被搜索
    但是如果是增加新的字段，就不会有这样的影响

# 当 Elasticsearch 自带的分词器无法满足时，可以自定义分词器。通过自组合不同的组件实现
    Character Filter
    Tokenizer
    Token Filter

### Character Filters
在 Tokenizer 之前对文本进行处理，例如增加删除及替换字符。可以配置多个 Character Filters。会影响 Tokenizer 的 position 和 offset 信息
一些自带的 Character Filters
HTML strip - 去除 html 标签
Mapping - 字符串替换
Pattern replace - 正则匹配替换

### Tokenizer
将原始的文本按照一定的规则，切分为词（term or token）
Elasticsearch 内置的 Tokenizers
whitespace | standard | uax_url_email | pattern | keyword | path hierarchy
可以用 JAVA 开发插件，实现自己的 Tokenizer

### Token Filters
将 Tokenizer 输出的单词，进行增加、修改、删除
自带的 Token Filters
Lowercase |stop| synonym（添加近义词）


- ik_max_word
- ik_smart
- hanlp: hanlp默认分词
- hanlp_standard: 标准分词
- hanlp_index: 索引分词
- hanlp_nlp: NLP分词
- hanlp_n_short: N-最短路分词
- hanlp_dijkstra: 最短路分词
- hanlp_crf: CRF分词（在hanlp 1.6.6已开始废弃）
- hanlp_speed: 极速词典分词





### 结构化数据
结构化搜索（Structured search） 是指对结构化数据的搜索
日期，布尔类型和数字都是结构化
文本也可以是结构化的
如彩色笔可以有离散的颜色集合：红（red）、绿（green）、蓝（blue）
一个博客可能被标记了标签，例如，分布式（distributed）和搜索（search）
电商网站上的商品都有 UPCs（通用产品码 Universal Product Codes）或其他的唯一标识，它们都遵从严格规定的、结构化的格式
布尔、时间，日期和数字这类结构化数据：有精确的格式，我们可以对这些格式进行逻辑操作。包括比较数字或时间的范围，或判断两个值的大小
结构化的文本可以做到精确匹配或者部分匹配
Term 查询 / Prefix 前缀查询
结构化结构只有 “是” 或 “否” 两个值
根据场景需要，可以决定结构化搜索是否需要打分

### 什么时候用 term 跟 match查询
结构化数据的精确匹配，就使用term查询。日期属于结构化数据。match主要用于文本的full-text查询,Term 查询是包含，不是完全相等。针对多值字段查询要尤其注意

### 相关性算分 - Relevance
搜索的相关性算分，描述了一个文档和查询语句匹配的程度。ES 会对每个匹配查询条件的结构进行算分_score
打分的本质是排序 , 需要把最符合用户需求的文档排在前面。ES 5 之前，默认的相关性打分采用 TF-IDF，现在采用 BM25

### Multi Match
- 三种场景
最佳字段（Best Fields）
    当字段之间相互竞争，又相互关联。例如 title 和 body 这样的字段，评分来自最匹配字段
多数字段（Most Fields）
    处理英文内容时：一种常见的手段是，在主字段（English Analyzer），抽取词干，加入同义词，以匹配更多的文档。相同的文本，加入子字段（Standard Analyzer），以提供更加精确的匹配。其他字段作为匹配文档提高性相关度的信号。匹配字段越多越好
混合字段（Cross Field）
    对于某些实体，例如人名，地址，图书信息。需要在多个字段中确定信息，单个字段只能作为整体的一部分。希望在任何这些列出的字段中尽可能找出多的词
- 使用多字段匹配解决
用广度匹配字段 title 包括尽可能多的文档 - 以提高召回率 ，同时又使用字段 title.std 作为信息将相关度更高的文档结至于文档顶部
每个字段对于最终评分的贡献可以通过自定义值 boost 来控制。比如，使 title 字段更为重要，这样同时也降低了其他信号字段的作用
- 跨字段搜索
most_fields 无法使用 opeartor
可以用 copy_to 解决，但是需要额外的储存空间
cross_fields 可以支持 operator
与 copy_to 相比，其中一个优势就是可以在搜索时为某个字段提升权重
```
PUT address/_doc/1
{
  "street":"5 Poland Street",
  "city" : "Lodon",
  "country":"United Kingdom",
  "postcode" : "W1V 3DG"
}

POST address/_search
{
  "query":{
    "multi_match": {
      "query": "Poland Street W1V",
      "type": "cross_fields",
      "operator": "and", 
      "fields": ["street","city","country","postcode"]
    }
  }
}
```

# 搜索建议
帮助用户在输入搜索的过程中，进行自动补全或者纠错。通过协助用户输入更加精准的关键词，提高后续搜索阶段文档匹配的程度
搜索引擎中类似的功能，在 ES 中通过 Sugester API 实现的
原理：将输入的文档分解为 Token，然后在索引的字段里查找相似的 Term 并返回
根据不同的使用场景，ES 设计了 4 种类别的 Suggesters
Term & Phrase Suggester
Complete & Context Suggester

#### Suggester 就是一种特殊类型的搜索。“text” 里是调用时候提供的文本，通常来自用户界面上用户输入的内容
用户输入的 “lucen” 是一个错误的拼写
会到 指定的字段 “body” 上搜索，当无法搜索到结果时（missing），返回建议的词
- 几种 Suggestion Mode
    missing - 如索引中已存在，就不提供建议
    popular - 推荐出现频率更加高的词
    always - 无论是否存在，都提供建议

```
POST article/_search
{
  "size": 1,
  "query": {
    "match": {
      "body": "lucen rock"
    }
  },
  "suggest": {
    "term-suggestion": { //自定义名称
      "text": "lucen rock",
      "term": {
        "suggest_mode": "missing",
        "field": "body"
      }
    }
  }
}


//返回结果
"suggest" : {
    "term-suggestion" : [
      {
        "text" : "lucen",
        "offset" : 0,
        "length" : 5,
        "options" : [
          {
            "text" : "lucene",//推荐了
            "score" : 0.8,
            "freq" : 2
          }
        ]
      },
      {
        "text" : "rock",//没有推荐
        "offset" : 6,
        "length" : 4,
        "options" : [ ]
      }
    ]
  }
  每个建议都包含了一个算分，相似性是通过 Levenshtein Edit Distance 的算法实现的。核心思想就是一个词改动多少字段就可以和另外一个词一致。提供了很多可选参数来控制相似性的模糊程度。
  ```

###  Phrase Suggester
Phrase Suggesetr 上增加了一些额外的逻辑
- suggeset_mode ： missing,popular ,always
- max_errors: 最多可以拼错的 Terms 数
- condfidence ： 限制返回结果数，默认为 1
```
POST article/_search
{
  "suggest": {
    "my-suggestion": { //自定义名称
      "text": "lucne and elasticsear rock hello world ", //输入内容
      "phrase": {
        "field": "body",
        "max_errors":2,
        "confidence":0,
        "direct_generator":[{
          "field":"body",
          "suggest_mode":"always"
        }],
        "highlight": {
          "pre_tag": "<em>",
          "post_tag": "</em>"
        }
      }
    }
  }
}
```

### The Completion Suggester
Completion Suggester 提供了 “自动完成”（Auto Complete）的功能。用户每输入一个字符，就需要即时发送一个插叙请求到后端查询匹配项
对性能要求比较苛刻。ES 采用了不同的数据结构，并非通过倒排索引来完成。而是将 Analyze 的数据编码成 FST 和索引一起存放。FST 会被 ES 整个加载进内容，速度很快
FST 只能用于前缀查找
```
//设置comments的mapping信息
PUT comments/_mapping
{
  "properties":{
    "comment_autocomplete":{
      "type":"completion",
      "contexts":[{
       "type":"category",
       "name":"comment_category"
      }]
    }
  }
}
//添加movies类型的索引
POST comments/_doc
{
  "comment": "I love the star war movies",
  "comment_autocomplete": {
    "input": ["star wars"],
    "contexts": {
      "comment_category": "movies"
    }
  }
}
//添加coffee类型的索引
POST comments/_doc
{
  "comment":"Where can I find a Starbucks",
  "comment_autocomplete":{
    "input":["starbucks"],
    "contexts":{
      "comment_category":"coffee"
    }
  }
} 
//输入sta查询
POST comments/_search
{
  "suggest": {
    "MY_SUGGESTION": {
      "prefix": "sta",
      "completion":{
        "field":"comment_autocomplete",
        "contexts":{
         //"comment_category":"movies" 
          "comment_category":"coffee"  
        }
      }
    }
  }
}
//返回结果
 "suggest" : {
    "MY_SUGGESTION" : [
      {
        "text" : "sta",
        "offset" : 0,
        "length" : 3,
        "options" : [
          {
            "text" : "starbucks",
            "_index" : "comments",
            "_type" : "_doc",
            "_id" : "wXX-i3QBPYS-ktvJMVfM",
            "_score" : 1.0,
            "_source" : {
              "comment" : "Where can I find a Starbucks",
              "comment_autocomplete" : {
                "input" : [
                  "starbucks"
                ],
                "contexts" : {
                  "comment_category" : "coffee"
                }
              }
            },
            "contexts" : {
              "comment_category" : [
                "coffee"
              ]
            }
          }
        ]
      }
    ]
  }
```

### 跨集群搜索 - Cross Cluster Search
ES5.3 引入跨集群搜索的功能（Cross Cluster Search），推荐使用
允许任何节点扮演 federated 节点，以轻量的方式，将搜索请求进行代理
不需要以 Client Node 的形式加入其它集群
- 启动3个集群
bin/elasticsearch -E node.name=cluster0node -E cluster.name=cluster0 -E path.data=cluster0_data -E discovery.type=single-node -E http.port=9200 -E transport.port=9300
bin/elasticsearch -E node.name=cluster1node -E cluster.name=cluster1 -E path.data=cluster1_data -E discovery.type=single-node -E http.port=9201 -E transport.port=9301
bin/elasticsearch -E node.name=cluster2node -E cluster.name=cluster2 -E path.data=cluster2_data -E discovery.type=single-node -E http.port=9202 -E transport.port=9302
- 在每个集群上设置动态的设置
PUT _cluster/settings
{
  "persistent": {
    "cluster": {
      "remote": {
        "cluster0": {
          "seeds": [
            "127.0.0.1:9300"
          ],
          "transport.ping_schedule": "30s"
        },
        "cluster1": {
          "seeds": [
            "127.0.0.1:9301"
          ],
          "transport.compress": true,
          "skip_unavailable": true
        },
        "cluster2": {
          "seeds": [
            "127.0.0.1:9302"
          ]
        }
      }
    }
  }
}
- cURL
curl -XPUT "http://localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
{"persistent":{"cluster":{"remote":{"cluster0":{"seeds":["127.0.0.1:9300"],"transport.ping_schedule":"30s"},"cluster1":{"seeds":["127.0.0.1:9301"],"transport.compress":true,"skip_unavailable":true},"cluster2":{"seeds":["127.0.0.1:9302"]}}}}}'

curl -XPUT "http://localhost:9201/_cluster/settings" -H 'Content-Type: application/json' -d'
{"persistent":{"cluster":{"remote":{"cluster0":{"seeds":["127.0.0.1:9300"],"transport.ping_schedule":"30s"},"cluster1":{"seeds":["127.0.0.1:9301"],"transport.compress":true,"skip_unavailable":true},"cluster2":{"seeds":["127.0.0.1:9302"]}}}}}'

curl -XPUT "http://localhost:9202/_cluster/settings" -H 'Content-Type: application/json' -d'
{"persistent":{"cluster":{"remote":{"cluster0":{"seeds":["127.0.0.1:9300"],"transport.ping_schedule":"30s"},"cluster1":{"seeds":["127.0.0.1:9301"],"transport.compress":true,"skip_unavailable":true},"cluster2":{"seeds":["127.0.0.1:9302"]}}}}}'  

- 创建测试数据
curl -XPOST "http://localhost:9200/users/_doc" -H 'Content-Type: application/json' -d'
{"name":"user1","age":10}'

curl -XPOST "http://localhost:9201/users/_doc" -H 'Content-Type: application/json' -d'
{"name":"user2","age":20}'

curl -XPOST "http://localhost:9202/users/_doc" -H 'Content-Type: application/json' -d'
{"name":"user3","age":30}'

- 查询
GET /users,cluster1:users,cluster2:users/_search
{
  "query": {
    "range": {
      "age": {
        "gte": 20,
        "lte": 40
      }
    }
  }
}

### 协调节点(Coordinating Node)
处理请求的节点，叫 Coordinating Node
- 路由请求到正确的节点，例如创建索引的请求，需要路由到Master节点
- 所有节点默认都是Coordinating Node
- 创建/删除索引的请求，只能被Master节点处理
- 通过将其他类型设置成false ，使其成为专用的协调节点(Dedicated Coordinating Node)
  
### 数据节点（Data Node）
可以保存数据的节点，叫做Data Node
- 节点启动后，默认就是数据节点。可以设置 node.data:false 禁止
- 保存分片数据。在数据扩展上起到了至关重要的作用（由 Master Node 决定把分片分发到数据节点上）
- 通过增加数据节点可以解决数据水平扩展和解决数据单点的问题

### 主节点（Master Node）
- 处理创建/删除索引等请求 / 决定分片被分配到哪个节点 
- 更新 Cluster State

### Master Eligible Nodes
一个集群支持配置多个Master Eligble（有资格竞选Master的）节点。这些节点可以在必要时（如Master节点出现故障）参与选主流程，成为Master节点
- 每个节点启动后，默认就是一个 Master Eligible 节点:可以设置node.data:false
- 当属于集群内的第一Master Eligible节点时候，它会将自己选举成Master节点

### Master Eligible Nodes的选主流程
- 互相ping对方。Node Id 低的会成为被选举的节点
- 其他节点会加入集群，但是不承担Master节点的角色。一旦发现被选中的主节点丢失，就会选举新的Master节点

### 集群状态
集群状态信息（Cluster State），维护了一个集群中必要的信息，包括：所有的节点信息、所有的索引和其相关的 Mapping 与 Setting 信息、分片的路由信息
- 在每个节点都保存了集群的状态信息，但是，只有Master节点才能修改集群的状态信息，并负责同步给其他节点因为，任意节点都能修改信息会导致Cluster State信息不一致
  
### 如何避免脑裂问题
限定一个选举条件，这是quorum（仲裁），只有在Master eligble节点数大于quorum时，才能进行选举：Quorum = (master 节点总数 / 2) +1

### 一个节点默认是一个Master Eligible Node（有资格竞选master节点）/Data Node/Ingest Node
| 节点类型          | 配置参数         | 默认值                      |
| ----------------- | ---------------- | --------------------------- |
| Maste Eligible    | node.master      | true                        |
| Data Node         | node.data        | true                        |
| Ingest Node       | node.ingest      | ture                        |
| Coordinating Only | ⽆                | 设置上⾯三个参数全部为 false |
| Machine           | learning node.ml | true (需要 enable x-pack)   |


# shard(分片)
分片是 ES 分布式储存的基石:主分片 / 副本分片

### primary shard(主分片) - 提高数据可用性
通过主分片，将数据分布在所有节点上,默认值为 1
- Primary Shard可以将一份索引的数据，分散在多个Data Node上，实现储存的水平扩展
- 主分片（Primary Shard）数在索引创建时候指定，后续默认不能修改，如要修改，需重建索引

### Replica Shard - 提高数据可用性
- 通过引入副本分片（Replica Shard）提高数据的可用性。一旦主分片丢失，副本分片可以Promote（升级）成主分片。副本分片数可以动态调整的。每个节点上都有完备的数据。如果不设置副本分片，一旦出现节点故障，就有可能造成数据丢失。
- 副本分片数据由主分片（Primary Shard）同步。通过增加Replica（副本）个数，一定程度可以提高读取的吞吐量

### 如何规划一个索引的主分片数和副本分片数
- 主分片数过小：例如创建一个 1 个 Primary Shard 的 index,如果该索引增长很快，集群无法通过增加节点实现对这个索引的数据扩展
- 主分片数设置过大：导致单个 Shard 容量很小，引发一个节点上有过多分片，影响性能
- 副本分片设置过多，会降低集群整体的写入性能

### 单节点集群
副本无法分片，集群状态为黄色

### 1个Master节点，1个Data节点
集群状态转为绿色,集群具备故障转移能力

### 1个Master节点，2个Data节点
Master节点会决定分片分配到哪个节点，通过增加节点数，提高集群的计算能力

### 集群健康状态
- Green : 健康状态，所有的主分片和副本分片都可用
- Yellow: 亚健康，所有的主分片可用，部分副本分片不可用
- Red：不健康状态，部分主分片不可用

### 文档会存储在具体的某个主分片和副本分片上：例如文档1，会储存在主分片（P0）副本分片（R0）上

### 文档到分片的路由算法
shard = hash(_routing) % number_of_primary_shards
    Hash算法确保文档均匀分散到分片中
    默认的_routing值是文档id
    可以自行制定routing数值，例如用相同国家的商品，都分配到制定的shard
    设置Index Setting后，主分片（Primary shard）数，不能随意修改的根本原因

### 更新文档流程:index -> hash -> route -> delete -> index -> success -> response
![更新文档流程](https://cdn.learnku.com/uploads/images/201912/18/29212/66MmOFTfsG.png)

### 删除一个文档:detele -> hash&route -> delete -> delete replica -> success -> deleted -> response
![删除文档流程](https://cdn.learnku.com/uploads/images/201912/18/29212/qUeDNJysfC.png)

### 分片
- 分片是ES中最小的工作单元
- 分片是一个Lucence 的Index

### 为甚删除文档，并不会立刻释放空间

### 为什么 ES 的搜索时近实时的（1 秒后被搜到）
    将Index Buffer写入es，但不执行刷新，Refresh频率默认1秒发生一次，可通过 index.refresj_interval配置。Refresh 后，数据就可以被搜索到了。

### 倒排索引的不可变性
    不许考虑并发写文件的问题，避免了锁机制带来的性能问题
    一旦读入内核的文件系统缓存，便留在那里，只要文件系统存有足够的空间，大部分请求就会直接请求内存，不会命中磁盘，提高了很大的性能
    缓存容易生成和维护 / 数据可以被压缩

### Lucence Index
- 在 Lucene 中，单个倒排索引文件被称为 Segment。Segment 是自包含的，不可变更的。多个 Segment 汇总在一起，称为 Lucene 的 Index，其对应的就是 ES 中的 Shard
- 当有新文档写入时，会生成新的 Segment, 查询时会同时查询所有的 Segment，并且对结果汇总。Luncene 中有个文件，用来记录所有的 Segment 的信息，叫做 Commit Point
- 删除的文档信息，保存在”.del” 文件中
![Lucence Index](https://cdn.learnku.com/uploads/images/201912/21/29212/rqHt7DDjoq.png)

### 刷新（Refresh）
- 将 Index buffer 写入 Segment 的过程叫做 Refresh。Refresh 不执行 fsync 操作
- Refresh 频率：默认 1 秒发生一次，可通过 index.refresj_interval 配置。Refresh 后，数据就可以被搜索到了。这也就是为什么 ES 被称为近实时搜索
- 如果系统有大量的数据写入，那就会产生很多的 Segment
- Index Buffer 被占满时，会触发 Refresh, 默认值是 JVM 的 10%
![刷新（Refresh）](https://cdn.learnku.com/uploads/images/201912/21/29212/ZdYiqooHdy.png)

### 事物日志（Transaction Log）
- Segment 写入磁盘的过程相对耗时，借助文件系统缓存，Refresh 时，先将 Segment 写入缓存以开放查询
- 为了保证数据不会丢失。所有在 Index 文档时，同时写 Transaction Log，高版本开始，ra 默认落盘。每个分片都有一个 Transaction Log
- 当ES Refresh时，Index Buffer被清空，Transaction Log不会清空
![](https://cdn.learnku.com/uploads/images/201912/21/29212/KxNcCt3KzF.png)

### Flush
- 调用 Refresh ，Index Buffer 清空并且 Refresh
- 调用 fsync, 将缓存中的 Segments 写入磁盘
- 清空（删除）Transaction Log
- 默认30分钟调用一次
- Transaction Log满（默认512M）
![](https://cdn.learnku.com/uploads/images/201912/21/29212/mSRldP0ySd.png)

### 合并（Merge）
Segment很多，需要定期被合并,减少Segment/删除已经删除的文档
ES和Lucene会自动进行Merge操作,调用接口强制刷新：POST _index/_forcemerge

### es的查询会分成2个阶段，1.查询，2fetch

### Query阶段
用户发出搜索请求到ES节点，节点收到请求后会以（协调者）Coordinating 节点的身份，在主副分片中随机选择几个分片，发送查询请求，被选中的分片执行查询，进行排序。然后，每个分片都会返回 From + Size 个排序后的文档Id和排序值给（协调）Coordinating节点
![Query阶段](https://cdn.learnku.com/uploads/images/201912/21/29212/ZevsuQ0O4e.png)

### Fetch阶段
- 协调节点(Coordinating Node)会将Query阶段，从每个分片获取的排序后的文档Id列表，重新进行排序。选取 From 到 From + Size个文档的Id以multi get请求的方式，到相应的分片获取详细的文档数据

### Query Then Fetch 潜在的问题
- 性能问题
    每个分片上需要查的文档个数 = from + size
    最终协调节点需要处理：number_of_shard * (from + size)
    深度分页
- 相关性算分
  每个分片都基于自己的分片上的数据进行相关度计算。这会导致打分偏离的情况，特别是数据量很少时，如果文档总数很好的情况下，如果主分片大于 1，主分片越多，相关性算分会越不准

### 解决算分不准的方法
- 数据量不大的时候，可以将主分片数设置为 1
- 当数据量足够大时候，只要保证文档均匀分散在各个分片上，结果一般就不会出现偏差
- 使用 DFS Query Then Fetch,搜索的 URL 中指定参数 “_search?search_type=dfs_query_then_fetch”到每个分片把各分片的词频和文档频率进行搜集，然后完整的进行一次相关性算分，消耗更加多的 CPU 和内存，执行性能低下，一般不建议使用

### 排序
ES 默认采用相关性算分对结果进行降序排序
可以通过设置 sorting 参数，自行设定排序
如果不指定_score, 算分为 null
```
POST _index/_search
{
    "size" : 5
    "query":{
        "match_all":{}
    },
    "sort":[
     {
        "order_field":{
            "order:"desc"
        }
     } 
    ]
}
```

### 多字段进行排序
组合多个条件
优先考虑写在前面的排序
支持对相关性算分进行排序
```
POST /**/_search
{
    "size" : 5
    "query":{
        "match_all":{}
    },
    "sort":[
      {"order_field":{"order:"desc"}},
      {"_doc":{"order:"asc"}},
      {"_score":{"order:"desc"}},
    ]
}
```

### 对Text类型排序
//对 text 字段进行排序。默认会报错，需打开fielddata
```
PUT kibana_sample_data_ecommerce/_mapping
{
  "properties": {
    "sort_field": {
      "type": "text",
      "fielddata": true,
      "fields": {
        "keyword": {
          "type": "keyword",
          "ignore_above": 256
        }
      }
    }
  }
}
```

### 排序的过程
- 排序是针对字段原始内容进行的。倒排索引无法发挥作用
- 需要用到正排索引。通过文档ID和字段快速得到字段原始内容
- ES有2种实现方式:Fielddata/Doc Values (列式存储，对 Text 类型无效）
  
| --       | Doc Values                                                          | Field data                       |
| -------- | ------------------------------------------------------------------- | -------------------------------- |
| 何时创建 | 索引时，和倒排索引一起创建                                          | 搜索时候动态创建                 |
| 创建位置 | 磁盘文件                                                            | JVM Heap                         |
| 优点     | 避免大量内存占用                                                    | 索引速度快，不占用额外的磁盘空间 |
| 缺点     | 降低索引速度，占用额外磁盘空间	文档过多时，动态创建开销大，占用过多 | JVM Heap                         |
| 缺省值   | ES 2.x 之后                                                         | ES1.x 及之前                     |

### 打开 Fielddata
默认关闭，可以通过 Mapping 设置打开。修改设置后，即时生效，无需缩减索引
支持对 Text 进行设定,其他字段类型不支持
打开后，可以对 Text 字段进行排序，但是结果无法满足预期，不建议使用
部分情况下打开，满足一些聚合分析的特定需求

### 关闭Doc Values
默认启动，可以通过 Mapping设置关闭?增减索引速度/减少磁盘空间
如果重新打开，需要重建索引
什么时候需要关闭?明确不需要做排序及聚合分析
```
PUT _index/_mapping
{
  "properties": {
    "field_name": {
      "type": "keyword",
      "doc_values": false
    }
  }
}
```

### 获取Doc Values&Fielddata中储存的内容
Text类型的不支持Doc Values
Text类型打开Fielddata后，可以查看分词后的数据

### from/size
默认情况下，查询按照相关度算分排序，返回前10条记录
容易理解的分页方案:from-开始位置size-期望获取文档的总数

### 分布式系统中深度分页的问题
ES天生就是分布式，查询信息，但是数据分别保存在多个分片，多台机器，ES 天生就需要满足排序的需要（按照相关性算分）
当一个查询：from = 990 ，size =10会在每个分片上先获取 1000 个文档。然后，通过 Coordinating Node 聚合所有结果。最后在通过排序选取前 1000 个文档
页数越深，占用内容越多。为了避免深度分页带来的内存开销。ES 有个设定，默认限定到 10000 个文档
![](https://cdn.learnku.com/uploads/images/201912/23/29212/0V7DB4WKyH.png)

### Search After避免深度分页的问题
- 避免深度分页的性能问题，可以实时获取下一页文档信息,不支持指定页数（From）,不能往下翻
- 第一步搜索需要指定 sort，并且保证值是唯一的（可以通过加入_id 保证唯一性）,然后使用上一次，最后一个文档的 sort 值进行查询
```
//第一次查询
POST users/_search
{
  "size": 1,
  "query": {
      "match_all": {}
  },
  "sort": [
      {"age": "desc"} ,
      {"_id": "asc"}
  ]
}

//返回结果

{
"took" : 0,
"timed_out" : false,
"_shards" : {
  "total" : 1,
  "successful" : 1,
  "skipped" : 0,
  "failed" : 0
},
"hits" : {
  "total" : {
    "value" : 5,
    "relation" : "eq"
  },
  "max_score" : null,
  "hits" : [
    {
      "_index" : "users",
      "_type" : "_doc",
      "_id" : "I5aMPW8Bb23XqE-8Pu1n",
      "_score" : null,
      "_source" : {
        "name" : "user2",
        "age" : 13
      },
      "sort" : [
        13,
        "I5aMPW8Bb23XqE-8Pu1n"
      ]
    }
  ]
}
}
//第二次查询
POST users/_search
{
  "size": 1,
  "query": {
      "match_all": {}
  },
  "search_after":
       [
        10,
        "H5aMPW8Bb23XqE-8IO1c"
      ],
  "sort": [
      {"age": "desc"} ,
      {"_id": "asc"}
  ]
}
```
- Search After 是如何解决深度分页的问题?假设Size是10,当查询 990 -100,通过唯一排序值定位，将每次要处理的文档都控制在10

### Scoll API
创建一个快照，有新的数据写入以后，无法被查找,每次查询后，输入上一次的 Sroll Id
```
//第一次查询
POST /users/_search?scroll=1m
{
  "size": 1,
  "query": {
      "match_all" : {
      }
  }
}
//第二次查询
POST /_search/scroll
{
  "scroll" : "1m",
  "scroll_id" : "DXF1ZXJ5QW5kRmV0Y2gBAAAAAAAAFpIWR1liUWY4WXVUZktYMWFqdW1UbzExUQ=="
}

```

### 不同的搜索类型和使用场景
常规(Regular)：需要实时获取顶部的部分文档。例如查询最新的订单
滚动(scroll)：需要全部文档，例如导出全部数据
分页(Page)：from和size。如果需要深度分页，则选用Search After

### 聚合(Aggregation)的语法
Aggregation 属于 Search 的一部分。一般情况下，建议将其 Size 指定为 0
![](https://cdn.learnku.com/uploads/images/201912/26/29212/oo7yURZQZC.png)
![](https://cdn.learnku.com/uploads/images/201912/26/29212/vQPKEQ5Uzr.png)

### Mertric Aggregation
- 单值分析：只输出一个分析结果
    min，max，avg，sum
    Cardinality（类似 distinct Count）
- 多值分析：输出多个分析结果
    stats ,extended stats
    percentile, percentile rank
    top hits （排在前面的示例）

### Bucket + Metric Aggregation
Bucket聚合分析允许通过添加子聚合分析进一步分析，子聚合分析可以是:Bucket、Metric
一个聚合查询中可以包含多个聚合：每个 Bucket 聚合可以包含多个子聚合

### Pipeline
管道的概念：支持对聚合分析的结果，再次进行聚合分析
Pipeline 的分析结果会输出到原结果汇总，根据位置的不同，分为两类
- Sibling - 结果和现有分析结果同级
    Max，min，Avg&Sum Bucket
    Stats ， Extened Status Bucket
    Percentiles Bucket
- Parent - 结果内嵌到现有的聚合分析结果之中
    Derivative（求导）
    Cumultive Sum（累计求和）
    Moving Function（滑动窗口）

### 统计平均工资最低的工作岗位
```
POST employees/_search
{
  "size": 0,
  "aggs": {
    "jobs": {
      "terms": {
        "field": "job.keyword",
        "size": 10
      },
      "aggs": {
        "avg_salary": {
          "avg": {
            "field": "salary"
          }
        }
      }
    },
    "min_salary_by_job": {
      "min_bucket": {
        "buckets_path": "jobs>avg_salary"
      }
    }
  }
}
```

### 统计每个工作岗位平均工资的平均工资
```
POST employees/_search
{
  "size": 0,
  "aggs": {
    "jobs": {
      "terms": {
        "field": "job.keyword",
        "size": 10
      },
      "aggs": {
        "avg_salary": {
          "avg": {
            "field": "salary"
          }
        }
      }
    },
    "avg_salary_by_job": {
      "avg_bucket": {
        "buckets_path": "jobs>avg_salary"
      }
    }
  }
}
```

### 按年龄、对工资进行求导（看工资发展的趋势）
```
POST employees/_search
{
  "size": 0,
  "aggs": {
    "age": {
      "histogram": {
        "field": "age",
        "min_doc_count": 1,
        "interval": 1
      },
      "aggs": {
        "avg_salary": {
          "avg": {
            "field": "salary"
          }
        },
        "derivative_avg_salary": {
          "derivative": {
            "buckets_path": "avg_salary"
          }
        }
      }
    }
  }
}
```

# Parent Pipeline
基于父聚集的管道聚集包括moving_avg、moving_fn、bucket_script、bucket_selector、bucket_sort、derivative、cumulative_sum、serial_diff八种
### 按照age分桶，计算平均薪资，累计平均薪资
```
POST employees/_search
{
  "size": 0,
  "aggs": {
    "age": {
      "histogram": {
        "field": "age",
        "min_doc_count": 1,
        "interval": 1
      },
      "aggs": {
        "avg_salary": {
          "avg": {
            "field": "salary"
          }
        },
        "cumulative_salary": {
          "cumulative_sum": {
            "buckets_path": "avg_salary"
          }
        }
      }
    }
  }
}
```

### Moving Function
moving_avg和moving_fn这两种管道聚集的运算机制相同，都是基于滑动窗口( Siding Window)算法对父聚集的结果做新的聚集运算。滑动窗口算法使用一个具有固定宽度的窗口滑过一组数据， 在滑动的过程中对落在窗口内的数据做运算。moving_avg管道聚集是对落在窗口内的父聚集结果做平均值运算，而moving_fn管道聚集则可以对落在窗口内的父聚集结果做各种自定义的运算。由于moving_avg管道可以使用moving_fn管道聚集实现，所以moving_avg在Elaticearch版本6.4.0中已经被废止。由于使用滑动窗口运算时每次移动1个位置，这就要求moving_avg和moving_fn所在聚集桶与桶间隔必须固定，所以这两种管道聚集只能在histogam和date_histogam聚集中使用
```
POST employees/_search
{
  "size": 0,
  "aggs": {
    "age": {
      "histogram": {
        "field": "age",
        "min_doc_count": 1,
        "interval": 1
      },
      "aggs": {
        "avg_salary": {
          "avg": {
            "field": "salary"
          }
        },
        "moving_avg_salary":{
          "moving_fn": {
            "buckets_path": "avg_salary",
            "window":10,
            "script": "MovingFunctions.min(values)"
          }
        }
      }
    }
  }
}
```

### 对查询结果， 按照职位分桶，统计年龄大于30的人数
```
POST employees/_search
{
  "size": 0,
  "query": {
    "range": {
      "age": {
        "gte": 30
      }
    }
  },
  "aggs": {
    "jobs": {
      "terms": {
        "field": "job.keyword"
      }
    }
  }
}
```

# 排序 order
### 查询年龄大于20的记录，按照职位分桶根据count数正序，key倒序排序
```
POST employees/_search
{
  "size": 0,
  "query": {
    "range": {
      "age": {
        "gte": 20
      }
    }
  },
  "aggs": {
    "jobs": {
      "terms": {
        "field": "job.keyword",
        "order": [
          {
            "_count": "asc"
          },
          {
            "_key": "desc"
          }
        ]
      }
    }
  }
}
```

### Filter过滤: 统计年龄大于35的人员职位数，统计所有职位人数
```
POST employees/_search
{
  "size": 0,
  "aggs": {
    "older_person": {
      "filter": {
        "range": {
          "age": {
            "from": 35
          }
        }
      },
      "aggs": {
        "jobs": {
          "terms": {
            "field": "job.keyword"
          }
        }
      }
    },
    "all_jobs": {
      "terms": {
        "field": "job.keyword"
      }
    }
  }
}
```

# Post_Filter 是对聚合分析后的文档进行再次过滤，Size无需设置为0
使用场景：一条语句，获取聚合信息 + 获取符合条件的文档
### 按照职位分桶统计，并查询职位为Dev的用户信息
```
POST employees/_search
{
  "aggs": {
    "jobs": {
      "terms": {
        "field": "job.keyword"
      }
    }
  },
  "post_filter": {
    "match": {
      "job.keyword": "Dev Manager"
    }
  }
}
```
# global
### 查询年龄大于40并按照职位分桶统计，all计算所有人的平均工资
```
POST employees/_search
{
  "size": 0,
  "query": {
    "range": {
      "age": {
        "gte": 40
      }
    }
  },
  "aggs": {
    "jobs": {
      "terms": {
        "field":"job.keyword"
      }
    },
    "all":{
      "global":{}, // Golbal，无视query，对全部文档进行统计
      "aggs":{
        "salary_avg":{
          "avg":{
            "field":"salary"
          }
        }
      }
    }
  }
}
```

# 基于子聚合的值排序
### 按照职位分桶统计并按照子聚合平均薪资降序排列
```
POST employees/_search
{
  "size": 0,
  "aggs": {
    "jobs": {
      "terms": {
        "field": "job.keyword",
        "order": [
          {
            "avg_salary": "desc"
          }
        ]
      },
      "aggs": {
        "avg_salary": {
          "avg": {
            "field": "salary"
          }
        }
      }
    }
  }
}
```

### 按照职位分桶统计并按照子聚合统计的min降序排序
```
POST employees/_search
{
  "size": 0,
  "aggs": {
    "jobs": {
      "terms": {
        "field": "job.keyword",
        "order": [
          {
            "stats_salary.min": "desc"
          }
        ]
      },
      "aggs": {
        "stats_salary": {
          "stats": {
            "field": "salary"
          }
        }
      }
    }
  }
}
```

### 在 Terms Aggregation 的返回中有两个特殊的数值
doc_count_error_upper_bound：被遗漏的 term 分桶，包含的文档，有可能的最大值
sum_other_doc_count: 处理返回结果 bucket 的 terms 以外，其他 terms 的文档总数（总数 - 返回的总数）

### 如何解决 Terms 不准的问题：提升 shard_size 的参数
Terms聚合分析不准的原因，数据分散在多个分片上，协调节点(Coordinating Node)无法获取数据全貌
    解决方案 1：当数据量不大时，设置Primary Shard为1；实现准确性
    解决方案 2：在分布式数据上，设置shard_size参数，提高精确度,因为每次从Shard上额外多获取数据，提升准确率

### 打开 show_term_doc_count_error
```
POST employees/_search
{
  "size": 0,
  "aggs": {
    "jobs": {
      "terms": {
        "field": "job.keyword",
        "size": 1,
        "show_term_doc_count_error":true

      }
    }
  }
}
```

### shard_size 设定
调整shard size大小，降低doc_count_error_upper_bound来提升准确度
增加整体计算量，提高了准确率，但会降低相应时间
Shard Size 默认大小设定:shard size = size * 1.5 +10
```
POST kibana_sample_data_flights/_search
{
  "size": 0,
  "aggs": {
    "weather": {
      "terms": {
        "field": "OriginWeather",
        "size": 1,
        "shard_size": 1,
        "show_term_doc_count_error": true
      }
    }
  }
}
```

### 关系型数据库，一般会考虑范式化(Normalize) 数据；在 Elasticsearch，往往考虑反范式(Denormalize) 数据
反范式设计(Denormalize)的好处：读的速度变快、无需表连接、无需行锁

### Elasticsearch并不擅长处理关联关系，一般采用以下四种方法处理关联
对象类型、嵌套对象（Nested Object）、父子关联关系（Parent 、Child）、应用端关联

### 设置文档mapping，对象嵌套
```
PUT /blog
{
  "mappings": {
    "properties": {
      "content": {
        "type": "text"
      },
      "time": {
        "type": "date"
      },
      "user": {
        "properties": {
          "city": {
            "type": "text"
          },
          "userid": {
            "type": "long"
          },
          "username": {
            "type": "keyword"
          }
        }
      }
    }
  }
}
```

### 为啥有时搜不到嵌套的对象数组文档
- 储存时，内部对象的边界没有在考虑在内，JSON格式被处理成扁平键值对的结构
- 当对多个字段进行查询时，导致了意外的搜索结果
- 可以用 Nested Data Type 解决这个问题

### Nested Data Type
Nested 数据类型：允许对象数组中的对象被独立索引
使用Nested和Properties关键词，将所有数组索引到多个分隔的文档
在内部，Nested文档会被保存在两个Lucene 文档中，查询时做join处理
```
PUT my_movies
{
      "mappings" : {
      "properties" : {
        "actors" : {
          "type": "nested",
          "properties" : {
            "first_name" : {"type" : "keyword"},
            "last_name" : {"type" : "keyword"}
          }},
        "title" : {
          "type" : "text",
          "fields" : {"keyword":{"type":"keyword","ignore_above":256}}
        }
      }
    }
}
```

### 嵌套查询
```
# Nested 查询
POST my_movies/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "match": {
            "title": "Speed"
          }
        },
        {
          "nested": {
            "path": "actors", //嵌套对象名称
            "query": {
              "bool": {
                "must": [
                  {
                    "match": {
                      "actors.first_name": "Keanu"
                    }
                  },
                  {
                    "match": {
                      "actors.last_name": "Reeves"
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }
}
```

# 嵌套聚合(Nested Aggregation)

### 根据嵌套对象actors属性聚合统计
```
POST my_movies/_search
{
  "size": 0,
  "aggs": {
    "actors": {
      "nested": {
        "path": "actors"
      },
      "aggs": {
        "actor_name": {
          "terms": {
            "field": "actors.first_name",
            "size": 10
          }
        }
      }
    }
  }
}
```

### 父子关系(Parent/Child)
- 对象和 Nested 对象的局限性
    每次更新，需要重新索引整个对象（包括根对象和嵌套对象）
- ES 提供了类似关系型数据库中 Join 的实现。使用 Join 数据类型实现，可以通过 Parent / Child 的关系，从而分离两个对象
    父文档和子文档是两个独立的文档
    更新父文档无需重新索引整个子文档。子文档被新增，更改和删除也不会影响到父文档和其他子文档。
- 定义父子关系的几个步骤
    设置索引的 Mapping
    索引父文档
    索引子文档
    按需查询文档

### 设置索引的 Mapping
```
PUT my_blogs
{
  "settings": {
    "number_of_shards": 2
  },
  "mappings": {
    "properties": {
      "blog_comments_relation": {
        "type": "join",
        "relations": {
          "blog": "comment"
        }
      },
      "content": {
        "type": "text"
      },
      "title": {
        "type": "keyword"
      }
    }
  }
}
```

### 索引子文档
```
PUT my_blogs/_doc/1
{
  "title": "Learning Elasticsearch",
  "content": "learning ELK @ geektime",
  "blog_comments_relation": {
    "name": "blog"
  }
}
```

### 索引子文档
父文档和子文档必须存在相同的分片上: 确保查询 join 的性能
当指定文档时候，必须指定它的父文档ID:使用 route 参数来保证，分配到相同的分片
```
PUT my_blogs/_doc/1?routing=1
{
  "comment":"I am learning ELK",
  "username":"Jack",
  "blog_comments_relation":{
    "name":"comment",
    "parent":"1"
  }
}
```

### 父子关系(Parent/Child) 所支持的查询
- 查询所有文档/Parent Id 查询/Has Child 查询/Has Parent 查询

- 查询所有文档
```
POST my_blogs/_search
{}
```

- 根据父文档ID查看,返回父文档
```
GET my_blogs/_doc/2
```

- Parent Id查询，返回子文档
```
POST my_blogs/_search
{
  "query": {
    "parent_id": {
      "type": "comment",
      "id": "1" //父文档id
    }
  }
}
```

- Has Child查询,通过对子文档进行查询,返回父文档
因为父子文档在相同的分片上，因此 Join 效率高
```
POST my_blogs/_search
{
  "query": {
    "has_child": {
      "type": "comment", //子文档名称
      "query": {
        "match": {
          "username": "Jack" //子文档属性
        }
      }
    }
  }
}
```

- Has Parent查询，通过对父文档进行查询,返回相关的子文档
```
POST my_blogs/_search
{
  "query": {
    "has_parent": {
      "parent_type": "blog", //父文档名称
      "query": {
        "match": {
          "title": "Learning Hadoop" //父文档属性
        }
      }
    }
  }
}

```
- 通过子文档id,查询子文档
```
GET my_blogs/_doc/child_id
```

- 通过子文档id和routing=父文档id,查询子文档
```
GET my_blogs/_doc/child_id?routing=parent_id
```

嵌套对象 VS 父子文档
|          | Nested Object                        | Parent/Child                             |
| -------- | ------------------------------------ | ---------------------------------------- |
| 优点     | 文档存储在一起，读取性能高           | 父子文档可以独立更新                     |
| 缺点     | 更新嵌套的子文档时，需要更新整个文档 | 需要额外的内存去维护关系。读取性能相对差 |
| 适用场景 | 子文档偶尔更新，以查询为主           | 子文档更新频繁                           |

