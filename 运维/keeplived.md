# Keepalived
    健康检查和失败切换是keepalived的两大核心功能。所谓的健康检查，就是采用tcp三次握手，icmp请求，http请求，udp echo请求等方式对负载均衡器后面的实际的服务器(通常是承载真实业务的服务器)进行保活；而失败切换主要是应用于配置了主备模式的负载均衡器，利用VRRP维持主备负载均衡器的心跳，当主负载均衡器出现问题时，由备负载均衡器承载对应的业务，从而在最大限度上减少流量损失，并提供服务的稳定性。
    它根据TCP/IP参考模型的第三、第四层、第五层交换机制检测每个服务节点的状态，如果某个服务器节点出现异常，或者工作出现故障，Keepalived将检测到，并将出现的故障的服务器节点从集群系统中剔除，这些工作全部是自动完成的，不需要人工干涉，需要人工完成的只是修复出现故障的服务节点。
    VRRP（VritrualRouterRedundancyProtocol,虚拟路由冗余协议)出现的目的是解决静态路由出现的单点故障问题，通过VRRP可以实现网络不间断稳定运行，因此Keepalvied一方面具有服务器状态检测和故障隔离功能，另外一方面也有HAcluster功能。
### keepalived的HA分为抢占模式和非抢占模式，抢占模式即MASTER从故障中恢复后，会将VIP从BACKUP节点中抢占过来。非抢占模式即MASTER恢复后不抢占BACKUP升级为MASTER后的VIP。


## keepaliaved 抢占式配置
    master配置(keepalived.conf)
    ```
    global_defs {
        router_id lb01 #标识信息，一个名字而已；
        notification_email { #通知email
            acassen@firewall.loc

        }
        notification_email_from Alexandre.Cassen@firewall.loc #发送邮箱配置
        smtp_server 192.168.200.1
        smtp_connect_timeout 30
    }
    vrrp_instance VI_1 {
        state MASTER    #角色是master
        interface eth0  #vip绑定网卡端口
        virtual_router_id 50    #让master和backup在同一个虚拟路由里，id号必须相同；
        priority 150            #优先级,谁的优先级高谁就是master ;
        advert_int 1            #心跳间隔时间(s)
        authentication {
            auth_type PASS      #认证
            auth_pass 1111      #密码 
        }
        virtual_ipaddress {
            10.0.0.3            #虚拟ip
        }
    }
    ```
    backup配置(keepalived.conf)
    ```
    global_defs {
        router_id lb02 #标识信息，一个名字而已；
        notification_email { #通知email
            acassen@firewall.loc

        }
        notification_email_from Alexandre.Cassen@firewall.loc #发送邮箱配置
        smtp_server 192.168.200.1
        smtp_connect_timeout 30
    }
    vrrp_instance VI_2 {
        state BACKUP    #角色是backup
        interface eth0  #vip绑定网卡端口
        virtual_router_id 50    #让master和backup在同一个虚拟路由里，id号必须相同；
        priority 100            #优先级,谁的优先级高谁就是master ;
        advert_int 1            #心跳间隔时间(s)
        authentication {
            auth_type PASS      #认证
            auth_pass 1111      #密码 
        }
        virtual_ipaddress {
            10.0.0.3            #虚拟ip
        }
    }
    ```

## keepaliaved 非抢占式配置
    master配置(keepalived.conf)
    ```
    global_defs {
        router_id lb01 #标识信息，一个名字而已；
        notification_email { #通知email
            acassen@firewall.loc

        }
        notification_email_from Alexandre.Cassen@firewall.loc #发送邮箱配置
        smtp_server 192.168.200.1
        smtp_connect_timeout 30
    }
    vrrp_instance VI_1 {
        state BACKUP    #角色是BACKUP
        interface eth0  #vip绑定网卡端口
        virtual_router_id 50    #让master和backup在同一个虚拟路由里，id号必须相同；
        priority 150            #优先级,谁的优先级高谁就是master ;
        advert_int 1            #心跳间隔时间(s)
        nopreempt #非抢占式
        authentication {
            auth_type PASS      #认证
            auth_pass 1111      #密码 
        }
        virtual_ipaddress {
            10.0.0.3            #虚拟ip
        }
    }
    ```
    backup配置(keepalived.conf)
    ```
    global_defs {
        router_id lb02 #标识信息，一个名字而已；
        notification_email { #通知email
            acassen@firewall.loc

        }
        notification_email_from Alexandre.Cassen@firewall.loc #发送邮箱配置
        smtp_server 192.168.200.1
        smtp_connect_timeout 30
    }
    vrrp_script check {
        script "/server/scripts/check_list" #检测nginx脚本
        interval  10 #间隔时间
    }
    track_script  {
        check #调用nginx检测脚本
    }
    vrrp_instance VI_2 {
        state BACKUP    #角色是BACKUP
        interface eth0  #vip绑定网卡端口
        virtual_router_id 50    #让master和backup在同一个虚拟路由里，id号必须相同；
        priority 100            #优先级,谁的优先级高谁就是master ;
        advert_int 1            #心跳间隔时间(s)
        nopreempt #非抢占式
        authentication {
            auth_type PASS      #认证
            auth_pass 1111      #密码 
        }
        virtual_ipaddress {
            10.0.0.3            #虚拟ip
        }
    }
    ```
    
    ```shell
    #check_list脚本
    #!/bin/sh
    nginxpid=$(ps -C nginx --no-header|wc -l)
    #1.判断Nginx是否存活,如果不存活则尝试启动Nginx
    if [ $nginxpid -eq 0 ];then
        systemctl start nginx
        sleep 3
        #2.等待3秒后再次获取一次Nginx状态
        nginxpid=$(ps -C nginx --no-header|wc -l) 
        #3.再次进行判断, 如Nginx还不存活则停止Keepalived,让地址进行漂移,并退出脚本  
        if [ $nginxpid -eq 0 ];then
            systemctl stop keepalived
        fi
    fi
    ```