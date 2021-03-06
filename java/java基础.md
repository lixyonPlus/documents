### Servlet是不是线程安全的。
  - Servlet不是线程安全的。当Tomcat接收到Client的HTTP请求时，Tomcat从线程池中取出一个线程，之后找到该请求对应的Servlet对象并进行初始化，之后调用service()方法。要注意的是每一个Servlet对象再Tomcat容器中只有一个实例对象，即是单例模式。如果多个HTTP请求请求的是同一个Servlet，那么这两个HTTP请求对应的线程将并发调用Servlet的service()方法。

### 为什么需要重写equals和hashCode方法？
  - 不重写equals和hashCode方法的话是不依赖于对象属性的变化的，也就是说这里使用默认的hashCode方法可以取到值。但是我们重写equal方法的初衷是判定对象属性都相等的对象是相等的，而不是说同一个对象的引用才相等。
  - 如果只重写了equals方法而没有重写hashCode方法的话，则会违反约定的第二条：相等的对象必须具有相等的散列码（hashCode）。
  - 同时对于HashSet和HashMap这些基于散列值（hash）实现的类。HashMap的底层处理机制是以数组的方法保存放入的数据的(Node<K,V>[] table)，其中的关键是数组下标的处理。数组的下标是根据传入的元素hashCode方法的返回值再和特定的值异或决定的。所以如果不重写hashCode的话，可能导致HashSet、HashMap不能正常的运作。

### String
  1. String的创建机制，由于String在Java世界中使用过于频繁，Java为了避免在一个系统中产生大量的String对象，引入了字符串常量池。
      - 其运行机制是:创建一个字符串时，首先检查池中是否有值相同的字符串对象，如果有则不需要创建直接从池中刚查找到的对象引用;如果没有则新建字符串对象，返回对象引用，并且将新创建的对象放入池中。但是，通过new方法创建的String对象是不检查字符串池的，而是直接在堆区或栈区创建一个新的对象，也不会把对象放入池中。上述原则只适用于通过直接量给String对象引用赋值的情况。
      - 举例:String str1 = "123"; //通过直接量赋值方式，放入字符串常量池
      - String str2 = new String(“123”);//通过new方式赋值方式，不放入字符串常量池
      - 注意:String提供了inter()方法。调用该方法时，如果常量池中包括了一个等于此String对象的字符串(由equals方法确定)，则返回池中的字符串。否则，将此String对象添加到池中，并且 返回此池中对象的引用。
  2. String的特性
    - 不可变。是指String对象一旦生成，则不能再对它进行改变。不可变的主要作用在于当一个对象需要被多线程共享，并且访问频繁时，可以省略同步和锁等待的时间，从而大幅度提高系统性能。不可变模   式是一个可以提高多线程程序的性能，降低多线程程序复杂度的设计模式。
    - 针对常量池的优化。当2个String对象拥有相同的值时，他们只引用常量池中的同一个拷贝。当同一个字符串反复出现时，这个技术可以大幅度节省内存空间。

### String字符串+号与concat拼接字符串
String字符串+号拼接字符串是将String转成了StringBuilder后，使用其append方法进行处理的。+号属于语法糖
concat拼接字符串，首先创建了一个字符数组(char[])，长度是已有字符串和待拼接字符串的长度之和，再把两个字符串的值复制到新的字符数组中，并使用这个字符数组创建一个新的String对象并返回。


