## Ansible安装K8S集群

#### 安装ansible
```shell
yum  -y install epel-release
yum -y install ansible
```
设置ssh免输入yes

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
# 设置ntp地址
ntp_server: [ntp.aliyun.com, ntp1.aliyun.com, ntp2.aliyun.com]
# 设置DNS地址
dns_server: [192.168.26.2, 223.5.5.5, 223.6.6.6]
# 配置阿里云加速器
registry-mirrors: https://i9utjj72.mirror.aliyuncs.com
# 配置私有镜像仓库
insecure-registries: harbor.example.com
# 设置K8S版本
kubernetes_version: 1.22.8
# 第一台Master IP地址
advertiseAddress: 192.168.26.101
# 第一台master 主机名
mastername0: k8s-node101
# Master APIServer LB地址加端口，地址127.0.0.1不可修改。
controlPlaneEndpoint: 127.0.0.1:7443
# 设置k8s组件镜像仓库地址
imageRepository: registry.aliyuncs.com/google_containers
# 设置svc网段
serviceSubnet: 10.1.0.0/16
# 设置pod网段
podSubnet: 10.2.0.0/16
```

#### 执行playbook安装集群
```shell
ansible-playbook -i hosts.ini k8s-cluster.yml
```

#### 安装calico网络插件
```shell
# wget https://docs.projectcalico.org/v3.20/manifests/calico.yaml --no-check-certificate

# 修改calico.yaml
          - name: CALICO_IPV4POOL_CIDR
              value: "10.2.0.0/16"
```


#### 配置completion bash
```shell
echo 'source <(kubectl completion bash)' >>~/.bashrc
# kubectl 有关联的别名，你可以扩展 shell 补全来适配此别名：
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -F __start_kubectl k' >>~/.bashrc
```

#### 查看集群情况
```shell
# kubectl get po -A -o wide
NAMESPACE     NAME                                       READY   STATUS    RESTARTS        AGE     IP               NODE          NOMINATED NODE   READINESS GATES
kube-system   calico-kube-controllers-594649bd75-qsdkp   1/1     Running   0               3m      10.2.1.130       k8s-node101   <none>           <none>
kube-system   calico-node-2m7wn                          1/1     Running   0               3m      192.168.26.101   k8s-node101   <none>           <none>
kube-system   calico-node-6gl5r                          1/1     Running   0               105s    192.168.26.103   k8s-node103   <none>           <none>
kube-system   calico-node-mmxkg                          1/1     Running   0               2m44s   192.168.26.104   k8s-node104   <none>           <none>
kube-system   calico-node-sfprt                          1/1     Running   0               2m30s   192.168.26.102   k8s-node102   <none>           <none>
kube-system   coredns-7f6cbbb7b8-zdhlb                   1/1     Running   0               3m      10.2.1.129       k8s-node101   <none>           <none>
kube-system   coredns-7f6cbbb7b8-zsjqv                   1/1     Running   0               3m      10.2.1.131       k8s-node101   <none>           <none>
kube-system   etcd-k8s-node101                           1/1     Running   2               3m5s    192.168.26.101   k8s-node101   <none>           <none>
kube-system   etcd-k8s-node102                           1/1     Running   0               2m25s   192.168.26.102   k8s-node102   <none>           <none>
kube-system   etcd-k8s-node103                           1/1     Running   0               80s     192.168.26.103   k8s-node103   <none>           <none>
kube-system   kube-apiserver-k8s-node101                 1/1     Running   2               3m5s    192.168.26.101   k8s-node101   <none>           <none>
kube-system   kube-apiserver-k8s-node102                 1/1     Running   1               2m28s   192.168.26.102   k8s-node102   <none>           <none>
kube-system   kube-apiserver-k8s-node103                 1/1     Running   3 (81s ago)     102s    192.168.26.103   k8s-node103   <none>           <none>
kube-system   kube-controller-manager-k8s-node101        1/1     Running   4 (2m14s ago)   3m5s    192.168.26.101   k8s-node101   <none>           <none>
kube-system   kube-controller-manager-k8s-node102        1/1     Running   1               2m29s   192.168.26.102   k8s-node102   <none>           <none>
kube-system   kube-controller-manager-k8s-node103        1/1     Running   1               44s     192.168.26.103   k8s-node103   <none>           <none>
kube-system   kube-proxy-8vw8j                           1/1     Running   0               2m44s   192.168.26.104   k8s-node104   <none>           <none>
kube-system   kube-proxy-crz96                           1/1     Running   0               105s    192.168.26.103   k8s-node103   <none>           <none>
kube-system   kube-proxy-gphcz                           1/1     Running   0               2m30s   192.168.26.102   k8s-node102   <none>           <none>
kube-system   kube-proxy-nb26r                           1/1     Running   0               3m      192.168.26.101   k8s-node101   <none>           <none>
kube-system   kube-scheduler-k8s-node101                 1/1     Running   4 (2m14s ago)   3m5s    192.168.26.101   k8s-node101   <none>           <none>
kube-system   kube-scheduler-k8s-node102                 1/1     Running   1               2m29s   192.168.26.102   k8s-node102   <none>           <none>
kube-system   kube-scheduler-k8s-node103                 1/1     Running   1               91s     192.168.26.103   k8s-node103   <none>           <none>

```

### 后期手动扩容节点方法
#### 添加maser节点
```shell
# 获取添加节点命令
kubeadm --kubeconfig  /etc/kubernetes/admin.conf token create --print-join-command

# 获取key
kubeadm --kubeconfig  /etc/kubernetes/admin.conf init phase upload-certs --upload-certs

# 添加master节点完整命令
kubeadm join 127.0.0.1:7443 --token mgo2mp.hx5252kmdidx23p3 \
--discovery-token-ca-cert-hash sha256:a1bba55f6fd460a3db6f1039ee8e050827aba32e4b2a2ecf5ca0916abca3b237 \
 --control-plane --certificate-key 45891c050a10816de15a16918da4f74fed069241b7ff286fa04675191aa799de
```

#### 添加worker节点
```shell
# 获取添加节点命令
kubeadm --kubeconfig  /etc/kubernetes/admin.conf token create --print-join-command

# 添加worker节点完整命令
kubeadm join 127.0.0.1:7443 --token mgo2mp.hx5252kmdidx23p3 \
--discovery-token-ca-cert-hash sha256:a1bba55f6fd460a3db6f1039ee8e050827aba32e4b2a2ecf5ca0916abca3b237
```