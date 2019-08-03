Spring:
@Configuration 会进行动态代理保证单例，不加会初始化多次，不会生成动态代理。
 ConfigurationClassPostProcessor : 
 DefaultListableBeanFactory：
 ConfigurationClassEnhancer: cglib代理，基于类实现， （代理名称：xxBySpringCGLIB），BeanMethodInterceptor对目标对象 拦截，保证对象不会重复创建
 BeanFactoryPostProcessor：后置执行器
 BeanPostProcess： AOP基于此实现

BeanFactory定义了 IOC 容器的最基本形式，并提供了 IOC 容器应遵守的的最基本的接口，也就是 Spring IOC所遵守的最底层和最基本的编程规范。在  Spring 代码中， BeanFactory 只是个接口，并不是 IOC 容器的具体实现，但是 Spring 容器给出了很多种实现，如 DefaultListableBeanFactory 、 XmlBeanFactory 、 ApplicationContext等，都是附加了某种功能的实现。

一般情况下，Spring 通过反射机制利用 <bean> 的 class 属性指定实现类实例化 Bean。在某些情况下，实例化Bean 过程比较复杂，如果按照传统的方式，则需要在 <bean> 中提供大量的配置信息。配置方式的灵活性是受限的，这时采用编码的方式可能会得到一个简单的方案。Spring 为此提供了一个org.springframework.bean.factory.FactoryBean 的工厂类接口，用户可以通过实现该接口定制实例化 Bean 的逻辑。
FactoryBean接口对于 Spring 框架来说占用重要的地位， Spring 自身就提供了 70 多个 FactoryBean 的实现。它们隐藏了实例化一些复杂 Bean 的细节，给上层应用带来了便利。从 Spring 3.0 开始， FactoryBean 开始支持泛型，即接口声明改为 FactoryBean<T> 的形式：

区别：
BeanFactory是个 Factory ，也就是 IOC 容器或对象工厂， FactoryBean 是个 Bean 。在 Spring 中，所有的Bean 都是由 BeanFactory( 也就是 IOC 容器 ) 来进行管理的。但对 FactoryBean 而言，这个 Bean 不是简单的 Bean，而是一个能生产或者修饰对象生成的工厂 Bean, 它的实现与设计模式中的工厂模式和修饰器模式类似。


  ①BeanFactroy采用的是延迟加载形式来注入Bean的，即只有在使用到某个Bean时(调用getBean())，才对该Bean进行加载实例化。这样，我们就不能发现一些存在的Spring的配置问题。如果Bean的某一个属性没有注入，BeanFacotry加载后，直至第一次使用调用getBean方法才会抛出异常。
  ②ApplicationContext，它是在容器启动时，一次性创建了所有的Bean。这样，在容器启动时，我们就可以发现Spring中存在的配置错误，这样有利于检查所依赖属性是否注入。 ApplicationContext启动后预载入所有的单实例Bean，通过预载入单实例bean ,确保当你需要的时候，你就不用等待，因为它们已经创建好了。




AOP 是基于动态代理模式实现的，具体实现上可以基于 JDK 动态代理或者 Cglib 动态代理。其中 JDK 动态代理只能代理实现了接口的对象，而 Cglib 动态代理则无此限制。所以在为没有实现接口的对象生成代理时，只能使用 Cglib。
1. AOP 逻辑介入 BeanFactory 实例化 bean 的过程
2. 根据 Pointcut 定义的匹配规则，判断当前正在实例化的 bean 是否符合规则
3. 如果符合，代理生成器将切面逻辑 Advice 织入 bean 相关方法中，并为目标 bean 生成代理对象
4. 将生成的 bean 的代理对象返回给 BeanFactory 容器，到此，AOP 逻辑执行结束


所谓 IOC ，就是由 Spring IOC 容器来负责对象的生命周期和对象之间的关系

spring bean生命周期：
实例化bean对象，设置对象属性，检查aware相关接口并设置相关依赖，执行BeanPostProcessor前置处理，
检查是否有InitializingBean以决定是否调用afterPropertiesSet方法，检查是否有配置初始化方法，
BeanPostProcessor后置处理，调用DisposableBean接口，是否配置有销毁方法。


spring 解决循坏依赖问题：三层依赖
其中第一层是singletonObjects，首先会去看singletonObjects是否已经创建了一个对象。如果没有，那么从第二层缓存earlySingletonObjects提前曝光对象的缓存中获取；如果没有，那么最后从第三层缓存singletonFactories单实例工厂缓存中获取。当获取成功后，会把第三层缓存singletonFactories的bean去掉，加入到第二层缓存中。


