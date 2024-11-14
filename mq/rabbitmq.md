# RabbitMQ最初起源于金融系统，用于在分布式系统中存储转发消息，在易用性、扩展性、高可用性等方面表现不俗。
- 应用场景： 异步、解耦、削峰填谷
## RabbitMQ组件说明: 
  Broker:它提供一种传输服务,它的角色就是维护一条从生产者到消费者的路线，保证数据能按照指定的方式进行传输。
  Exchange：消息交换机,它指定消息按什么规则,路由到哪个队列。 
  Queue:消息的载体,每个消息都会被投到一个或多个队列。 
  Binding:绑定，它的作用就是把交换机和队列按照路由规则绑定起来. 
  Routing Key:路由关键字,交换机根据这个关键字进行消息投递。 
  vhost:虚拟主机,一个broker里可以有多个vhost，用作不同用户的权限分离。 
  Producer:消息生产者,就是投递消息的程序。
  Consumer:消息消费者,就是接受消息的程序。
  Channel:消息通道,在客户端的每个连接里,可建立多个channel。

## AMQP协议本身包括三层：
  1.Module Layer，位于协议最高层，主要定义了一些供客户端调用的命令，客户端可以利用这些命令实现自己的业务逻辑，例如，客户端可以通过queue.declare声明一个队列，利用consume命令获取一个队列中的消息。
  2.Session Layer，主要负责将客户端的命令发送给服务器，在将服务器端的应答返回给客户端，主要为客户端与服务器之间通信提供可靠性、同步机制和错误处理。
  3.Transport Layer，主要传输二进制数据流，提供帧的处理、信道复用、错误检测和数据表示。


## RabbitMQ具体特点包括：
  1. 可靠性（Reliability）：RabbitMQ 使用一些机制来保证可靠性，如持久化、传输确认、发布确认。
  2. 灵活的路由（Flexible Routing）：在消息进入队列之前，通过 Exchange 来路由消息的。对于典型的路由功能，RabbitMQ 已经提供了一些内置的 Exchange 来实现。针对更复杂的路由功能，可以将多个 Exchange 绑定在一起，也通过插件机制实现自己的 Exchange 。
  3. 消息集群（Clustering）：多个 RabbitMQ 服务器可以组成一个集群，形成一个逻辑 Broker 。
  4. 高可用（Highly Available Queues）：队列可以在集群中的机器上进行镜像，使得在部分节点出问题的情况下队列仍然可用。
  5. 多种协议（Multi-protocol）：RabbitMQ 支持多种消息队列协议，比如 STOMP、MQTT 等等。
  6. 多语言客户端（Many Clients）：RabbitMQ 几乎支持所有常用语言，比如 Java、.NET、Ruby 等等。
  7. 管理界面（Management UI）:RabbitMQ 提供了一个易用的用户界面，使得用户可以监控和管理消息 Broker 的许多方面。
  8. 跟踪机制（Tracing）:如果消息异常，RabbitMQ 提供了消息跟踪机制，使用者可以找出发生了什么。
  9. 插件机制（Plugin System）:RabbitMQ 提供了许多插件，来从多方面进行扩展，也可以编写自己的插件。

## 模式：
  1. Direct（直连）：消息中的路由键routing_key如果和交换机与队列绑定的key一致，交换器就将消息发到对应的队列中。它是完全匹配、单播的模式。
  2. Fanout（广播分发）：每个发到 fanout交换器的消息都会发送到所有绑定的队列上去。无需routing_key匹配，fanout 类型转发消息是最快的。
  3. Topic（发布订阅）：Topic 交换器通过模式匹配分配消息的路由键属性，将路由键和某个模式进行匹配，此时队列需要绑定到一个模式上。它将路由键和绑定键的字符串切分成单词，这些单词之间用点隔开。它同样也会识别两个通配符：符号“#”和符号“*”。#匹配0个或多个单词，*匹配不多不少一个单词。 
  4. Headers（消息头订阅）：消息发布前,为消息定义一个或多个键值对的消息头,然后消费者接收消息同时需要定义类似的键值对请求头:(如:x-mactch=all或者x_match=any)，只有请求头与消息头匹配,才能接收消息,忽略RoutingKey. 
  5. 默认的exchange:如果用空字符串去声明一个exchange，那么系统就会使用”amq.direct”这个exchange，我们创建一个queue时,默认的都会有一个和新建queue同名的routingKey绑定到这个默认的exchange上去

