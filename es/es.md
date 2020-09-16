# 系统相关查询语句

---

### 查看索引相关信息
GET kibana_sample_data_ecommerce
 
### 查看索引的文档总数
GET kibana_sample_data_ecommerce/_count

### 查看前10条文档，了解文档格式
POST kibana_sample_data_ecommerce/_search
{}

### 查看indices
GET /_cat/indices/msc-use*?v&s=index

### 查看状态为绿的索引
GET /_cat/indices?v&health=green

### 按照文档个数排序
GET /_cat/indices?v&s=docs.count:desc

### 查看具体的字段
GET /_cat/indices/msc-use*?pri&v&h=health,index,pri,rep,docs.count,mt

### 查看文档占用的内存大小
GET /_cat/indices?v&h=i,tm&s=tm:desc

### 查看所有节点
GET _cat/nodes?v

### 查看指定的节点
GET /_nodes/es7_hot

### 查看所有节点,显示指定的字段
GET /_cat/nodes?v&h=id,ip,port,v,m

### 查看集群健康状态
GET _cluster/health?level=shards

### 查看指定索引的集群健康状态
GET /_cluster/health/msc-user

### 集群状态
GET /_cluster/state

### 查看集群的配置信息
GET /_cluster/settings
GET /_cluster/settings?include_defaults=true

---

# crud语句

### 重建索引
- 应用背景：
  1.当你的数据量过大，而你的索引最初创建的分片数量不足，导致数据入库较慢的情况，此时需要扩大分片的数量，此时可以尝试使用Reindex
  2.当数据的mapping需要修改，但是大量的数据已经导入到索引中了，重新导入数据到新的索引太耗时；但是在ES中，一个字段的mapping在定义并且导入数据之后是不能再修改的，所以这种情况下也可以考虑尝试使用Reindex
- Reindex：ES提供了_reindex这个API。相对于我们重新导入数据肯定会快不少，实测速度大概是bulk导入数据的5-10倍。
- 但如果新的index中有数据，并且可能发生冲突，那么可以设置version_type"version_type": "internal"或者不设置，则Elasticsearch强制性的将文档转储到目标中，覆盖具有相同类型和ID的任何内容
```
POST _reindex
{
  "source": {
    "index": "kibana_sample_data_flights"
  },
  "dest": {
    "index": "my_flights",
    "version_type": "internal" 
  }
}
```

- 常规的如果我们只是进行少量的数据迁移利用普通的reindex就可以很好的达到要求，但是当我们发现我们需要迁移的数据量过大时，我们会发现reindex的速度会变得很慢,数据量几十个G的场景下，elasticsearch reindex速度太慢，从旧索引导数据到新索引，当前最佳方案是什么？
原因分析：
reindex的核心做跨索引、跨集群的数据迁移。
慢的原因及优化思路无非包括：
    1）批量大小值可能太小。需要结合堆内存、线程池调整大小；
    2）reindex的底层是scroll实现，借助scroll并行优化方式，提升效率；
    3）跨索引、跨集群的核心是写入数据，考虑写入优化角度提升效率。
可行方案：
1）提升批量写入大小值:默认情况下，_reindex使用1000进行批量操作，您可以在source中调整batch_size。
```
POST _reindex
{
  "source": {
    "index": "source",
    "size": 5000
  },
  "dest": {
    "index": "dest",
    "routing": "=cat"
  }
}
```
批量大小设置的依据：
- 1、使用批量索引请求以获得最佳性能
批量大小取决于数据、分析和集群配置，但一个好的起点是每批处理5-15 MB。注意，这是物理大小。文档数量不是度量批量大小的好指标。例如，如果每批索引1000个文档:
1）每个1kb的1000个文档是1mb。
2）每个100kb的1000个文档是100 MB。
这些是完全不同的体积大小。
- 2、逐步递增文档容量大小的方式调优
1）从大约5-15 MB的大容量开始，慢慢增加，直到你看不到性能的提升。然后开始增加批量写入的并发性(多线程等等)。
2）使用kibana、cerebro或iostat、top和ps等工具监视节点，以查看资源何时开始出现瓶颈。如果您开始接收EsRejectedExecutionException，您的集群就不能再跟上了:至少有一个资源达到了容量。要么减少并发性，或者提供更多有限的资源(例如从机械硬盘切换到ssd固态硬盘)，要么添加更多节点。
- 3、借助scroll的sliced提升写入效率
Reindex支持Sliced Scroll以并行化重建索引过程。 这种并行化可以提高效率，并提供一种方便的方法将请求分解为更小的部分。
sliced原理（from medcl）
  1）用过Scroll接口吧，很慢？如果你数据量很大，用Scroll遍历数据那确实是接受不了，现在Scroll接口可以并发来进行数据遍历了。
  2）每个Scroll请求，可以分成多个Slice请求，可以理解为切片，各Slice独立并行，利用Scroll重建或者遍历要快很多倍。