Spring容器中的bean可以分为5个范围：
（1）singleton：默认，每个容器中只有一个bean的实例，单例的模式由BeanFactory自身来维护。
（2）prototype：为每一个bean请求提供一个实例。
（3）request：为每一个网络请求创建一个实例，在请求完成以后，bean会失效并被垃圾回收器回收。
（4）session：与request范围类似，确保每个session中有一个bean的实例，在session过期后，bean会随之失效。
（5）global-session：全局作用域，global-session和Portlet应用相关。当你的应用部署在Portlet容器中工作时，它包含很多portlet。如果你想要声明让所有的portlet共用全局的存储变量的话，那么这全局变量需要存储在global-session中。全局作用域与Servlet中的session作用域效果相同。

Spring 提供了以下5种标准的事件：
（1）上下文更新事件（ContextRefreshedEvent）：在调用ConfigurableApplicationContext 接口中的refresh()方法时被触发。
（2）上下文开始事件（ContextStartedEvent）：当容器调用ConfigurableApplicationContext的Start()方法开始/重新开始容器时触发该事件。
（3）上下文停止事件（ContextStoppedEvent）：当容器调用ConfigurableApplicationContext的Stop()方法停止容器时触发该事件。
（4）上下文关闭事件（ContextClosedEvent）：当ApplicationContext被关闭时触发该事件。容器被关闭时，其管理的所有单例Bean都被销毁。
（5）请求处理事件（RequestHandledEvent）：在Web应用中，当一个http请求（request）结束触发该事件。
  如果一个bean实现了ApplicationListener接口，当一个ApplicationEvent 被发布以后，bean会自动被通知。

在 Spring Boot 启动的时候运行一些特定的代码？
  可以实现接口 ApplicationRunner 或者 CommandLineRunner，这两个接口实现方式一样，它们都只提供了一个 run 方法。

@Autowired注解原理：
  注解解析器：AutowiredAnnotationBeanPostProcessor
  1.Spring容器启动时，AutowiredAnnotationBeanPostProcessor被注册到容器；
  2.扫描代码，如果带有@Autowired注解，（扫描当前类中标注@Autowired的属性和方法；再查找父类中注@Autowired的属性和方法，依次遍历；）
    则将依赖注入信息封装到InjectionMetadata中（见扫描过程）；
  3.创建bean时（实例化对象和初始化），会调用各种BeanPostProcessor对bean初始化，AutowiredAnnotationBeanPostProcessor负责将相关的依赖注入进来


springmvc是不是线程安全的。
  对于使用过SpringMVC和Struts2的人来说，大家都知道SpringMVC是基于方法的拦截，而Struts2是基于类的拦截。struct2为每一个请求都实例化一个action所以不存在线程安全问题，springmvc默认单例请求使用一个Controller，假如这个Controller中定义了静态变量，就会被多个线程共享。所以springmvc的controller不要定义静态变量。如果要使用可以用ThreadLocal或者@Scope("prototype")开启不以单例的模式运行但是以这种方式运行就不是单例了会有额外的开销。



springmvc:
1.客户端（浏览器）发送请求，直接请求到 DispatcherServlet。
2.DispatcherServlet 根据请求信息调用 HandlerMapping，解析请求对应的 Handler。
3.解析到对应的 Handler（也就是我们平常说的 Controller 控制器）后，开始由 HandlerAdapter 适配器处理。
4.HandlerAdapter 会根据 Handler 来调用真正的处理器开处理请求，并处理相应的业务逻辑。
5.处理器处理完业务后，会返回一个 ModelAndView 对象，Model 是返回的数据对象，View 是个逻辑上的 View。
6.ViewResolver 会根据逻辑 View 查找实际的 View。
7.DispaterServlet 把返回的 Model 传给 View（视图渲染）。
8.把 View 返回给请求者（浏览器）

OncePerRequestFilter： 为了兼容不同的web容器，默认的所有filter继承他。

Spring 事务：
  spring事务基于AOP实现，首先判断当前是否存在事务环境，然后根据事务的传播行为以及隔离级别来管理事务提交与回滚。

脏读、不可重复读、幻读:
脏读：事务A读到了事务B未提交的数据。
不可重复读：事务A第一次查询得到一行记录row1，事务B提交修改后，事务A第二次查询得到row1，但列内容发生了变化。
幻读：事务A第一次查询得到一行记录row1，事务B提交修改后，事务A第二次查询得到两行记录row1和row2

ACID：
原子性（Atomicity）
原子性是指事务是一个不可分割的工作单位，事务中的操作要么都发生，要么都不发生。
一致性（Consistency）
事务前后数据的完整性必须保持一致。
隔离性（Isolation）
事务的隔离性是多个用户并发访问数据库时，数据库为每一个用户开启的事务，不能被其他事务的操作数据所干扰，多个并发事务之间要相互隔离。
持久性（Durability）
持久性是指一个事务一旦被提交，它对数据库中数据的改变就是永久性的，接下来即使数据库发生故障也不应该对其有任何影响