### StringBufer/StringBuilder
  - StringBufer和StringBuilder都实现了AbstractStringBuilder抽象类，拥有几乎一致对外提供的调用接口;其底层在内存中的存储方式与String相同，都是以一个有序的字符序列(char类型的数组)进行存储，不同点是StringBufer/StringBuilder对象的值是可以改变的，并且值改变以后，对象引用不会发生改变;两者对象在构造过程中，首先按照默认大小申请一个字符数组，由 于会不断加入新数据，当超过默认大小后，会创建一个更大的数组，并将原先的数组内容复制过来，再丢弃旧的数组。因此，对于较大对象的扩容会涉及大量的内存复制操作，如果能够预先评 估大小，可提升性能。唯一需要注意的是:StringBufer是线程安全的，但是StringBuilder是线程不安全的。可参看Java标准类库的源代码，StringBufer类中方法定义前面都会有synchronize关键字。为 此，StringBufer的性能要低于StringBuilder。
  - 应用场景 
  1. 在字符串内容不经常发生变化的业务场景优先使用String类。例如:常量声明、少量的字符串拼接操作等。如果有大量的字符串内容拼接，避免使用String与String之间的“+”操作，因为这样会产生大量无用的中间对象，耗费空间且执行效率低下(新建对象、回收对象花费大量时间)。
  2. 在频繁进行字符串的运算(如拼接、替换、删除等)，并且运行在多线程环境下，建议使用StringBufer，例如XML解析、HTTP参数解析与封装。
  3. 在频繁进行字符串的运算(如拼接、替换、删除等)，并且运行在单线程环境下，建议使用StringBuilder，例如SQL语句拼装、JSON封装等。

### int和Integer
  - JDK1.5引入了自动装箱与自动拆箱功能，Java可根据上下文，实现int/Integer,double/Double,boolean/Boolean 等基本类型与相应对象之间的自动转换，为开发过程带来极大便利。最常用的是通过new方法构建Integer对象。但是，基于大部分数据操作都是集中在有限的、较小的数值范围，在JDK1.5 中新增了静态工厂方法 valueOf，其背后实现是将int值为-128 到 127 之间的Integer对象进行缓存，在调用时候直接从缓存中获取，进而提升构建对象的性能，也就是说使用该方法后，如果两个对象的int值相同且落在缓存值范围内，那么这个两个对象就是同一个对象;当值较小且频繁使用时，推荐优先使用整型池方法(时间与空间性能俱佳)。
  - 注意事项
  1. 基本类型均具有取值范围，在大数*大数的时候，有可能会出现越界的情况。
  2. 基本类型转换时，使用声明的方式。例:long result= 1234567890 * 24 * 365;结果值一定不会是你所期望的那个值，因为1234567890 * 24已经超过了int的范围，如果修改 为:long result= 1234567890L * 24 * 365;就正常了。
  3. 慎用基本类型处理货币存储。如采用double常会带来差距，常采用BigDecimal、整型(如果要精确表示分，可将值扩大100倍转化为整型)解决该问题。
  4. 优先使用基本类型。原则上，建议避免无意中的装箱、拆箱行为，尤其是在性能敏感的场合，
  5. 如果有线程安全的计算需要，建议考虑使用类型AtomicInteger、AtomicLong 这样的线程安全类。部分比较宽的基本数据类型，比如 float、double，甚至不能保证更新操作的原子性，可能出现程序读取到只更新了一半数据位的数值。


### 反射中Class.forName()和ClassLoader.loadClass()的区别：
  - Class.forName(className)方法，内部实际调用的方法是  Class.forName(className,true,classloader);第2个boolean参数表示类是否需要初始化，  Class.forName(className)默认是需要初始化。 一旦初始化，就会触发目标对象的 static块代码执行，static参数也会被再次初始化。
  - ClassLoader.loadClass(className)方法，内部实际调用的方法是  ClassLoader.loadClass(className,false);false表示不进行链接，不进行链接意味着不进行包括初始化等一些列步骤，那么静态块和静态对象就不会得到执行

