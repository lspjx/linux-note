## Ansible安装K8S集群

#### 安装ansible
```shell
yum  -y install epel-release
yum -y install ansible
```
#### 设置ssh免输入yes

```shell
sed -i '/StrictHostKeyChecking/s/.*/    StrictHostKeyChecking no/g' /etc/ssh/ssh_config
```

#### 修改 自定义配置
- inventory/group_vars/all.yaml 
- inventory/hosts.ini

```shell
# cat inventory/hosts.ini 
[all]
k8s-node101 ansible_host=192.168.26.101  ip=192.168.26.101 ansible_ssh_user=root ansible_ssh_pass=root
k8s-node102 ansible_host=192.168.26.102  ip=192.168.26.102 ansible_ssh_user=root ansible_ssh_pass=root
k8s-node103 ansible_host=192.168.26.103  ip=192.168.26.103 ansible_ssh_user=root ansible_ssh_pass=root
k8s-node104 ansible_host=192.168.26.104  ip=192.168.26.104 ansible_ssh_user=root ansible_ssh_pass=root

[kube_control_plane]
k8s-node101
k8s-node102
k8s-node103

[kube_node]
k8s-node104

[k8s_cluster:children]
kube_control_plane
kube_node


# cat inventory/group_vars/all.yaml 
---
# 设置ntp
ntp_server: [ntp.aliyun.com, ntp1.aliyun.com, ntp2.aliyun.com]
# 设置DNS
dns_server: [192.168.26.2, 223.5.5.5, 223.6.6.6]
# 配置阿里云镜像加速器
# registry-mirrors: https://i9utjj72.mirror.aliyuncs.com
# 配置私有镜像仓库
# insecure-registries: harbor.example.com
# 设置K8S版本
kubernetes_version: 1.22.8
# APIServer LB地址加端口，地址127.0.0.1不可修改。
controlPlaneEndpoint: 127.0.0.1:7443
# 设置k8s组件镜像仓库地址
imageRepository: registry.aliyuncs.com/google_containers
# 设置svc网段
serviceSubnet: 10.1.0.0/16
# 设置pod网段
podSubnet: 10.2.0.0/16
```

#### 安装集群
执行playbook安装集群
```shell
# ansible-playbook -i inventory/hosts.ini k8s-cluster.yml 
```
查看集群节点信息
```shell
# ansible-playbook -i inventory/hosts.ini k8s-cluster.yml --tags check-cluster
```

#### 自动扩容节点方法
添加master节点
```shell
# ansible-playbook -i inventory/hosts.ini k8s-cluster.yml --tags init-system,get-token,join-worker
```
添加worker节点
```shell
# ansible-playbook -i inventory/hosts.ini k8s-cluster.yml --tags init-system,get-token,nginx-proxy,join-worker
```

#### 手动扩容节点方法
添加maser节点
```shell
# 获取添加节点命令
kubeadm --kubeconfig /etc/kubernetes/admin.conf token create --print-join-command
或者
kubeadm --kubeconfig /etc/kubernetes/admin.conf  token create $(kubeadm token generate ) --print-join-command

# 获取key
kubeadm --kubeconfig  /etc/kubernetes/admin.conf init phase upload-certs --upload-certs

# 添加master节点完整命令
kubeadm join 127.0.0.1:7443 --token mgo2mp.hx5252kmdidx23p3 \
--discovery-token-ca-cert-hash sha256:a1bba55f6fd460a3db6f1039ee8e050827aba32e4b2a2ecf5ca0916abca3b237 \
 --control-plane --certificate-key 45891c050a10816de15a16918da4f74fed069241b7ff286fa04675191aa799de
```
添加worker节点
```shell
# 获取添加节点命令
kubeadm --kubeconfig /etc/kubernetes/admin.conf token create --print-join-command

# 添加worker节点完整命令
kubeadm join 127.0.0.1:7443 --token mgo2mp.hx5252kmdidx23p3 \
--discovery-token-ca-cert-hash sha256:a1bba55f6fd460a3db6f1039ee8e050827aba32e4b2a2ecf5ca0916abca3b237
```

#### 查看集群情况

```shell
# kubectl get nodes -o wide
NAME          STATUS   ROLES                  AGE    VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION          CONTAINER-RUNTIME
k8s-node101   Ready    control-plane,master   117m   v1.22.8   192.168.26.101   <none>        CentOS Linux 7 (Core)   3.10.0-862.el7.x86_64   docker://20.10.18
k8s-node102   Ready    control-plane,master   116m   v1.22.8   192.168.26.102   <none>        CentOS Linux 7 (Core)   3.10.0-862.el7.x86_64   docker://20.10.18
k8s-node103   Ready    control-plane,master   115m   v1.22.8   192.168.26.103   <none>        CentOS Linux 7 (Core)   3.10.0-862.el7.x86_64   docker://20.10.18
k8s-node104   Ready    <none>                 115m   v1.22.8   192.168.26.104   <none>        CentOS Linux 7 (Core)   3.10.0-862.el7.x86_64   docker://20.10.18
k8s-node105   Ready    <none>                 109m   v1.22.8   192.168.26.105   <none>        CentOS Linux 7 (Core)   3.10.0-862.el7.x86_64   docker://20.10.18
```

#### 验证集群可用性

```shell
# kubectl create deployment nginx-deploy --image=nginx:1.19 --namespace=default --port=80
# kubectl expose deployment nginx-deploy --name=nginx-svc --port=80 --type=NodePort --namespace=default

# 查看pod,endpoints,servece链路情况
# kubectl get po,ep,svc 
NAME                                READY   STATUS    RESTARTS   AGE
pod/nginx-deploy-689cdc4cb6-nn9km   1/1     Running   0          8m8s

NAME                   ENDPOINTS                                                     AGE
endpoints/kubernetes   192.168.26.101:6443,192.168.26.102:6443,192.168.26.103:6443   13h
endpoints/nginx-svc    10.224.111.129:80                                             33s

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/kubernetes   ClusterIP   10.223.0.1       <none>        443/TCP        13h
service/nginx-svc    NodePort    10.223.182.224   <none>        80:30994/TCP   33s

# 查看ipvs路由
# ipvsadm -ln |grep -A1 10.223.182.224
TCP  10.223.182.224:80 rr
  -> 10.224.111.129:80            Masq    1      0          3  

# 验证服务是否能正常访问
# curl -I 10.223.182.224
HTTP/1.1 200 OK
Server: nginx/1.19.10
Date: Fri, 14 Oct 2022 02:19:14 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 13 Apr 2021 15:13:59 GMT
Connection: keep-alive
ETag: "6075b537-264"
Accept-Ranges: bytes  
```