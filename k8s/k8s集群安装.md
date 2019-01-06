### 集群拓扑结构
> master:  
kube-apiserver kube-controller-manager kube-scheduler  kube-proxy pause etcd coredns  flannel  
> node1:  
kube-proxy  pause flannel   
> node2:  
kube-proxy  pause flannel 

# 1. 安装 Kubeadm  (master、node1、node2)
1.1. 安装 Kubeadm 首先我们要配置好阿里云的国内源，执行如下命令：  
```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
EOF
```
1.2. 执行以下命令来重建 Yum 缓存  
```
yum -y install epel-release
yum clean all
yum makecache
```
1.3. 下面就开始正式安装 Kubeadm  
```
yum -y install kubelet kubeadm kubectl
#设置开机启动
systemctl enable kubelet && systemctl start kubelet
```
查看kubeadm配置文件：
```
rpm -ql kubelet
/etc/kubernetes/manifests
/etc/sysconfig/kubelet
/etc/systemd/system/kubelet.service
/usr/bin/kubelet
# 查看kubelet配置
cat /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS=
# 修改kubelet配置
vim /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS="--fail-swap-on=false"
```

### master节点：
1.4. 配置 Kubeadm 所用到的镜像  
> 这里是重中之重，因为在国内的原因，无法访问到 Google 的镜像库，所以我们需要执行以下脚本来从 Docker Hub 仓库中获取相同的镜像，并且更改 TAG 让其变成与 Google 拉去镜像一致。    

1.4.1. 新建一个 Shell 脚本，填入以下代码之后保存。  
```
#!/bin/bash
images=(kube-proxy-amd64:v1.11.0 kube-scheduler-amd64:v1.11.0 kube-controller-manager-amd64:v1.11.0 kube-apiserver-amd64:v1.11.0
etcd-amd64:3.2.18 coredns:1.1.3 pause:3.1 kubernetes-dashboard-amd64:v1.8.3 k8s-dns-sidecar-amd64:1.14.9 k8s-dns-kube-dns-amd64:1.14.9
k8s-dns-dnsmasq-nanny-amd64:1.14.9 )
for imageName in ${images[@]} ; do
docker pull keveon/$imageName
docker tag keveon/$imageName k8s.gcr.io/$imageName
docker rmi keveon/$imageName
done
```
1.4.2. 执行脚本   
```
chmod -R 777 ./xxx.sh 
./xxx.sh
```

# 2. 关闭系统服务 （master、node）  
2.1. 关闭 Swap
```
sudo swapoff -a
#要永久禁掉swap分区，打开如下文件注释掉swap那一行 
# sudo vi /etc/fstab
```
2.2 关闭 SELinux
```
# 临时禁用selinux
# 永久关闭 修改/etc/sysconfig/selinux文件设置
sed -i 's/SELINUX=permissive/SELINUX=disabled/' /etc/sysconfig/selinux
# 这里按回车，下面是第二条命令
setenforce 0
```
2.3 配置转发参数
```
# 配置转发相关参数，否则可能会出错
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.swappiness=0
EOF
# 这里按回车，下面是第二条命令
sysctl --system
# 重启
reboot
```
2.4 检查docker与k8s的cgroup是否相同： 
```
docker info

Server Version: 18.09.0
Storage Driver: overlay2
 Backing Filesystem: xfs
 Supports d_type: true
 Native Overlay Diff: false
Logging Driver: json-file
Cgroup Driver: cgroupfs
```

```
cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
```

