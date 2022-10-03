# Graylog个人总结笔记

## Kubernetes 部署graylog集群

架构图

![image-20220506170427495.png](./images/image-20220506170427495.png)

```shell
# helm repo add kongz https://charts.kong-z.com

# helm search repo kongz/graylog -l
# helm pull kongz/graylog --version 1.8.9
# helm pull stable/elasticsearch --version 1.32.2
# helm pull bitnami/mongodb --version 9.3.1
```

查看graylog 1.8.9版本对应的mongodb和elasticsearch版本号

```shell
# tar -xvf graylog-1.8.9.tgz
[root@ansible graylog]# cat graylog/Chart.yaml 
apiVersion: v2
appVersion: 4.1.3
dependencies:
- name: elasticsearch
  repository: https://charts.helm.sh/stable
  tags:
  - install-elasticsearch
  version: 1.32.2
- name: mongodb
  repository: https://charts.bitnami.com/bitnami
  tags:
  - install-mongodb
  version: 9.3.1
description: Graylog is the centralized log management solution built to open standards
  for capturing, storing, and enabling real-time analysis of terabytes of machine
  data.
home: https://www.graylog.org
icon: https://global-uploads.webflow.com/5a218ef7897bf400019e2f16/5a218ef7897bf400019e2f60_logo-graylog.png
keywords:
- graylog
- logs
- syslog
- gelf
maintainers:
- email: goonohc@gmail.com
  name: KongZ
name: graylog
sources:
- https://github.com/KongZ/charts
version: 1.8.9
```



## 手动安装依赖

当您想扩展服务的可用性、可扩展性和安全性时，*建议使用*此方法。在安装 Graylog 之前，您需要使用适当的设置安装 MongoDB 副本集和 Elasticsearch。

```shell
# tar -xvf graylog-1.8.9.tgz 
# tar xvf mongodb-9.3.1.tgz 
# tar -xvf elasticsearch-1.32.2.tgz 
# ll
total 244
drwxr-xr-x. 4 root root   106 May  7 14:14 elasticsearch
-rw-r--r--. 1 root root 17116 May  7 14:03 elasticsearch-1.32.2.tgz
drwxr-xr-x. 4 root root   123 May  7 14:06 graylog
-rw-r--r--. 1 root root 84106 May  7 13:56 graylog-1.8.9.tgz
drwxr-xr-x. 4 root root   216 May  7 14:13 mongodb
-rw-r--r--. 1 root root 45550 May  7 14:05 mongodb-9.3.1.tgz

# kubectl create ns graylog
```

安装 MongoDB

```shell
# helm install -n graylog mongodb ./mongodb
# 卸载
# helm uninstall -n graylog mongodb
```

安装 Elasticsearch

```shell
# helm install -n graylog elasticsearch ./elasticsearch
# 卸载
# helm uninstall -n graylog elasticsearch
# 更新
# helm upgrade -n graylog elasticsearch ./elasticsearch
```

安装 graylog

```shell
# vim graylog/values.yaml
... ...
tags:
  # If true, this chart will install Elasticsearch from requirement dependencies
  install-elasticsearch: false
  #install-elasticsearch: true
  # If true, this chart will install MongoDB replicaset from requirement dependencies
  install-mongodb: false
  #install-mongodb: true
  ... ...
  service:
    #type: ClusterIP
    type: NodePort
    port: 9000
    nodePort: 31506

    master:
      enabled: true
      port: 9000
      type: NodePort
      nodePort: 31508
  ... ...
  input:
    tcp:
       service:
         name: gelf-http
         type: NodePort
         NodePort: 31507
        #loadBalancerIP:
       ports:
         - name: gelf
           port: 12201
    #udp:
    #   service:
    #     name: your-udp-service-name
    #     type: ClusterIP
    #   ports:
    #     - name: syslog
    #       port: 12222

... ...
  rootTimezone: "Asia/Shanghai"
... ...
  elasticsearch:
    version: "6"
    # hosts: http://elasticsearch-client.graylog.svc.cluster.local:9200
    hosts: "http://elastic6-elasticsearch-client.graylog.svc.cluster.local:9200"
 
  mongodb:
    ## See https://docs.mongodb.com/manual/reference/connection-string/ for details
    # uri: mongodb://user:pass@host1:27017,host2:27017,host3:27017/graylog?replicaSet=rs01
    uri: "mongodb://graylog:123456@mongodb-0.mongodb-headless.graylog.svc.cluster.local:27017,mongodb-1.mongodb-headless.graylog.svc.cluster.local:27017/graylog?replicaSet=rs0"

# helm install -n graylog graylog ./graylog
# 卸载
# helm uninstall -n graylog graylog
```



