# aspect方法内部调用，会使aspect增强失效 

```

public class demo {
    public void A() {
        B();
    }

    @Retryable(Exception.class)
    public void B() {
        throw new RuntimeException("retry...");
    }
}

```

> 这种情况B()不会重试。