### 因为在第一个参数选择了默认的Exchange，而我们声明的队列叫TaskQueue，所以默认的，它会新建一个也叫TaskQueue的RoutingKey，并绑定在默认的Exchange上，导致了我们可以在第二个参数RoutingKey中写TaskQueue，这样它就会找到定义的同名的Queue，并把消息放进去。 

### 如果有两个消费端都是用了同一个的Queue和相同的RoutingKey去绑定Direct交换机的话，分发的行为是负载均衡的，也就是说第一个是程序1收到，第二个是程序2收到，以此类推。

### 如果有两个消费端用了不同的Queue，但使用相同的RoutingKey去绑定Direct交换机的话，分发的行为是复制的，也就是说每个程序都会收到这个消息的副本。行为相当于Fanout交换机。

### rabbitmq无法解决重复消费问题（幂等性），可以根据本地消息表保存唯一messageID或zookeeper去重。
### rabbitmq通过为用户指定Vhost（虚拟主机）提高资源利用率和命名冲突（队列、交换机）问题。
### rabbitmq把需要顺序消费的消息发送到一个指定的队列，单个消费者消费，可以保证顺序消费。（主动去分配队列，单个消费者。）

### 消息可靠性投递

- 生产者实现RabbitTemplate.ConfirmCallback, RabbitTemplate.ReturnCallback两个接口可确保消息可靠性投递。
- confirm：消息是否投递到broker服务端
- returnedMessage：消息投递失败会返回对应消息。
  ```txt
  spring.rabbitmq.addresses=127.0.0.1:5672
  spring.rabbitmq.username=admin
  spring.rabbitmq.password=admin
  spring.rabbitmq.virtual-host=/admin
  spring.rabbitmq.publisher-confirms=true
  spring.rabbitmq.publisher-returns=true
  ```
### 消息ACK机制

- 消费端配置application.properties文件并使用注解接受消息：
 ```txt
spring.rabbitmq.addresses=127.0.0.1:5672
spring.rabbitmq.username=admin
spring.rabbitmq.password=admin
spring.rabbitmq.virtual-host=/admin
spring.rabbitmq.listener.direct.acknowledge-mode=MANUAL
 ```

  ```java
    @RabbitListener(queues = {"队列名称"})
    @RabbitHandler
    public void prcess(Message message, Channel channel) {
        /*
         * DeliveryTag 用来标识信道中投递的消息。
         * RabbitMQ 保证在每个信道中，每条消息的 DeliveryTag 从 1 开始递增。
        */

        /*
         * multiple 取值为 false 时，表示通知 RabbitMQ 当前消息被确认；
         * 如果为 true，则额外将比第一个参数指定的 DeliveryTag 小的消息一并确认。（批量确认针对的是整个信道，参考    gordon.study.rabbitmq.ack.TestBatchAckInOneChannel.java。）
        */
          //确认消息消费成功     
          channel.basicAck(message.getMessageProperties().getDeliveryTag(), false);
          //消费失败，true重发
          channel.basicNack(message.getMessageProperties().getDeliveryTag(), false, true);
          //重复消费,false删除消息
          channel.basicReject(message.getMessageProperties().getDeliveryTag(), false);
          //消息丢弃，false不重发
          channel.basicNack(message.getMessageProperties().getDeliveryTag(), false, false);
    }
  ```

 ## 集群： 
    rabbitmq镜像模式集群：keepalived，ha-proxy，rabbitmq，rabbitmq管理端配置



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
