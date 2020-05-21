# jstat命令可以查看堆内存各部分的使用量，以及加载类的数量。

<h1>类加载统计
![](http://blog.itpub.net/ueditor/php/upload/image/20190916/1568613651777083.png)
jstat -class pid
Loaded: 加载class的数量<br>
Bytes: 所占用空间大小<br>  
Unloaded: 未加载数量 <br>
Bytes: 未加载占用空间<br> 
Time: 时间  
</h1>

<h1>编译统计
![](http://blog.itpub.net/ueditor/php/upload/image/20190916/1568613651950434.png)
jstat -complier pid
Compiled：编译数量 <br>
Failed：失败数量 <br>
Invalid：不可用数量 <br>
Time：时间 <br>
FailedType：失败类型 <br>
FailedMethod：失败的方法 <br>
</h1>

<h1>垃圾回收统计
![](http://blog.itpub.net/ueditor/php/upload/image/20190916/1568613651726791.png)
jstat -gc pid
S0C：第一个幸存区的大小 <br>
S1C：第二个幸存区的大小 <br>
S0U：第一个幸存区的使用大小 <br>
S1U：第二个幸存区的使用大小 <br>
EC：伊甸园区的大小 <br>
EU：伊甸园区的使用大小 <br>
OC：老年代大小 <br>
OU：老年代使用大小 <br>
MC：方法区大小 <br>
MU：方法区使用大小 <br>
CCSC:压缩类空间大小 <br>
CCSU:压缩类空间使用大小 <br>
YGC：年轻代垃圾回收次数 <br>
YGCT：年轻代垃圾回收消耗时间 <br>
FGC：老年代垃圾回收次数 <br>
FGCT：老年代垃圾回收消耗时间 <br>
GCT：垃圾回收消耗总时间 <br>
</h1>

<h1> 堆内存统计
![](http://blog.itpub.net/ueditor/php/upload/image/20190916/1568613651577967.png)
jstat -gccapacity pid
NGCMN：新生代最小容量 <br>
NGCMX：新生代最大容量 <br>
NGC：当前新生代容量 <br>
S0C：第一个幸存区大小 <br>
S1C：第二个幸存区的大小 <br>
EC：伊甸园区的大小 <br>
OGCMN：老年代最小容量 <br>
OGCMX：老年代最大容量 <br>
OGC：当前老年代大小 <br>
OC:当前老年代大小 <br>
MCMN:最小元数据容量 <br>
MCMX：最大元数据容量 <br>
MC：当前元数据空间大小 <br>
CCSMN：最小压缩类空间大小 <br>
CCSMX：最大压缩类空间大小 <br>
CCSC：当前压缩类空间大小 <br>
YGC：年轻代gc次数 <br>
FGC：老年代GC次数 <br>
</h1>

<h1> 新生代垃圾回收统计
![](http://blog.itpub.net/ueditor/php/upload/image/20190916/1568613652393346.png)
jstat -gcnew pid
S0C：第一个幸存区大小 <br>
S1C：第二个幸存区的大小 <br>
S0U：第一个幸存区的使用大小 <br>
S1U：第二个幸存区的使用大小 <br>
TT:对象在新生代存活的次数 <br>
MTT:对象在新生代存活的最大次数 <br>
DSS:期望的幸存区大小 <br>
EC：伊甸园区的大小 <br>
EU：伊甸园区的使用大小 <br>
YGC：年轻代垃圾回收次数 <br>
YGCT：年轻代垃圾回收消耗时间 <br>
</h1>

<h1> 新生代内存统计
![](http://blog.itpub.net/ueditor/php/upload/image/20190916/1568613652851652.png)
jstat -gcnewcapacity pid
NGCMN：新生代最小容量 <br>
NGCMX：新生代最大容量 <br>
NGC：当前新生代容量 <br>
S0CMX：最大幸存1区大小 <br>
S0C：当前幸存1区大小 <br>
S1CMX：最大幸存2区大小 <br>
S1C：当前幸存2区大小 <br>
ECMX：最大伊甸园区大小 <br>
EC：当前伊甸园区大小 <br>
YGC：年轻代垃圾回收次数 <br>
FGC：老年代回收次数 <br>
</h1>

<h1> 老年代垃圾回收统计
![](http://blog.itpub.net/ueditor/php/upload/image/20190916/1568613652660641.png)
jstat -gcold pid
MC：方法区大小 <br>
MU：方法区使用大小 <br>
CCSC:压缩类空间大小 <br>
CCSU:压缩类空间使用大小 <br>
OC：老年代大小 <br>
OU：老年代使用大小 <br>
YGC：年轻代垃圾回收次数 <br>
FGC：老年代垃圾回收次数 <br>
FGCT：老年代垃圾回收消耗时间 <br>
GCT：垃圾回收消耗总时间 <br>
</h1>

<h1> 老年代内存统计
![](http://blog.itpub.net/ueditor/php/upload/image/20190916/1568613652826230.png)
jstat -gcoldcapacity pid
OGCMN：老年代最小容量 <br>
OGCMX：老年代最大容量 <br>
OGC：当前老年代大小 <br>
OC：老年代大小 <br>
YGC：年轻代垃圾回收次数 <br>
FGC：老年代垃圾回收次数 <br>
FGCT：老年代垃圾回收消耗时间 <br>
GCT：垃圾回收消耗总时间 <br>
</h1>

<h1> 元数据空间统计
![](http://blog.itpub.net/ueditor/php/upload/image/20190916/1568613652434062.png)
jstat -gcmetacapacity pid
MCMN: 最小元数据容量 <br>
MCMX：最大元数据容量 <br>
MC：当前元数据空间大小 <br>
CCSMN：最小压缩类空间大小 <br>
CCSMX：最大压缩类空间大小 <br>
CCSC：当前压缩类空间大小 <br>
YGC：年轻代垃圾回收次数 <br>
FGC：老年代垃圾回收次数 <br>
FGCT：老年代垃圾回收消耗时间 <br>
GCT：垃圾回收消耗总时间 <br>
</h1>

<h1> 总结垃圾回收统计
![](http://blog.itpub.net/ueditor/php/upload/image/20190916/1568613652845688.png)
jstat -gcutil pid
S0：幸存1区当前使用比例 <br>
S1：幸存2区当前使用比例 <br>
E：伊甸园区使用比例 <br>
O：老年代使用比例 <br>
M：元数据区使用比例 <br>
CCS：压缩使用比例 <br>
YGC：年轻代垃圾回收次数 <br>
YGC：年轻代垃圾回收消耗时间 <br>
FGC：老年代垃圾回收次数 <br>
FGCT：老年代垃圾回收消耗时间 <br>
GCT：垃圾回收消耗总时间 <br>
</h1>

<h1>  JVM编译方法统计
![](http://blog.itpub.net/ueditor/php/upload/image/20190916/1568613653566655.png)
jstat -printcompilation pid
Compiled：最近编译方法的数量 <br>
Size：最近编译方法的字节码数量 <br>
Type：最近编译方法的编译类型 <br>
Method：方法名标识 <br>
</h1>