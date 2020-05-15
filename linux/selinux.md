# SELinux
### restorecon命令用来恢复SELinux文件属性即恢复文件的安全上下文。
#### 假设CentOS安装了apache，网页默认的主目录是/var/www/html，我们经常遇到这样的问题，在其他目录中创建了一个网页文件，然后用mv移动到网页默认目录/var/www/html中，但是在浏览器中却打不开这个文件，这很可能是因为这个文件的SELinux配置信息是继承原来那个目录的，与/var/www/html目录不同，使用mv移动的时候，这个SELinux配置信息也一起移动过来了，从而导致无法打开页面，
    /*使用restorecon来恢复网页主目录中所有文件的SELinux配置信息(如果目标为一个目录，可以添加-R参数递归)*/
    [root@linuxde.net html]# restorecon -R /var/www/html/

### 临时关闭/关闭SELinux(不需要重启)：
    setenforce 0 ##设置SELinux 成为permissive模式（关闭）
    setenforce 1 ##设置SELinux 成为enforcing模式（开启）
### 永久关闭/关闭SELinux(需要重启)：
    修改/etc/selinux/config文件将SELINUX=enforcing改为SELINUX=disabled,重启机器即可
