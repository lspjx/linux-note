#!/bin/bash

if [ $# -eq 0 ]; then
	echo "usage: `basename $0` num"
	exit 1
fi
[[ $1 =~ ^[0-9]+$ ]]
if [ $? -ne 0 ]; then
	echo "usage: `basename $0` 10~240"
	exit 1
fi

cat > /etc/sysconfig/network-scripts/ifcfg-ens32 <<EOF
TYPE=Ethernet
BOOTPROTO=none
NAME=ens32
DEVICE=ens32
ONBOOT=yes
IPADDR=192.168.26.${1}
NETMASK=255.255.255.0
GATEWAY=192.168.26.2
DNS1=192.168.26.2
EOF

systemctl restart network &> /dev/null
ip=$(ifconfig ens32 | awk '/inet /{print $2}')
sed -i '/192/d' /etc/issue
echo $ip
echo $ip >> /etc/issue
hostnamectl set-hostname node${1}
echo "192.168.26.${1} node${1}"  >> /etc/hosts
