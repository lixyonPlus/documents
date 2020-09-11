# 系统相关查询语句

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


# crud语句

### 创建文档使用自动生成_id
POST _index/_doc
{
	"user" : "Mike",
    "post_date" : "2019-04-15T14:12:12",
    "message" : "trying out Kibana"
}

### 创建文档指定Id，如果id已经存在，报错
PUT _index/_doc/1?op_type=create/index
{
    "user" : "Jack",
    "post_date" : "2019-05-15T14:12:12",
    "message" : "trying out Elasticsearch"
}

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

### 通过id查询文档
GET _index/_doc/1

### url search
  q: 指定查询语句，语法为 Query String Syntax
  df: q中不指定字段时默认查询的字段，如果不指定，es会查询所有字段(泛查询)
  sort：排序
  timeout：指定超时时间，默认不超时
  from,size：用于分页

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

### 通过在设置mapping的时候设置copy_to为fullName，实现以下查询，copy_to 的目标字段不出现在_source 中
GET _index/_search?q=fullName:(www com)

# 聚合查询

### 按照DestCountry的值进行分桶统计
GET kibana_sample_data_flights/_search
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

#### 按照DestCountry的值进行分桶统计并根据AvgTicketPrice计算平均价格/最高价格/最低价格
GET kibana_sample_data_flights/_search
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

###嵌套查询，按照DestCountry的值进行分桶统计并根据DestWeather分词统计不同的天气，根据AvgTicketPrice统计不同维度的价格
GET kibana_sample_data_flights/_search
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
				    "size": 5
				  }
				}
			}
		}
	}
}