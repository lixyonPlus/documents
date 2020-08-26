# Spring:

- @Configuration 会进行动态代理保证单例，不加会初始化多次，不会生成动态代理。
- ConfigurationClassPostProcessor : 
- DefaultListableBeanFactory：
- ConfigurationClassEnhancer: cglib代理，基于类实现， （代理名称：xxBySpringCGLIB），BeanMethodInterceptor对目标对象 拦截，保证对象不会重复创建
- BeanFactoryPostProcessor：后置执行器
- BeanPostProcess： AOP基于此实现

- BeanFactory定义了 IOC 容器的最基本形式，并提供了 IOC 容器应遵守的的最基本的接口，也就是 Spring IOC所遵守的最底层和最基本的编程规范。在Spring代码中， BeanFactory 只是个接口，并不是 IOC 容器的具体实现，但是 Spring 容器给出了很多种实现，如 DefaultListableBeanFactory 、 XmlBeanFactory 、 ApplicationContext等，都是附加了某种功能的实现。

- 一般情况下，Spring 通过反射机制利用 <bean> 的 class 属性指定实现类实例化 Bean。在某些情况下，实例化Bean 过程比较复杂，如果按照传统的方式，则需要在 <bean> 中提供大量的配置信息。配置方式的灵活性是受限的，这时采用编码的方式可能会得到一个简单的方案。Spring 为此提供了一个org.springframework.bean.factory.FactoryBean 的工厂类接口，用户可以通过实现该接口定制实例化 Bean 的逻辑。
FactoryBean接口对于 Spring 框架来说占用重要的地位， Spring 自身就提供了 70 多个 FactoryBean 的实现。它们隐藏了实例化一些复杂 Bean 的细节，给上层应用带来了便利。从 Spring 3.0 开始， FactoryBean 开始支持泛型，即接口声明改为 FactoryBean<T> 的形式：区别：
 - BeanFactory是个 Factory ，也就是 IOC 容器或对象工厂， FactoryBean 是个 Bean 。在 Spring 中，所有的Bean 都是由 BeanFactory( 也就是 IOC 容器 ) 来进行管理的。但对 FactoryBean 而言，这个 Bean 不是简单的 Bean，而是一个能生产或者修饰对象生成的工厂 Bean, 它的实现与设计模式中的工厂模式和修饰器模式类似。


- BeanFactory是一个最顶层的接口，他定义了IOC容器的基本功能规范，他有三个子类：ListableBeanFactory、HierarchicalBeanFactory、AutowireCapableBeanFactory但是最终的默认实现类是DefaultListableBeanFactory它实现了所有接口。ListableBeanFactory表示Bean是可列表的，HierarchicalBeanFactory表示bean是有继承关系的，AutowireCapableBeanFactory表示bean自动装配规则，他们共同定义了bean的集合，bean之间的关系和bean的行为。
- XMlBeanFactory就是对DefaultListableBeanFactory的实现，这个IOC容器可以读取XML配置BeanDefinition（就是xml配置文件中对bean的配置）。
- ApplicationContext不仅继承了容器的基本实现，还支持一些高级功能，比如：国际化、访问资源、时间机制。
- Bean的定义在spring中是通过BeanDefinition来描述的。


### IOC容器初始化过程：
 - 初始化包括Beandefinition的Resource定位、载入、注册三个基本的过程。
 - ①BeanFactroy采用的是延迟加载形式来注入Bean的，即只有在使用到某个Bean时(调用getBean())，才对该Bean进行加载实例化。这样，我们就不能发现一些存在的Spring的配置问题。如果Bean的某一个属性没有注入，BeanFacotry加载后，直至第一次使用调用getBean方法才会抛出异常。
 - ②ApplicationContext，它是在容器启动时，一次性创建了所有的Bean。这样，在容器启动时，我们就可以发现Spring中存在的配置错误，这样有利于检查所依赖属性是否注入。 ApplicationContext启动后预载入所有的单实例Bean，通过预载入单实例bean ,确保当你需要的时候，你就不用等待，因为它们已经创建好了。

### IOC容器什么时候依赖注入？
 - 1.第一次getBean()的时候，触发依赖注入。
 - 2.在<bean>资源中定义lazy-init时，即让bean在解析注册bean时预实例化触发依赖注入。

### 创建bean：AbstractAutowireCapableBeanFactory实现了ObjectFactory接口，创建容器指定的bean实例，同时还对创建的对象进行初始化。BeanWrapperImpl处理依赖注入



