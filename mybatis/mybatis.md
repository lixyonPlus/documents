## mybatis

- Statement（namespace + id 确定一条sql）。
- mybatis加载mapper有4种方式。(package、resource、url、calss)，package优先级最高。
- mybatis有3种执行器（BatchExector、ResultExector、SimpleExector）。默认是SimpleExector
- CachingExector:内部使用SimpleExector来执行【装饰器模式】，主要是做缓存处理。
- xml与注解都有sql语句，以注解优先。
- mybatis自带逻辑分页（RowBound），对查询出的数据在内存中做分页。
- mybatis用到的设计模式：动态代理、装饰器模式、工厂模式、委托执行模式
- Mybatis的一级缓存是指Session缓存。一级缓存的作用域默认是一个SqlSession。Mybatis默认开启一级缓存。如果不想使用一级缓存，可以把一级缓存的范围指定为STATEMENT，这样每次执行完一个Mapper中的语句后都会将一级缓存清除。（同一个事务会维护一个session）
- Mybatis的二级缓存是指mapper映射文件。二级缓存的作用域是同一个namespace下的mapper映射文件内容，多个SqlSession共享。Mybatis需要手动设置启动二级缓存。二级缓存是默认启用的(要生效需要对每个Mapper进行配置)，如想取消，则可以通过Mybatis配置文件中的元素下的子元素来指定cacheEnabled为false。

  - XmlConfigBuilder： mybatis全局配置文件。
  - XmlMapperBuilder: mapper文件。 
  - XmlStatementBuilder： 一条SQL标签。
  - TypeHandler： java类型与数据库类型映射
  - ResultHandler: 返回结果映射
  - MapperProxy：mapper业务接口代理
  - MapperScannerConfigurer：BeanDefinitionRegistryPostProcessor以xml方式加载mybatis接口
  - MapperScannerRegistrar：ImportBeanDefinitionRegistrar注解扫描mybatis接口
  - 隔离级别 以数据库配置为准。


### 多表联合查询
- 嵌套查询：n+1问题(可以用懒加载解决)【association::select,Collection::select、ofType】
- 嵌套结果:【association::javaType】
- 多表查询调用方法 getPropertyMappingValue::getNestedQueryMappingValue()
- 二级缓存用联合查询时会出现 1.脏数据，2.全部失效