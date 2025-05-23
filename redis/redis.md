### redis数据类型

- string

  底层使用SDS简单动态字符串存储。

  ![](https://i-blog.csdnimg.cn/blog_migrate/2acf7c2df7307b8666930533c73007c6.png)

  ![](https://i-blog.csdnimg.cn/blog_migrate/15865b86ac00f23d3427574489bcf2fd.png)

- list

  使用quickList存储对象（quicklist每个节点内部是一个ziplist），从 Redis 6.2 版本开始，quicklist 的底层实现由原来的 ziplist 改为了 listpack。Listpack 是 ziplist 的升级版本，主要是为了解决ziplist中存在的一些问题，比如，ziplist中扩展元素长度时可能需要进行昂贵的重新分配操作。listpack 提供了更好的性能和内存使用效率，在保持与 ziplist 类似的密集存储方式的同时，允许更大的单个元素大小，并且有更强的扩展性。
  
  - 优点：
  
  快表的节点大小固定，可以有效地避免内存碎片的发生。
  快表支持动态增加和删除节点，可以随着数据的增长而自动扩容或缩容，不需要预先分配空间。
  快表的节点采用ziplist的紧凑存储方式，使得节点访问和遍历的效率较高。同时，快表支持从头和尾部两个方向同时遍历节点。
  
  - 缺点：
  
  快表的节点大小固定，如果节点中的元素数量较少，会造成一定的空间浪费。
  快表中的元素只能是整数或字节数组，不支持其他数据类型的存储。
  快表的插入和删除操作的效率较低，因为在插入或删除元素时，需要移动后面的元素，可能会导致大量的内存复制操作。如果需要频繁进行插入和删除操作，建议使用其他数据结构，例如链表。
  当快表中的元素数量较大时，遍历整个快表的效率也可能较低，因为快表是由多个节点组成的链表，需要依次遍历每个节点才能访问所有元素。
  
  
- hash

  ziplist,对于那些长度小于配置中 hash-max-ziplist-entries 选项配置的值(默认为512),且所有元素的大小都小于配置中 hash-max-ziplist-value 选项配置的值(默认64 字节)的哈希，采用此编码。ziplist编码对于较小的哈希而言可以节省占用空间。
  hashtable:当 ziplist 不适用时使用的默认编码。
  
  

- set

  intset,对于那些元素都是整数，且元素个数小于配置中 set-max-intset-entries 选项设置的值( 默认 512)的集合，采用此编码。intset 编码对于较小的集合而言可以节省占用空间。
  hashtable,intset 不适用时的默认编码

  

- zset

  ziplist,对于那些长度小于配置中 zset-max-ziplist-entries 选项配置的值(默认为128),且所有元素的大小都小于配置中 zset-max-ziplist-value 选项配置的值( 默认为64 字节)的有序集合，采用此编码。ziplist 用于节省较小集合所占用的空间。

  - ziplist是内存紧凑的数据结构，占用一块连续的内存空间。一个 ziplist 可以包含多个节点（entry）， 每个节点可以保存一个长度受限的[字符数组](https://so.csdn.net/so/search?q=字符数组&spm=1001.2101.3001.7020)（不以 \0 结尾的 char 数组）或者整数。
  - 缺点：不能保存过多的元素，否则访问性能会下降，不能保存过大的元素，否则容易导致内存重新分配，甚至引起连锁更新。

  skiplist,当 ziplist 不适用时使用的默认编码。 

  - Skip list是一个分层结构多级链表，最下层是原始的链表，每个层级都是下一个层级的“高速跑道”。

  - 跳跃表（SkipList）是一种可以替代平衡树的数据结构。跳跃表让已排序的数据分布在多层次的链表结构中，默认是将Key值升序排列的，以 0-1 的随机值决定一个数据是否能够攀升到高层次的链表中。它通过容许一定的数据冗余，达到 “以空间换时间” 的目的。

  - 跳跃表的效率和AVL相媲美，查找／添加／插入／删除操作都能够在O（LogN）的复杂度内完成。
    

- hyperloglog

  稀疏(Sparse)，对于那些长度小于配置中 hll-sparse-max-bytes 选项设置的值 (默认为 3000)的 HLL 对象，采用此编码。稀疏表示方式的存储效率更高，但可能会消耗更多的CPU 资源。
  稠密(Dense)，当稀疏方式不能适用时的默认编码

  

- geo

  使用zset存储。