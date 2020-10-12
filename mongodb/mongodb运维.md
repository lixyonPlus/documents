# 问题诊断工具 - mongostat
![](https://s1.ax1x.com/2020/10/12/0R0xQe.png)
mongostat: 用于了解 MongoDB 运行状态的工具

# 问题诊断工具 - mongotop
![](https://s1.ax1x.com/2020/10/12/0RBawR.png)
mongotop: 用于了解集合压力状态的工具

# 问题诊断 - mtools
https://github.com/rueckstiess/mtools
![](https://s1.ax1x.com/2020/10/12/0RB5ff.png)
- 安装:pip install mtools 
-  常用指令:
   - mplotqueries 日志文件:将所有慢查询通过图表形式展现
   - mloginfo --queries 日志文件:总结出所有慢查询的模式和出现次数、消耗时间等;

### 同步
1. 数据库导出导入
步骤:
- 停止现有的基于 RDBMS 的应用
- 使用 RDBMS 的数据库导出工具，将数据库表导出到 CSV 或者 JSON(如 mysqldump)
- 使用 mongoimport 将 CSV 或者 JSON 文件导入 MongoDB 数据库
- 启动新的 MongoDB 应用
备注:
- 适用于一次性数据迁移
- 需要应用/数据库下线，较长的下线时间

2. 批量同步
步骤:
- 安装同步工具(如 Kettle / Talend)
- 创建输入源(关系型数据库)
- 创建输出源(MongoDB)
- 编辑数据同步任务
- 执行
备注:
- 适用批量同步，定期更新, 特别是每晚跑批的场景
- 支持基于时间戳的增量同步，需要源表有合适的时间戳支持
- 对源库有较明显的性能影响，不宜频繁查询
- 不支持实时同步

3. 实时同步
步骤:
- 安装实时同步工具(如Informatica / Tapdata)
- 创建输入源(关系型数据库)
- 创建输出源(MongoDB)
- 编辑实时数据同步任务
- 执行
备注:
- 基于源库的日志文件解析机制，可以实现秒级数据的同步 - 对源库性能影响较小
- 可以支持应用的无缝迁移

### 数据迁移方式比较
![](https://s1.ax1x.com/2020/10/12/0R4VUS.png)