### AOP 是基于动态代理模式实现的，具体实现上可以基于JDK动态代理或者Cglib动态代理。其中 JDK 动态代理只能代理实现了接口的对象，而 Cglib 动态代理则无此限制。所以在为没有实现接口的对象生成代理时，只能使用 Cglib。
 - 切面、切入点、连接点、通知、目标对象、aop代理
 - 通知：前置通知、后置通知、返回后通知、环绕通知、抛出异常后通知
 - 1. AOP 逻辑介入 BeanFactory 实例化 bean 的过程
 - 2. 根据 Pointcut 定义的匹配规则，判断当前正在实例化的 bean 是否符合规则
 - 3. 如果符合，代理生成器将切面逻辑 Advice 织入 bean 相关方法中，并为目标 bean 生成代理对象
 - 4. 将生成的 bean 的代理对象返回给 BeanFactory 容器，到此，AOP 逻辑执行结束
 
### springmvc优化点：每次发起请求时，springmvc没有对请求地址进行缓存。

### AbstractAutoProxyCreator:spring代理对象顶级抽象类

### 所谓 IOC ，就是由 Spring IOC 容器来负责对象的生命周期和对象之间的关系

### spring bean生命周期：
  - 实例化bean对象，检查aware相关接口并设置相关依赖，执行BeanPostProcessor前置处理，检查是否有InitializingBean以决定是否调用afterPropertiesSet方法，检查是否有配置初始化方法，BeanPostProcessor后置处理，调用DisposableBean接口执行destroy方法，是否配置有销毁方法。
  

### spring 解决循坏依赖问题：三层依赖
- 其中第一层是singletonObjects，首先会去看singletonObjects是否已经创建了一个对象。如果没有，那么从第二层缓存earlySingletonObjects提前曝光对象的缓存中获取；如果没有，那么最后从第三层缓存singletonFactories单实例工厂缓存中获取。当获取成功后，会把第三层缓存singletonFactories的bean去掉，加入到第二层缓存中。


### Spring容器中的bean可以分为5个范围：
 - 1. singleton：默认，每个容器中只有一个bean的实例，单例的模式由BeanFactory自身来维护。
 - 2. prototype：为每一个bean请求提供一个实例。
 - 3. request：为每一个网络请求创建一个实例，在请求完成以后，bean会失效并被垃圾回收器回收。
 - 4. session：与request范围类似，确保每个session中有一个bean的实例，在session过期后，bean会随之失效。
 - 5. global-session：全局作用域，global-session和Portlet应用相关。当你的应用部署在Portlet容器中工作时，它包含很多portlet。如果你想要声明让所有的portlet共用全局的存储变量的话，那么这全局变量需要存储在global-session中。全局作用域与Servlet中的session作用域效果相同。

### Spring 提供了以下5种标准的事件：
 - 1. 上下文更新事件（ContextRefreshedEvent）：在调用ConfigurableApplicationContext 接口中的refresh()方法时被触发。
 - 2. 上下文开始事件（ContextStartedEvent）：当容器调用ConfigurableApplicationContext的Start()方法开始/重新开始容器时触发该事件。
 - 3. 上下文停止事件（ContextStoppedEvent）：当容器调用ConfigurableApplicationContext的Stop()方法停止容器时触发该事件。
 - 4. 上下文关闭事件（ContextClosedEvent）：当ApplicationContext被关闭时触发该事件。容器被关闭时，其管理的所有单例Bean都被销毁。
 - 5. 请求处理事件（RequestHandledEvent）：在Web应用中，当一个http请求（request）结束触发该事件。
 - 如果一个bean实现了ApplicationListener接口，当一个ApplicationEvent 被发布以后，bean会自动被通知。

### 在 Spring Boot 启动的时候运行一些特定的代码？
 - 可以实现接口 ApplicationRunner 或者 CommandLineRunner，这两个接口实现方式一样，它们都只提供了一个 run 方法。

### SmartInitializingSingleton是所有单例的bean初始化完成之后执行的回调方法。

### @Autowired注解原理：
 - 注解解析器：AutowiredAnnotationBeanPostProcessor
 - 1.Spring容器启动时，AutowiredAnnotationBeanPostProcessor被注册到容器；
 - 2.扫描代码，如果带有@Autowired注解，（扫描当前类中标注@Autowired的属性和方法；再查找父类中注@Autowired的属性和方法，依次遍历；）则将依赖注入信息封装到InjectionMetadata中（见扫描过程）；
 - 3.创建bean时（实例化对象和初始化），会调用各种BeanPostProcessor对bean初始化，AutowiredAnnotationBeanPostProcessor负责将相关的依赖注入进来
 
