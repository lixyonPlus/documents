### 用户信息文件分析（每项用:隔开）
    例如：jack:X:503:504:::/home/jack/:/bin/bash
    jack　　//用户名
    X　　//口令、密码
    503　　//用户id（0代表root、普通新建用户从500开始）
    504　　//所在组
    :　　//描述
    /home/jack/　　//用户主目录
    /bin/bash　　//用户缺省Shell

### 组信息文件分析
    例如：jack:$!$:???:13801:0:99999:7:*:*:
    jack　　//组名
    $!$　　//被加密的口令
    13801　　//创建日期与今天相隔的天数
    0　　//口令最短位数
    99999　　//用户口令
    7　　//到7天时提醒
    *　　//禁用天数
    *　　//过期天数



### 添加一个用户到指定组，不会删除该用户所属的组
    gpasswd -a user_name group_name
    -a：添加用户到组；
    -d：从组删除用户；
    -A：指定管理员；
    -M：指定组成员和-A的用途差不多；
    -r：删除密码；
    -R：限制用户登入组，只有组中的成员才可以用newgrp加入该组。

### 添加一个用户到指定组,会删除所属的组
    usermod -G group_name user_name

### chsh命令用来更换登录系统时使用的shell。若不指定任何参数与用户名称，则chsh会以应答的方式进行设置。
    查看系统安装了哪些shell的两种方法: chsh -l  cat /etc/shells
    查看当前正在使用的shell: echo $SHELL
    把我的shell改成zsh(重启生效,修改的就是/etc/passwd文件里和你的用户名相对应的那一行): chsh -s /bin/zsh

### passwd linuxde    //更改或创建linuxde用户的密码
    -d：删除密码，仅有系统管理者才能使用；
    -f：强制执行；
    -k：设置只有在密码过期失效后，方能更新；
    -l：锁住密码；
    -s：列出密码的相关信息，仅有系统管理者才能使用；
    -u：解开已上锁的帐号。
### passwd  //普通用户如果想更改自己的密码，直接运行passwd即可，比如当前操作的用户是linuxde

### passwd -l linuxde    //锁定用户linuxde不能更改密码

### su linuxde   //通过su切换到linuxde用户

### newusers命令用于批处理的方式一次创建多个命令。
    newusers uers.txt
    ```txt
    jingang0:x:520:520::/home/jingang0:/sbin/nologin
    jingang1:x:521:521::/home/jingang1:/sbin/nologin
    ```

### chpasswd命令是批量更新用户口令的工具，是把一个文件内容重新定向添加到/etc/shadow中。
    chpasswd < user.txt
    先创建用户密码对应文件，格式为username:password，如abc:abc123，必须以这种格式来书写，并且不能有空行，保存成文本文件user.txt

### usermod命令用于修改用户的基本信息
    -c<备注>：修改用户帐号的备注文字；
    -d<登入目录>：修改用户登入时的目录；
    -e<有效期限>：修改帐号的有效期限；
    -f<缓冲天数>：修改在密码过期后多少天即关闭该帐号；
    -g<群组>：修改用户所属的群组；
    -G<群组>；修改用户所属的附加群组；
    -l<帐号名称>：修改用户帐号名称；
    -L：锁定用户密码，使密码无效；
    -s<shell>：修改用户登入后所使用的shell；
    -u<uid>：修改用户ID；
    -U:解除密码锁定。
    usermod -l newuser1 newuser //修改newuser的用户名为newuser1

### groupadd命令用于创建一个新的工作组，新工作组的信息将被添加到系统文件中。
    groupadd -g 344 linuxde //建立一个linuxde新组，并设置组ID加入系统,此时在/etc/passwd文件中产生一个组ID（GID）是344的项目

### userdel命令用于删除给定的用户，以及与用户相关的文件。若不加选项，则仅删除用户帐号，而不删除相关文件。
    -f：强制删除用户，即使用户当前已登录；
    -r：删除用户的同时，删除与用户相关的所有文件。
    userdel linuxde       //删除用户linuxde，但不删除其家目录及文件；
    userdel -r linuxde    //删除用户linuxde，其家目录及文件一并删除；

### useradd命令用于Linux中创建的新的系统用户
    -c<备注>：加上备注文字。备注文字会保存在passwd的备注栏位中；
    -d<登入目录>：指定用户登入时的启始目录；
    -D：变更预设值；
    -e<有效期限>：指定帐号的有效期限；
    -f<缓冲天数>：指定在密码过期后多少天即关闭该帐号；
    -g<群组>：指定用户所属的群组；
    -G<群组>：指定用户所属的附加群组；
    -m：自动建立用户的登入目录；
    -M：不要自动建立用户的登入目录；
    -n：取消建立以用户名称为名的群组；
    -r：建立系统帐号；
    -s<shell>：指定用户登入后所使用的shell；
    -u<uid>：指定用户id

