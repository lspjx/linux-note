#!/bin/bash

# 禁用selinux
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 禁用防火墙
systemctl stop firewalld ; systemctl disable firewalld

# 修改内核参数
cat > /etc/sysctl.d/k8s.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_nonlocal_bind = 1
net.ipv4.ip_forward = 1
vm.swappiness=0
EOF
sysctl --system

# 加载ipvs模块
yum -y install ipset ipvsadm
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
chmod +x /etc/sysconfig/modules/ipvs.modules 
source /etc/sysconfig/modules/ipvs.modules
lsmod | grep -e ip_vs -e nf_conntrack_ipv4
cut -f1 -d " "  /proc/modules | grep -e ip_vs -e nf_conntrack_ipv4

# 禁用SWAP
swapoff -a
sed -i '/swap/s/.*/#&/g' /etc/fstab

# 优化ssh禁用DNS解析
sed -i '/UseDNS/s/.*/UseDNS no/g' /etc/ssh/sshd_config
systemctl restart sshd