#!/bin/bash
#
firewall-cmd --set-default-zone=trusted &> /dev/null

swapoff -a ; sed -i '/swap/d' /etc/fstab

yum install docker-ce -y

systemctl enable docker --now

cat > /etc/docker/daemon.json <<EOF
{
   "registry-mirrors": ["https://frz7i079.mirror.aliyuncs.com"]
}
EOF
systemctl restart docker
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl -p /etc/sysctl.d/k8s.conf

docker load -i /root/calico_3_14.tar

yum install -y kubelet-1.20.1-0 kubeadm-1.20.1-0 kubectl-1.20.1-0  --disableexcludes=kubernetes 

systemctl restart kubelet ; systemctl enable kubelet
sed -i '2i source <(kubectl completion bash)' /etc/profile

echo "在master上执行如下命令: "
echo ""
echo "kubeadm init --image-repository registry.aliyuncs.com/google_containers --kubernetes-version=v1.20.1 --pod-network-cidr=10.244.0.0/16"
echo ""