slicing使用举例: slicing的设定分为两种方式：手动设置分片、自动设置分片。
自动设置分片如下：
```
POST _reindex?slices=5&refresh
{
  "source": {
    "index": "twitter"
  },
  "dest": {
    "index": "new_twitter"
  }
}
```
slices大小设置注意事项：
1）slices大小的设置可以手动指定，或者设置slices设置为auto，auto的含义是：针对单索引，slices大小=分片数；针对多索引，slices=分片的最小值。
2）当slices的数量等于索引中的分片数量时，查询性能最高效。slices大小大于分片数，非但不会提升效率，反而会增加开销。
3）如果这个slices数字很大(例如500)，建议选择一个较低的数字，因为过大的slices 会影响性能。
效果:实践证明，比默认设置reindex速度能提升10倍+。

---

### 创建文档使用自动生成_id
POST _index/_doc
{
	"user" : "Mike",
  "post_date" : "2019-04-15T14:12:12",
  "message" : "trying out Kibana"
}

### 创建文档指定Id，如果op_type=create时且id已存在，报错
PUT _index/_doc/1?op_type=create/index
{
    "user" : "Jack",
    "post_date" : "2019-05-15T14:12:12",
    "message" : "trying out Elasticsearch"
}

### index和create区别
  - index时会检查_version。如果插入时没有指定_version，那对于已有的doc，_version会递增，并对文档覆盖。插入时如果指定_version，如果与已有的文档_version不相等，则插入失败，如果相等则覆盖，_version递增。

### 创建文档指定Id，如果id已经存在，报错
PUT _index/_create/1
{
    "user" : "Jack",
    "post_date" : "2019-05-15T14:12:12",
    "message" : "trying out Elasticsearch"
}

### 在原文档上增加字段,原文档不存在报错
POST _index/_update/1
{
    "doc":{
        "message" : "trying out Elasticsearch"
    }
}

### update
 - 由于Lucene中的update其实就是覆盖替换，并不支持针对特定Field进行修改，Elasticsearch中的update为了实现针对特定字段修改，在Lucene的基础上做了一些改动。每次update都会调用 InternalEngine 中的get方法，来获取整个文档信息，从而实现针对特定字段进行修改，这也就导致了每次更新要获取一遍原始文档，性能上会有很大影响。所以根据使用场景，有时候使用index会比update好很多。


### 更新指定id的文档.(存在：先删除，在写入，不存在：直接写入)
PUT _index/_doc/1
{
	"user" : "Tom"
}

### 删除文档通过id（存在：result=deleted，不存在：result=not found）
DELETE _index/_doc/1

### 批量执行（第二次执行相同的语句errors=true，但是version版本号会增加)
POST _bulk
{ "index" : { "_index" : "test", "_id" : "1" } }
{ "field1" : "value1" }
{ "delete" : { "_index" : "test", "_id" : "2" } }
{ "create" : { "_index" : "test2", "_id" : "3" } }
{ "field1" : "value3" }
{ "update" : {"_id" : "1", "_index" : "test"} }
{ "doc" : {"field2" : "value2"} }

### url search
  q: 指定查询语句，语法为 Query String Syntax
  df: q中不指定字段时默认查询的字段，如果不指定，es会查询所有字段(泛查询)
  sort：排序
  timeout：指定超时时间，默认不超时
  from,size：用于分页

### 通过id查询文档
GET _index/_doc/1

### 根据指定的字段内容查询文档
GET _index/_search?q=field:value

### 根据模糊索引加指定的字段内容查询文档
GET _index_prefix*/_search?q=key:value

