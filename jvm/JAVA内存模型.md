JAVA内存模型：
  java内存模型是如何实现的：主要通过内存屏障禁止重排序，即时编译器根据具体的底层体系架构，将这些内存屏障替换成具体的cpu指令。
  3个特性：有序性、可见性、原子性
  导致可见性的原因是缓存，导致有序性的原因是编译优化（指令重排）
  涉及 volatile、synchronized、final 以及 6项Happens-Before规则
  Happens-Benfore：前面一个操作的结果对后续的操作是可见的。
    1.程序顺序性规则：在一个线程中，按照程序顺序Happers-Before于后续操作可见。
    2.volatile变量规则：对一个volatile变量的写操作，Happens-Before于后续对这个Volatile变量的读操作。
    3.传递性：如果A Happens-Before B，且B Happens-Before C，那么A Happens-Before C。
    4.管程中的锁（synchronized）规则：对一个锁的解锁Happens-Before于后续对这个锁的加锁，管程是一种通用的同步原语，在java中指的是synchronized，是java对管程的实现。
    5.线程start（）规则：主线程序A启动子线程B后，子线程B能够看到主线程在启动子线程B前的操作。
    6.线程join（）规则：主线程A等待子线程B完成，子线程B完成后，主线程能够看到子线程的操作。
    7.线程interrupt（）规则：对线程interrupt（）的方法的调用先行发生于被中断的线程的代码检测到中断的事件的发生，可以通过Thread.interrupted（）方法检测到是否有中断发生。
    8.对象终结规则： 一个对象的初始化完成（构造方法执行结束）先行发生于他的finalize（）方法的开始。
    final：变量生而不变，
    volatile：目的是为了禁用缓存和编译优化。
  synchronized：修饰静态方法时锁定的是当前类的class对象，修饰非静态方法时，锁定的是当前实例对象this。