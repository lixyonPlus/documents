# Kafka

## kafka命令

##### kafka-topic.sh

```shell
./kafka-topic.sh --zookeeper localhost:2181 --create --replication-factor 1 --partitions 1 --topic test
### 如果topic不存在时新建topic
./kafka-topic.sh --zookeeper localhost:2181 --create --if-not-exists --replication-factor 1 --partitions 1 --topic test
### 新增topic分区数量
./kafka-topic.sh --zookeeper localhost:2181 --alter --partitions 1 --topic test
### 删除topic分区数量
./kafka-topic.sh --zookeeper localhost:2181 --delete --topic test
### 查看所有topic
./kafka-topic.sh --zookeeper localhost:2181 --list
### 查看topic
./kafka-topic.sh --zookeeper localhost:2181 --describe --if-exists --topic test
### 查询包含不同步副本的分区
./kafka-topic.sh --zookeeper localhost:2181 --describe --under-replicated-partitions
### 查询没有leader副本的分区
./kafka-topic.sh --zookeeper localhost:2181 --describe --unavailable-partitions
```

##### Kafka-consumer-group.sh

```shell
### 查询所有消费者组
./kafka-consumer-group.sh --zookeeper localhost:2181 --list
### 查询消费组信息
./kafka-consumer-group.sh --zookeeper localhost:2181 --describe --group group.test
### 删除消费者组
./kafka-consumer-groups.sh --bootstrap-server localhost:9092 --delete --group group.test
### 把消费者组offset调整到分区当前最新offset
./kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group group.demo --reset-offsets --all-topics --to-latest --execute
### 把消费者组offset调整到分区当前最小offset
./kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group group.demo --reset-offsets --all-topics --to-earliest --execute
### 把消费者组offset调整到分区指定的offset（不能小于当前最小offset或大于当前最大offset）
./kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group group.demo --reset-offsets --all-topics --to-offset 191 --execute
```

##### kafka-configs.sh

```shell
### 修改topic默认配置，消息保留时间为1小时
./kafka-configs.sh --bootstrap-server localhost:9092 --alter --entity-type topics --entity-name first --add-config retention.ms=3600000
### 查询被覆盖的配置
./kafka-configs.sh --bootstrap-server localhost:9092 --describe --entity-type topics --entity-name first
### 移除被覆盖的配置
./kafka-configs.sh --bootstrap-server localhost:9092 --alter --entity-type topics --entity-name first --delete-config retention.ms
```

##### Kafka-preferred-replica-election.sh

```shell
### 启动首选副本选举
./kafka-preferred-replica-election.sh --bootstrap-server localhost:9092 
```

##### kafka-replica-verification.sh

```shell
### 副本验证
./kafka-replica-verification.sh --broker-list localhost:9092 --topic-white-list 'first'
```



##### 往topic发送消息

```shell
./kafka-console-producer.sh --broker-list localhost:9092 --topic test1
./kafka-console-producer.sh --bootstrap-server localhost:9092 --topic test1
```

##### 消费topic消息

```shell
### 从头开始消费
./kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test --from-beginning
### 实时消费
./kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test1
```

##### Kafka-verifiable-producer.sh

```shell

### 生产测试数据发送到指定topic,并将数据已json格式打印到控制台

### --max-messages: 最大消息数量，默认-1，一直生产消息
### --throughput: 设置吞吐量，默认-1
### --acks: 指定分区中必须有多少个副本收到这条消息，才算消息发送成功，默认-1
### --message-create-time: 设置消息创建的时间，时间戳
### --value-prefix: 设置消息前缀
### --repeating-keys: key从0开始，每次递增1，直到指定的值，然后再从0开始
./kafka-verifiable-producer.sh --bootstrap-server localhost:9092 --topic first --message-create-time 1527351382000 --value-prefix 1 --repeating-keys 10 --max-message 20

```

##### kafka-verifiable-consumer.sh

```shell
### 消费指定topic消息
### --topic: 要消费的topic
### --group-id: 消费组id
### --max-messages: 最大消费消息数量，默认-1，一直消费
### --session-timeout: 消费者会话超时时间，默认30000ms，服务端如果在该时间内没有接收到消费者的心跳，就会将该消费者从消费组中删除
### --enable-autocommit: 自动提交，默认false
### --reset-policy: 设置消费偏移量，earliest从头开始消费，latest从最近的开始消费，none抛出异常，默认earliest
### --assignment-strategy: 消费者的分区配置策略, 默认 RangeAssignor
./kafka-verifiable-consumer.sh --broker-list localhost:9092 --topic first --group-id group.demo --max-messages 2 --enable-autocommit --reset-policy earliest
```

##### kafka-log-dirs.sh

```shell
### 查看指定broker上日志目录使用情况
./kafka-log-dirs.sh --bootstrap-sever localhost:9092 --describe --topic-list test,first
```