### 查询所有索引中指定的字段内容查询文档
GET _all/_search?q=key:value

### 泛查询,查询所有字段中等于value的记录
GET _index/_search?q=value

### 查询_index中key中包含value的记录和泛查询otherValue(查询所有字段中包含该值的记录)
GET _index/_search?q=key:value otherValue

### 使用引号，Phrase查询(查询key包含短语,短语顺序不能改变)
GET _index/_search?q=key:"value1 value2"

### 分组，Bool查询(查询key中包含value1或value2的记录)
GET _index/_search?q=key:(value1 value2)

### 查询索引中key包含value1和value2的记录
GET _index/_search?q=key:(value1 AND value2)

### 查询索引中key包含value1且不包含value2的记录
GET _index/_search?q=key:(value1 NOT value2)

### 查询索引中key必须包含value2和包含value1的记录
GET _index/_search?q=key:(value1 %2Bvalue2)
- ‘+ 必须包含，- 必须不包含’

### 查询索引中key1包含value1且满足key2区间范围的记录
GET _index/_search?q=key1:value1 AND key2:[date1 TO date2]
- 区间写法，闭区间用[],开区间用{}

### 查询索引中key1大于value1的记录
GET _index/_search?q=key1>value1
- 算数符号 >=1,>=1&&<=10/+>=1 +<=10

### 通配符查询
### 查询_index中key的内容以prefix开头的记录
GET _index/_search?q=key:prefix*
- ？代表一个字符，*代表0或多个字符

### 模糊匹配
### 模糊查询_index中key值为与value相差1个character的记录
GET _index/_search?q=key:value~1

### 近似度匹配
### 查询_index中key值为与value相差2个character的记录
GET _index/_search?q=key:"value"~2

### 批量查询
GET /_mget
{
    "docs" : [
        {
            "_index" : "test",
            "_id" : "1"
        },
        {
            "_index" : "test2",
            "_id" : "3"
        }
    ]
}

### 根据_index批量查询
GET /_index/_mget
{
    "docs" : [
        {

            "_id" : "1"
        },
        {

            "_id" : "2"
        }
    ]
}

### 根据条件批量匹配查询
GET /_mget
{
    "docs" : [
        {
            "_index" : "test",
            "_id" : "1",
            "_source" : false
        },
        {
            "_index" : "test",
            "_id" : "2",
            "_source" : ["field3", "field4"]
        },
        {
            "_index" : "test",
            "_id" : "3",
            "_source" : {
                "include": ["user"],
                "exclude": ["user.location"]
            }
        }
    ]
}

### msearch批量查询
POST _index/_msearch
{}
{"query" : {"match_all" : {}},"size":1}
{"index" : "users"}
{"query" : {"match_all" : {}},"size":2}

### 清除数据
DELETE _index

### 手动安装分词器
sudo bin/elasticsearch-plugin install file:///analysis-icu-7.5.0.zip


### 查看分词器结果
POST _analyze
{
  "analyzer": "standard",
  "text": "Elasticsearch Server"
}

### 查看分词器结果,使用char_filter进行替换
POST _analyze
{
  "tokenizer": "standard",
  "char_filter": [
      {
        "type" : "mapping",
        "mappings" : [ "- => _"]
      }
    ],
  "text": "123-456, I-test! test-990 650-555-1234"
}

### 查看_index每个字段使用的分词器
GET _index/_mapping

### 设置_index字段的索引
PUT _index
{
  "mappings" : {
    "properties" : {
      "newField" : {
        "type" : "text",
        "copy_to": "fullName"
      },
      "lastField" : {
        "type" : "text",
        "index": false,
        "copy_to": "fullName" //copy_to 的目标字段不出现在_source 中
      },
      "mobile" : {
        "type" : "keyword", //这个如果是text 无法设置为空
        "null_value": "NULL" // 可以对null值进行索引
      }
    }
  }
}

### 查看_index分词结果
POST _index/_analyze
{
  "field": "msg",
  "text": "Eating an apple a day keeps doctor away"
}

### 指定索引中某个字段的写时分词器
PUT _index/_mapping
{
  "properties": {
    "englishName":{
      "type":"text",
      "analyzer": "english"
    }
  }
}

