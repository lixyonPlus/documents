docker : 
  namespace : 环境隔离（进程、网络以及文件系统）
  cgroup：资源隔离（cpu、内存）
  UnionFS（镜像分层存储）


docker for mac开启远程api：
1.用 socat

 - brew install socat #安装socat：
 - $ socat -d TCP-LISTEN:2375,range=127.0.0.1/32,reuseaddr,fork UNIX:/var/run/docker.sock #启动socat
 - $ socat -d TCP-LISTEN:2375,reuseaddr,fork UNIX:/var/run/docker.sock #开放全部端口
 - 测试一下：
 ```
 $ curl localhost:2375/version
{"Version":"1.11.2","ApiVersion":"1.23","GitCommit":"56888bf","GoVersion":"go1.5.4",
"Os":"linux","Arch":"amd64","KernelVersion":"4.4.12-moby",
"BuildTime":"2016-06-06T23:57:32.306881674+00:00"}
 ```
 2.使用docker socat
 ```
 docker run -d -v /var/run/docker.sock:/var/run/docker.sock -p 2376:2375 \
 bobrik/socat TCP4-LISTEN:2375,fork,reuseaddr UNIX-CONNECT:/var/run/docker.sock
 ```
 3.使用docker proxy
```
docker run -p 3375:2375 -v /var/run/docker.sock:/var/run/docker.sock \
 -d -e PORT=2375 shipyard/docker-proxy
```