事务的隔离级别分为：未提交读(read uncommitted)、已提交读(read committed)、可重复读(repeatable read)、串行化(serializable)。

Spring 事务中哪几种事务传播行为?
支持当前事务的情况：
TransactionDefinition.PROPAGATION_REQUIRED： 如果当前存在事务，则加入该事务；如果当前没有事务，则创建一个新的事务。
TransactionDefinition.PROPAGATION_SUPPORTS： 如果当前存在事务，则加入该事务；如果当前没有事务，则以非事务的方式继续运行。
TransactionDefinition.PROPAGATION_MANDATORY： 如果当前存在事务，则加入该事务；如果当前没有事务，则抛出异常。（mandatory：强制性）
不支持当前事务的情况：
TransactionDefinition.PROPAGATION_REQUIRES_NEW： 创建一个新的事务，如果当前存在事务，则把当前事务挂起。
TransactionDefinition.PROPAGATION_NOT_SUPPORTED： 以非事务方式运行，如果当前存在事务，则把当前事务挂起。
TransactionDefinition.PROPAGATION_NEVER： 以非事务方式运行，如果当前存在事务，则抛出异常。
其他情况：
TransactionDefinition.PROPAGATION_NESTED： 如果当前存在事务，则创建一个事务作为当前事务的嵌套事务来运行；如果当前没有事务，则该取值等价于TransactionDefinition.PROPAGATION_REQUIRED。
事务挂起： 不使用这个事务，如果抛出异常不影响事务。
嵌套事务：
  如果里面出现了异常，回到保存点的状态，外部事务不会回滚，如果外部事务抛出异常，影响嵌套事务回滚。

Spring 事务中隔离级别有哪几种?
  TransactionDefinition 接口中定义了五个表示隔离级别的常量：
    1.TransactionDefinition.ISOLATION_DEFAULT: 使用后端数据库默认的隔离级别，Mysql 默认采用的 REPEATABLE_READ隔离级别 Oracle 默认采用的 READ_COMMITTED隔离级别.
    2.TransactionDefinition.ISOLATION_READ_UNCOMMITTED: 最低的隔离级别，允许读取尚未提交的数据变更，可能会导致脏读、幻读或不可重复读
    3.TransactionDefinition.ISOLATION_READ_COMMITTED: 允许读取并发事务已经提交的数据，可以阻止脏读，但是幻读或不可重复读仍有可能发生
    4.TransactionDefinition.ISOLATION_REPEATABLE_READ: 对同一字段的多次读取结果都是一致的，除非数据是被本身事务自己所修改，可以阻止脏读和不可重复读，但幻读仍有可能发生。
    5.TransactionDefinition.ISOLATION_SERIALIZABLE: 最高的隔离级别，完全服从ACID的隔离级别。所有的事务依次逐个执行，这样事务之间就完全不可能产生干扰，也就是说，该级别可以防止脏读、不可重复读以及幻读。但是这将严重影响程序的性能。通常情况下也不会用到该级别。




