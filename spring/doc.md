# aspect方法内部调用，会使aspect增强失效 

```

public class Demo {
    public void a() {
        b();
    }

    @Retryable(Exception.class)
    public void b() {
        throw new RuntimeException("retry...");
    }
}

```

> 以上情况B()不会重试。  
>  解决方式，添加代理：  
```
        Demo demoProxy= ((Demo)AopContext.currentProxy());
        demoProxy.b();
```
