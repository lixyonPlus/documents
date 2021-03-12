# redis应用场景： 数据缓存，分布式session，分布式锁。

### 常用的淘汰算法：
 - FIFO：First In First Out，先进先出。判断被存储的时间，离目前最远的数据优先被淘汰。
 - LRU：Least Recently Used，最近最少使用。判断最近被使用的时间，目前最远的数据优先被淘汰。
 - LFU：Least Frequently Used，最不经常使用。在一段时间内，数据被使用次数最少的，优先被淘汰。

### Redis提供的淘汰策略：
volatile-lru（least recently used）：从已设置过期时间的数据集（server.db[i].expires）中挑选最近最少使用的数据淘汰
volatile-lfu（least frequently used）：从已设置过期时间的数据集(server.db[i].expires)中挑选最不经常使用的数据淘汰
volatile-ttl：从已设置过期时间的数据集（server.db[i].expires）中挑选将要过期的数据淘汰
volatile-random：从已设置过期时间的数据集（server.db[i].expires）中任意选择数据淘汰
allkeys-lru（least recently used）：当内存不足以容纳新写入数据时，在键空间中，移除最近最少使用的 key（这个是最常用的）
allkeys-random：从数据集（server.db[i].dict）中任意选择数据淘汰
allkeys-lfu（least frequently used）：当内存不足以容纳新写入数据时，在键空间中，移除最不经常使用的 key
no-eviction：禁止驱逐数据，也就是说当内存不足以容纳新写入数据时，新写入操作会报错。这个应该没人使用吧！


### redis事物
redis事物不像mysql事物，没有事物隔离性，不保证原子操作，不支持回滚。
1.开始事物(multi)
2.命令入队
3.执行事物(exec)、撤销事物(discard)
![](https://s3.ax1x.com/2021/03/10/6GM176.png)


### redis io模式
redis属于单线程，使用IO多路复用技术（epoll）完成。
![](https://s3.ax1x.com/2021/03/10/6GcKiT.md.png)
IO多路复用技术对比
![](https://s3.ax1x.com/2021/03/10/6Gc3QJ.md.png)