分布式事务：分布式事务由事务发起者、资源管理器（参与者）、事务协调者组成。
  1 基于XA协议的两阶段提交方案
    交易中间件与数据库通过 XA 接口规范，使用两阶段提交来完成一个全局事务， XA 规范的基础是两阶段提交协议。
    第一阶段是表决阶段，所有参与者都将本事务能否成功的信息反馈发给协调者；
    第二阶段是执行阶段，协调者根据所有参与者的反馈，通知所有参与者，步调一致地在所有分支上提交或者回滚。
  两阶段提交方案应用非常广泛，几乎所有商业OLTP数据库都支持XA协议。但是两阶段提交方案锁定资源时间长，对性能影响很大，基本不适合解决微服务事务问题。
  优点：
    1 较强的一致性，适合于对数据一致性要求比较高对场景，当然并不是100%一致性
  缺点：
  1 整个过程耗时过程，锁定资源时间过长，同步阻塞（准备阶段回复后，一直等待协调者调用commit 或者rollback），CAP中达到了CP，牺牲了可用性，不适合高并发场景
  2 协调者可能存在单点故障
  3 Commit阶段可能存在部分成功，部分失败情况，并没有提及是否rollback


  3PC三阶段提交(非阻塞，引入超时和准备阶段)
    进入阶段3之后，如果协调者或者执行者因为网络等问题，接受不到docommit请求，超时后默认都执行doCommit请求，解决了2PC的第三个缺点
    第一阶段canCommit
      事务发起方发起事务后，事务协调器会给所有的事务参与者发起canCommit?的请求，参与者收到后根据自己的情况判断是否可以执行提交，如果可以则回执OK，否者返回fail，并不开启本地事务并执行。具体参与者是如何判断本地是否可以执行提交协议并没有具体规定，需要协议实现者自己规定，比如可能判断参与者是否存在（网络是否OK）或者本地数据库连接是否可用来判断（YY）。
      如果协调器发现有些发起方返回fail或者等待超时后参与者还没返回则给所有事务参与者发起中断操作，具体中断操作做什么协议也没有具体规定。如果协调器发现所有参与者返回可以提交，则进入第二阶段。
    第二阶段preCommit
      事务协调器向所有参与者发起准备事务请求，参与者接受到后，开启本地事务并执行，但是不提交。剩下的与二阶段的一阶段一致。
    第三阶段commit
      事务协调器向所有事务参与者发起提交事务的请求，事务参与者接受到请求后，执行本地事务的提交操作。如果事务协调器收到所有参与者提交OK则分布式事务结束。

    优点：
      降低了阻塞范围，在等待超时后协调者或参与者会中断事务。避免了协调者单点问题，阶段3中协调者出现问题时，参与者会继续提交事务。
    缺陷：
      脑裂问题依然存在，即在参与者收到PreCommit请求后等待最终指令，如果此时协调者无法与参与者正常通信，会导致参与者继续提交事务，造成数据不一致。
  2pc与3pc区别：
      三阶段与二阶段最大不同在于三阶段协议把二阶段的第一阶段拆分为了两个阶段，其中第一阶段并不锁定资源，而是询问参与者是否可以提交，等所有参与者回复OK后在具体执行第二阶段锁定资源。理论上如果第一阶段返回都OK，则第二阶段和三阶段执行成功的概率就很大，另外如果第一阶段有些参与者返回了fail，由于这时候其他参与者还没有锁定资源，所以不会造成资源的阻塞。3PC引入了超时提交的策略，而不是盲等待，


  TCC（事务补偿）方案：
    TCC方案其实是两阶段提交的一种改进。其将整个业务逻辑的每个分支显式的分成了Try、Confirm、Cancel三个操作。Try部分完成业务的准备工作，confirm部分完成业务的提交，cancel部分完成事务的回滚。
    事务开始时，业务应用会向事务协调器注册启动事务。之后业务应用会调用所有服务的try接口，完成一阶段准备。之后事务协调器会根据try接口返回情况，决定调用confirm接口或者cancel接口。如果接口调用失败，会进行重试。
    TCC方案让应用自己定义数据库操作的粒度，使得降低锁冲突、提高吞吐量成为可能。 当然TCC方案也有不足之处，集中表现在以下两个方面：
      对应用的侵入性强。业务逻辑的每个分支都需要实现try、confirm、cancel三个操作，应用侵入性较强，改造成本高。
      实现难度较大。需要按照网络状态、系统故障等不同的失败原因实现不同的回滚策略。为了满足一致性的要求，confirm和cancel接口必须实现幂等。

    TCC与2pc/3pc区别： 2pc/3pc执行需要依赖数据库层面，而tcc更适合微服务应用层面。  

  基于MQ的最终一致性方案
    消息一致性方案是通过消息中间件保证上、下游应用数据操作的一致性。基本思路是将本地操作和发送消息放在一个事务中，保证本地操作和消息发送要么两者都成功或者都失败。下游应用向消息系统订阅该消息，收到消息后执行相应操作。消息方案从本质上讲是将分布式事务转换为两个本地事务，然后依靠下游业务的重试机制达到最终一致性。基于消息的最终一致性方案对应用侵入性也很高，应用需要进行大量业务改造，成本较高。


CAP理论：
C(Consistency)
  一致性是说数据的原子性,这种原子性在经典ACID的数据库中是通过事务来保证的,当事务完成时,无论其是成功还是回滚,数据都会处于一致的状态.
  在分布式环境中,一致性是说多点的数据是否一致.
A(Availability)
  可用性是说服务能一直保证是可用的状态，当用户发出一个请求，服务能在有限时间内返回结果。
而这种可用性是不关乎结果的正确与否，所以，如果服务一致返回错误的数据,其实也可以称为其是可用的。
P(Tolerance of network Partition)
  是指网络的分区，网络中的两个服务结点出现分区的原因很多，比如网络断了、对方结点因为程序bug或死机等原因不能访问
一个分布式系统不可能满足一致性，可用性和分区容错性这三个需求,最多只能同时满足两个。


BASE理论：
  Basically Availble 牺牲高一致性，获得可用性或可靠性 --基本可用
  Soft-state --软状态/软事务，状态可以有一段时间不同步，异步。
  Eventual Consistency --最终一致性，最终数据是一致的就可以了，而不是实时一致。