```shell
helm install --namespace "graylog" graylog ./graylog \
  --set tags.install-mongodb=false\
  --set tags.install-elasticsearch=false\
  --set graylog.mongodb.uri=mongodb://mongodb-mongodb-replicaset-0.mongodb-mongodb-replicaset.graylog.svc.cluster.local:27017/graylog?replicaSet=rs0 \
  --set graylog.elasticsearch.hosts=http://elasticsearch-master.graylog.svc.cluster.local:9200
  --set graylog.elasticsearch.version=7
```



参考：https://github.com/KongZ/charts/tree/graylog-1.8.9/charts/graylog

部署方式采用helm3.

Charts包和镜像包路径：

  100.65.16.3:/root/graylog-new目录下

使用独立的namespace:

   空间名为： graylog

1. 部署mongodb repliaset副本集

  



cd /root/graylog-newKubectl  create  ns  graylogHelm install -n graylog mongodb ./mongodb Helm list -n graylog [root@k8s-node01 graylog-new]# helm install -n graylog mongodb ./mongodb NAME: mongodbLAST DEPLOYED: Sun Nov 14 22:01:43 2021NAMESPACE: graylogSTATUS: deployedREVISION: 1TEST SUITE: NoneNOTES:** Please be patient while the chart is being deployed ** MongoDB can be accessed via port 27017 on the following DNS name(s) from within your cluster:     mongodb-0.mongodb-headless.graylog.svc.cluster.local    mongodb-1.mongodb-headless.graylog.svc.cluster.local     To get the root password run:     export MONGODB_ROOT_PASSWORD=$(kubectl get secret --namespace graylog mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 --decode) To get the password for "graylog" run:     export MONGODB_PASSWORD=$(kubectl get secret --namespace graylog mongodb -o jsonpath="{.data.mongodb-password}" | base64 --decode) To connect to your database, create a MongoDB client container:     kubectl run --namespace graylog mongodb-client --rm --tty -i --restart='Never' --image 100.65.34.29:8082/bitnami/mongodb:4.4.1-debian-10-r39 --command -- bash Then, run the following command:    mongo admin --host "mongodb-0.mongodb-headless.graylog.svc.cluster.local,mongodb-1.mongodb-headless.graylog.svc.cluster.local," --authenticationDatabase admin -u root -p $MONGODB_ROOT_PASSWORD[root@k8s-node01 graylog-new]# export MONGODB_ROOT_PASSWORD=$(kubectl get secret --namespace graylog mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 --decode)[root@k8s-node01 graylog-new]# echo $MONGODB_ROOT_PASSWORDX7VhslR8qo





1. 部署elasticsearch集群



Helm install -n graylog elastic6 ./elasticsearch  [root@k8s-node01 graylog-new]# helm install -n graylog elastic6 ./elasticsearchNAME: elastic6LAST DEPLOYED: Sun Nov 14 22:03:53 2021NAMESPACE: graylogSTATUS: deployedREVISION: 1NOTES:The elasticsearch cluster has been installed. Elasticsearch can be accessed:   * Within your cluster, at the following DNS name at port 9200:     elastic6-elasticsearch-client.graylog.svc   * From outside the cluster, run these commands in the same shell:     export POD_NAME=$(kubectl get pods --namespace graylog -l "app=elasticsearch,component=client,release=elastic6" -o jsonpath="{.items[0].metadata.name}")    echo "Visit http://127.0.0.1:9200 to use Elasticsearch"    kubectl port-forward --namespace graylog $POD_NAME 9200:9200 





1. 部署graylog

   

1. 其他

graylog登录信息 

http://100.65.16.3:32230  (目前以nodePort方式暴露)

用户：admin

密码：P9u9OkRJpmKLyxOD



查看pod运行状态

