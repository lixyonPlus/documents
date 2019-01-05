
```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
 name: string # 名称
 namespace: string  #命名空间
 labels: # 标签(k/v)
   key: value 
spec:
 replicas: 0 #副本数量
 minReadySeconds: 0 #滚动升级时，容器准备就绪时间最少为多少秒
 strategy:
   type: recreate #升级方式
   #rollingUpdate:##由于replicas为3,则整个升级,pod个数在2-4个之间
   #  maxSurge: 3 #滚动升级时会先启动3个pod
   #  maxUnavailable: 1 #滚动升级时允许的最大Unavailable的pod个数
 selector:
   matchLabels: #匹配pod标签（k/v）
     key: value 
 template:  #定义容器模板，该模板可以包含多个容器
    metadata:
     labels: #pod标签（k/v）
       key: value 
   spec:
     terminationGracePeriodSeconds: 60 ##k8s将会给应用发送SIGTERM信号，可以用来正确、优雅地关闭应用,默认为30秒
     containers: #容器
     - name: lykops-dpm # 容器名称
       image: web:apache #镜像名称
       command: [ "sh", "/etc/run.sh" ]  #启动命令
       args: #启动参数
        - ‘-version=123’
        - ‘-app=3’
       #如果command和args均没有写，那么用Docker默认的配置。
       #如果command写了，但args没有写，那么Docker默认的配置会被忽略而且仅仅执行.yaml文件的command（不带任何参数的）。
       #如果command没写，但args写了，那么Docker默认配置的ENTRYPOINT的命令行会被执行，但是调用的参数是.yaml中的args。
       #如果如果command和args都写了，那么Docker默认的配置被忽略，使用.yaml的配置。
       imagePullPolicy: IfNotPresent  #如果不存在则拉取
       ports: # 端口
       - containerPort: 80 #对service暴露端口
         name: http #名称
         protocol: TCP #协议
       resources: ##资源限制
         requests:
           cpu: 0.05
           memory: 16Mi
         limits:
           cpu: 0.1
           memory: 32Mi
       livenessProbe: #livenessProbe是K8S认为该pod是存活的，不存在则需要kill掉，然后再新启动一个，以达到RS指定的个数。
         httpGet:
           path: /
           port: 80
           scheme: HTTP
         initialDelaySeconds: 30
         timeoutSeconds: 5
         successThreshold: 1
         failureThreshold: 5
       readinessProbe: #readinessProbe是K8S认为该pod是启动成功的，这里根据每个应用的特性，自己去判断，可以执行command，也可以进行httpGet。
         httpGet:
           path: /
           port: 80
           scheme: HTTP
         initialDelaySeconds: 30
         timeoutSeconds: 5
         successThreshold: 1
         failureThreshold: 5
        volumeMounts:     #挂载volumes中定义的磁盘
          - name: log-cache
            mount: /tmp/log
          - name: sdb       #普通用法，该卷跟随容器销毁，挂载一个目录
            mountPath: /data/media    
          - name: nfs-client-root    #直接挂载硬盘方法，如挂载下面的nfs目录到/mnt/nfs
            mountPath: /mnt/nfs
          - name: example-volume-config  #高级用法第1种，将ConfigMap的log-script,backup-script分别挂载到/etc/config目录下的一个相对路径path/to/...下，如果存在同名文件，直接覆盖。
            mountPath: /etc/config       
          - name: rbd-pvc                #高级用法第2中，挂载PVC(PresistentVolumeClaim)
      #使用volume将ConfigMap作为文件或目录直接挂载，其中每一个key-value键值对都会生成一个文件，key为文件名，value为内容，
        volumes:  # 定义磁盘给上面volumeMounts挂载
        - name: log-cache
          emptyDir: {}
        - name: sdb  #挂载宿主机上面的目录
          hostPath:
            path: /any/path/it/will/be/replaced
        - name: example-volume-config  # 供ConfigMap文件内容到指定路径使用
          configMap:
            name: example-volume-config  #ConfigMap中名称
            items:
            - key: log-script           #ConfigMap中的Key
              path: path/to/log-script  #指定目录下的一个相对路径path/to/log-script
            - key: backup-script        #ConfigMap中的Key
              path: path/to/backup-script  #指定目录下的一个相对路径path/to/backup-script
        - name: nfs-client-root         #供挂载NFS存储类型
          nfs:
            server: 10.42.0.55          #NFS服务器地址
            path: /opt/public           #showmount -e 看一下路径
        - name: rbd-pvc                 #挂载PVC磁盘
          persistentVolumeClaim:
            claimName: rbd-pvc1         #挂载已经申请的pvc磁盘
```