### 指定索引中某个字段的读时分词器
POST _index/_search
  {
    "query":{
      "match":{
        "msg":{
          "query": "eating",
          "analyzer": "english"
        }
      }
    }
  }

### 常见分词器
- Simple Analyzer – 按照非字母切分（符号被过滤），小写处理
- Stop Analyzer – 小写处理，停用词过滤（the，a，is）
- Whitespace Analyzer – 按照空格切分，不转小写
- Keyword Analyzer – 不分词，直接将输入当作输出
- Patter Analyzer – 正则表达式，默认 \W+ (非字符分隔)
- Language – 提供了30多种常见语言的分词器

# 索引模版
就是把已经创建好的某个索引的参数设置(settings)和索引映射(mapping)保存下来作为模板, 在创建新索引时, 指定要使用的模板名, 就可以直接重用已经定义好的模板中的设置和映射.

### 查看索引是否存在
HEAD _template/template_name
  a) 如果存在, 响应结果是: 200 - OK
  b) 如果不存在, 响应结果是: 404 - Not Found

### 查看所有模板
GET _template   
### 查看与通配符相匹配的模板             
GET _template/temp*         
###  查看多个模板
GET _template/temp1,temp2   
###  删除模板
DELETE _template/template_name

### 为索引建立别名
POST _aliases
{
  "actions": [
    {
      "add": {
        "index": "old_index_name", 
        "alias": "alias"
      }
    }
  ]
}
### 为索引删除别名1
POST /_aliases
{
  "actions": [
    {
      "remove": {
        "index": "old_index_name", 
        "alias": "alias"
      }
    }
  ]
}

### 为索引删除别名2
DELETE _index/_alias/alias


# Index Template
  ndex Templates 帮助你设定 Mapping 和 Settings，并按照一定的规则，自动匹配到新创建的索引之上
  模板仅在一个索引被新创建时，才会产生作用。修改模板不会影响已创建的索引
  可以设定多个索引模板，这些设置会被 merge 在一起
  可以指定 order 的数值，控制 merging 的过程
  当一个索引被新创建时
  应用Elasticsearch默认的 settings 和 mappings
  先应用order值低的IndexTemplate中的设定
  再应用order值高的IndexTemplate中的设定，之前的设定会被覆盖
  应用创建索引时，用户所指定的Settings和Mappings，并覆盖之前模板中的设定

### 创建索引模版
PUT /_template/template_name
{
    "index_patterns" : ["test*"], //匹配前缀
    "order" : 1, //模板的权重, 多个模板的时候优先匹配用, 值越大, 权重越高
    "settings" : {
    	"number_of_shards": 1, //分片数量, 可以定义其他配置项
      "number_of_replicas" : 2
    },
    "mappings" : {
    	"date_detection": false,
    	"numeric_detection": true
    }
}

### Dynamic Template
在具体的索引上指定规则，为新增的字段指定mappings
匹配条件： match_mapping_type，match，match_pattern，unmatch，path_match，path_unmatch

### 自定义dynamic_templates(动态映射)模板,将is开头的string类型的字段类型设置为boolean，将string类型设置为keyword
PUT _index
{
  "mappings": {
    "dynamic_templates": [
      {
        "strings_as_boolean": { //名称
          "match_mapping_type": "string", //匹配条件
          "match": "is*",
          "mapping": {
            "type": "boolean" //映射结果
          }
        }
      },
      {
        "strings_as_keywords": { //名称
          "match_mapping_type": "string", //匹配条件
          "mapping": {
            "type": "keyword" //映射结果
          }
        }
      }
    ]
  }
}

### 自定义dynamic_templates(动态映射)模板，将name开头的字段类型转换为text并添加到copy_to中，互忽略middle结尾的字段
PUT _index
{
  "mappings": {
    "dynamic_templates": [
      {
        "full_name": {
          "path_match": "name.*",
          "path_unmatch": "*.middle",
          "mapping": {
            "type": "text",
            "copy_to": "full_name"
          }
        }
      }
    ]
  }
}



