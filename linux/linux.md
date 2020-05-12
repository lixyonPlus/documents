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

