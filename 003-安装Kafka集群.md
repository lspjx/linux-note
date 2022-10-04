## 安装JDK

### 1、下载jdk安装包

http://java.sun.com/javase/downloads/index.jsp

https://www.oracle.com/java/technologies/downloads/archive/

<img src="./images/jdk-1.png" style="zoom:80%;" />

账号：li1121567428@live.com

### 2、解压安装

```shell
tar -xvf jdk-8u202-linux-x64.tar.gz -C /usr/local/
ln -sv /usr/local/jdk1.8.0_202 /usr/local/jdk
```

### 3、添加到环境变量PATH

```shell
cat <<'EOF' > /etc/profile.d/jdk.sh
export JAVA_HOME=/usr/local/jdk
export JRE_HOME=$JAVA_HOME/jre
export PATH=$PATH:$JAVA_HOME/bin
export CLASSPATH=.:$JAVA_HOME/lib:$JRE_HOME/lib
EOF
source /etc/profile 

java -version
```


## 安装Zookeeper集群

### 1、下载zk安装包
https://github.com/apache/zookeeper
https://zookeeper.apache.org/
https://zookeeper.apache.org/releases.html

### 2、解压配置zookeeper
```shell
tar -xf apache-zookeeper-3.6.3-bin.tar.gz -C /opt/
ln -sv /opt/apache-zookeeper-3.6.3-bin /opt/zookeeper

cp /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg

# grep -vE "^#|^$" /opt/zookeeper/conf/zoo.cfg 
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/data/zookeeper
clientPort=2181
server.1=node01:2888:3888
server.2=node02:2888:3888
server.3=node03:2888:3888
```

### 3、同步配置文件到其他服务器
```shell
rsync -arPv /opt/* node02:/opt/
rsync -arPv /opt/* node03:/opt/

# node01
mkdir /data/zookeeper ; echo 1 > /data/zookeeper/myid
# node02
mkdir /data/zookeeper ; echo 2 > /data/zookeeper/myid
# node03
mkdir /data/zookeeper ; echo 3 > /data/zookeeper/myid
```

### 4、开启防火墙
```shell
firewall-cmd --permanent --add-port=2181/tcp 
firewall-cmd --permanent --add-port=2888/tcp 
firewall-cmd --permanent --add-port=3888/tcp 
firewall-cmd --reload
```

### 5、启动ZK服务
```shell
/opt/zookeeper/bin/zkServer.sh start 
/opt/zookeeper/bin/zkServer.sh status
```

重启zk服务
```shell
/opt/zookeeper/bin/zkServer.sh stop
/opt/zookeeper/bin/zkServer.sh start 
/opt/zookeeper/bin/zkServer.sh status
```

#### 5.1、[systemd]配置管理ZK服务

```shell
cat << EOF > /usr/lib/systemd/system/zookeeper.service
[Unit]
Description=zookeeper.service
After=network.target

[Service]
Type=forking
User=zookeeper
Group=zookeeper
# 第一行设置日志目录，如果没有设置，默认是当前目录，对有的用户来说，可能没有权限。
Environment=ZOO_LOG_DIR=/opt/zookeeper/logs
# 第二行是配置环境变量，systemd用户实例不会继承类似.bashrc中定义的环境变量，所以是找不到jdk目录的，而zookeeper又必须有。
Environment=PATH=$PATH
ExecStart=/opt/zookeeper/bin/zkServer.sh start
ExecStop=/opt/zookeeper/bin/zkServer.sh stop
ExecReload=/opt/zookeeper/bin/zkServer.sh restart
PIDFile=/opt/zookeeper/zookeeper_server.pid
# 只要不是通过systemctl stop来停止服务，任何情况下都必须要重启服务，默认值为no
Restart=always
# 重启间隔，比如某次异常后，等待5(s)再进行启动，默认值0.1(s)
RestartSec=10
# StartLimitInterval: 无限次重启，默认是10秒内如果重启超过5次则不再重启，设置为0表示不限次数重启
StartLimitInterval=0
[Install]
WantedBy=multi-user.target

EOF
```

```shell

```

#### 5.1、[supervison]管理Zookeeper服务
安装supervisor
```shell
yum -y install epel-release 
yum -y install supervisor

systemctl enable supervisord.service --now
```
配置zookeeper.ini 
```shell
# cat <<EOF > /etc/supervisord.d/zookeeper.ini 
[program:zookeeper]
command=/opt/zookeeper/bin/zkServer.sh start-foreground
process_name=%(program_name)s
numprocs=1
buffer_size=10 
directory=/opt/zookeeper
autostart=true
autorestart=true
startsecs=10
startretries=999
stopsignal=KILL
stopasgroup=true
user=root
redirect_stderr=true
stdout_logfile=/var/log/supervisor/zookeeper.out
stdout_logfile_maxbytes=1MB 
stdout_logfile_backups=5
stdout_events_enabled=false
stderr_logfile=/var/log/supervisor/zookeeper.err
stderr_logfile_maxbytes=1MB
stderr_logfile_backups=5
stderr_events_enabled=false
environment=JAVA_HOME=/opt/jdk
#startsecs=0
#exitcodes=0
EOF
```

启动服务
```shell
supervisorctl update zookeeper 
supervisorctl restart zookeeper
supervisorctl status zookeeper
jps
```
### 6、连接zk
```shell
# /opt/zookeeper/bin/zkCli.sh -server 127.0.0.1:2181
... ...
[zk: 127.0.0.1:2181(CONNECTED) 0] get /zookeeper/config
server.1=node01:2888:3888:participant
server.2=node02:2888:3888:participant
server.3=node03:2888:3888:participant
version=0
[zk: 127.0.0.1:2181(CONNECTED) 1] 
```