​                 ![img](https://docimg1.docs.qq.com/image/1DG5OcRnQwRggxhST7hNrg.png?w=1169&h=402)        



1. 验证

创建一个GELF HTTP的INPUT测试。

​                 ![img](https://docimg3.docs.qq.com/image/Usqyd0Zn4LzWKnmnxiHAgQ.png?w=1646&h=995)        



进入grayloy-0 POD中执行如下shell

curl -XPOST http://127.0.0.1:12201/gelf -p0 -d '{"short_message":"这是一条测试消息", "host":"172.3.3.3", "facility":"test", "_foo":"bar"}'

进入graylog-web查看

​                 ![img](https://docimg6.docs.qq.com/image/8kKLdPwkuYXom6nnmfoM1g.png?w=1510&h=894)        







https://docs.graylog.org/docs/gelf#gelf-via-udp





## Graylog 日志收集

## （1）graylog-sidecar 收集应用日志

**Graylog Sidecar**是一个针对不同日志收集器的轻量级配置管理系统，也称为*Backends*。Graylog 节点充当包含日志收集器配置的集中式枢纽。在支持的消息生成设备/主机上，Sidecar 可以作为服务（Windows 主机）或守护进程（Linux 主机）运行。

![sidecaroverview.png](https://cdn.document360.io/49d29856-3708-4e61-a1fc-cf1f90558543/Images/Documentation/sidecaroverview.png)

参考：
https://docs.graylog.org/docs/sidecar
https://www.elastic.co/downloads/beats/filebeat
https://nxlog.co/products/nxlog-community-edition/download

### 创建 API 令牌

导航到*System* > *Sidecars*，然后单击说明文本：*为 graylog-sidecar 用户创建或重用令牌*

![image-20220506170547832](./images/image-20220506170547832.png)

![image-20220506170509027](./images/image-20220506170509027.png)



![image-20220506170427496](./images/image-20220506170427496.png)

### 创建Inputs

![image-20220506171208652](./images/image-20220506171208652.png)

![image-20220506171445569](./images/image-20220506171445569.png)

![image-20220506230527051](./images/image-20220506230527051.png)

```
# cat graylog-beats.yaml 
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: graylog
    meta.helm.sh/release-namespace: graylog
  labels:
    app.kubernetes.io/component: TCP
    app.kubernetes.io/instance: graylog
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: graylog
    app.kubernetes.io/version: 4.1.3
    helm.sh/chart: graylog-1.8.9
  name: graylog-beats
  namespace: graylog
spec:
  ports:
  - name: beats
    nodePort: 30544
    port: 5044
    protocol: TCP
    targetPort: 5044
  selector:
    app.kubernetes.io/instance: graylog
    app.kubernetes.io/name: graylog
  sessionAffinity: None
  type: NodePort
status:
  loadBalancer: {}
  
[root@ansible graylog]# kubectl -n graylog get po,ep,svc
NAME                                                 READY   STATUS    RESTARTS   AGE
pod/elastic6-elasticsearch-client-6dc67bdf96-jdtrk   1/1     Running   0          204d
pod/elastic6-elasticsearch-client-6dc67bdf96-lprvz   1/1     Running   6          204d
pod/elastic6-elasticsearch-data-0                    1/1     Running   0          11d
pod/elastic6-elasticsearch-data-1                    1/1     Running   0          11d
pod/elastic6-elasticsearch-master-0                  1/1     Running   0          154d
pod/elastic6-elasticsearch-master-1                  1/1     Running   0          154d
pod/elastic6-elasticsearch-master-2                  1/1     Running   0          154d
pod/graylog-0                                        1/1     Running   0          154d
pod/graylog-1                                        1/1     Running   0          154d
pod/graylog-2                                        1/1     Running   0          154d
pod/mongodb-0                                        1/1     Running   0          205d
pod/mongodb-1                                        1/1     Running   0          205d
pod/mongodb-arbiter-0                                1/1     Running   6          205d

NAME                                         ENDPOINTS                                                       AGE
endpoints/elastic6-elasticsearch-client      10.233.112.189:9200,10.233.74.250:9200                          204d
endpoints/elastic6-elasticsearch-discovery   10.233.110.230:9300,10.233.64.234:9300,10.233.68.28:9300        204d
endpoints/gelf-http                          10.233.110.228:12201,10.233.110.229:12201,10.233.64.233:12201   205d
endpoints/graylog                            10.233.110.228:9000,10.233.110.229:9000,10.233.64.233:9000      205d
endpoints/graylog-beats                      10.233.110.228:5044,10.233.110.229:5044,10.233.64.233:5044      175m
endpoints/graylog-master                     10.233.110.229:9000                                             205d
endpoints/graylog-tcp                        10.233.110.228:12222,10.233.110.229:12222,10.233.64.233:12222   202d
endpoints/graylog-web                        10.233.110.228:9000,10.233.110.229:9000,10.233.64.233:9000      205d
endpoints/mongodb-arbiter-headless           10.233.74.21:27017                                              205d
endpoints/mongodb-headless                   10.233.82.71:27017,10.233.82.72:27017                           205d

NAME                                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)           AGE
service/elastic6-elasticsearch-client      NodePort    10.233.45.117   <none>        9200:31597/TCP    204d
service/elastic6-elasticsearch-discovery   ClusterIP   None            <none>        9300/TCP          204d
service/gelf-http                          NodePort    10.233.50.37    <none>        12201:30829/TCP   205d
service/graylog                            ClusterIP   None            <none>        9000/TCP          205d
service/graylog-beats                      NodePort    10.233.49.35    <none>        5044:30544/TCP    175m
service/graylog-master                     ClusterIP   10.233.2.74     <none>        9000/TCP          205d
service/graylog-tcp                        ClusterIP   10.233.26.147   <none>        12222/TCP         202d
service/graylog-web                        NodePort    10.233.48.254   <none>        9000:32230/TCP    205d
service/mongodb-arbiter-headless           ClusterIP   None            <none>        27017/TCP         205d
service/mongodb-headless                   ClusterIP   None            <none>        27017/TCP         205d

```

设置代理

```shell
# nginx配置L4代理
# vim /etc/nginx/nginx.conf
... ...
stream {
    include /etc/nginx/stream.conf.d/*.conf;
}
... ...

# cat /etc/nginx/stream.conf.d/graylog.conf 
upstream graylog-beats-proxy {
  server 100.65.16.5:30544 weight=5 max_fails=3 fail_timeout=30s;
  server 100.65.16.9:30544 weight=5 max_fails=3 fail_timeout=30s;
  server 100.65.16.8:30544 backup;
}
server {
      listen 5044;
      proxy_connect_timeout 30s;
      proxy_timeout 600s;
      proxy_pass graylog-beats-proxy;
}
```

### 安装客户端

```shell
yum install -y http://100.65.34.22/software/filebeat-8.1.1-x86_64.rpm
yum install -y http://100.65.34.22/software/graylog-sidecar-1.1.0-1.x86_64.rpm
#yum install -y http://100.65.34.22/software/nxlog-ce-3.0.2272-1_rhel7.x86_64.rpm
```

编辑配置（参见配置）并将 Sidecar 激活为系统服务：
```shell
# vim /etc/graylog/sidecar/sidecar.yml 
... ...
server_url: "https://t-graylog.example.com/api"
server_api_token: "6v78hec3ppmaieisicojn4nn4o4uhbf3nig1o6e460e7ij7ae8s"  # TEST

sudo graylog-sidecar -service install
sudo systemctl start graylog-sidecar
sudo systemctl enable graylog-sidecar
sudo systemctl status graylog-sidecar

sudo service nxlog stop
sudo chkconfig --del nxlog
sudo gpasswd -a nxlog root
sudo chown -R nxlog.nxlog /var/spool/nxlog
```

### 配置Graylog

![image-20220506170732490](./images/image-20220506170732490.png)

![image-20220506170837560](./images/image-20220506170837560.png)

```
# Needed for Graylog
fields_under_root: true
fields.collector_node_id: ${sidecar.nodeName}
fields.gl2_source_collector: ${sidecar.nodeId}

fields.source: ${sidecar.nodeName}   # 解决Filebeat linux source: unknown问题

filebeat.inputs:
- input_type: log
  paths:
    - /var/log/*.log
    - /data/kafka/logs/*.log
    - /data/zookeeper/logs/zookeeper*.out
    - /data/mongodb/log/*.log
  type: log
output.logstash:
   hosts: ["graylog.example.com:5044"]
path:
  data: /var/lib/graylog-sidecar/collectors/filebeat/data
  logs: /var/lib/graylog-sidecar/collectors/filebeat/log
tags:
 - ${sidecar.operatingSystem}
 - TEST
```

![image-20220506170908889](./images/image-20220506170908889.png)

![image-20220506170946366](./images/image-20220506170946366.png)

![image-20220506170956053](./images/image-20220506170956053.png)

![image-20220506171049681](./images/image-20220506171049681.png)

参考：
https://docs.graylog.org/docs/sidecar
https://www.elastic.co/downloads/beats/filebeat
https://nxlog.co/products/nxlog-community-edition/download

## （2）syslog收集系统日志：

![image-20220506174502142](./images/image-20220506174502142.png)

K8S 暴露出syslog服务端口

```shell
$ cat Graylog-Syslog-TCP.yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: graylog
    meta.helm.sh/release-namespace: graylog
  labels:
    app.kubernetes.io/component: TCP
    app.kubernetes.io/instance: graylog
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: graylog
    app.kubernetes.io/version: 4.1.3
    helm.sh/chart: graylog-1.8.9
  name: graylog-syslog-tcp
  namespace: graylog
spec:
  ports:
  - name: syslog-tcp
    nodePort: 31514
    port: 12514
    protocol: TCP
    targetPort: 12514
  selector:
    app.kubernetes.io/instance: graylog
    app.kubernetes.io/name: graylog
  sessionAffinity: None
  type: NodePort
status:
  loadBalancer: {}
```

配置rsyslog

```shell
# yum install rsyslog

# cat /etc/rsyslog.d/graylog.conf
*.*@@100.65.34.188:31514;RSYSLOG_SyslogProtocol23Format

# systemctl start rsyslog.service 
```
参考：https://docs.graylog.org/docs/syslog

 ## （3）收集docker容器日志

![image-20220506175353220](./images/image-20220506175353220.png)

```shell
$ kubectl get svc -n graylog 
NAME                               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)           AGE
graylog-beats                      NodePort    10.22.61.120   <none>        5044:31544/TCP    6h31m
gelf-http                          NodePort    10.22.57.82    <none>        12201:31028/TCP   36d
gelf-tcp                           NodePort    10.22.2.42     <none>        12202:31029/TCP   36d
gelf-udp                           NodePort    10.22.29.200   <none>        12203:31030/UDP   36d
graylog                            ClusterIP   None           <none>        9000/TCP          36d
graylog-master                     NodePort    10.22.30.34    <none>        9000:31508/TCP    36d
graylog-syslog-tcp                 NodePort    10.22.6.188    <none>        12514:31514/TCP   7h40m
graylog-web                        NodePort    10.22.37.227   <none>        9000:31506/TCP    36d
```

```shell
使用 CURL 通过 HTTP 发送 GELF 消息
$ curl -X POST -H 'Content-Type: application/json' -d '{ "version": "1.1", "host": "example.org", "short_message": "A short message", "level": 5, "_some_info": "foo" }' http://100.65.34.188:31028/gelf

使用 NETCAT 通过 TCP 发送 GELF 消息
# echo -n '{ "version": "1.1", "host": "example.org", "short_message": "A short message", "level": 5, "_some_info": "foo" }' | nc -w12 -u 100.65.34.188 31030 

使用 NETCAT 通过 TCP 发送 GELF 消息
echo -n -e '{ "version": "1.1", "host": "example.org", "short_message": "A short message", "level": 5, "_some_info": "foo" }'"\0" | nc -w01 100.65.34.188 31029
```

将日志驱动程序设置为`gelf`并设置`gelf-address` 选项

```shell
# cat /etc/docker/daemon.json 
{
  "insecure-registries":["100.65.34.29:8082","docker.example.com"],
  "log-driver": "gelf",
  "log-opts": {
    "gelf-address": "udp://100.65.34.188:31030"
  }
}

# 测试
 docker run \
      --log-driver gelf --log-opt gelf-address=udp://100.65.34.188:31030 \
      docker.example.com/alpine:3.6 echo hello world
```

docker 启动容器指定地址和 driver 

```shell
# [docker] 启动容器指定地址和 driver 
# cat start-jenkins.sh 
#!/bin/bash

docker run \
  -u root \
  -d \
  -p 8080:8080 \
  -p 50000:50000 \
  --restart always \
  --name jenkins \
  -v /data/jenkins/data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --log-driver gelf \
  --log-opt gelf-address=udp://100.65.34.188:31030 \
  --log-opt tag=jenkins \
  docker.example.com/jenkinsci/blueocean
```

docker-compose 启动使用方式 

```shell
# [docker-compose] 启动使用方式 
# cat docker-compose.yml 
version: "3"

networks:
  gitea:
    external: false

services:
  server:
    image: docker.example.com/gitea/gitea:1.15.2
    container_name: gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=mysql
      - GITEA__database__HOST=db:3306
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=gitea
    restart: always
    networks:
      - gitea
    volumes:
      - /data/gitea/data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3000:3000"
      - "2222:22"
    depends_on:
      - db
    logging:
      driver: gelf
      options:
        gelf-address: udp://100.65.34.188:31030
        tag: "gitea"

 
  db:
    image: docker.example.com/mysql:8.0.26
    restart: always
    container_name: mysql
    environment:
      - MYSQL_ROOT_PASSWORD=gitea
      - MYSQL_USER=gitea
      - MYSQL_PASSWORD=gitea
      - MYSQL_DATABASE=gitea
    networks:
      - gitea
    volumes:
      - /data/gitea/mysql:/var/lib/mysql
    ports:
      - 33306:3306 
    logging:
      driver: gelf
      options:
        gelf-address: udp://100.65.34.188:31030
        tag: "gitea-mysql"
```

参考：https://docs.docker.com/config/containers/logging/gelf/