### rsync命令是一个远程数据同步工具
    从远程rsync服务器中拷贝文件到本地机。当SRC路径信息包含"::"分隔符时启动该模式。如：rsync -av root@192.168.78.192::www /databack
    从本地机器拷贝文件到远程rsync服务器中。当DST路径信息包含"::"分隔符时启动该模式。如：rsync -av /databack root@192.168.78.192::www

### xargs命令是给其他命令传递参数的一个过滤器，也是组合多个命令的一个工具。(xargs的默认命令是echo，空格是默认定界符。)
    cat test.txt | xargs //多行输入单行输出
    cat test.txt | xargs -n3  //3列多行输出
    echo "nameXnameXnameXname" | xargs -dX  //-d选项可以自定义一个定界符
    echo "nameXnameXnameXname" | xargs -dX -n2 //2行2列输出name
    ls *.jpg | xargs -n1 -I cp {} /data/images //复制所有图片文件到 /data/images 目录下
    find . -type f -name "*.jpg" -print | xargs tar -czvf images.tar.gz //查找所有的jpg 文件，并且压缩

### awk是一种编程语言，用于在linux/unix下对文本和数据进行处理。
    awk -F: '{print $1,$7}' /etc/passwd   //以:分行读取，显示第1个字段和第7个字段的内容
        $0 //表示整个当前行
        $1 //每行第一个字段
        NF //字段数量变量
        NR //每行的记录号，多文件记录递增
        -F [:#/]    //定义了三个分隔符
        OFS  //输出字段分隔符， 默认也是空格，可以改为其他的
        ORS  //输出的记录分隔符，默认为换行符,即处理结果也是一行一行输出到屏幕
### mount挂载
    mount -t auto /dev/cdrom(设备文件名) /mnt/cdrom(挂载点)     #挂载cdrom,如果cdrom不存在则创建/mnt/cdrom目录
### mount卸载(通过设备名卸载,通过挂载点卸载)
    umount -v /mnt/cdrom/

### 开启swap
    1.创建用于交换分区的文件：
        dd if=/dev/zero of=/mnt/swap bs=1M count=8192   //创建8g虚拟内存 bs=block_size count=number_of_block
    2. 设置交换分区文件：
       mkswap /mnt/swap
    3. 立即启用交换分区文件：
       swapon /mnt/swap
    4. 查看是否生效,注：如果在 /etc/rc.local 中有 swapoff -a 需要修改为 swapon -a
      free -m
    5. 设置开机时自启用 SWAP 分区：
       在/etc/fstab文件末尾添加： 
       /mnt/swap swap swap defaults 0 0
    6.在 Linux 系统中，可以通过查看 /proc/sys/vm/swappiness内容的值来确定系统对 SWAP 分区的使用原则。当 swappiness 内容的值为 0 时，表示最大限度地使用物理内存，物理内存使用完毕后，才会使用 SWAP 分区。当 swappiness 内容的值为 100 时，表示积极地使用 SWAP 分区，并且把内存中的数据及时地置换到 SWAP 分区。
        临时修改：echo 10 >/proc/sys/vm/swappiness
        永久修改：修改/etc/sysctl.conf文件vm.swappiness属性值改为10，执行 sysctl -p

### 关闭swap
    当系统出现内存不足时，开启 SWAP 可能会因频繁换页操作，导致 IO 性能下降。
    1.swapoff /mnt/swap  #关闭swap
    2.修改 /etc/fstab,删除相关内容
    3.修改 swappiness文件或修改/etc/sysctl.conf文件，执行sysctl -p

### linux开启/关闭/重启
    halt命令用来关闭正在运行的Linux操作系统。halt命令会先检测系统的runlevel，若runlevel为0或6，则关闭系统，否则即调用shutdown来关闭系统。
    -d：不要在wtmp中记录；
    -f：不论目前的runlevel为何，不调用shutdown即强制关闭系统；
    -i：在halt之前，关闭全部的网络界面；
    -n：halt前，不用先执行sync；
    -p：halt之后，执行poweroff；
    -w：仅在wtmp中记录，而不实际结束系统。
    halt -p     #关闭系统后关闭电源。
    halt -d     #关闭系统，但不留下纪录。

    reboot命令用来重新启动正在运行的Linux操作系统。
    -d：重新开机时不把数据写入记录文件/var/tmp/wtmp。本参数具有“-n”参数效果；
    -f：强制重新开机，不调用shutdown指令的功能；
    -i：在重开机之前，先关闭所有网络界面；
    -n：重开机之前不检查是否有未结束的程序；
    -w：仅做测试，并不真正将系统重新开机，只会把重开机的数据写入/var/log目录下的wtmp记录文件。
    reboot        //重开机。
    reboot -w     //做个重开机的模拟（只有纪录并不会真的重开机）。

    shutdown命令用来系统关机命令。shutdown指令可以关闭所有程序，并依用户的需要，进行重新开机或关机的动作。
    -c：当执行“shutdown -h 11:50”指令时，只要按+键就可以中断关机的指令；
    -f：重新启动时不执行fsck；
    -F：重新启动时执行fsck；
    -h：将系统关机；
    -k：只是送出信息给所有用户，但不会实际关机；
    -n：不调用init程序进行关机，而由shutdown自己进行；
    -r：shutdown之后重新启动；
    -t<秒数>：送出警告信息和删除信息之间要延迟多少秒。
    shutdown -h now #指定现在立即关机

    poweroff命令用来关闭计算机操作系统并且切断系统电源。
    -n：关闭操作系统时不执行sync操作；
    -w：不真正关闭操作系统，仅在日志文件“/var/log/wtmp”中；
    -d：关闭操作系统时，不将操作写入日志文件“/var/log/wtmp”中添加相应的记录；
    -f：强制关闭操作系统；
    -i：关闭操作系统之前关闭所有的网络接口；
    -h：关闭操作系统之前将系统中所有的硬件设置为备用模式。
    poweroff

### fg/bg前后台执行
    ctrl+z #掛起當前執行程序
    bg %進程id #將程序放到後臺運行 
    jobs  #列出所有後臺進程
    fg %進程id  #將後臺程序調到前臺執行

### curl下载文件
    curl -o xxx www.baidu.com

### wget下载文件
    curl -O xxx www.baidu.com

### RPM安装
    rpm -ivh your-package.rpm #安装rpm软件包
    rpm -i you-package.src.rpm && cd /usr/src/redhat/SPECS && rpmbuild -bb your-package.specs
        #这时在/usr/src/redhat/RPM/i386/（根据具体包的不同，也可能是i686,noarch等等）在这个目录下，有一个新的rpm包，这个是编译好的二进制文件。执行rpm -i new-package.rpm即可安装完成。

### RPM卸载
    rpm -e proftpd 
    rpm -e --nodeps # 强制卸载

### 查询已安装的rpm包
    rpm -qa | grep sql

### basename与dirname
    basename #显示路径中文件名称
    dirname #显示路径中的路径
    basename /user/xx.jpg #结果为 xx.jpg
    dirname /user/xx.jpg #结果为 /user

### 软链接/硬链接
    原理上，硬链接和源文件的inode节点号相同，两者互为硬链接。软连接和源文件的inode节点号不同，进而指向的block也不同，软连接block中存放了源文件的路径名。实际上，硬链接和源文件是同一份文件，而软连接是独立的文件，类似于快捷方式，存储着源文件的位置信息便于指向。使用限制上，不能对目录创建硬链接，不能对不同文件系统创建硬链接，不能对不存在的文件创建硬链接；可以对目录创建软连接，可以跨文件系统创建软连接，可以对不存在的文件创建软连接。
    ln -s oldfile slink #软链接
    ln  oldfile slink #硬链接

### sed命令
    sed 's/q/Q/g' file #全局替换file文件中每一行q为Q
    sed 's/q/Q/' file #全局替换file文件中q为Q
    sed -i '/q/d' file #删除file文件中包含q的行
    sed -i '/q/a xxxx' file #在file文件中包含q的下一行追加xxxx
    sed -i '/\/bin\/sh/a xxxx' file #在file文件中包含\bin\sh的下一行插入sxxxx
    sed -i '/^nginx/i xxxxx' file #匹配到以nginx开头的行，在匹配行前面一行插入xxxxx
    
### chown改变某个文件或目录的所有者和所属的组
    chown -R liu /usr/meng #将目录/usr/meng及其下面的所有文件、子目录的文件主改成liu

### chmod命令用来变更文件或目录的权限
    chmod 777 /root #当前用户拥有读写执行权限
    chmod +x /root #当前用户拥有执行权限    
    r=读取属性　　//值＝4
    w=写入属性　　//值＝2
    x=执行属性　　//值＝1
    rwx、rw-、r--

### egrep
    egrep Linux * #查找当前目录下所有包含linux文件

### grep在文件中搜索一个单词，命令会返回一个包含搜索内容的文本行
    grep match_pattern file_name
    grep "match_pattern" file_1 file_2 file_3  #在多个文件中查找
    grep -v "match_pattern" file_name #反向查找
    grep "text" . -r -n #在多级目录中对文本进行递归搜索

### split
    split -l 10 date.file #把文件分割成每个包含10行的小文件
    split -b 10k date.file  #把文件分割成大小为10KB的小文件

### zip
    zip -r mysql.zip mysql #将mysql文件夹压缩成mysql.zip

### unzip
    unzip mysql.zip #在当前目录下直接解压mysql.zip

### tar 
    tar -cvf 123.tar file1 file2 dir1 #将两个文件（file1和file2）和一个文件夹(dir1)压缩成一个123.tar文件
    tar -zcvf log.tar.gz log2012.log   打包后，以gzip 压缩 
    tar-xvf log.tar.gz #解压到当前目录
    tar -zxvf apache-tomcat-7.0.75.tar.gz -C /root #apache-tomcat.7.0.75.tar.gz直接解压到root目录下

### free可以显示当前系统未使用的和已使用的内存数目，还可以显示被内核使用的内存缓冲区
    -b：以Byte为单位显示内存使用情况；
    -k：以KB为单位显示内存使用情况；
    -m：以MB为单位显示内存使用情况；
    第一部分Mem行解释：total = used + free
    total：内存总数；
    used：已经使用的内存数；
    free：空闲的内存数；
    shared：当前已经废弃不用；
    buffers Buffer：缓存内存数；
    cached Page：缓存内存数。
    第二部分(-/+ buffers/cache)解释:
    (-buffers/cache) used内存数：第一部分Mem行中的 used – buffers – cached
    (+buffers/cache) free内存数: 第一部分Mem行中的 free + buffers + cached
    -buffers/cache反映的是被程序实实在在吃掉的内存，而+buffers/cache反映的是可以挪用的内存总数。

### top命令可以实时动态地查看系统的整体运行情况，是一个综合了多方信息监测系统性能和运行信息的实用工具。通过top命令所提供的互动式界面，用热键可以管理
    top
    在top命令执行过程中可以使用的一些交互命令。这些命令都是单字母的，如果在命令行中使用了-s选项， 其中一些命令可能会被屏蔽。
    m：切换显示内存信息；
    M：根据驻留内存大小进行排序；
    P：根据CPU使用百分比大小进行排序；
    q：退出程序；

### du文件和目录磁盘使用的空间的查看
    du
    -b或-bytes 显示目录或文件大小时，以byte为单位。
    -k或--kilobytes 以KB(1024bytes)为单位输出。
    -m或--megabytes 以MB为单位输出。

### df命令用于显示磁盘分区上的可使用的磁盘空间。默认显示单位为KB。可以利用该命令来获取硬盘被占用了多少空间，目前还剩下多少空间等信息。  
    df -h #使用-h选项以KB以上的单位来显示，可读性高

### source命令（从 C Shell 而来）是bash shell的内置命令。点命令，就是一个点符号，（从Bourne Shell而来）是source的另一名称。这两个命令都以一个脚本为参数，该脚本将作为当前shell的环境执行，即不会启动一个新的子进程。所有在脚本中设置的变量将成为当前Shell的一部分。

### source、sh、bash、./ 对比
    source a.sh # 在当前shell内去读取、执行a.sh，而a.sh不需要有"执行权限",source命令可以简写为".", . a.sh 注意：中间是有空格的。
    sh a.sh,bash a.sh # 都是打开一个subshell去读取、执行a.sh，而a.sh不需要有"执行权限"通常在subshell里运行的脚本里设置变量，不会影响到父shell的。
    ./a.sh
    #bash: ./a.sh: 权限不够
    chmod +x a.sh
    ./a.sh
    打开一个subshell去读取、执行a.sh，但a.sh需要有"执行权限",可以用chmod +x添加执行权限

### scp用于在Linux下进行远程拷贝文件的
    1.远处复制文件到本地目录
        scp root@10.10.10.10:/opt/soft/nginx-0.5.38.tar.gz /opt/soft/
    2.从远处复制目录到本地
        scp -r root@10.10.10.10:/opt/soft/mongodb /opt/soft/
    3.上传本地文件到远程机器指定目录
        scp /opt/soft/nginx-0.5.38.tar.gz root@10.10.10.10:/opt/soft/scptest
    4.上传本地目录到远程机器指定目录
        scp -r /opt/soft/mongodb root@10.10.10.10:/opt/soft/scptest