# requestbody方式查询
  query: 符合Query DSL语法的查询语句（Query DSL: 基于json定义的查询语言
  match在匹配时会对所查找的关键词进行分词，然后按分词匹配查找，而term会直接对关键词进行查找。一般模糊查找的时候，多用match，而精确查找时可以使用term。
  match_all: 查询所有，不包含查询条件
  term是代表完全匹配，即不进行分词器分析，文档中必须包含整个搜索的词汇
  match和term的区别是,match查询的时候,elasticsearch会根据你给定的字段提供合适的分析器,而term查询不会有分析器分析的过程,match查询相当于模糊匹配,只包含其中一部分关键词就行
  match_phrase：短语查询，slop定义的是关键词之间隔多少未知单词
  multi_match:多字段查询
  term结合bool使用时：should是或，must是与，must_not是非
  from,size :分页参数
  timeout :查询超时
  sort :排序
  字段类查询：如term、match、range等，只针对某一字段进行查询
  复合查询：如bool查询等，包含一个或多个字段类查询或者复合查询语句
  
 ### 问题 
  - match和match_phrase的区别：match中的term是or关系，match_phrase是and关系，且term之间位置也会影响结果
  - 可以为text类型的字段设置Not Indexed使其无法被搜索

### url添加ignore_unavailable=true忽略不存在的索引
POST _index,404_idx/_search?ignore_unavailable=true
{
  "profile": true,
	"query": {
		"match_all": {}
	}
}

### 基于全文本的查询
基于全文本的查找：Match Query / Match Phrase Query / Query String Query
特点：索引和搜索时会进行分词，查询字符串先传递到一个合适的分词器，然后生成一个供查询的词项列表
查询时候，先会对输入的查询进行分词。然后每个词项逐个进行底层的查询，最终将结果进行合并。并未每个文档生成一个算分。 例如查 “Martix reloaded”, 会查到包括 Matrix 或者 reload 的所有结果。

# 模糊匹配查询
POST _index/_search
{ 
  "sort":[{"sort_field":"desc/asc"}],
  "from":10,
  "size":20,
  "_source":["需要显示的字段,默认显示所有字段"],
  "query":{
    "match": {
      "query": "value",
      "operator": "and/or"
      “minimum_should_match“：1  //当operator参数设置为or时，用来控制应该匹配的分词的最少数量
    }
  }
}
### 基于 Term 的查询
Term的重要性：Term 是表达语意的最小单位。搜索和利用统计语言模型进行自然语言处理都需要处理 Term
特点 ：Term Level Query：Term Query / Range Query / Exists Query / Prefix Query / Wildcard Query
在 ES 中，Term 查询，对输入不做分词。会将输入作为一个整体，在倒排索引中查找准确的词项，并且使用相关度算分公式为每个包含该词项的文档进行相关度算分 - 例如 “Apple Store”，可以通过 Constant Score 将查询转换换成一个 Filtering，避免算分，并利用缓存，提交性能

- position_increment_gap是距离查询时，最大允许查询的距离，默认是100

### term查询1，会对desc做分词
POST /products/_search
{
  "query": {
    "term": {
      "desc": {
        "value": "iphone"
      }
    }
  }
}

### term查询2，不会对desc.keyword的输入内容做分词
POST /products/_search
{
  "query": {
    "term": {
      "desc.keywork": {
        "value": "iphone"
      }
    }
  }
}




# phrase查询
POST _index/_search
{ 
  "sort":[{"sort_field":"desc/asc"}],
  "from":10,
  "size":20,
  "_source":["需要显示的字段,默认显示所有字段"],
  "query":{
    "match_phrase": {
      "query": "value",
      "slop": 1 #控制单词的间隔数（差异数）
    }
  }
}

### 多字段查询
POST _index/_search
{
  "query":{
    "multi_match": {
      "query": "value", #查询内容
      "fields": ["field"] #查询字段
    }
  }
} 

### 复合查询1 - Constant Score 转为 Filter，没有算分
POST /products/_search
{
  "explain": true,
  "query": {
    "constant_score": {
      "filter": {
        "term": {
          "productID.keyword": "XHDK-A-1293-#fJ3"
        }
      }
    }
  }
}

### 复合查询2 - Constant Score 转为 Filter，没有算分
POST products/_search
{
"query": {
  "constant_score": {
    "filter": {
      "range": {
        "date": {
           "gte": "now-1y"  //当前时间减1年
        }
      }
    }
  }
}
}


