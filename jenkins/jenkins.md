## 安装 jdk
```sh 
wget https://mirrors.huaweicloud.com/openjdk/11.0.2/openjdk-11.0.2_linux-x64_bin.tar.gz

tar xf openjdk-11.0.2_linux-x64_bin.tar.gz

mv jdk-11.0.2/ /usr/local/jdk11
```

## 安装 Jenkins
```sh
wget https://mirrors.tuna.tsinghua.edu.cn/jenkins/redhat-stable/jenkins-2.426.1-1.1.noarch.rpm
# 如果不安装 fontconfig 可能会遇到相关报错
yum -y install fontconfig
yum -y localinstall jenkins-2.426.1-1.1.noarch.rpm
```
```sh
egrep -v '^#|^$' /usr/lib/systemd/system/jenkins.service

[Unit]
Description=Jenkins Continuous Integration Server
Requires=network.target
After=network.target
[Service]
Type=notify
NotifyAccess=main
ExecStart=/usr/bin/jenkins
Restart=on-failure
SuccessExitStatus=143
User=jenkins
Group=jenkins
Environment="JENKINS_HOME=/data/.jenkins"
WorkingDirectory=/data/.jenkins
Environment="JENKINS_WEBROOT=%C/jenkins/war"
Environment="JAVA_HOME=/usr/local/jdk11"
Environment="JAVA_OPTS=-Djava.awt.headless=true"
Environment="JENKINS_PORT=8080"
[Install]
WantedBy=multi-user.target
```

## 配置 Jenkins 插件使用国内 URL
1. 修改 /var/lib/jenkins/hudson.model.UpdateCenter.xml 文件，将 url 的值改成如下值:
```
sed -i 's@updates.jenkins.io@mirrors.tuna.tsinghua.edu.cn/jenkins/updates@' /var/lib/jenkins/hudson.model.UpdateCenter.xml
```
或者登录 Jenkins，点击 –> 插件管理 –> 高级;找到升级站点，修改 URL 的值为 https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json

2. 修改 defaults.json 文件
```sh
sed -i 's/https:\/\/updates.jenkins.io\/download/https:\/\/mirrors.tuna.tsinghua.edu.cn\/jenkins/g' /var/lib/jenkins/updates/default.json
sed -i 's/http:\/\/www.google.com/https:\/\/www.baidu.com/g' /var/lib/jenkins/updates/default.json
```

## 启动
```
systemctl daemon-reload
systemctl start jenkins
```

## 如果启动失败，检查文件是否创建

## 更新 Jenkins
1. 下载新版本的 Jenkins war 包
```
wget --no-check-certificate https://mirrors.tuna.tsinghua.edu.cn/jenkins/war/2.321/jenkins.war
```
2. 停止 Jenkins 服务，替换 war 包
```sh
systemctl stop jenkins.service 
mv jenkins.war /usr/lib/jenkins/jenkins.war
```
3.重新启动 Jenkins 服务
```sh
systemctl restart jenkins
```
4.登录 Jenkins 验证版本是否升级成功


## 问题排查
1. 缺少 fontconfig
```
AWT is not properly configured on this server. Perhaps you need to run your container with "-Djava.awt.headless=true"? See also: https://jenkins.io/redirect/troubleshooting/java.awt.headless

java.lang.NullPointerException
    at java.desktop/sun.awt.FontConfiguration.getVersion(FontConfiguration.java:1262)
    at java.desktop/sun.awt.FontConfiguration.readFontConfigFile(FontConfiguration.java:225)
    at java.desktop/sun.awt.FontConfiguration.init(FontConfiguration.java:107)
    at java.desktop/sun.awt.X11FontManager.createFontConfiguration(X11FontManager.java:719)
    at java.desktop/sun.font.SunFontManager$2.run(SunFontManager.java:372)
    at java.base/java.security.AccessController.doPrivileged(AccessController.java:312)
    at java.desktop/sun.font.SunFontManager.<init>(SunFontManager.java:317)
    at java.desktop/sun.awt.FcFontManager.<init>(FcFontManager.java:35)
    at java.desktop/sun.awt.X11FontManager.<init>(X11FontManager.java:56)
  ......
```
- 安装字体 yum install -y fontconfig

2. 第一次访问 Jenkins，输入密码解锁 Jenkins 后一直卡在 Setup Wizard 页面。解决方法如下:
```sh
## 修改 /etc/sysconfig/jenkins 文件，修改其中的 JENKINS_JAVA_OPTIONS 配置，添加代理，如下：
JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Djava.net.preferIPv4Stack=true -DsocksProxyHost=192.168.64.151 -DsocksProxyPort=8888"

```

## jenkinsfile

```sh
node {
    def mvnHome = tool 'maven3' //引入maven
    def build_branch = params.build_branch.split("/")[1]
    def sonarqubeScannerHome = tool name: 'SonarQubeScanner'
    env.PATH = "${sonarqubeScannerHome}/bin:${mvnHome}/bin:${env.PATH}" //配置maven环境变量

    // 检出指定分支代码
    stage('Checkout') { // for display purposes
        git branch: build_branch, url: 'git@:xxxx.git'
    }
    //构建
    stage('Build') {
        sh 'mvn clean package -Dmaven.test.skip=true'
    }

    //单元测试 第二阶段改为自动化测试
    stage('Test') {
        sh 'mvn -Dspring.profiles.active=test -Dmaven.test.failure.ignore=true test'//单元测试/覆盖测试
        jacoco()
        junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
    }

    //代码质量检查
    stage('Sonar Scan') {
        withSonarQubeEnv('SonarQube') {
            sh "sonar-scanner -Dsonar.projectKey=service-user -Dsonar.sources=src/main/java -Dsonar.java.binaries=target/classes"
        }
    }

    //归档构建
    stage('Artifact') {
        //sh 'mvn clean package'
    }

    // 部署
    stage('Deploy') {
        sshPublisher(publishers: [sshPublisherDesc(configName: 'test.xxx.com', transfers: [sshTransfer(cleanRemote: false, excludes: '', execCommand: 'cd workspace && ./deploy.sh restart service-user test 512M', execTimeout: 600000, flatten: false, makeEmptyDirs: false, noDefaultExcludes: false, patternSeparator: '[, ]+', remoteDirectory: '', remoteDirectorySDF: false, removePrefix: 'target/', sourceFiles: 'target/service-user.jar')], usePromotionTimestamp: false, useWorkspaceInPromotion: false, verbose: false)])
    }
}
```
