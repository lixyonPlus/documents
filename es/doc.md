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

