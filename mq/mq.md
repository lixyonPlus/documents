### 引入消息队列之后如何保证高可用性
- RabbitMQ使用镜像集群模式保证高可用,每个节点上都有这个queue的一个镜像，包含了这个queue的完整数据，任何一个节点当机了，都可以到其他节点上消费。（缺点：1.同步数据时，性能开销大。2.如果queue负载很重，新增的机器会同步queue的所有数据，无法线性扩展）

### 如何保证消息不被重复消费（保证幂等性）
- 生成全局唯一id
- 根据主键id查一下唯一性 

### 如何保证消息的可靠性传输（如何处理消息丢失的问题）
- 3种情况下会丢失数据（生产者丢失、rabbitmq当机、消费者拿到这个消息还没来得及消费挂掉）
- 生产者丢失数据：RabbitMQ提供事务机制和confirm模式来确保生产者不丢消息。 RabbitMQ 事务机制（同步）就是说，发送消息前开启事务，发送过程中如果出现什么异常，事务就会回滚，如果发送成功则提交事务，它的缺点是吞吐量会下降，因为是同步的，提交一个事务之后会阻塞在哪儿，太耗性能。生产上都是用confirm模式的居多。在生产者那里设置开启confirm模式之后，每次写的消息都会分配一个唯一的id，然后如果写入了RabbitMQ中，RabbitMQ会告诉你这个消息是否接受成功，如果接收失败，你可以重试。confirm机制是异步的，你发送消息之后就可以发送下一个消息，然后RabbitMQ接收之后会异步回调你的一个接口通知你这个消息接收到了。
- rabbitmq当机：开启RabbitMQ的持久化（队列：durable设置为true && 消息：deliveryMode设置为 2），写入消息之后会自动持久化到磁盘，哪怕RabbitMQ挂了，恢复之后会自动读取之前存储的数据。
- 消费者丢失数据：启用手动确认模式可以解决这个问题。手动确认模式，如果消费者来不及处理就死掉时，没有响应ack时会重复发送同一条信息给其他消费者；如果监听程序处理异常了，且未对异常进行捕获，会一直重复接收消息，然后一直抛异常；如果对异常进行了捕获，但是没有在finally里ack，也会一直重复发送消息(重试机制)。

### 怎么保证从消息队列里拿到的数据按顺序执行
- Rabbitmq发生的场景：1.一个queue，有多个consumer去消费，这样就会造成顺序的错误，consumer从MQ里面读取数据是有序的，但是每个consumer的执行时间是不固定的，无法保证先读到消息的consumer一定先完成操作，这样就会出现消息并没有按照顺序执行，造成数据顺序错误。2.一个queue对应一个consumer，但是consumer里面进行了多线程消费，这样也会造成消息消费顺序错误。
- 
- Rabbitmq一个Queue对应一个Consumer

### 如何解决消息队列的延时以及过期失效问题
- Rabbitmq发生的场景：ttl
- 批量重导：手动去查询丢失的那部分数据，然后将消息重新发送到mq里面，把丢失的数据重新补回来。


### 消息队列满了以后该怎么处理，有几百万消息持续积压几小时，说说怎么解决？
- Rabbitmq发生的场景：消费端(Consumer)拿到消息，消费的时候出现错误或者消费很慢。
- 临时紧急扩容：1.先修复消费端(Consumer)的问题，确保其能够正常消费，然后将现有消费端(Consumer)都停掉。
- 2.新建一个topic，partition是原来的10倍，临时建立好原先10倍的queue数量。
- 3.然后写一个临时的分发数据的消费(Consumer)程序，这个程序部署上去消费MQ积压的数据，消费之后不做耗时的处理，直接均匀轮询写入临时建立好的10倍数量的Queue,接着临时征用10倍的机器来部署消费端(Consumer)，每一批消费端(Consumer)消费一个临时Queue的数据。这种做法相当于是临时将Queue 资源和消费端(Consumer)资源扩大10倍，以正常的10倍速度来消费数据。等快速消费完积压数据之后，得恢复原先部署的架构，重新用原先的消费端(Consumer)机器来消费消息。