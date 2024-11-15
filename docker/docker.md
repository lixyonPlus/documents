[toc]

## docker : 
  - namespace : 环境隔离（进程、网络以及文件系统）
  - cgroup：资源隔离（cpu、内存）
  - UnionFS（镜像分层存储）


### docker for mac开启远程api：
 1. 用 socat

 - brew install socat #安装socat：
 - socat -d TCP-LISTEN:2375,range=127.0.0.1/32,reuseaddr,fork UNIX:/var/run/docker.sock #启动socat
 - socat -d TCP-LISTEN:2375,reuseaddr,fork UNIX:/var/run/docker.sock #开放全部端口
 - 测试一下：
 ```
 curl localhost:2375/version
{"Version":"1.11.2","ApiVersion":"1.23","GitCommit":"56888bf","GoVersion":"go1.5.4",
"Os":"linux","Arch":"amd64","KernelVersion":"4.4.12-moby",
"BuildTime":"2016-06-06T23:57:32.306881674+00:00"}
 ```
 2. 使用docker socat
 ```
 docker run -d -v /var/run/docker.sock:/var/run/docker.sock -p 2376:2375 \
 bobrik/socat TCP4-LISTEN:2375,fork,reuseaddr UNIX-CONNECT:/var/run/docker.sock
 ```
 3. 使用docker proxy
```
docker run -p 3375:2375 -v /var/run/docker.sock:/var/run/docker.sock \
 -d -e PORT=2375 shipyard/docker-proxy
```

### Docker与虚拟机有何不同
 - 虚拟机启动需要数分钟，而Docker容器不需要引导操作系统内核可以在数毫秒内启动

 - Docker有着小巧(基于apline系统只有几兆大小)

 - 迁移部署快速（将镜像导出运行就可以）

 - 运行高效、轻量级

   

 ### 什么是Docker镜像
  - Docker镜像是Docker容器的源代码，Docker镜像用于创建容器。使用build命令创建镜像。

 ### 什么是Docker容器
  - Docker容器包括应用程序及其所有依赖项，作为操作系统的独立进程运行。

 ### Docker容器有几种状态
  - 四种状态：运行、已暂停、重新启动、已退出。

 ### Dockerfile中的命令COPY和ADD命令有什么区别
  - Dockerfile中的COPY指令和ADD指令都可以将主机上的资源复制或加入到容器镜像中，都是在构建镜像的过程中完成的。COPY指令和ADD指令的唯一区别在于是否支持从远程URL获取资源。COPY指令只能从执行docker build所在的主机上读取资源并复制到镜像中。而ADD指令还支持通过URL从远程服务器读取资源并复制到镜像中。满足同等功能的情况下，推荐使用COPY指令。ADD指令更擅长读取本地tar文件并解压缩。

### 构建Docker镜像应该遵循哪些原则
 - 尽量选取满足需求但较小的基础系统镜像，建议选择alpine镜像，仅有3MB大小
 - 清理编译生成文件、安装包的缓存等临时文件
 - 安装各个软件时候要指定准确的版本号，并避免引入不需要的依赖
 - 从安全的角度考虑，应用尽量使用系统的库和依赖

### 如何临时退出一个正在交互的容器的终端，而不终止它
 - 按Ctrl+p，后按Ctrl+q，如果按Ctrl+c会使容器内的应用进程终止，进而会使容器终止

### 如何控制容器占用系统资源（CPU，内存）的份额
 - 在使用docker create命令创建容器或使用docker run 创建并运行容器的时候，可以使用-c|–cpu-shares[=0]参数来调整同期使用CPU的权重，使用-m|–memory参数来调整容器使用内存的大小。

### 如何更改Docker的默认存储设置
 - Docker的默认存放位置是/var/lib/docker,如果希望将Docker的本地文件存储到其他分区，可以使用Linux软连接的方式来做。

### docker多阶段构建
 - 对于多阶段构建，您可以在Dockerfile中使用多个FROM语句。每个FROM指令可以使用不同的基础，并且每个指令都开始一个新的构建。您可以选择性地将工件从一个阶段复制到另一个阶段，从而在最终image中只留下您想要的内容。
 - COPY –from = 0行仅将前一阶段的构建文件复制到此新阶段。
 - 默认情况下，阶段未命名，您可以通过整数来引用它们，从第0个FROM指令开始。但是，您可以通过向FROM指令添加as NAME来命名您的阶段。此示例通过命名阶段并使用COPY指令中的名称来改进前一个示例。

### docker run经历了什么
	检查本地是否存在指定的镜像，不存在就从公有仓库下载
	利用镜像创建并启动一个容器
	分配一个文件系统，并在只读的镜像层外面挂载一层可读写层
	从宿主主机配置的网桥接口中桥接一个虚拟接口到容器中去
	从地址池配置一个 ip 地址给容器
	执行用户指定的应用程序
	执行完毕后容器被终止

### 容器要想访问外部网络，需要本地系统的转发支持。在Linux 系统中，检查转发是否打开。
	sysctl net.ipv4.ip_forward
	net.ipv4.ip_forward = 1 #如果为 0，说明没有开启转发，则需要手动打开。
	$sysctl -w net.ipv4.ip_forward=1
	如果在启动 Docker 服务的时候设定 --ip-forward=true, Docker 就会自动设定系统的 ip_forward 参数为 1。

### 当启动 Docker 服务时候，默认会添加一条转发策略到 iptables 的 FORWARD 链上。策略为通过（ACCEPT）还是禁止（DROP）取决于配置--icc=true（缺省值）还是 --icc=false。当然，如果手动指定 --iptables=false 则不会添加 iptables 规则。可见，默认情况下，不同容器之间是允许网络互通的。如果为了安全考虑，可以在 /etc/default/docker 文件中配置 DOCKER_OPTS=--icc=false 来禁止它。

### iptables -t nat -nL 查看nat转发
### brctl show 查看网桥信息
### sudo docker inspect -f '{{.State.Pid}}' container_id
### ENTRYPOINT 配置容器启动后执行的命令，并且不可被 docker run 提供的参数覆盖。每个 Dockerfile 中只能有一个 ENTRYPOINT，当指定多个时，只有最后一个起效。

### WORKDIR为后续的 RUN、CMD、ENTRYPOINT 指令配置工作目录。可以使用多个 WORKDIR 指令，后续命令如果参数是相对路径，则会基于之前命令指定的路径

### ONBUILD 配置当所创建的镜像作为其它新创建镜像的基础镜像时，所执行的操作指令。

