### bitmap：
- 应用场景：统计上亿的日活跃用户
```
SETBIT key offset value
//对一个或多个保存二进制位的字符串 key 进行位元操作，并将结果保存到 destkey 上,operation可以是 AND 、 OR 、 NOT 、 XOR 这四种操作中的任意一种：BITOP operation destkey key [key …]
//对一个或多个 key 求逻辑并，并将结果保存到 destkey
BITOP AND destkey key [key ...]
//对一个或多个 key 求逻辑或，并将结果保存到 destkey
BITOP OR destkey key [key ...]
//对一个或多个 key 求逻辑异或，并将结果保存到 destkey
BITOP XOR destkey key [key ...] 
//对给定 key 求逻辑非，并将结果保存到 destkey
BITOP NOT destkey key
//计算给定字符串中，被设置为 1 的比特位的数量
BITCOUNT key [start] [end]
```