### 使用query_string多字段查询，7.0版本中query使用+-|无效
POST _index/_search
{
  "query": {
    "query_string": {
      "default_operator": "AND/OR/NOT", 
      "fields":["field1","field2"],
      "query": "(value1 AND value2) OR (value3 AND value4)"
    }
  }
}

### simple_query_string是query_string的另一种版本，其更适合为用户提供一个搜索框中，因为其使用+/|/- 分别替换AND/OR/NOT，如果输入了错误的查询，其直接忽略这种情况而不是抛出异常。Simple Query 默认的operator是 OR,query中可以使用+、|、-，默认为|，不能使用and/or/not
POST _index/_search
{
  "query": {
    "simple_query_string": {
      "default_operator": "AND/OR/NOT", 
      "query": "value1 +/|/- value2",
      "fields": ["field"]
    }
  }
}

### 脚本字段
  lang:用于指定加脚本的语言:painless/expression，默认 painless
  source/id:指定脚本的源或id用于指定我们自己预定义的脚本
  params:指定作为变量传递到脚本中的任何命名参数

### 根据脚本处理查询结果
GET _index/_search
{
  "script_fields": {
    "new_field": {
      "script": {
        "lang": "painless",
        "source": "doc['source_field'].value + params.param",
        "params": { "param": content}
      }
    }
  },
  "query": {
    "match_all": {}
  }
}

### bool查询
bool查询是组合叶子查询或复合查询子句的默认查询方式,如must,should,must_not或者filter子句;must与should子句查询最终分数由两个子句各自匹配分数相加得到,而must_not与filter子句需要在过滤查询中执行;bool查询底层由Lucene中的BooleanQuery类实现,该查询由一个或多个布尔子句组成,每个子句由特定类型声明;


### 查询字段为null的记录
POST _index/_search
{
  "query":{
    "bool": {
      "must_not": {
       "exists":{
         "field":"fieldName"
       }
      }
    }
  }
}

### 查询字段非null的记录
POST _index/_search
{
    "query" : {
        "constant_score" : {
            "filter" : {
                "exists": {
                    "field":"fieldName"
                }
            }
        }
    }
}

### 通过在设置mapping的时候设置copy_to为fullName，实现以下查询，copy_to 的目标字段不出现在_source 中
GET _index/_search?q=fullName:(www com)

# 聚合查询

### 对Text类型字段需要打开fielddata，支持terms aggregation
```
PUT employees/_mapping
{
  "properties": {
    "DestCountry": {
      "type": "text",
      "fielddata": true
    }
  }
}
```

### 按照DestCountry的值进行分桶统计
```
POST kibana_sample_data_flights/_search
{
	"size": 0, //不返回记录
	"aggs":{ //聚合
		"flight_dest":{ //自定义名称
			"terms":{ //分词
				"field":"DestCountry" //按照字段DestCountry，进行分桶统计
			}
		}
	}
}
```

### 对Term聚合统计优化
在聚合经常发生，性能高的，索引不断写入
```
PUT _index
{
  "mappings":{
    "properties":{
      "job":{
        "type":"keyword",
        "eager_global_ordinals":true
      }
    }
  }
}
```

### 按照DestCountry的值进行分桶统计，不统计重复的值
- cardinality = distinct
```
POST kibana_sample_data_flights/_search
{
  "size": 0,
  "aggs": {
    "cardinate1": {
      "cardinality": {
        "field": "DestCountry"
      }
    }
  }
}
```

### 按照DestCountry的值进行分桶统计并根据AvgTicketPrice计算平均价格/最高价格/最低价格
POST kibana_sample_data_flights/_search
{
	"size": 0, //不反悔记录
	"aggs":{
		"flight_dest":{ //自定义返回字段名
			"terms":{
				"field":"DestCountry" //分桶字段
			},
			"aggs":{
				"avg_price":{ //自定义返回字段名
					"avg":{ //计算符
						"field":"AvgTicketPrice" //计算字段
					}
				},
				"max_price":{ //自定义返回字段名
					"max":{ //计算符
						"field":"AvgTicketPrice" //计算字段
					}
				},
				"min_price":{ //自定义返回字段名
					"min":{ //计算符
						"field":"AvgTicketPrice" //计算字段
					}
				}
			}
		}
	}
}

