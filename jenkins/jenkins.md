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