### 在Java语言中，除了基本数据类型外，其他的都是指向各类对象的对象引用;Java中根据其生命周期的长短，将引用分为4类。
  1. 强引用
  - 特点:我们平常典型编码Object obj = new Object()中的obj就是强引用。通过关键字new创建的对象所关联的引用就是强引用。 当JVM内存空间不足，JVM宁愿抛出OutOfMemoryError运行时错误(OOM)，使程序异常终止，也不会靠随意回收具有强引用的“存活”对象来解决内存不足的问题。对于一个普通的对象，如果没有其他的引用关系，只要超过了引用的作用域或者显式地将相应(强)引用赋值为null，就是可以被垃圾收集的了，具体回收时机还是要看垃圾收集策略。
  2. 软引用
  - 特点:软引用通过SoftReference类实现。 软引用的生命周期比强引用短一些。只有当 JVM 认为内存不足时，才会去试图回收软引用指向的对象:即JVM 会确保在抛出 OutOfMemoryError 之前，清理软引用指向的对象。软引用可以和一个引用队列(ReferenceQueue)联合使用，如果软引用所引用的对象被垃圾回收器回收，Java虚拟机就会把这个软引用加入到与之关联的引用 队列中。后续，我们可以调用ReferenceQueue的poll()方法来检查是否有它所关心的对象被回收。如果队列为空，将返回一个null,否则该方法返回队列中前面的一个Reference对象。
  - 应用场景:软引用通常用来实现内存敏感的缓存。如果还有空闲内存，就可以暂时保留缓存，当内存不足时清理掉，这样就保证了使用缓存的同时，不会耗尽内存。
  3. 弱引用
  - 弱引用通过WeakReference类实现。 弱引用的生命周期比软引用短。在垃圾回收器线程扫描它所管辖的内存区域的过程中，一旦发现了具有弱引用的对象，不管当前内存空间足够与否，都会 回收它的内存。由于垃圾回收器是一个优先级很低的线程，因此不一定会很快回收弱引用的对象。弱引用可以和一个引用队列(ReferenceQueue)联合使用，如果弱引用所引用的对象被垃圾 回收，Java虚拟机就会把这个弱引用加入到与之关联的引用队列中。
  - 应用场景:弱应用同样可用于内存敏感的缓存。
  4. 虚引用
  - 特点:虚引用也叫幻象引用，通过PhantomReference类来实现。无法通过虚引用访问对象的任何属性或函数。幻象引用仅仅是提供了一种确保对象被 fnalize 以后，做某些事情的机制。如果 一个对象仅持有虚引用，那么它就和没有任何引用一样，在任何时候都可能被垃圾回收器回收。虚引用必须和引用队列 (ReferenceQueue)联合使用。当垃圾回收器准备回收一个对象时，如 果发现它还有虚引用，就会在回收对象的内存之前，把这个虚引用加入到与之关联的引用队列中。
  - ReferenceQueue queue = new ReferenceQueue ();
  - PhantomReference pr = new PhantomReference (object, queue);
  - 程序可以通过判断引用队列中是否已经加入了虚引用，来了解被引用的对象是否将要被垃圾回收。如果程序发现某个虚引用已经被加入到引用队列，那么就可以在所引用的对象的内存被回收之前采取一些程序行动。
  - 应用场景:可用来跟踪对象被垃圾回收器回收的活动，当一个虚引用关联的对象被垃圾收集器回收之前会收到一条系统通知。

### 增强for循环只是一个语法糖，底层使用while+iterator实现。

### 使用增强for循环删除集合元素时抛出 ConcurrentModificationException 异常：
之所以会抛出ConcurrentModificationException异常，是因为我们的代码中使用了增强for循环，而在增强for循环实现中，集合遍历是通过iterator进行的，但是元素的add/remove却是直接使用的集合类自己的方法。这就导致iterator在遍历的时候，会发现有一个元素在自己不知不觉的情况下就被删除/添加了，就会抛出一个异常，用来提示用户，可能发生了并发修改!

### SimpleDateFormat非线程安全的原理：
将SimpleDateFormat声明未静态变量，由于SimpleDateFormat类中有calendar成员变量，多线程环境下format、parse会出现问题。

### ThreadLocal为什么会发生内存泄漏
ThreadLocalMap中使用的key为ThreadLocal的弱引用,而value是强引用。所以，如果ThreadLocal没有被外部强引用的情况下，在垃圾回收的时候，key会被清理掉，而value不会被清理掉。这样一来，ThreadLocalMap中就会出现key为null的Entry。假如我们不做任何措施的话，value永远无法被GC回收，这个时候就可能会产生内存泄露。ThreadLocalMap实现中已经考虑了这种情况，在调用set()、get()、remove() 方法的时候，会清理掉key为null的记录。使用完 ThreadLocal方法后 最好手动调用remove()方法。
