#!bin/sh

xx=123123
echo "获取变量1:${xx}"
echo ${xx}
echo '获取变量2:'${xx}''
echo "截取字符串:${xx:1:2}"

array_name=(value0 value1 value2 value3)

echo "获取数组元素:${array_name[@]}"
echo "获取数组长度:${#array_name[@]}"

# 参数传递
echo "文件名为：$0"
echo "第一个参数为：$1"
echo "第二个参数为：$2"
echo "第三个参数为：$3"
echo "展示所有参数为：$*"

# $*与$@
echo "-- \$* 演示 ---"
for i in "$*"; do
    echo $i
done

echo "-- \$@ 演示 ---"
for i in "$@"; do
    echo $i
done

int=1
while (($int <= 5)); do
    echo $int
    let "int++"
done

# if 判断

if [ 0 -eq 0 ]; then
    echo "0 eq 0"
else
    echo "0 -ne 0"
fi

if [ xx = xx ]; then
    echo "xx = xx"
else
    echo "xx != xx"
fi
if [ -f $0 ]; then
    echo "$0是一个文件"
else
    echo "$0不是一个文件"
fi

if [ -x $0 ]; then
    echo "$0包含的文件可执行"
else
    echo "$0包含的文件不可执行"
fi

if [ -d $(pwd) ]; then
    echo "$(pwd)是一个目录"
else
    echo "$(pwd)不是一个目录"
fi

if [ -e $0 ]; then
    echo "$0包含的文件存在"
else
    echo "$0包含的文件不存在"
fi

read name
echo "read读取标准输入:${name}"

# -e 开启转义
echo "OK! \n"

echo "$(date)"
echo $(date)

if [ $(ps -ef | grep -c "ssh") -gt 1 ]; then echo "true"; fi

a=10
b=20
if [ $a == $b ]; then
    echo "a 等于 b"
elif [ $a -gt $b ]; then
    echo "a 大于 b"
elif [ $a -lt $b ]; then
    echo "a 小于 b"
else
    echo "没有符合的条件"
fi

echo '按下 <CTRL-D> 退出'
echo -n '输入你最喜欢的网站名: '
while read FILM; do
    echo "是的！$FILM 是一个好网站"
    break
done

demoFun() {
    echo "这是我的第一个 shell 函数!"
}
echo "-----函数开始执行-----"
demoFun
echo "-----函数执行完毕-----"

echo "如果希望执行某个命令，但又不希望在屏幕上显示输出结果，那么可以将输出重定向到 /dev/null： echo 123 /dev/null"
echo "/dev/null 是一个特殊的文件，写入到它的内容都会被丢弃；如果尝试从该文件读取内容，那么什么也读不到。但是 /dev/null 文件非常有用，将命令的输出重定向到它，会起到"禁止输出"的效果。"
echo "如果希望屏蔽 stdout 和 stderr，可以这样写：echo 123 > /dev/null 2>&1"
echo "注意：0 是标准输入（STDIN），1 是标准输出（STDOUT），2 是标准错误输出（STDERR）。这里的 2 和 > 之间不可以有空格，2> 是一体的时候才表示错误输出。"

echo "exec xxxxx 执行命令"
echo "exec 是bash的内置命令"
echo "exec是用被执行的命令行替换掉当前的shell进程，且exec命令后的其他命令将不再执行。"
echo "source 和 . 不启用新的shell，在当前shell中执行，设定的局部变量在执行完命令后仍然有效。"
echo "bash 或 sh 或 shell script 执行时，另起一个子shell，其继承父shell的环境变量，其子shelll的变量执行完后不影响父shell。"

exit 0
