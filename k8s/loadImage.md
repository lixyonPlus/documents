```
#!/bin/bash
images=(kube-proxy:v1.13.1 kube-scheduler:v1.13.1 kube-controller-manager:v1.13.1 kube-apiserver:v1.13.1
etcd:3.2.24 coredns:1.2.6 pause:3.1 kubernetes-dashboard-amd64:v1.10.0)
for imageName in ${images[@]} ; do
docker pull keveon/$imageName
docker tag keveon/$imageName k8s.gcr.io/$imageName
docker rmi keveon/$imageName
done
```
