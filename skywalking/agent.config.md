- 建议一个应用的多个实例，使用有相同的application_code。请使用英文
  - agent.application_code=Your_ApplicationName

- 每三秒采样的Trace数量
  - 默认为负数，代表在保证不超过内存Buffer区的前提下，采集所有的Trace
  - agent.sample_n_per_3_secs=-1

- 设置需要忽略的请求地址
  - 默认配置如下
  - agent.ignore_suffix=.jpg,.jpeg,.js,.css,.png,.bmp,.gif,.ico,.mp3,.mp4,.html,.svg

- 探针调试开关，如果设置为true，探针会将所有操作字节码的类输出到/debugging目录下
  - skywalking团队可能在调试，需要此文件
  - agent.is_open_debugging_class = true

- 对应Collector的config/application.yml配置文件中 agent_server/jetty/port 配置内容
  - 例如：
  - 单节点配置：SERVERS="127.0.0.1:8080" 
  - 集群配置：SERVERS="10.2.45.126:8080,10.2.45.127:7600" 
  - collector.servers=127.0.0.1:10800

- 日志文件名称前缀
  - logging.file_name=skywalking-agent.log

- 日志文件最大大小
  - 如果超过此大小，则会生成新文件。
  - 默认为300M
  - logging.max_file_size=314572800

- 日志级别，默认为DEBUG。
  -logging.level=DEBUG