## 安装kafka集群
### 1、下载kafka安装包
https://github.com/apache/kafka
https://kafka.apache.org/downloads
https://kafka.apache.org/quickstart

### 2、解压安装kafka
```shell
tar -xvf kafka_2.13-3.3.1.tgz -C /opt
ln -sv /opt/kafka_2.13-3.3.1 /opt/kafka
```
### 配置kafka
```shell
# grep -vE "^$|^#" /opt/kafka/config/server.properties 
broker.id=0
listeners=PLAINTEXT://:9092
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.dirs=/data/kafka/logs
num.partitions=1
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
log.retention.hours=168
log.retention.check.interval.ms=300000
zookeeper.connect=node01:2181,node02:2181,node03:2181
zookeeper.connection.timeout.ms=18000
group.initial.rebalance.delay.ms=0

```
### 开启防火墙
```shell
firewall-cmd --permanent --add-port=9092/tcp 
firewall-cmd --reload
```
### 启动kafka
```shell
/opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties
```

#### [systemd]管理kafka服务

```shell
# cat <<EOF > /usr/lib/systemd/system/kafka.service
[Unit]
Description=Apache Kafka server (broker)
After=network.target zookeeper.service

[Service]
Type=forking
User=app
Group=app
Environment=PATH=$PATH:/opt/jdk/bin:/opt/kafka/bin
ExecStart=/opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh /opt/kafka/config/server.properties
# 只要不是通过systemctl stop来停止服务，任何情况下都必须要重启服务，默认值为no
Restart=always
# 重启间隔，比如某次异常后，等待5(s)再进行启动，默认值0.1(s)
RestartSec=10
# StartLimitInterval: 无限次重启，默认是10秒内如果重启超过5次则不再重启，设置为0表示不限次数重启
StartLimitInterval=0
LimitNOFILE=265535

[Install]
WantedBy=multi-user.target
EOF
```

#### [supervison]管理kafka服务

```shell
# cat <<EOF > /etc/supervisord.d/kafka.ini 
[program:kafka]
command=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
directory=/opt/kafka
autostart=true
autorestart=true
startsecs=10
startretries=999
stopsignal=KILL
stopasgroup=true
user=root
redirect_stderr=true
stdout_logfile=/var/log/supervisor/kafka.out
stdout_logfile_maxbytes=1MB 
stdout_logfile_backups=5
stdout_events_enabled=false
stderr_logfile=/var/log/supervisor/kafka.err
stderr_logfile_maxbytes=1MB
stderr_logfile_backups=5
stderr_events_enabled=false
environment=JAVA_HOME=/opt/jdk
EOF
```
启动服务
```shell
supervisorctl update kafka 
supervisorctl restart kafka
supervisorctl status kafka
jps
```


### 测试kafka
- ##### 创建主题
```shell
# ./kafka-topics.sh --bootstrap-server node01:9092 --create --replication-factor 2  --partitions 2 --topic topic-test01
Created topic topic-test01.
```
- ##### 查看主题
```shell
# ./kafka-topics.sh --bootstrap-server node01:9092 --list
topic-test01
# ./kafka-topics.sh --bootstrap-server node01:9092 --describe --topic topic-test01
Topic: topic-test01	TopicId: wPOHoBcbQOmMw2LWH5uLnQ	PartitionCount: 3	ReplicationFactor: 2	Configs: 
	Topic: topic-test01	Partition: 0	Leader: 2	Replicas: 2,1	Isr: 2,1
	Topic: topic-test01	Partition: 1	Leader: 1	Replicas: 1,0	Isr: 1,0
	Topic: topic-test01	Partition: 2	Leader: 0	Replicas: 0,2	Isr: 0,2
```
PartitionCount：显示分区数量一共有多少
ReplicationFactor：副本数量
Partition：分区编号
Leader：该分区的Leader副本在哪个broker上，这里显示的是broker的ID
Replicas：显示该partitions所有副本存储在哪些节点上 broker.id 这个是配置文件中设置的，它包括leader和follower节点
Isr：显示副本都已经同步的节点集合，这个集合的所有节点都是存活的，并且跟Leader节点同步

- ##### 修改主题
修改副本数，只能增加不能减少
```shell
# kafka-topics.sh --bootstrap-server node01:9092  --alter --replication-factor 3 --partitions 3 --topic topic-test01
```
- ##### 删除主题
```shell
# 如果主题存在就删除
# kafka-topics.sh --bootstrap-server node01:9092 --delete --topic topic-test03 --if-exists
# kafka-topics.sh --bootstrap-server node01:9092 --delete --topic topic-test02
```
- ##### 生产者
```shell
# kafka-console-producer.sh --broker-list node01:9092,node02:9092,node03:9092 --topic topic-test01
```
- ##### 消费者
```shell
# kafka-console-consumer.sh --bootstrap-server node01:9092,node02:9092,node03:9092 --group testGroup1 --topic topic-test01
# 从最后一个offset（偏移量）+1 开始消费

# kafka-console-consumer.sh --bootstrap-server node01:9092,node02:9092,node03:9092 --group testGroup1 --from-beginning --topic topic-test01
# --from-beginning 表示从头消费

# kafka-console-consumer.sh --bootstrap-server node01:9092,node02:9092,node03:9092 --group testGroup2 --topic topic-test01
 
# kafka-console-consumer.sh --bootstrap-server node01:9092,node02:9092,node03:9092 --group testGroup3 --topic topic-test01
```
