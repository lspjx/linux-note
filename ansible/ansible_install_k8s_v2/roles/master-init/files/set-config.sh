#!/bin/bash

test -d $HOME/.kube && rm -rf $HOME/.kube
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

echo 'source <(kubectl completion bash)' > /etc/profile.d/kubectl.sh
echo 'alias k=kubectl' >>  /etc/profile.d/kubectl.sh
echo 'complete -F __start_kubectl k' >>  /etc/profile.d/kubectl.sh