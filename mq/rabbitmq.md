RabbitMQ 最初起源于金融系统，用于在分布式系统中存储转发消息，在易用性、扩展性、高可用性等方面表现不俗。
应用场景： 异步、解耦、削峰填谷

具体特点包括：
  1. 可靠性（Reliability）：RabbitMQ 使用一些机制来保证可靠性，如持久化、传输确认、发布确认。
  2. 灵活的路由（Flexible Routing）：在消息进入队列之前，通过 Exchange 来路由消息的。对于典型的路由功能，RabbitMQ 已经提供了一些内置的 Exchange 来实现。针对更复杂的路由功能，可以将多个 Exchange 绑定在一起，也通过插件机制实现自己的 Exchange 。
  3. 消息集群（Clustering）：多个 RabbitMQ 服务器可以组成一个集群，形成一个逻辑 Broker 。
  4. 高可用（Highly Available Queues）：队列可以在集群中的机器上进行镜像，使得在部分节点出问题的情况下队列仍然可用。
  5. 多种协议（Multi-protocol）：RabbitMQ 支持多种消息队列协议，比如 STOMP、MQTT 等等。
  6. 多语言客户端（Many Clients）：RabbitMQ 几乎支持所有常用语言，比如 Java、.NET、Ruby 等等。
  7. 管理界面（Management UI）:RabbitMQ 提供了一个易用的用户界面，使得用户可以监控和管理消息 Broker 的许多方面。
  8. 跟踪机制（Tracing）:如果消息异常，RabbitMQ 提供了消息跟踪机制，使用者可以找出发生了什么。
  9. 插件机制（Plugin System）:RabbitMQ 提供了许多插件，来从多方面进行扩展，也可以编写自己的插件。 
模式：
  1. Direct（直连）：消息中的路由键routing_key如果和交换机与队列绑定的key一致，交换器就将消息发到对应的队列中。它是完全匹配、单播的模式。
  2. Fanout（广播分发）：每个发到 fanout交换器的消息都会发送到所有绑定的队列上去。无需routing_key匹配，fanout 类型转发消息是最快的。
  3. Topic（发布订阅）：Topic 交换器通过模式匹配分配消息的路由键属性，将路由键和某个模式进行匹配，此时队列需要绑定到一个模式上。它将路由键和绑定键的字符串切分成单词，这些单词之间用点隔开。它同样也会识别两个通配符：符号“#”和符号“”。#匹配0个或多个单词，*匹配不多不少一个单词。 
  4. Headers（消息头订阅）：消息发布前,为消息定义一个或多个键值对的消息头,然后消费者接收消息同时需要定义类似的键值对请求头:(如:x-mactch=all或者x_match=any)，只有请求头与消息头匹配,才能接收消息,忽略RoutingKey. 
  默认的exchange:如果用空字符串去声明一个exchange，那么系统就会使用”amq.direct”这个exchange，我们创建一个queue时,默认的都会有一个和新建queue同名的routingKey绑定到这个默认的exchange上去

因为在第一个参数选择了默认的Exchange，而我们声明的队列叫TaskQueue，所以默认的，它会新建一个也叫TaskQueue的RoutingKey，并绑定在默认的Exchange上，导致了我们可以在第二个参数RoutingKey中写TaskQueue，这样它就会找到定义的同名的Queue，并把消息放进去。 

如果有两个消费端都是用了同一个的Queue和相同的RoutingKey去绑定Direct交换机的话，分发的行为是负载均衡的，也就是说第一个是程序1收到，第二个是程序2收到，以此类推。

如果有两个消费端用了不同的Queue，但使用相同的RoutingKey去绑定Direct交换机的话，分发的行为是复制的，也就是说每个程序都会收到这个消息的副本。行为相当于Fanout交换机。

rabbitmq无法解决重复消费问题，可以根据本地消息表保存唯一messageID或zookeeper去重。
rabbitmq：通过为用户指定Vhost（虚拟主机）提高资源利用率和命名冲突（队列、交换机）问题。

概念说明: 
  Broker:它提供一种传输服务,它的角色就是维护一条从生产者到消费者的路线，保证数据能按照指定的方式进行传输。
  Exchange：消息交换机,它指定消息按什么规则,路由到哪个队列。 
  Queue:消息的载体,每个消息都会被投到一个或多个队列。 
  Binding:绑定，它的作用就是把交换机和队列按照路由规则绑定起来. 
  Routing Key:路由关键字,交换机根据这个关键字进行消息投递。 
  vhost:虚拟主机,一个broker里可以有多个vhost，用作不同用户的权限分离。 
  Producer:消息生产者,就是投递消息的程序。
  Consumer:消息消费者,就是接受消息的程序。
  Channel:消息通道,在客户端的每个连接里,可建立多个channel。


AMQP协议本身包括三层：
  1.Module Layer，位于协议最高层，主要定义了一些供客户端调用的命令，客户端可以利用这些命令实现自己的业务逻辑，例如，客户端可以通过queue.declare声明一个队列，利用consume命令获取一个队列中的消息。
  2.Session Layer，主要负责将客户端的命令发送给服务器，在将服务器端的应答返回给客户端，主要为客户端与服务器之间通信提供可靠性、同步机制和错误处理。
  3.Transport Layer，主要传输二进制数据流，提供帧的处理、信道复用、错误检测和数据表示。

生产者实现RabbitTemplate.ConfirmCallback, RabbitTemplate.ReturnCallback两个接口可确保消息可靠性投递。
confirm：消息是否投递到broker服务端
returnedMessage：消息投递失败会返回对应消息。
  ```txt
  spring.rabbitmq.addresses=127.0.0.1:5672
  spring.rabbitmq.username=admin
  spring.rabbitmq.password=admin
  spring.rabbitmq.virtual-host=/admin
  spring.rabbitmq.publisher-confirms=true
  spring.rabbitmq.publisher-returns=true
  ```

消费端配置application.properties文件并使用注解接受消息：
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