## JAVA内存模型(JMM)
- JMM主要是指java线程之间的通信，也就是工作内存和主内存之间如何通信，它涵盖了缓存、写缓存区、寄存器和其他的硬件编译器优化等内容。

### java内存模型是如何实现的：
- 主要是通过重排序、三个同步原语（synchronize、volatile、final）、内存屏障构成的happen-before原则。

#### 重排序:重排序是指编译器和处理器为了优化程序性能对指令序列进行重新排序的手段
- 重排序分三种类型：
    1. 编译器优化的重排序。编译器在不改变单线程程序语义的前提下，可以重新安排语句的执行顺序。
    2. 指令级并行的重排序。现代处理器采用了指令级并行技术（Instruction-Level Parallelism， ILP）来将多条指令重叠执行。如果不存在数据依赖性，处理器可以改变语句对应机器指令的执行顺序。
    3. 内存系统的重排序。由于处理器使用缓存和读 / 写缓冲区，这使得加载和存储操作看上去可能是在乱序执行。

#### volatile的定义和实现
- volatile是轻量级的synchronize，有volatile修饰的变量转换成汇编代码时，会增加lock前缀，lock前缀的指令在多核处理器会发生两件事：
1. 将当前处理器的缓存行的数据写入到系统内存
2. 这个写回内存会导致其他处理器缓存了该内存地址的数据无效
3. volatile的内存语义
   - 原子性：对volatile变量的单个读/写，具有原子性
   - 可见性：对一个volatile变量的读，总能看到对这个变量最后的写。
4. volatile的内存屏障
   - 当第二个操作为volatile写时，不管第一个操作是什么，都禁止重排序。
   - 当第一个操作为volatile读时，不管第二个操作是什么，都禁止重排序
5. synchronize的实现原理
代码块的实现是通过moniorenter和monitorexit指令，方法的实现是通过修饰符ACC_SYNCHRONIZE实现的。

#### JMM通过“内存屏障”实现final,在final域的写之后，构造函数return之前，插入一个StoreStore屏障。在读final域的操作前面插入一个LoadLoad屏障。

#### 内存屏障
   - 为了保证内存可见性，Java编译器在生成指令序列的适当位置会插入内存屏障指令来禁止特定类型的处理器重排序，java把内存屏障分为4类。LoadLoad、StoreStore、LoadStore、StoreLoad，其中StoreLoad同时具备其他三个屏障的效果。
  
#### Happens-Benfore：前面一个操作的结果对后续的操作是可见的。
    1. 程序顺序性规则：在一个线程中，按照程序顺序Happers-Before于后续操作可见。
    2. volatile变量规则：对一个volatile变量的写操作，Happens-Before于后续对这个Volatile变量的读操作。
    3. 传递性：如果A Happens-Before B，且B Happens-Before C，那么A Happens-Before C。
    4. 管程中的锁（synchronized）规则：对一个锁的解锁Happens-Before于后续对这个锁的加锁，管程是一种通用的同步原语，在java中指的是synchronized，是java对管程的实现。
    5. 线程start（）规则：主线程序A启动子线程B后，子线程B能够看到主线程在启动子线程B前的操作。
    6. 线程join（）规则：主线程A等待子线程B完成，子线程B完成后，主线程能够看到子线程的操作。
    7. 线程interrupt（）规则：对线程interrupt（）的方法的调用先行发生于被中断的线程的代码检测到中断的事件的发生，可以通过Thread.interrupted（）方法检测到是否有中断发生。
    8. 对象终结规则： 一个对象的初始化完成（构造方法执行结束）先行发生于他的finalize（）方法的开始。
    9. final：变量生而不变，
    10. volatile：目的是为了禁用缓存和编译优化。

#### 3个特性：
   - 有序性、可见性、原子性,导致可见性的原因是缓存，导致有序性的原因是编译优化（指令重排）涉及 volatile、synchronized、final 以及 6项Happens-Before规则，原子性是因为线程切换。
  