### Salary Ranges分桶，可以自己定义key,统计每个阶段的总数
```
POST employees/_search
{
  "size": 0,
  "aggs": {
    "salary_range": {
      "range": {
        "field": "salary",
        "ranges": [
          {
            "key": "10000",
            "to": 10000
          },
          {
            "key": "10000-20000",
            "from": 10000,
            "to": 20000
          },
          {
            "key": ">20000",
            "from": 20000
          }
        ]
      }
    }
  }
}
```

### 柱状图统计,工资0到10万，以5000为一个区间进行分桶
```
POST employees/_search
{
  "size": 0,
  "aggs": {
    "salary_histrogram": {
      "histogram": {
        "field": "salary",
        "interval": 5000,
        "extended_bounds": {
          "min": 0,
          "max": 100000
        }
      }
    }
  }
}
```

### 嵌套查询,根据工作类型分桶，然后按照性别分桶，计算工资的统计信息
```
POST employees/_search
{
  "size": 0,
  "aggs": {
    "Job_gender_stats": {
      "terms": {
        "field": "job.keyword"
      },
      "aggs": {
        "gender_stats": {
          "terms": {
            "field": "gender"
          },
          "aggs": {
            "salary_stats": {
              "stats": {
                "field": "salary"
              }
            }
          }
        }
      }
    }
  }
}
```

### 嵌套查询，按照DestCountry的值进行分桶统计并根据DestWeather分词统计不同的天气，根据AvgTicketPrice统计不同维度的价格
POST kibana_sample_data_flights/_search
{
	"size": 0,
	"aggs":{
		"flight_dest":{
			"terms":{
				"field":"DestCountry"
			},
			"aggs":{
				"stats_price":{
					"stats":{
						"field":"AvgTicketPrice"
					}
				},
				"wather":{
				  "terms": {
				    "field": "DestWeather",
				    "size": 5 //只显示5条记录
				  }
				}
			}
		}
	}
}

### 查询不同工种中，年纪最大的3个员工的具体信息
POST employees/_search
{
  "size": 0,
  "aggs": {
    "jobs": {
      "terms": {
        "field": "job.keyword"
      },
      "aggs": {
        "old_employee": {
          "top_hits": {
            "size": 3,
            "sort": [
              {
                "age": {
                  "order": "desc"
                }
              }
            ]
          }
        }
      }
    }
  }
}

### boosting查询
返回匹配positive查询的文档并降低匹配negative查询的文档相似度分;
这样可以在不排除某些文档的前提下对文档进行查询,搜索结果中存在只不过相似度分数相比正常匹配的要低;
POST _index/_search
{
    "query": {
        "boosting" : {
            "positive" : {
                "term" : {
                    "content" : "elasticsearch"
                }
            },
            "negative" : {
                 "term" : {
                     "content" : "like"
                }
            },
            "negative_boost" : 2
        }
    }
}

### 基于内容的推荐查询,通常是给定一篇文档信息，然后给用户推荐与该文档相识的文档。Lucene的api中有实现查询文章相似度的接口，叫MoreLikeThis。Elasticsearch封装了该接口，通过Elasticsearch的More like this查询接口，我们可以非常方便的实现基于内容的推荐。
| 关键字                 | 描述                                                                   |
| ---------------------- | ---------------------------------------------------------------------- |
| fields                 | 要匹配的字段，如果不填的话默认是_all字段                               |
| like                   | 是匹配的文本                                                           |
| percent_terms_to_match | 匹配项（term）的百分比，默认是0.3                                      |
| min_term_freq          | 一篇文档中一个词语至少出现次数，小于这个值的词将被忽略，默认是2        |
| max_query_terms        | 一条查询语句中允许最多查询词语的个数，默认是25                         |
| stop_words             | 设置停止词，匹配时会忽略停止词                                         |
| min_doc_freq           | 一个词语最少在多少篇文档中出现，小于这个值的词会将被忽略，默认是无限制 |
| max_doc_freq           | 一个词语最多在多少篇文档中出现，大于这个值的词会将被忽略，默认是无限制 |
| min_word_len           | 最小的词语长度，默认是0                                                |
| max_word_len           | 最多的词语长度，默认无限制                                             |
| boost_terms            | 设置词语权重，默认是1                                                  |
| boost                  | 设置查询权重，默认是1                                                  |
| analyzer               | 设置使用的分词器，默认是使用该字段指定的分词器                         |

