### 如何打破双亲委派机制，加载自己的类。
类加载器两大核心方法：loadClass(String name) 和 findClass(String name)，其中双亲委派机制就是通过递归调用loadClass方法来实现的。我们只需有针对性的重写该方法即可打破该委派模型，首先我们自定义一个类加载器：CustClassLoader.class

### tomcat类加载器
tomcat实现类自己的类加载器，没有使用双亲委派机制。
![](https://images2018.cnblogs.com/blog/137084/201805/137084-20180526104342525-959933190.png)
- commonLoader：Tomcat最基本的类加载器，加载路径中的class可以被Tomcat容器本身以及各个Webapp访问；
- catalinaLoader：Tomcat容器私有的类加载器，加载路径中的class对于Webapp不可见；
- sharedLoader：各个Webapp共享的类加载器，加载路径中的class对于所有Webapp可见，但是对于Tomcat容器不可见；
- WebappClassLoader：各个Webapp私有的类加载器，加载路径中的class只对当前Webapp可见；