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