# 3. 初始化kubeadm
> 前面是版本号，后面是你 POD 网络的 IP 段。(如果使用flannel必须设置 --pod-network-cidr)
```
kubeadm init --kubernetes-version=v1.11.0 --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=Swap
```
> 执行之后:
```
I0712 10:46:30.938979   13461 feature_gate.go:230] feature gates: &{map[]}
[init] using Kubernetes version: v1.11.0
[preflight] running pre-flight checks
I0712 10:46:30.961005   13461 kernel_validator.go:81] Validating kernel version
I0712 10:46:30.961061   13461 kernel_validator.go:96] Validating kernel config
    [WARNING SystemVerification]: docker version is greater than the most recently validated version. Docker version: 18.03.1-ce. Max validated version: 17.03
    [WARNING Hostname]: hostname "g2-apigateway" could not be reached
    [WARNING Hostname]: hostname "g2-apigateway" lookup g2-apigateway on 100.100.2.138:53: no such host
[preflight/images] Pulling images required for setting up a Kubernetes cluster
[preflight/images] This might take a minute or two, depending on the speed of your internet connection
[preflight/images] You can also perform this action in beforehand using 'kubeadm config images pull'
[kubelet] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[preflight] Activating the kubelet service
[certificates] Generated ca certificate and key.
[certificates] Generated apiserver certificate and key.
[certificates] apiserver serving cert is signed for DNS names [g2-apigateway kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 172.16.8.62]
[certificates] Generated apiserver-kubelet-client certificate and key.
[certificates] Generated sa key and public key.
[certificates] Generated front-proxy-ca certificate and key.
[certificates] Generated front-proxy-client certificate and key.
[certificates] Generated etcd/ca certificate and key.
[certificates] Generated etcd/server certificate and key.
[certificates] etcd/server serving cert is signed for DNS names [g2-apigateway localhost] and IPs [127.0.0.1 ::1]
[certificates] Generated etcd/peer certificate and key.
[certificates] etcd/peer serving cert is signed for DNS names [g2-apigateway localhost] and IPs [172.16.8.62 127.0.0.1 ::1]
[certificates] Generated etcd/healthcheck-client certificate and key.
[certificates] Generated apiserver-etcd-client certificate and key.
[certificates] valid certificates and keys now exist in "/etc/kubernetes/pki"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/admin.conf"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/kubelet.conf"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/controller-manager.conf"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/scheduler.conf"
[controlplane] wrote Static Pod manifest for component kube-apiserver to "/etc/kubernetes/manifests/kube-apiserver.yaml"
[controlplane] wrote Static Pod manifest for component kube-controller-manager to "/etc/kubernetes/manifests/kube-controller-manager.yaml"
[controlplane] wrote Static Pod manifest for component kube-scheduler to "/etc/kubernetes/manifests/kube-scheduler.yaml"
[etcd] Wrote Static Pod manifest for a local etcd instance to "/etc/kubernetes/manifests/etcd.yaml"
[init] waiting for the kubelet to boot up the control plane as Static Pods from directory "/etc/kubernetes/manifests" 
[init] this might take a minute or longer if the control plane images have to be pulled
[apiclient] All control plane components are healthy after 41.001672 seconds
[uploadconfig] storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.11" in namespace kube-system with the configuration for the kubelets in the cluster
[markmaster] Marking the node g2-apigateway as master by adding the label "node-role.kubernetes.io/master=''"
[markmaster] Marking the node g2-apigateway as master by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[patchnode] Uploading the CRI Socket information "/var/run/dockershim.sock" to the Node API object "g2-apigateway" as an annotation
[bootstraptoken] using token: o337m9.ceq32wg9g2gro7gx
[bootstraptoken] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstraptoken] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstraptoken] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstraptoken] creating the "cluster-info" ConfigMap in the "kube-public" namespace
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes master has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join 172.16.8.62:6443 --token o337m9.ceq32wg9g2gro7gx --discovery-token-ca-cert-hash sha256:e8adc6dc2bbe6bd18569c73e4c0468b4652655e7c5c97209a9ec214beac55ea3
```
执行创建文件：
```
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

3.1 配置 kubectl 认证信息
```
export KUBECONFIG=/etc/kubernetes/admin.conf
# 如果你想持久化的话，直接执行以下命令【推荐】
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bash_profile
```
3.2 安装 Flannel 网络
```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```
---  

### node节点：
1.4. 配置 Kubeadm 所用到的镜像
> 这里是重中之重，因为在国内的原因，无法访问到 Google 的镜像库，所以我们需要执行以下脚本来从 Docker Hub 仓库中获取相同的镜像，并且更改 TAG 让其变成与 Google 拉去镜像一致。  
新建一个 Shell 脚本，填入以下代码之后保存。
```
#!/bin/bash
images=(kube-proxy-amd64:v1.11.0 pause:3.1)
for imageName in ${images[@]} ; do
docker pull keveon/$imageName
docker tag keveon/$imageName k8s.gcr.io/$imageName
docker rmi keveon/$imageName
done
```
执行脚本  
```
chmod -R 777 ./xxx.sh 
./xxx.sh
```
1.4.1. 在node1/node2上复制 kubectl 认证信息
```
scp /etc/kubernetes/admin.conf node1:/etc/kubernetes/admin.conf
scp /etc/kubernetes/admin.conf node2:/etc/kubernetes/admin.conf

export KUBECONFIG=/etc/kubernetes/admin.conf
# 如果你想持久化的话，直接执行以下命令【推荐】
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bash_profile
```
 1.4.2. 在node1/node2上执行刚刚master输出的：
 ```
kubeadm join 172.16.8.62:6443 --token o337m9.ceq32wg9g2gro7gx --discovery-token-ca-cert-hash sha256:e8adc6dc2bbe6bd18569c73e4c0468b4652655e7c5c97209a9ec214beac55ea3 --ignore-preflight-errors=Swap
 ```
 1.4.3. 在node1/node2上安装 Flannel 网络
```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

### 在master服务器，执行以下命令：
```
$ kubectl get nodes

NAME               STATUS    ROLES     AGE       VERSION
master           Ready     master    46m       v1.11.0
node1            Ready     <none>    41m       v1.11.0
node2            Ready     <none>    41m       v1.11.0
```