### @Autowired注入对象顺序: 按类型找->通过限定符@Qualifier过滤->@Primary->@Priority->根据名称找（字段名称或者方法名称）
### @Resource注入对象顺序: 按名称（字段名称、方法名称、set属性名称）找->按类型找->通过限定符@Qualifier过滤


### 当@Bean方法在没有使用@Configuration注解的类中声明时称之为lite @Bean mode，不会被动态代理,否则称为full @Bean mode，会被动态代理

### 被CGLIB的方法是不能被声明为private和final，因为CGLIB是通过生成子类来实现代理的，private和final方法是不能被子类Override的，也就是说，Full @Configuration模式下，@Bean的方法是不能不能被声明为private和final，不然在启动时Spring会直接报错。

### OrderComparator比较器进行排序的时候，若2个对象中有一个对象实现了PriorityOrdered接口，那么这个对象的优先级更高。若2个对象都是PriorityOrdered或Ordered接口的实现类，那么比较Ordered接口的getOrder方法得到order值，值越低，优先级越高。

### BeanMethodInterceptor主要作用是：拦截@Bean方法的调用，以确保正确处理@Bean语义。当调用@Bean方法时，就会被以下代码所拦截

### BeanFactoryPostProcessor接口，获取BeanFactory，操作BeanFactory对象，修改BeanDefinition，但不要去实例化bean。

### BeanDefinitionRegistryPostProcessor是BeanFactoryPostProcessor的子类，在父类的基础上，增加了新的方法，允许我们获取到BeanDefinitionRegistry，从而编码动态修改BeanDefinition。例如往BeanDefinition中添加一个新的BeanDefinition。


### springmvc是不是线程安全的。
  - 对于使用过SpringMVC和Struts2的人来说，大家都知道SpringMVC是基于方法的拦截，而Struts2是基于类的拦截。struct2为每一个请求都实例化一个action所以不存在线程安全问题，springmvc默认单例请求使用一个Controller，假如这个Controller中定义了静态变量，就会被多个线程共享。所以springmvc的controller不要定义静态变量。如果要使用可以用ThreadLocal或者@Scope("prototype")开启不以单例的模式运行但是以这种方式运行就不是单例了会有额外的开销。



### springmvc:
 - 1.客户端（浏览器）发送请求，直接请求到 DispatcherServlet。
 - 2.DispatcherServlet 根据请求信息调用 HandlerMapping，解析请求对应的 Handler。
 - 3.解析到对应的 Handler（也就是我们平常说的 Controller 控制器）后，开始由 HandlerAdapter 适配器处理。
 - 4.HandlerAdapter 会根据 Handler 来调用真正的处理器开处理请求，并处理相应的业务逻辑。
 - 5.处理器处理完业务后，会返回一个 ModelAndView 对象，Model 是返回的数据对象，View 是个逻辑上的 View。
 - 6.ViewResolver 会根据逻辑 View 查找实际的 View。
 - 7.DispaterServlet 把返回的 Model 传给 View（视图渲染）。
 - 8.把 View 返回给请求者（浏览器）

### OncePerRequestFilter： 为了兼容不同的web容器，默认的所有filter继承他。


### 什么是springboot自动装配？
    spring程序在main方法中添加了@springbootapplication和@enableAutoConfiguration会自动读取每一个starter包下的spring.factories中的配置文件。

### 如何将springboot打成war包运行
  - 启动类继承SpringBootServletInitializer类重写configure方法。
  - 修改pom文件配置war格式。

### SpringBootApplication包含@SpringBootConfiguration、@EnableAutoConfiguration、@ComponentScann


### AbstractBeanFactoryAwareAdvisingPostProcessor 方法级验证，注解验证基于此实现

### spring父子容器
  - 通常我们使用springmvc的时候，采用3层结构，controller层，service层，dao层；父容器中会包含dao层和service层，而子容器中包含的只有controller层；这2个容器组成了父子容器的关系，controller层通常会注入service层的bean。采用父子容器可以避免有些人在service层去注入controller层的bean，导致整个依赖层次是比较混乱的。父容器和子容器的需求也是不一样的，比如父容器中需要有事务的支持，会注入一些支持事务的扩展组件，而子容器中controller完全用不到这些，对这些并不关心，子容器中需要注入一下springmvc相关的bean，而这些bean父容器中同样是不会用到的，也是不关心一些东西，将这些相互不关心的东西隔开，可以有效的避免一些不必要的错误，而父子容器加载的速度也会快一些。
  - 子容器可以访问父容器中bean，父容器无法访问子容器中的bean
