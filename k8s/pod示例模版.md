

```
apiVersion: v1
kind: Pod
metadata: #元数据
  name: string #pod名称（唯一）
  namespace: string #命名空间
  labels:
    - name: string #标签名称
  annotations:
    - name: string #注解
spec:
  containers: # 容器属性
  - name: string #容器名称
    image: string #镜像名称
    imagePullPolicy: #镜像拉取策略 [Always不管镜像是否存在都会进行一次拉取。|Never不管镜像是否存在都不会进行拉取.|默认IfNotPresent只有镜像不存在时，才会进行镜像拉取。]
    command: [string] #执行命令，相当于docker中entrypoint
    args: [string] #执行命令，相当于docker中cmd
    workingDir: string #容器的工作目录
    volumeMounts: #挂载到容器内部的存储卷配置
    - name: string #名称
      mountPath: string #挂载路径
      readOnly: boolean #是否只读
    ports:
    - name: string # 端口名称
      containerPort: init # 容器端口
      hostPort: in  # 容器所在主机需要监听的端口号，默认与Container相同
      protocol: string #端口协议，支持TCP和UDP，默认TCP
    env: # 容器运行前设置的环境变量列表
    - name: string # 环境变量名称
      value: string # 环境变量的值
    resources: # 资源限制和请求的设置
      requests: # 设置容器需要的最小资源
        memory: string #内存请求，容器启动的初始可用数量 
        cpu: string #Cpu请求，容器启动的初始可用数量
      limits: #用于限制运行时容器占用的资源，用来限制容器的最大CPU、内存的使用率。当容器申请内存超过limits时会被终止，并根据重启策略进行重启
        cpu: string #Cpu的限制，单位为core数
        memory: string #内存限制，单位可以为Mib/Gib
    livenessProbe: #对Pod内容器健康检查的设置，当探测无响应几次后将自动重启该容器
      exec: #通过执行命令来检查服务是否正常，针对复杂检测或无HTTP接口的服务，命令返回值为0则表示容器健康。
        command: [string]
      httpGet: #通过发送http请求检查服务是否正常，返回200-399状态码则表明容器健康。
        path: string # http服务器上的访问URI。
        port: number # 容器上要访问端口号或名称。
        host: string # 要连接的主机名，默认为Pod IP，可以在http request head中设置host头部。
        scheme: string # 用于连接host的协议，默认为HTTP。
        httpHeaders: # 自定义HTTP请求headers，HTTP允许重复headers。
        - name: string
          value: string
      tcpSocket: # 通过TCP方式做健康探测
        port: number #端口
      initialDelaySeconds: 0 # Pod启动后延迟多久才进行检查，单位：秒。
      timeoutSeconds: 0 # 探测的超时时间，默认为1，单位：秒。
      periodSeconds: 0 # 检查的间隔时间，默认为10，单位：秒。
      successThreshold: 0 # 探测失败后认为成功的最小连接成功次数，默认为1，在Liveness探针中必须为1，最小值为1。
      failureThreshold: 0 # 探测失败的重试次数，重试一定次数后将认为失败，在readiness探针中，Pod会被标记为未就绪，默认为3，最小值为1。
      securityContext: # 限制不可信容器的行为，保护系统和其他容器不受其影响。
        priviledge: false #是否运行特权容器
    restartPolicy: [Always 只要退出就重启 | Never 只要退出就不再重启  | OnFailure 失败退出（exit code不等于0）时重启]
    nodeSelector: object # 通过nodeSelector，一个Pod可以指定它所想要运行的Node节点。（kv）
    imagePullSecrets: # 声明拉取镜像时需要指定密钥, regsecret 必须和上面生成密钥的键名一致, 另外检查一下pod和密钥是否在同一个namespace, 之后k8s便可以拉取镜像
    - name: string
    hostNetwork: false # true：pod中运行的应用程序可以直接看到宿主机的网络接口，宿主主机所在的局域网上所有网络接口都可以访问到该应用程序。
    volumes: # 声明虚拟卷
    - name: string #名称
      emptyDir: {} # EmptyDir是一个空目录，他的生命周期和所属的 Pod 是完全一致的，可以在同一 Pod 内的不同容器之间共享工作过程中产生的文件。
      hostPath: # 把宿主机上的指定卷加载到容器之中
        path: string #宿主机路径
      secret: # 敏感配置信息（例如密码等）
        secretName: string # 名称
        items: 
        - keys: string
          path: string #路径
      configMap: #配置信息
        name: string # 名称
        items:
        - key: string
          path: string #路径
```
