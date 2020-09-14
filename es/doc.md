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


