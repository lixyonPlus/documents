# firewall
### firewall-cmd 是 firewalld的字符界面管理工具，firewalld是centos7的一大特性，最大的好处有两个：支持动态更新，不用重启服务；第二个就是加入了防火墙的“zone”概念。
    firewalld可以动态修改单条规则，而不需要像iptables那样，在修改了规则后必须得全部刷新才可以生效。
    firewalld在使用上要比iptables人性化很多，即使不明白“四张表五条链”而且对TCP/ip协议也不理解也可以实现大部分功能。
    firewalld自身并不具备防火墙的功能，而是和iptables一样需要通过内核的netfilter来实现，也就是说firewalld和 iptables一样，他们的作用都是用于维护规则，而真正使用规则干活的是内核的netfilter，只不过firewalld和iptables的结 构以及使用方法不一样罢了。
    
    yum install firewalld firewall-config #安装firewalld
    systemctl start  firewalld #启动
    systemctl status firewalld #或者 firewall-cmd --state 查看状态
    systemctl disable firewalld #停止
    systemctl stop firewalld  #禁用

    firewall-cmd --version  #查看版本
    firewall-cmd --help     #查看帮助
    firewall-cmd --state  # 显示状态
    firewall-cmd --get-active-zones  # 查看区域信息
    firewall-cmd --get-zone-of-interface=eth0  # 查看指定接口所属区域
    firewall-cmd --panic-on  # 拒绝所有包
    firewall-cmd --panic-off  # 取消拒绝状态
    firewall-cmd --query-panic  # 查看是否拒绝
    firewall-cmd --reload # 更新防火墙规则
    firewall-cmd --complete-reload #两者的区别就是第一个无需断开连接，就是firewalld特性之一动态添加规则，第二个需要断开连接，类似重启服务
    firewall-cmd --zone=dmz --list-ports # 查看所有打开的端口
    firewall-cmd --zone=dmz --add-port=8080/tcp # 加入一个端口到区域,永久生效再加上 --permanent 然后reload防火墙
    firewall-cmd --get-services # 显示服务列表  
    firewall-cmd --enable service=ssh # 允许ssh服务通过
    firewall-cmd --disable service=ssh #禁止SSH服务通过
    firewall-cmd --enable ports=8080/tcp #打开TCP的8080端口
    firewall-cmd --enable service=samba --timeout=600 #临时允许Samba服务通过600秒
    firewall-cmd --list-services # 显示当前服务
    # 添加HTTP服务到内部区域（internal）
    firewall-cmd --permanent --zone=internal --add-service=http
    firewall-cmd --reload     # 在不改变状态的条件下重新加载防火墙
    # 查看防火墙，添加的端口也可以看到
    firewall-cmd --list-all

    控制端口/服务可以通过两种方式控制端口的开放，一种是指定端口号另一种是指定服务名。虽然开放 http 服务就是开放了 80 端口，但是还是不能通过端口号来关闭，也就是说通过指定服务名开放的就要通过指定服务名关闭；通过指定端口号开放的就要通过指定端口号关闭。还有一个要注意的就是指定端口的时候一定要指定是什么协议，tcp 还是 udp。知道这个之后以后就不用每次先关防火墙了，可以让防火墙真正的生效。
    firewall-cmd --add-service=mysql        # 开放mysql端口
    firewall-cmd --remove-service=http      # 阻止http端口
    firewall-cmd --list-services            # 查看开放的服务
    firewall-cmd --add-port=3306/tcp        # 开放通过tcp访问3306
    firewall-cmd --remove-port=80tcp        # 阻止通过tcp访问3306
    firewall-cmd --add-port=233/udp         # 开放通过udp访问233
    firewall-cmd --list-ports               # 查看开放的端口

    端口转发，转发的目标机器如果不指定ip的话就默认为本机，如果指定了ip却没指定端口，则默认使用来源端口。要打开端口转发，则需要先开启IP伪装，firewall-cmd --zone=public --add-masquerade
    firewall-cmd --add-forward-port=port=80:proto=tcp:toport=8080   # 将80端口的流量转发至8080
    firewall-cmd --add-forward-port=port=80:proto=tcp:toaddr=192.168.0.1 # 将80端口的流量转发至192.168.0.1
    firewall-cmd --add-forward-port=port=80:proto=tcp:toaddr=192.168.0.1:toport=8080 # 将80端口的流量转发至192.168.0.1的8080端口





# iptable
### 四表五链：链就是位置：共有五个：进路由(PREROUTING)、进系统(INPUT) 、转发(FORWARD)、出系统(OUTPUT)、出路由(POSTROUTING)。 表就是存储的规则；数据包到了该链处，会去对应表中查询设置的规则，然后决定是否放行、丢弃、转发还是修改等等操作。
    ![](https://img-blog.csdn.net/20180602143140248?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80MjM1MDIxMg==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

    ![](https://img-blog.csdn.net/20180602143216908?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80MjM1MDIxMg==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

### 我们在平时配置防火墙 主要用到表 就是filter和nat表
    Filter表:用来处理是否放行
    NAT表:实现数据包转发，修改源地址 端口 目标地址 端口，实现地址转换
    mangle:用于对特定数据包的修改
    raw:有限级最高，设置raw时一般是为了不再让iptables做数据包的链接跟踪处理，提高性能

    ![](https://img-blog.csdn.net/20180602143238532?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80MjM1MDIxMg==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

### 实例
    1. iptables -t nat -A PREROUTING -d 192.168.102.55 -p tcp --dport 90 -j DNAT --to 172.20.11.1:800
    -A PREROUTING 指定在路由前做的。完整的意思是在 NAT TABLE 的路由前处理，目的地为192.168.102.55 的 目的端口为90的我们做DNAT处理，给他转向到172.20.11.1:800那里去。
    2. iptables -t nat -A POSTROUTING -d 172.20.11.1 -j SNAT --to 192.168.102.55
    -A POSTROUTING 路由后。意思为在 NAT TABLE 的路由后处理，凡是目的地为 172.20.11.1 的，我们都给他做SNAT转换，把源地址改写成 192.168.102.55 。
    3. iptables -A INPUT -p tcp -m tcp --sport 5000 -j DROP
       iptables -A INPUT -p udp -m udp --sport 5000 -j DROP
       iptables -A OUTPUT -p tcp -m tcp --dport 5000 -j DROP
       iptables -A OUTPUT -p udp -m udp --dport 5000 -j DROP
    屏蔽端口5000
    4. iptables -A INPUT -p tcp -m tcp --dport 3306 -j DROP
    防止 Internet 网的用户访问 MySQL服务器(就是3306端口)

