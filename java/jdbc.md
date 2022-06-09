## java.sql.Driver
### 获取Driver实现
前提：数据库驱动Driver实现会显式地调用java.sql.DriverManager#registerDriver方法
- 通过ClassLoader加载Driver实现（Class.forName("xxxxx")）
- 通过java SPI ServiceLoad获取Driver实现（读取META-INFO/service下配置文件）
- 通过“jdbc.drivers”系统属性

### 多个Driver同时被加载到Classloader，使用哪一个
- 通过jdbc url尝试连接每个Driver，直到成功。

### sql执行结果接口 ResultSet
    - ORM框架基于此实现

### sql元数据接口 ResultSetMetaData
    - mybatis generate 基于此实现

 ### 事务保护点 SavePoint

 ### Introspector java提供的内省类，可以获取类信息   