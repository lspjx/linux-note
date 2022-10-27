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
安装集群
```shell
# ansible-playbook -i inventory/hosts.ini k8s-cluster.yml 
```
查看集群节点信息
```shell
# ansible-playbook -i inventory/hosts.ini k8s-cluster.yml  --tags check-cluster
```

#### 自动扩容节点方法
扩展添加master节点
```shell
# ansible-playbook -i inventory/hosts.ini k8s-cluster.yml --tags get-token --tags join-worker
```
添加worker节点
```shell
# ansible-playbook -i inventory/hosts.ini k8s-cluster.yml --tags get-token --tags join-worker
```

#### 手动扩容节点方法
添加maser节点
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
添加worker节点
```shell
# 获取添加节点命令
kubeadm --kubeconfig  /etc/kubernetes/admin.conf token create --print-join-command

# 添加worker节点完整命令
kubeadm join 127.0.0.1:7443 --token mgo2mp.hx5252kmdidx23p3 \
--discovery-token-ca-cert-hash sha256:a1bba55f6fd460a3db6f1039ee8e050827aba32e4b2a2ecf5ca0916abca3b237
```

#### 安装calico网络插件
```shell
# wget https://docs.projectcalico.org/v3.20/manifests/calico.yaml --no-check-certificate

# 修改calico.yaml
          - name: CALICO_IPV4POOL_CIDR
              value: "10.2.0.0/16"
```


#### 配置completion bash和别名
```shell
echo 'source <(kubectl completion bash)' >>~/.bashrc
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -F __start_kubectl k' >>~/.bashrc
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