POST tmdb/_search
{
  "_source": ["title","overview"],
  "query": {
    "more_like_this": {
      "fields": [ //fields是要匹配的字段，如果不填的话默认是_all字段
        "title^10","overview"
      ],
      "like": [{"_id":"14191"}], //要匹配的文本
      "min_term_freq": 1, //一篇文档中一个词语至少出现次数，小于这个值的词将被忽略，默认是2
      "max_query_terms": 12 //一条查询语句中允许最多查询词语的个数，默认是25
    } 
  }
}

### dis_max查询与bool查询
不使用 bool 查询，可以使用 dis_max 即分离最大化查询（Disjunction Max Query） 。分离（Disjunction）的意思是 或（or） ，这与可以把结合（conjunction）理解成 与（and） 相对应。分离最大化查询（Disjunction Max Query）指的是： 将任何与任一查询匹配的文档作为结果返回，但只将最佳匹配的评分作为查询的评分结果返回。
POST /blogs/_search
{
    "query": {
        "bool": {
            "should": [
                { "match": { "title": "Brown fox" }},
                { "match": { "body":  "Brown fox" }}
            ]
        }
    }
}
- 回想一下 bool 是如何计算评分的：它会执行should语句中的两个查询。对两个查询的评分相加。乘以匹配语句的总数。除以所有语句总数。
- 如果不是简单将每个字段的评分结果加在一起，而是将最佳匹配字段的评分作为查询的整体评分，结果会怎样？这样返回的结果可能是： 同时包含brown和fox的单个字段比反复出现相同词语的多个不同字段有更高的相关度。
  
### dis_max查询
POST blogs/_search
{
    "query": {
        "dis_max": {
            "queries": [
                { "match": { "title": "Brown fox" }},
                { "match": { "body":  "Brown fox" }}
            ]
        }
    }
}

### 最佳字段查询调优
有一些情况下，同时匹配 title 和 body 字段的文档比只与一个字段匹配的文档的相关度更高
但 disjunction max query 查询指挥简单的使用单个最佳匹配语句的评分_scoce 作为整体评分
- 通过 Tie Breaker 参数调整
获得最佳匹配语句的评分
将其他匹配语句的评分 与 tie_breaker 相乘
对以上评分求和并规范化
Tie Breanker 是一个介于 0-1 之间的浮点数。0 代表使用最佳匹配;1 代表所有语句同等重要

POST blogs/_search
{
    "query": {
        "dis_max": {
            "queries": [
                { "match": { "title": "Brown fox" }},
                { "match": { "body":  "Brown fox" }}
            ],
            "tie_breaker": 0.2
        }
    }
}

### multi_match
POST titles/_search
{
  "query": {
    "multi_match": {
      "query": "barking dogs",
      "type": "most_fields", //默认是best_fields
      "fields": ["title","title.std"]//累计叠加
    }
  }
}

### 综合排序 Function Score Query 优化算分
可以在查询结束后，对每一个匹配的文档进行一系列的重新算分，根据新生成的分数进行排序
  Weight：为每一个文档设置一个简单而不被规范化的权重
  Field Value Factor：使用该数值来修改_score，例如将 “热度” 和 “点赞数” 作为算分的参考因素
  Random Score：为每一个用户使用一个不同的，随机算分结果
  Boost Mode
    Multiply：算分和函数值的乘积
    Sum：算分和函数值的和
    Min/Max：算分与函数去 最小 / 最大值
    Replace：使用函数取代算分
    Max Boost 可以将算分控制在一个最大值

POST /blogs/_search
{
  "query": {
    "function_score": {
      "query": {
        "multi_match": {
          "query":    "popularity",
          "fields": [ "title", "content" ]
        }
      },
      "field_value_factor": {
        "field": "votes", //使用votes的值与_score相乘，根据结果排序
        "modifier": "log1p", //新的算分 = 老的算分 * log（1 + 投票数）
        "factor": 1.2 //新的算分 = 老的算分 * log（1 + factor * 投票数）
      },
      "boost_mode": "sum",
      "max_boost": 3
    }
  }
}
