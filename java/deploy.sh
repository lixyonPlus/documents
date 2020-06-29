#!/bin/sh
set -e
# 环境变量
export JAVA_HOME=/opt/jdk
export PATH=$JAVA_HOME/bin:$PATH

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

# 使用说明
usage() {
    echo "usage: sh deploy.sh ( usage | start | stopped | restart | status ) APP_NAME [ENV] [APP_MEM]"
}
# 启动函数
start() {
    mkdir -p ./logs/{gc,err,dump}
    local pid=$(ps -ef | grep $APP_FILE | grep -v grep | awk '{print $2}')
    if [ "$pid" != "" ]; then
        echo "$APP_NAME is already running, the pid is $pid"
    else
        nohup java -jar $JAVA_OPTS -Dspring.profiles.active=$ENV $APP_FILE >/dev/null 2>&1 &
        echo "started $APP_NAME success, the pid is $!"
    fi
}

# 停止函数
stopped() {
    while [ true ]; do
        local pid=$(ps -ef | grep $APP_FILE | grep -v grep | awk '{print $2}')
        if [ "$pid" = "" ]; then
            break
        else
            for p in $pid; do
                kill -9 $p
                echo "$p killed"
            done
            sleep 1
        fi
    done
}
# 重启函数
restart() {
    stopped
    start
}

# 状态函数
status() {
    local pid=$(ps -ef | grep $APP_FILE | grep -v grep | awk '{print $2}')
    if [ "$pid" != "" ]; then
        echo "$APP_NAME is running pid is $pid"
    else
        echo "$APP_NAME is not running"
    fi
}
# 根据选择判断执行
case "$1" in
start)
    start
    ;;
stopped)
    stopped
    ;;
restart)
    restart
    ;;
status)
    status
    ;;
usage)
    usage
    ;;
*)
    usage
    ;;
esac
exit 0
