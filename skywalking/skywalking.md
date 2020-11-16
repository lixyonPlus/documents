## skywalking
    - 配置覆盖：只需要一个【4】agent配置文件，但是每个服务需要重写【2】-Dskywalking.agent.service_name=xxx
    - 或【1】-javaagent:/skywalking-agent.jar=agent.service_name=xxx或【3】系统变量
    - 通过ignore插件过滤不想被监控的端点
    - 支持webhook告警通知
    - 一个trace包含多个span，一个span下包含多个log
    - tags是多span的补充说明，增加了一些属性

### 基于配置文件启动
```shell
# 变量
APP_NAME=$2
APP_FILE=$2.jar
ENV=${3:-"dev"}
APP_MEM=${4:-"256M"}

# jvm 参数
JAVA_OPTS="
 -Xms${APP_MEM}
 -Xmx${APP_MEM}
 -XX:+UseG1GC
 -XX:MaxGCPauseMillis=200
 -XX:SurvivorRatio=4
 -XX:+PrintGCDetails
 -XX:+PrintGCDateStamps
 -XX:+PrintTenuringDistribution
 -Xloggc:./logs/gc/${APP_NAME}_gc.log
 -XX:ErrorFile=./logs/err/${APP_NAME}_err.log
 -XX:HeapDumpPath=./logs/dump/${APP_NAME}_heapdump.hprof
 -XX:+HeapDumpOnOutOfMemoryError
"

# skywalking 参数
SKYWALKING_OPTS="
 -javaagent:/home/msdev/workspace/skywalking-agent/skywalking-agent.jar
 -DSW_AGENT_NAME=${APP_NAME}
 -Dskywalking_config=/home/msdev/workspace/skywalking-agent/config/agent.config
"

# 启动
nohup java $SKYWALKING_OPTS -jar $JAVA_OPTS -Dspring.profiles.active=$ENV $APP_FILE > /dev/null 2>&1 &
```

 ### 仪表盘
    服务吞吐量、接口性能最差的耗时

 ### 拓扑图
    各个服务关系图

 ### 追踪
    trace：表示一个请求链路
    span：表示一个请求的一部分

 ### 告警