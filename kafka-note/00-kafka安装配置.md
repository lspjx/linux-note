# kafka安装配置

## 安装JDK

```shell
tar -xvf jdk-8u202-linux-x64.tar.gz -C /usr/local/
ln -sv /usr/local/jdk1.8.0_202 /usr/local/jdk
```

# 添加到环境变量PATH
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

## 安装kafka

```shell
# 添加到环境变量PATH
cat <<'EOF' >/etc/profile.d/kafka.sh 
export PATH=$PATH:/data/kafka/bin:/data/zookeeper/bin
EOF

source /etc/profile 
```

## 配置kafka

```
[root@kafka-0 config]# cat server.properties
broker.id=1
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
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181
zookeeper.connection.timeout.ms=18000
group.initial.rebalance.delay.ms=0
listeners=PLAINTEXT://10.10.34.224:9092
advertised.listeners=PLAINTEXT://10.10.34.224:9092
```
## 配置zk和kafka服务

先启动zk后启动kafka


```
[root@kafka-uat-0 ~]# cat /etc/systemd/system/zookeeper.service
[Unit]
Description=zookeeper.service
After=network.target

[Service]
Type=forking
User=app
Group=app
# 第一行设置日志目录，如果没有设置，默认是当前目录，对有的用户来说，可能没有权限。
Environment=ZOO_LOG_DIR=/data/zookeeper/logs
# 第二行是配置环境变量，systemd用户实例不会继承类似.bashrc中定义的环境变量，所以是找不到jdk目录的，而zookeeper又必须有。
Environment=PATH=/data/jdk1.8.0_202/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/root/bin
ExecStart=/data/zookeeper/bin/zkServer.sh start
ExecStop=/data/zookeeper/bin/zkServer.sh stop
ExecReload=/data/zookeeper/bin/zkServer.sh restart
PIDFile=/data/zookeeper/data/zookeeper_server.pid
# 只要不是通过systemctl stop来停止服务，任何情况下都必须要重启服务，默认值为no
Restart=always
# 重启间隔，比如某次异常后，等待5(s)再进行启动，默认值0.1(s)
RestartSec=10
# StartLimitInterval: 无限次重启，默认是10秒内如果重启超过5次则不再重启，设置为0表示不限次数重启
StartLimitInterval=0
[Install]
WantedBy=multi-user.target
```

```
[root@kafka-uat-0 ~]# cat /etc/systemd/system/kafka.service
[Unit]
Description=Apache Kafka server (broker)
After=network.target zookeeper.service

[Service]
Type=forking
User=app
Group=app
Environment=PATH=/data/jdk1.8.0_202/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/root/bin
ExecStart=/data/kafka/bin/kafka-server-start.sh -daemon /data/kafka/config/server.properties
ExecStop=/data/kafka/bin/kafka-server-stop.sh /data/kafka/config/server.properties
# 只要不是通过systemctl stop来停止服务，任何情况下都必须要重启服务，默认值为no
Restart=always
# 重启间隔，比如某次异常后，等待5(s)再进行启动，默认值0.1(s)
RestartSec=10
# StartLimitInterval: 无限次重启，默认是10秒内如果重启超过5次则不再重启，设置为0表示不限次数重启
StartLimitInterval=0
LimitNOFILE=265535

[Install]
WantedBy=multi-user.target
```

## ZK管理

```shell
[root@kafka-0 ~]# cd /data/zookeeper/bin/
[root@kafka-0 bin]# ./zkCli.sh 
Connecting to localhost:2181
... ...
[zk: localhost:2181(CONNECTED) 0] ls /
[admin, brokers, cluster, config, consumers, controller, controller_epoch, feature, isr_change_notification, latest_producer_id_block, log_dir_event_notification, zookeeper]
[zk: localhost:2181(CONNECTED) 1] ls /brokers 
[ids, seqid, topics]
[zk: localhost:2181(CONNECTED) 2] ls /brokers/ids
[1, 2, 3]
[zk: localhost:2181(CONNECTED) 3] ls /brokers/topics
[__consumer_offsets, topic-test01, topic-test02]
```

<img src="./images/image-20220108233927619.png" style="zoom:80%;" />

## 创建主题

创建主题的时候有两种方式一个是使用--zookeeper和--bootstrap-server，前者不需要认证因为它不连接broker，但是后者需要。

`注意：Kafka 从 2.2 版本开始将 kafka-topic.sh 脚本中的 −−zookeeper 参数标注为 “过时”，推荐使用 −−bootstrap-server 参数。若读者依旧使用的是 2.1 及以下版本，请将下述的 --bootstrap-server 参数及其值手动替换为 --zookeeper zk:2181。一定要注意两者参数值所指向的集群地址是不同的。`

```shell
# kafka-topics.sh --create --zookeeper 10.10.34.224:2181 --replication-factor 3  --partitions 2 --topic topic-test01

# 如果主题不存在就创建
# kafka-topics.sh --create --zookeeper 10.10.34.224:2181 --replication-factor 3  --partitions 2 --topic topic-test01 --if-not-exists 

或者：
# kafka-topics.sh --create --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 --replication-factor 3  --partitions 2 --topic topic-test03
Created topic topic-test03.
```

## 修改主题

`修改副本数，只能增加不能减少`

```shell
# kafka-topics.sh --alter --zookeeper 10.10.34.224:2181  --partitions 3 --topic topic-test01
```

## 删除主题

```shell
# 如果主题存在就删除
# kafka-topics.sh --delete --zookeeper 10.10.34.224:2181  --topic topic-test03 --if-exists
# kafka-topics.sh --delete --zookeeper 10.10.34.224:2181  --topic topic-test02
```

## 查看主题

```shell
# kafka-topics.sh --list --zookeeper 10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181  
__consumer_offsets
topic-test01
topic-test02

# kafka-topics.sh --describe --zookeeper 10.10.34.224:2181 --topic topic-test01
Topic: topic-test01	TopicId: 6x2exh8JQDiglSfBNYPsUA	PartitionCount: 2	ReplicationFactor: 3	Configs: 
	Topic: topic-test01	Partition: 0	Leader: 3	Replicas: 3,1,2	Isr: 3,1,2
	Topic: topic-test01	Partition: 1	Leader: 1	Replicas: 1,2,3	Isr: 1,2,3
```

PartitionCount：显示分区数量一共有多少

ReplicationFactor：副本数量

Partition：分区编号

Leader：该分区的Leader副本在哪个broker上，这里显示的是broker的ID

Replicas：显示该partitions所有副本存储在哪些节点上 broker.id 这个是配置文件中设置的，它包括leader和follower节点

Isr：显示副本都已经同步的节点集合，这个集合的所有节点都是存活的，并且跟Leader节点同步

<img src="./images/image-20220108233927609.png" alt="image-20220108233927609" style="zoom:80%;" />

## 生产者：

```shell
# kafka-console-producer.sh --broker-list 10.10.34.224:9092,10.10.34.227:9092,10.10.34.226:9092 --topic topic-test01
```

## 消费者：

```shell
# kafka-console-consumer.sh --bootstrap-server 10.10.34.224:9092,10.10.34.227:9092,10.10.34.226:9092 --group testGroup1 --topic topic-test01
# 从最后一个offset（偏移量）+1 开始消费

# kafka-console-consumer.sh --bootstrap-server 10.10.34.224:9092,10.10.34.227:9092,10.10.34.226:9092 --group testGroup1 --from-beginning --topic topic-test01
# --from-beginning 表示从头消费

# kafka-console-consumer.sh --bootstrap-server 10.10.34.224:9092,10.10.34.227:9092,10.10.34.226:9092 --group testGroup2 --topic topic-test01
 
# kafka-console-consumer.sh --bootstrap-server 10.10.34.224:9092,10.10.34.227:9092,10.10.34.226:9092 --group testGroup3 --topic topic-test01

```

<img src="./images/image-20220108233909085.png" alt="image-20220108233909085" style="zoom:80%;" />



## ACL权限配置

### 配置kafka

```shell
[root@kafka-0 config]# cat server.properties
broker.id=1
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
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181
zookeeper.connection.timeout.ms=18000
group.initial.rebalance.delay.ms=0

listeners=SASL_PLAINTEXT://10.10.34.224:9092,PLAINTEXT://10.10.34.224:9093
advertised.listeners=SASL_PLAINTEXT://10.10.34.224:9092,PLAINTEXT://10.10.34.224:9093
sasl.enabled.mechanisms=SCRAM-SHA-512
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
security.inter.broker.protocol=SASL_PLAINTEXT
#authorizer.class.name=kafka.security.auth.SimpleAclAuthorizer
authorizer.class.name=kafka.security.authorizer.AclAuthorizer
allow.everyone.if.no.acl.found=false
super.users=User:admin;User:nvadmin
delete.topic.enable=true
```

说明：官网这里设置的security.inter.broker.protocol这个参数是SASL_SSL，
包括listeners也是SASL_SSL，需要说明一下如果你启用了SSL加密通信的话你就设置，如果你没有启用那么就设置SASL_PLAINTEXT就好。

### 修改Broker启动脚本

修改kafka_server_jaas.conf文件

```
[root@kafka-0 config]#  cat <<EOF > /data/kafka/config/kafka_server_jaas.conf 
KafkaServer {
   org.apache.kafka.common.security.scram.ScramLoginModule required
   username="admin"
   password="admin123";
};
EOF
```

如果使用外部kafka_server_jaas.conf文件方式，则需要修改启动脚本，把下面的环境变量添加到kafka-server-start.sh脚本中。

```shell
[root@kafka-0 config]# cat /data/kafka/bin/kafka-server-start.sh 
#!/bin/bash

if [ $# -lt 1 ];
then
	echo "USAGE: $0 [-daemon] server.properties [--override property=value]*"
	exit 1
fi
base_dir=$(dirname $0)

if [ "x$KAFKA_LOG4J_OPTS" = "x" ]; then
    export KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:$base_dir/../config/log4j.properties"
fi

if [ "x$KAFKA_HEAP_OPTS" = "x" ]; then
    export KAFKA_HEAP_OPTS="-Xmx4G -Xms4G"  # 修改为4G
fi

EXTRA_ARGS=${EXTRA_ARGS-'-name kafkaServer -loggc'}

COMMAND=$1
case $COMMAND in
  -daemon)
    EXTRA_ARGS="-daemon "$EXTRA_ARGS
    shift
    ;;
  *)
    ;;
esac

添加如下KAFKA_OPTS配置
export JMX_PORT="9999" 
export KAFKA_OPTS="-Djava.security.auth.login.config=$base_dir/../config/kafka_server_jaas.conf"
exec $base_dir/kafka-run-class.sh $EXTRA_ARGS kafka.Kafka "$@"


或者：
##添加-Djava.security.auth.login.config=$base_dir/../config/kafka_server_jaas.conf配置
##exec $base_dir/kafka-run-class.sh $EXTRA_ARGS -Djava.security.auth.login.config=$base_dir/../config/kafka_server_jaas.conf kafka.Kafka "$@"
```

### 重启kafka服务

```shell
[root@kafka-0 config]# systemctl restart kafka
[root@kafka-0 config]# netstat -anltp|grep java|grep LISTEN
tcp6       0      0 :::9999                 :::*                    LISTEN      13322/java          
tcp6       0      0 10.10.34.224:3888      :::*                    LISTEN      17016/java          
tcp6       0      0 :::8080                 :::*                    LISTEN      17016/java          
tcp6       0      0 :::42037                :::*                    LISTEN      17016/java          
tcp6       0      0 :::35352                :::*                    LISTEN      13322/java          
tcp6       0      0 10.10.34.224:9092      :::*                    LISTEN      13322/java          
tcp6       0      0 10.10.34.224:9093      :::*                    LISTEN      13322/java          
tcp6       0      0 :::40005                :::*                    LISTEN      13322/java          
tcp6       0      0 :::2181                 :::*                    LISTEN      17016/java
```

### 创建admin用户

```shell
# kafka-configs.sh --zookeeper 10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181 \
--alter --add-config 'SCRAM-SHA-256=[password=admin123],SCRAM-SHA-512=[password=admin123]' \
--entity-type users --entity-name admin

# kafka-configs.sh --zookeeper 10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181 \
--alter --add-config 'SCRAM-SHA-256=[password=nvadmin123],SCRAM-SHA-512=[password=nvadmin123]' \
--entity-type users --entity-name nvadmin
```

ACL权限控制：参考《kafka设置ACL权限验证》文档

## 配置客户端认证

`broker配置了认证，那么这个客户端工具连接broker需要携带认证信息，这里配置的就是客户端使用的用户名和密码`

### 创建文件kafka_client_jaas.conf

```shell
# cat <<'EOF' >  /data/kafka_2.13-2.8.0/config/kafka_client_jaas.conf
KafkaClient {
  org.apache.kafka.common.security.scram.ScramLoginModule required
  username="admin"
  password="admin123";
};
EOF
```

### 创建文件admin-client-configs.conf

`这里的设置要和broker配置的认证方式一致(server.properties)`

```shell
# cat << 'EOF' >  /data/kafka_2.13-2.8.0/config/admin_client-configs.conf
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";
EOF
```

### 修改kafka-topics.sh脚本

添加如下内容：
export KAFKA_OPTS="-Djava.security.auth.login.config=/data/kafka_2.13-2.8.0/config/kafka_client_jaas.conf

```shell
[root@ansible ~]# cd /data/kafka_2.13-2.8.0/bin/
[root@ansible bin]# cp kafka-topics.sh kafka-topics-admin.sh 
[root@ansible bin]# vim kafka-topics-admin.sh
#!/bin/bash
# ... ...
# 添加如下行
# export KAFKA_OPTS="-Djava.security.auth.login.config=/data/kafka_2.13-2.8.0/config/kafka_client_jaas.conf"

exec $(dirname $0)/kafka-run-class.sh -Djava.security.auth.login.config=/data/kafka_2.13-2.8.0/config/kafka_client_jaas.conf kafka.admin.TopicCommand "$@"
```

### 命令行工具测试创建主题：

```shell
# kafka-topics-admin.sh --create --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 --replication-factor 3  --partitions 2 --topic topic-test03 --command-config ../config/admin_client-configs.conf 
Created topic topic-test03.

# 查看主题
# kafka-topics-admin.sh --list --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 --command-config /data/kafka_2.13-2.8.0/config/admin_client-configs.conf 
__consumer_offsets
connect-configs
connect-offsets
connect-status
topic-test01
topic-test03
```

或者：

```shell
[root@ansible bin]# cat /data/kafka_2.13-2.8.0/config/topic-configs.conf 
#bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";

[root@ansible bin]# kafka-topics.sh --list --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 --command-config /data/kafka_2.13-2.8.0/config/topic-configs.conf 
__consumer_offsets
topic-test01
topic-test02
topic-test03
```

### 命令行工具测试生产和消费

#### 修改consumer.properties配置文件

```shell
# vim /data/kafka_2.13-2.8.0/config/consumer.properties 
# ... ...
bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";
```

#### 修改producer.properties配置文件

```shell
# vim /data/kafka_2.13-2.8.0/config/producer.properties 
bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";
```

#### 通过生产和消费者命令进行测试

生产者

```shell
# kafka-console-producer.sh --broker-list 10.10.34.227:9092,10.10.34.226:9092,10.10.34.224:9092 --topic topic-test03 --producer.config /data/kafka_2.13-2.8.0/config/producer.properties 
```

消费者

```shell
# kafka-console-consumer.sh --bootstrap-server 10.10.34.227:9092,10.10.34.226:9092,10.10.34.224:9092 --topic topic-test03 --consumer.config /data/kafka_2.13-2.8.0/config/consumer.properties 
```

<img src="./images/image-20220108233927622.png" style="zoom:80%;" />

### kafkacat/kcat 工具测试：

查看主题：

```shell
# kcat -b 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092  -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-512 -X sasl.username=admin -X sasl.password=admin123 -L
```

生产者：

```shell
[root@ansible ~]# echo AAAAA | kcat -b 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092  -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-512 -X sasl.username=admin -X sasl.password=admin123 -t topic-test01 -P
```

消费者：

```shell
[root@ansible ~]# kcat -b 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092  -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-512 -X sasl.username=admin -X sasl.password=admin123 -t topic-test01 -C
```

亦可写成：
用-F kafka.conf 指定配置文件，默认配置$HOME/.config/kafkacat.conf 

```shell
[root@ansible ~]# cat << EOF > cat kafka.conf 
security.protocol=SASL_PLAINTEXT
sasl.mechanisms=SCRAM-SHA-512
sasl.username=admin
sasl.password=admin123
EOF

# kcat -b 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092  -L -F kafka.conf 

# echo A=a | kafkacat -b 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 -F kafka.conf -t topic-test01 -P

# kcat -b 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 -F kafka.conf -t topic-test01 -C
```

## Kafka Connect

Kafka Connect运用用户快速定义并实现各种Connector(File,Jdbc,Hdfs等)，这些功能让大批量数据导入/导出Kafka很方便。

<img src="./images/image-20220108233927623.png" style="zoom:90%;" />

如图中所示，左侧的Sources负责从其他异构系统中读取数据并导入到Kafka中；右侧的Sinks是把Kafka中的数据写入到其他的系统中。

### 各种Kafka Connector

　　Kafka Connector很多，包括开源和商业版本的。如下列表中是常用的开源Connector

| Connectors       | References                                                   |
| ---------------- | ------------------------------------------------------------ |
| Jdbc             | [Source](https://github.com/apache/ignite/tree/master/modules/kafka), [Sink](https://github.com/apache/ignite/tree/master/modules/kafka) |
| Elastic Search   | [Sink1](https://github.com/ksenji/kafka-connect-es), [Sink2](https://github.com/hannesstockner/kafka-connect-elasticsearch), [Sink3](https://github.com/DataReply/kafka-connect-elastic-search-sink) |
| Cassandra        | [Source1](https://github.com/tuplejump/kafka-connect-cassandra), [Source 2](https://github.com/datamountaineer/stream-reactor/tree/master/kafka-connect-cassandra), [Sink1](https://github.com/tuplejump/kafka-connect-cassandra), [Sink2 ](https://github.com/datamountaineer/stream-reactor/tree/master/kafka-connect-cassandra) |
| MongoDB          | [Source](https://github.com/DataReply/kafka-connect-mongodb) |
| HBase            | [Sink](https://github.com/mravi/kafka-connect-hbase)         |
| Syslog           | [Source](https://github.com/jcustenborder/kafka-connect-syslog) |
| MQTT (Source)    | [Source](https://github.com/evokly/kafka-connect-mqtt)       |
| Twitter (Source) | [Source](https://github.com/rollulus/twitter-kafka-connect), [Sink](https://github.com/Eneco/kafka-connect-twitter) |
| S3               | [Sink1](https://github.com/qubole/streamx), [Sink2](https://github.com/DeviantArt/kafka-connect-s3) |

### 示例

FileConnector Demo

　本例演示如何使用Kafka Connect把Source(test.txt)转为流数据再写入到Destination(test.sink.txt)中。如下图所示：

<img src="./images/image-20220108233927624.png" alt="image-20220108233927624" style="zoom:80%;" />



本例使用到了两个Connector:

- FileStreamSource：从test.txt中读取并发布到Broker中
- FileStreamSink：从Broker中读取数据并写入到test.sink.txt文件中

　　其中的Source使用到的配置文件是${KAFKA_HOME}/config/connect-file-source.properties

```shell
# Broker使用到的配置文件是${KAFKA_HOME}/config/connect-standalone.properties
[root@ansible kafka_2.13-2.8.0]# cat config/connect-standalone.properties |egrep -v "^#"|grep -v "^$"
bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=true
value.converter.schemas.enable=true
offset.storage.file.filename=/tmp/connect.offsets
offset.flush.interval.ms=10000

# 其中的Source使用到的配置文件是${KAFKA_HOME}/config/connect-file-source.properties
[root@ansible kafka_2.13-2.8.0]# cat config/connect-console-source.properties |egrep -v "^#"|grep -v "^$"
name=local-console-source
connector.class=org.apache.kafka.connect.file.FileStreamSourceConnector
tasks.max=1
topic=connect-test
 
# 其中的Sink使用到的配置文件是${KAFKA_HOME}/config/connect-file-sink.properties
[root@ansible kafka_2.13-2.8.0]# cat config/connect-console-sink.properties | egrep -v "^#"|grep -v "^$"
name=local-console-sink
connector.class=org.apache.kafka.connect.file.FileStreamSinkConnector
tasks.max=1
topics=connect-test
```

#### 启动Source Connector和Sink Connector

```shell
[root@ansible kafka_2.13-2.8.0]# ./bin/connect-standalone.sh config/connect-standalone.properties config/connect-file-source.properties config/connect-file-sink.properties 

# 打开console-consumer
[root@ansible kafka_2.13-2.8.0]# kafka-console-consumer.sh --bootstrap-server 10.10.34.224:9092,10.10.34.227:9092,10.10.34.226:9092 --from-beginning  --topic connect-test
```

![image-20220109170653955](./images/image-20220109170653955.png)



<<<<<<< HEAD
配置kafka connect

```shell
bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";
plugin.path=/data/kafka/plugins,/data/kafka/connectors


[root@kafka-0 kafka]# grep -v "^$"  config/connect-distributed.properties |grep -v "^#"
=======
Kafka Connect

​```shell
[root@kafka-0 ~]# cat /data/kafka/config/connect-distributed.properties |grep -v "^$"|grep -v "^#"
>>>>>>> 2a9a359bf20dd6fa0ab68937b9c98fc5522f3983
bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";
group.id=connect-cluster
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=true
value.converter.schemas.enable=true
offset.storage.topic=connect-offsets
offset.storage.replication.factor=1
config.storage.topic=connect-configs
config.storage.replication.factor=1
status.storage.topic=connect-status
status.storage.replication.factor=1
offset.flush.interval.ms=10000
plugin.path=/data/kafka/plugins,/data/kafka/connectors
<<<<<<< HEAD

[root@kafka-1 bin]# mkdir -p /data/kafka/plugins /data/kafka/connectors

```
=======
listeners=https://10.10.34.224:8443
rest.advertised.listener=https
listeners.https.ssl.client.authentication=requested
listeners.https.ssl.truststore.location=/data/kafka/config/ssl/kafka.server.truststore.jks
listeners.https.ssl.truststore.password=nvkafka123
listeners.https.ssl.keystore.location=/data/kafka/config/ssl/kafka.server.keystore.jks
listeners.https.ssl.keystore.password=nvkafka123
listeners.https.ssl.key.password=nvkafka123
rest.extension.classes=org.apache.kafka.connect.rest.basic.auth.extension.BasicAuthSecurityRestExtension

```



#### HTTP Basic authentication

https://docs.confluent.io/platform/current/security/basic-auth.html

​```shell
[root@kafka-0 ~]# cat /data/kafka/bin/connect-distributed.sh 
#!/bin/bash
... ...

# 添加如下配置
export KAFKA_OPTS="-Djava.security.auth.login.config=/data/kafka/config/kafka_connect_jaas.conf"
exec $(dirname $0)/kafka-run-class.sh $EXTRA_ARGS org.apache.kafka.connect.cli.ConnectDistributed "$@"

[root@kafka-0 ~]# cat /data/kafka/config/kafka_connect_jaas.conf 
KafkaConnect {
    org.apache.kafka.connect.rest.basic.auth.extension.PropertyFileLoginModule required
    file="/data/kafka/config/ssl/connect.password";
};

[root@kafka-0 ~]# cat /data/kafka/config/ssl/connect.password 
admin:admin123

```



## ACL设置验证

```shell
sed -i '/uat-kafka/d' /etc/hosts
cat <<EOF >> /etc/hosts
10.10.34.247 uat-kafka-0 kafka-uat-0.novalocal
10.10.34.248 uat-kafka-1 kafka-uat-1.novalocal
10.10.34.249 uat-kafka-2 kafka-uat-2.novalocal
EOF
cat /etc/hosts

cat <<'EOF' > /data/kafka/config/server-acl.properties
broker.id=3
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
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=10.10.34.247:2181,10.10.34.248:2181,10.10.34.249:2181
zookeeper.connection.timeout.ms=18000
group.initial.rebalance.delay.ms=0

listeners=SASL_PLAINTEXT://:9092
advertised.listeners=SASL_PLAINTEXT://:9092
sasl.enabled.mechanisms=SCRAM-SHA-512
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
security.inter.broker.protocol=SASL_PLAINTEXT
#authorizer.class.name=kafka.security.auth.SimpleAclAuthorizer
authorizer.class.name=kafka.security.authorizer.AclAuthorizer
allow.everyone.if.no.acl.found=false
super.users=User:admin;User:nvadmin
delete.topic.enable=true
EOF

cat <<EOF > /data/kafka/config/kafka_server_jaas.conf 
KafkaServer {
   org.apache.kafka.common.security.scram.ScramLoginModule required
   username="admin"
   password="admin123";
};
EOF

/data/kafka/bin/kafka-server-start.sh /data/kafka/config/server-acl.properties


测试OK
#  kcat -b 10.10.34.247:9092 \
 -X security.protocol=SASL_PLAINTEXT \
 -X sasl.mechanisms=SCRAM-SHA-512 \
 -X sasl.username=admin \
 -X sasl.password=admin123 \
 -L -m 30
```

## SSL 设置验证

### 通过OpenSSL签发证书

```shell
[root@ansible CAROOT]# cat create_self-signed-cert.sh 
#!/bin/bash -e

help ()
{
    echo  ' ================================================================ '
    echo  ' --ssl-domain: 生成ssl证书需要的主域名，如不指定则默认为www.rancher.local，如果是ip访问服务，则可忽略；'
    echo  ' --ssl-trusted-ip: 一般ssl证书只信任域名的访问请求，有时候需要使用ip去访问server，那么需要给ssl证书添加扩展IP，多个IP用逗号隔开；'
    echo  ' --ssl-trusted-domain: 如果想多个域名访问，则添加扩展域名（SSL_TRUSTED_DOMAIN）,多个扩展域名用逗号隔开；'
    echo  ' --ssl-size: ssl加密位数，默认2048；'
    echo  ' --ssl-cn: 国家代码(2个字母的代号),默认CN;'
    echo  ' 使用示例:'
    echo  ' ./create_self-signed-cert.sh --ssl-domain=www.test.com --ssl-trusted-domain=www.test2.com \ '
    echo  ' --ssl-trusted-ip=1.1.1.1,2.2.2.2,3.3.3.3 --ssl-size=2048 --ssl-date=3650'
    echo  ' ================================================================'
}

case "$1" in
    -h|--help) help; exit;;
esac

if [[ $1 == '' ]];then
    help;
    exit;
fi

CMDOPTS="$*"
for OPTS in $CMDOPTS;
do
    key=$(echo ${OPTS} | awk -F"=" '{print $1}' )
    value=$(echo ${OPTS} | awk -F"=" '{print $2}' )
    case "$key" in
        --ssl-domain) SSL_DOMAIN=$value ;;
        --ssl-trusted-ip) SSL_TRUSTED_IP=$value ;;
        --ssl-trusted-domain) SSL_TRUSTED_DOMAIN=$value ;;
        --ssl-size) SSL_SIZE=$value ;;
        --ssl-date) SSL_DATE=$value ;;
        --ca-date) CA_DATE=$value ;;
        --ssl-cn) CN=$value ;;
    esac
done

# CA相关配置
CA_DATE=${CA_DATE:-3650}
CA_KEY=${CA_KEY:-cakey.pem}
CA_CERT=${CA_CERT:-cacerts.pem}
CA_DOMAIN="NV ROOT CA"

# ssl相关配置
SSL_CONFIG=${SSL_CONFIG:-$PWD/openssl.cnf}
SSL_DOMAIN=${SSL_DOMAIN:-'www.example.com'}
SSL_DATE=${SSL_DATE:-3650}
SSL_SIZE=${SSL_SIZE:-2048}

## 国家代码(2个字母的代号),默认CN;
CN=${CN:-CN}

SSL_KEY=$SSL_DOMAIN.key
SSL_CSR=$SSL_DOMAIN.csr
SSL_CERT=$SSL_DOMAIN.crt

echo -e "\033[32m ---------------------------- \033[0m"
echo -e "\033[32m       | 生成 SSL Cert |       \033[0m"
echo -e "\033[32m ---------------------------- \033[0m"

if [[ -e ./${CA_KEY} ]]; then
    echo -e "\033[32m ====> 1. 发现已存在CA私钥，备份"${CA_KEY}"为"${CA_KEY}"-bak，然后重新创建 \033[0m"
    #mv ${CA_KEY} "${CA_KEY}"-bak
    #openssl genrsa -out ${CA_KEY} ${SSL_SIZE}
else
    echo -e "\033[32m ====> 1. 生成新的CA私钥 ${CA_KEY} \033[0m"
    openssl genrsa -out ${CA_KEY} ${SSL_SIZE}
fi

if [[ -e ./${CA_CERT} ]]; then
    echo -e "\033[32m ====> 2. 发现已存在CA证书，先备份"${CA_CERT}"为"${CA_CERT}"-bak，然后重新创建 \033[0m"
    #mv ${CA_CERT} "${CA_CERT}"-bak
    #openssl req -x509 -sha256 -new -nodes -key ${CA_KEY} -days ${CA_DATE} -out ${CA_CERT} -subj "/C=${CN}/CN=${CA_DOMAIN}"
else
    echo -e "\033[32m ====> 2. 生成新的CA证书 ${CA_CERT} \033[0m"
    openssl req -x509 -sha256 -new -nodes -key ${CA_KEY} -days ${CA_DATE} -out ${CA_CERT} -subj "/C=${CN}/CN=${CA_DOMAIN}"
fi

echo -e "\033[32m ====> 3. 生成Openssl配置文件 ${SSL_CONFIG} \033[0m"
cat > ${SSL_CONFIG} <<EOM
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
EOM

if [[ -n ${SSL_TRUSTED_IP} || -n ${SSL_TRUSTED_DOMAIN} ]]; then
    cat >> ${SSL_CONFIG} <<EOM
subjectAltName = @alt_names
[alt_names]
EOM
    IFS=","
    dns=(${SSL_TRUSTED_DOMAIN})
    dns+=(${SSL_DOMAIN})
    for i in "${!dns[@]}"; do
      echo DNS.$((i+1)) = ${dns[$i]} >> ${SSL_CONFIG}
    done

    if [[ -n ${SSL_TRUSTED_IP} ]]; then
        ip=(${SSL_TRUSTED_IP})
        for i in "${!ip[@]}"; do
          echo IP.$((i+1)) = ${ip[$i]} >> ${SSL_CONFIG}
        done
    fi
fi

echo -e "\033[32m ====> 4. 生成服务SSL KEY ${SSL_KEY} \033[0m"
openssl genrsa -out ${SSL_KEY} ${SSL_SIZE}

echo -e "\033[32m ====> 5. 生成服务SSL CSR ${SSL_CSR} \033[0m"
openssl req -sha256 -new -key ${SSL_KEY} -out ${SSL_CSR} -subj "/C=${CN}/CN=${SSL_DOMAIN}" -config ${SSL_CONFIG}

echo -e "\033[32m ====> 6. 生成服务SSL CERT ${SSL_CERT} \033[0m"
openssl x509 -sha256 -req -in ${SSL_CSR} -CA ${CA_CERT} \
    -CAkey ${CA_KEY} -CAcreateserial -out ${SSL_CERT} \
    -days ${SSL_DATE} -extensions v3_req \
    -extfile ${SSL_CONFIG}

echo -e "\033[32m ====> 7. 证书制作完成 \033[0m"
echo
echo -e "\033[32m ====> 8. 以YAML格式输出结果 \033[0m"
echo "----------------------------------------------------------"
echo "ca_key: |"
cat $CA_KEY | sed 's/^/  /'
echo
echo "ca_cert: |"
cat $CA_CERT | sed 's/^/  /'
echo
echo "ssl_key: |"
cat $SSL_KEY | sed 's/^/  /'
echo
echo "ssl_csr: |"
cat $SSL_CSR | sed 's/^/  /'
echo
echo "ssl_cert: |"
cat $SSL_CERT | sed 's/^/  /'
echo

echo -e "\033[32m ====> 9. 附加CA证书到Cert文件 \033[0m"
cat ${CA_CERT} >> ${SSL_CERT}
echo "ssl_cert: |"
cat $SSL_CERT | sed 's/^/  /'
echo

echo -e "\033[32m ====> 10. 重命名服务证书 \033[0m"
echo "cp ${SSL_DOMAIN}.key tls.key"
cp ${SSL_DOMAIN}.key tls.key
echo "cp ${SSL_DOMAIN}.crt tls.crt"
cp ${SSL_DOMAIN}.crt tls.crt
```

### 证书转换

将.crt和.key转换为.jks证书

```shell
./create_self-signed-cert.sh --ssl-domain=kafka.example.com \
--ssl-trusted-ip=10.10.34.224,10.10.34.226,10.10.34.227 \
--ssl-size=2048 --ssl-date=3650

mkdir kafka
cp kafka.example.com.crt kafka.example.com.key cacerts.pem cakey.pem kafka/

# 根据server.crt和server.key生成pkcs12证书
openssl pkcs12 -export -in kafka.example.com.crt -inkey kafka.example.com.key \
-out kafkacert.p12 -name kafka -CAfile cacerts.pem

# 将上一步的kafkacert.p12证书转换为jks证书, deststorepass就是将来的storepass
keytool -importkeystore -v -srckeystore kafkacert.p12 -srcstoretype pkcs12 \
-srcstorepass kafka123 -destkeystore kafka.server.keystore.jks -deststoretype jks -deststorepass kafka123

keytool -importkeystore -srckeystore kafka.server.keystore.jks \
-destkeystore kafka.server.keystore.jks -deststoretype pkcs12

 keytool -list -v -keystore kafka.server.keystore.jks
 scp kafka.server.keystore.jks 10.10.34.224:/data/kafka/config/
 scp kafka.server.keystore.jks 10.10.34.226:/data/kafka/config/
 scp kafka.server.keystore.jks 10.10.34.227:/data/kafka/config/
 
 keytool -keystore kafka.server.truststore.jks -alias CARoot -importcert -file cacerts.pem 
 keytool -list -v -keystore kafka.server.truststore.jks
 scp kafka.server.truststore.jks  10.10.34.224:/data/kafka/config/
 scp kafka.server.truststore.jks  10.10.34.226:/data/kafka/config/
 scp kafka.server.truststore.jks  10.10.34.227:/data/kafka/config/
 
 keytool -keystore kafka.client.truststore.jks -alias CARoot -importcert -file cacerts.pem 
 keytool -list -v -keystore kafka.client.truststore.jks

systemctl restart kafka kafka-connect
systemctl status kafka kafka-connect

# cat <<EOF > ./ssl-user-config.properties 
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin123";

ssl.endpoint.identification.algorithm=
ssl.truststore.location=./kafka.client.truststore.jks
ssl.truststore.password=kafka123
EOF

kafka-topics.sh --list --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 \
 --command-config ./ssl-user-config.properties 
 
kafka-topics.sh --create --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 \
 --command-config ./ssl-user-config.properties --replication-factor 1 --partitions 1 --topic test-topic11
 
 
 $ curl -v https://admin:admin123@10.10.34.224:8443 --cacert /data/CAROOT/cacerts.pem 
* About to connect() to 10.10.34.224 port 8443 (#0)
*   Trying 10.10.34.224...
* Connected to 10.10.34.224 (10.10.34.224) port 8443 (#0)
* Initializing NSS with certpath: sql:/etc/pki/nssdb
*   CAfile: /data/CAROOT/cacerts.pem
  CApath: none
* SSL connection using TLS_DHE_RSA_WITH_AES_256_CBC_SHA256
* Server certificate:
* 	subject: CN=kafka.example.com,C=CN
* 	start date: Jan 24 05:21:19 2022 GMT
* 	expire date: Jan 22 05:21:19 2032 GMT
* 	common name: kafka.example.com
* 	issuer: CN=NV ROOT CA,C=CN
* Server auth using Basic with user 'admin'
> GET / HTTP/1.1
> Authorization: Basic YWRtaW46YWRtaW4xMjM=
> User-Agent: curl/7.29.0
> Host: 10.10.34.224:8443
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Mon, 24 Jan 2022 07:31:58 GMT
< Content-Type: application/json
< Content-Length: 91
< Server: Jetty(9.4.39.v20210325)
< 
* Connection #0 to host 10.10.34.224 left intact
{"version":"2.8.0","commit":"ebb1d6e21cc92130","kafka_cluster_id":"Tm99FeZXRnaD_hYx6Aw8Kw"}
```

### 通过keytool签发证书

https://dzone.com/articles/kafka-security-with-sasl-and-acl

```shell
# 创建证书
keytool -keystore kafka.server.keystore.jks -alias localhost -keyalg RSA -validity 3650 -genkey
openssl req -new -x509 -keyout ca-key -out ca-cert -days  3650
keytool -keystore kafka.client.truststore.jks -alias CARoot -importcert -file ca-cert
keytool -keystore kafka.server.truststore.jks -alias CARoot -importcert -file ca-cert
keytool -keystore kafka.server.keystore.jks -alias localhost -certreq -file cert-file
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file -out cert-signed -days 3650 -CAcreateserial -passin pass:kafka123
keytool -keystore kafka.server.keystore.jks -alias CARoot -importcert -file ca-cert
keytool -keystore kafka.server.keystore.jks -alias localhost -importcert -file cert-signed

# 查看证书的内容
keytool -list -v -keystore server.keystore.jks  
```

### 配置kafka

```shell
# 添加本地解析
sed -i '/uat-kafka/d' /etc/hosts
cat <<EOF >> /etc/hosts
10.10.34.247 uat-kafka-0 kafka-uat-0.novalocal
10.10.34.248 uat-kafka-1 kafka-uat-1.novalocal
10.10.34.249 uat-kafka-2 kafka-uat-2.novalocal
EOF
cat /etc/hosts

cat <<'EOF' > /data/kafka/config/server-sasl-ssl.properties
broker.id=1
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
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=10.10.34.247:2181,10.10.34.248:2181,10.10.34.249:2181
zookeeper.connection.timeout.ms=18000
group.initial.rebalance.delay.ms=0

listeners=SASL_SSL://10.10.34.247:9092
advertised.listeners=SASL_SSL://10.10.34.247:9092

security.inter.broker.protocol=SASL_SSL
ssl.endpoint.identification.algorithm=
ssl.client.auth=required
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
sasl.enabled.mechanisms=SCRAM-SHA-512

ssl.truststore.location=/data/kafka/config/kafka.server.truststore.jks 
ssl.truststore.password=kafka123
ssl.keystore.location=/data/kafka/config/kafka.server.keystore.jks
ssl.keystore.password=kafka123
ssl.key.password=kafka123

# ACLs
authorizer.class.name=kafka.security.auth.SimpleAclAuthorizer
super.users=User:admin;User:nvadmin
allow.everyone.if.no.acl.found=false

delete.topic.enable=true
auto.create.topics.enable=false

# zookeeper SASL
zookeeper.set.acl=false

# With SASL & SSL encryption
scram-sha-512.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="admin" \
  password="admin123";
EOF

cat <<EOF > /data/kafka/config/kafka_server_jaas.conf 
KafkaServer {
   org.apache.kafka.common.security.scram.ScramLoginModule required
   username="admin"
   password="admin123";
};
EOF

/data/kafka/bin/kafka-server-start.sh  /data/kafka/config/server-sasl-ssl.properties

# kafka-configs.sh --zookeeper 10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181 \
--alter --add-config 'SCRAM-SHA-256=[password=admin123],SCRAM-SHA-512=[password=admin123]' \
--entity-type users --entity-name admin
```

### 测试创建主题、生产消费

```shell
# cat <<EOF > ./ssl-user-config.properties 
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin123";

ssl.endpoint.identification.algorithm=
ssl.truststore.location=./kafka.client.truststore.jks
ssl.truststore.password=kafka123
EOF

# kafka-topics.sh --create --bootstrap-server 10.10.34.247:9092,10.10.34.248:9092,10.10.34.249:9092 --command-config ./ssl-user-config.properties --replication-factor 1 --partitions 1 --topic test-topic05
Created topic test-topic05.

# kafka-topics.sh --list --bootstrap-server 10.10.34.247:9092,10.10.34.248:9092,10.10.34.249:9092 --command-config ./ssl-user-config.properties 
__consumer_offsets
connect-configs
connect-offsets
connect-status
test-topic05
topic-test01
topic-test03

#生产者
# kafka-console-producer.sh --broker-list 10.10.34.247:9092,10.10.34.248:9092,10.10.34.249:9092 --topic test-topic05 --producer.config ./ssl-user-config.properties 

#消费者
# kafka-console-consumer.sh --bootstrap-server 10.10.34.247:9092,10.10.34.248:9092,10.10.34.249:9092 --topic test-topic05 --consumer.config  ./ssl-user-config.properties 

# 配置kafkacat/kcat客户端测试
[root@ansible kafka]# cat kafka.conf 
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.username=admin
sasl.password=admin123
#metadata.broker.list=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
#enable.ssl.certificate.verification=false
ssl.ca.location=./cacerts.crt
#ssl.certificate.location=
#ssl.key.location=./cacerts.key
#ssl.key.password=

[root@ansible kafka]# kcat -F kafka.conf  -L
% Reading configuration from file kafka.conf
Metadata for all topics (from broker 3: sasl_ssl://10.10.34.227:9092/3):
 3 brokers:
  broker 2 at 10.10.34.226:9092
  broker 3 at 10.10.34.227:9092
  broker 1 at 10.10.34.224:9092 (controller)
 17 topics:
  topic "topic-test09" with 2 partitions:
    partition 0, leader 3, replicas: 3,2,1, isrs: 3,1,2
    partition 1, leader 1, replicas: 1,3,2, isrs: 3,1,2
```

## kafka connect 配置

```shell
[root@uat-kafka-0 kafka-uat]# egrep -v "^#|^$" /data/kafka/config/connect-distributed.properties 
bootstrap.servers=10.10.34.247:9092,10.10.34.248:9092,10.10.34.249:9092
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin123";
ssl.endpoint.identification.algorithm=
ssl.truststore.location=/data/kafka/config/kafka.server.truststore.jks 
ssl.truststore.password=kafka123

group.id=connect-cluster
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=true
value.converter.schemas.enable=true
offset.storage.topic=connect-offsets
offset.storage.replication.factor=1
config.storage.topic=connect-configs
config.storage.replication.factor=1
status.storage.topic=connect-status
status.storage.replication.factor=1
offset.flush.interval.ms=10000

plugin.path=/data/kafka/plugins,/data/kafka/connectors

listeners=https://10.10.34.247:8443
rest.advertised.listener=https
listeners.https.ssl.client.authentication=required
listeners.https.ssl.truststore.location=/data/kafka/config/kafka.server.truststore.jks
listeners.https.ssl.truststore.password=kafka123
listeners.https.ssl.keystore.location=/data/kafka/config/kafka.server.keystore.jks
listeners.https.ssl.keystore.password=kafka123
listeners.https.ssl.key.password=kafka123
rest.extension.classes=org.apache.kafka.connect.rest.basic.auth.extension.BasicAuthSecurityRestExtension

vim  /data/kafka/bin/connect-distributed.sh 
... ...
export KAFKA_OPTS="-Djava.security.auth.login.config=$base_dir/../config/kafka_connect_jaas.conf"

cat <<EOF > /data/kafka/config/kafka_connect_jaas.conf
KafkaConnect {
    org.apache.kafka.connect.rest.basic.auth.extension.PropertyFileLoginModule required
    file="/data/kafka/config/connect.password";
};
EOF

cat <<EOF >/data/kafka/config/connect.password 
admin:admin123
EOF

/data/kafka/bin/connect-distributed.sh /data/kafka/config/connect-distributed.properties

[root@ansible kafka-uat]# curl -k  https://10.10.34.247:8443/
{"version":"2.8.0","commit":"ebb1d6e21cc92130","kafka_cluster_id":"OmbmUAJwTHG3tq1R5TGSIw"}

[root@ansible kafka-uat]# curl -k  https://10.10.34.247:8443/
User cannot access the resource.

[root@ansible kafka-uat]# curl -k  https://admin:admin123@10.10.34.247:8443/
{"version":"2.8.0","commit":"ebb1d6e21cc92130","kafka_cluster_id":"OmbmUAJwTHG3tq1R5TGSIw"}

# curl https://admin:admin123@10.10.34.249:8443/ -k -v
* About to connect() to 10.10.34.249 port 8443 (#0)
*   Trying 10.10.34.249...
* Connected to 10.10.34.249 (10.10.34.249) port 8443 (#0)
* Initializing NSS with certpath: sql:/etc/pki/nssdb
* skipping SSL peer certificate verification
* SSL connection using TLS_DHE_RSA_WITH_AES_256_CBC_SHA256
* Server certificate:
* 	subject: CN=localhost,OU=IT,O=NV,L=SH,ST=SH,C=CN
* 	start date: Jan 22 05:50:12 2022 GMT
* 	expire date: Jan 20 05:50:12 2032 GMT
* 	common name: localhost
* 	issuer: OU=IT,O=NV,L=SH,ST=SH,C=CN
* Server auth using Basic with user 'admin'
> GET / HTTP/1.1
> Authorization: Basic YWRtaW46YWRtaW4xMjM=
> User-Agent: curl/7.29.0
> Host: 10.10.34.249:8443
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Sat, 22 Jan 2022 08:25:24 GMT
< Content-Type: application/json
< Content-Length: 91
< Server: Jetty(9.4.39.v20210325)
< 
* Connection #0 to host 10.10.34.249 left intact
{"version":"2.8.0","commit":"ebb1d6e21cc92130","kafka_cluster_id":"OmbmUAJwTHG3tq1R5TGSIw"}
```

### 配置kafka-connect服务

```shell
[root@kafka-0 ~]# chown -R app:app /data/kafka

[root@kafka-0 ~]# cat <<EOF > /etc/systemd/system/kafka-connect.service 
[Unit]
Description=Apache Kafka Connect
After=network.target kafka.service schema-registry.service

[Service]
Type=forking
User=app
Group=app
Environment=PATH=/usr/local/jdk1.8.0_202/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/root/bin
Environment="LOG_DIR=/data/kafka/logs"
ExecStart=/data/kafka/bin/connect-distributed.sh -daemon /data/kafka/config/connect-distributed.properties

# 只要不是通过systemctl stop来停止服务，任何情况下都必须要重启服务，默认值为no
Restart=always
# 重启间隔，比如某次异常后，等待5(s)再进行启动，默认值0.1(s)
RestartSec=10
# StartLimitInterval: 无限次重启，默认是10秒内如果重启超过5次则不再重启，设置为0表示不限次数重启
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart  kafka-connect
systemctl enable  kafka-connect
systemctl status kafka-connect
```





=======
# kafka安装配置

## 配置kafka

```
[root@kafka-0 config]# cat server.properties
broker.id=1
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
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181
zookeeper.connection.timeout.ms=18000
group.initial.rebalance.delay.ms=0
listeners=PLAINTEXT://10.10.34.224:9092
advertised.listeners=PLAINTEXT://10.10.34.224:9092
```
## 配置zk和kafka服务

先启动zk后启动kafka


```
[root@kafka-uat-0 ~]# cat /etc/systemd/system/zookeeper.service
[Unit]
Description=zookeeper.service
After=network.target

[Service]
Type=forking
User=app
Group=app
# 第一行设置日志目录，如果没有设置，默认是当前目录，对有的用户来说，可能没有权限。
Environment=ZOO_LOG_DIR=/data/zookeeper/logs
# 第二行是配置环境变量，systemd用户实例不会继承类似.bashrc中定义的环境变量，所以是找不到jdk目录的，而zookeeper又必须有。
Environment=PATH=/data/jdk1.8.0_202/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/root/bin
ExecStart=/data/zookeeper/bin/zkServer.sh start
ExecStop=/data/zookeeper/bin/zkServer.sh stop
ExecReload=/data/zookeeper/bin/zkServer.sh restart
PIDFile=/data/zookeeper/data/zookeeper_server.pid
# 只要不是通过systemctl stop来停止服务，任何情况下都必须要重启服务，默认值为no
Restart=always
# 重启间隔，比如某次异常后，等待5(s)再进行启动，默认值0.1(s)
RestartSec=10
# StartLimitInterval: 无限次重启，默认是10秒内如果重启超过5次则不再重启，设置为0表示不限次数重启
StartLimitInterval=0
[Install]
WantedBy=multi-user.target
```

```
[root@kafka-uat-0 ~]# cat /etc/systemd/system/kafka.service
[Unit]
Description=Apache Kafka server (broker)
After=network.target zookeeper.service

[Service]
Type=forking
User=app
Group=app
Environment=PATH=/data/jdk1.8.0_202/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/root/bin
ExecStart=/data/kafka/bin/kafka-server-start.sh -daemon /data/kafka/config/server.properties
ExecStop=/data/kafka/bin/kafka-server-stop.sh /data/kafka/config/server.properties
# 只要不是通过systemctl stop来停止服务，任何情况下都必须要重启服务，默认值为no
Restart=always
# 重启间隔，比如某次异常后，等待5(s)再进行启动，默认值0.1(s)
RestartSec=10
# StartLimitInterval: 无限次重启，默认是10秒内如果重启超过5次则不再重启，设置为0表示不限次数重启
StartLimitInterval=0
LimitNOFILE=265535

[Install]
WantedBy=multi-user.target
```

## ZK管理

```shell
[root@kafka-0 ~]# cd /data/zookeeper/bin/
[root@kafka-0 bin]# ./zkCli.sh 
Connecting to localhost:2181
... ...
[zk: localhost:2181(CONNECTED) 0] ls /
[admin, brokers, cluster, config, consumers, controller, controller_epoch, feature, isr_change_notification, latest_producer_id_block, log_dir_event_notification, zookeeper]
[zk: localhost:2181(CONNECTED) 1] ls /brokers 
[ids, seqid, topics]
[zk: localhost:2181(CONNECTED) 2] ls /brokers/ids
[1, 2, 3]
[zk: localhost:2181(CONNECTED) 3] ls /brokers/topics
[__consumer_offsets, topic-test01, topic-test02]
```

<img src="./images/image-20220108233927619.png" style="zoom:80%;" />

## 创建主题

创建主题的时候有两种方式一个是使用--zookeeper和--bootstrap-server，前者不需要认证因为它不连接broker，但是后者需要。

`注意：Kafka 从 2.2 版本开始将 kafka-topic.sh 脚本中的 −−zookeeper 参数标注为 “过时”，推荐使用 −−bootstrap-server 参数。若读者依旧使用的是 2.1 及以下版本，请将下述的 --bootstrap-server 参数及其值手动替换为 --zookeeper zk:2181。一定要注意两者参数值所指向的集群地址是不同的。`

```shell
# kafka-topics.sh --create --zookeeper 10.10.34.224:2181 --replication-factor 3  --partitions 2 --topic topic-test01

# 如果主题不存在就创建
# kafka-topics.sh --create --zookeeper 10.10.34.224:2181 --replication-factor 3  --partitions 2 --topic topic-test01 --if-not-exists 

或者：
# kafka-topics.sh --create --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 --replication-factor 3  --partitions 2 --topic topic-test03
Created topic topic-test03.
```

## 修改主题

`修改副本数，只能增加不能减少`

```shell
# kafka-topics.sh --alter --zookeeper 10.10.34.224:2181  --partitions 3 --topic topic-test01
```

## 删除主题

```shell
# 如果主题存在就删除
# kafka-topics.sh --delete --zookeeper 10.10.34.224:2181  --topic topic-test03 --if-exists
# kafka-topics.sh --delete --zookeeper 10.10.34.224:2181  --topic topic-test02
```

## 查看主题

```shell
# kafka-topics.sh --list --zookeeper 10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181  
__consumer_offsets
topic-test01
topic-test02

# kafka-topics.sh --describe --zookeeper 10.10.34.224:2181 --topic topic-test01
Topic: topic-test01	TopicId: 6x2exh8JQDiglSfBNYPsUA	PartitionCount: 2	ReplicationFactor: 3	Configs: 
	Topic: topic-test01	Partition: 0	Leader: 3	Replicas: 3,1,2	Isr: 3,1,2
	Topic: topic-test01	Partition: 1	Leader: 1	Replicas: 1,2,3	Isr: 1,2,3
```

PartitionCount：显示分区数量一共有多少

ReplicationFactor：副本数量

Partition：分区编号

Leader：该分区的Leader副本在哪个broker上，这里显示的是broker的ID

Replicas：显示该partitions所有副本存储在哪些节点上 broker.id 这个是配置文件中设置的，它包括leader和follower节点

Isr：显示副本都已经同步的节点集合，这个集合的所有节点都是存活的，并且跟Leader节点同步

<img src="./images/image-20220108233927609.png" alt="image-20220108233927609" style="zoom:80%;" />

## 生产者：

```shell
# kafka-console-producer.sh --broker-list 10.10.34.224:9092,10.10.34.227:9092,10.10.34.226:9092 --topic topic-test01
```

## 消费者：

```shell
# kafka-console-consumer.sh --bootstrap-server 10.10.34.224:9092,10.10.34.227:9092,10.10.34.226:9092 --group testGroup1 --topic topic-test01
# 从最后一个offset（偏移量）+1 开始消费

# kafka-console-consumer.sh --bootstrap-server 10.10.34.224:9092,10.10.34.227:9092,10.10.34.226:9092 --group testGroup1 --from-beginning --topic topic-test01
# --from-beginning 表示从头消费

# kafka-console-consumer.sh --bootstrap-server 10.10.34.224:9092,10.10.34.227:9092,10.10.34.226:9092 --group testGroup2 --topic topic-test01
 
# kafka-console-consumer.sh --bootstrap-server 10.10.34.224:9092,10.10.34.227:9092,10.10.34.226:9092 --group testGroup3 --topic topic-test01

```

<img src="./images/image-20220108233909085.png" alt="image-20220108233909085" style="zoom:80%;" />



## ACL权限配置

### 配置kafka

```shell
[root@kafka-0 config]# cat server.properties
broker.id=1
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
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181
zookeeper.connection.timeout.ms=18000
group.initial.rebalance.delay.ms=0

listeners=SASL_PLAINTEXT://10.10.34.224:9092,PLAINTEXT://10.10.34.224:9093
advertised.listeners=SASL_PLAINTEXT://10.10.34.224:9092,PLAINTEXT://10.10.34.224:9093
sasl.enabled.mechanisms=SCRAM-SHA-512
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
security.inter.broker.protocol=SASL_PLAINTEXT
#authorizer.class.name=kafka.security.auth.SimpleAclAuthorizer
authorizer.class.name=kafka.security.authorizer.AclAuthorizer
allow.everyone.if.no.acl.found=false
super.users=User:admin;User:nvadmin
delete.topic.enable=true
```

说明：官网这里设置的security.inter.broker.protocol这个参数是SASL_SSL，
包括listeners也是SASL_SSL，需要说明一下如果你启用了SSL加密通信的话你就设置，如果你没有启用那么就设置SASL_PLAINTEXT就好。

### 修改Broker启动脚本

修改kafka_server_jaas.conf文件

```
[root@kafka-0 config]#  cat <<EOF > /data/kafka/config/kafka_server_jaas.conf 
KafkaServer {
   org.apache.kafka.common.security.scram.ScramLoginModule required
   username="admin"
   password="admin123";
};
EOF
```

如果使用外部kafka_server_jaas.conf文件方式，则需要修改启动脚本，把下面的环境变量添加到kafka-server-start.sh脚本中。

```shell
[root@kafka-0 config]# cat /data/kafka/bin/kafka-server-start.sh 
#!/bin/bash

if [ $# -lt 1 ];
then
	echo "USAGE: $0 [-daemon] server.properties [--override property=value]*"
	exit 1
fi
base_dir=$(dirname $0)

if [ "x$KAFKA_LOG4J_OPTS" = "x" ]; then
    export KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:$base_dir/../config/log4j.properties"
fi

if [ "x$KAFKA_HEAP_OPTS" = "x" ]; then
    export KAFKA_HEAP_OPTS="-Xmx4G -Xms4G"  # 修改为4G
fi

EXTRA_ARGS=${EXTRA_ARGS-'-name kafkaServer -loggc'}

COMMAND=$1
case $COMMAND in
  -daemon)
    EXTRA_ARGS="-daemon "$EXTRA_ARGS
    shift
    ;;
  *)
    ;;
esac

添加如下KAFKA_OPTS配置
export JMX_PORT="9999" 
export KAFKA_OPTS="-Djava.security.auth.login.config=$base_dir/../config/kafka_server_jaas.conf"
exec $base_dir/kafka-run-class.sh $EXTRA_ARGS kafka.Kafka "$@"


或者：
##添加-Djava.security.auth.login.config=$base_dir/../config/kafka_server_jaas.conf配置
##exec $base_dir/kafka-run-class.sh $EXTRA_ARGS -Djava.security.auth.login.config=$base_dir/../config/kafka_server_jaas.conf kafka.Kafka "$@"
```

### 重启kafka服务

```shell
[root@kafka-0 config]# systemctl restart kafka
[root@kafka-0 config]# netstat -anltp|grep java|grep LISTEN
tcp6       0      0 :::9999                 :::*                    LISTEN      13322/java          
tcp6       0      0 10.10.34.224:3888      :::*                    LISTEN      17016/java          
tcp6       0      0 :::8080                 :::*                    LISTEN      17016/java          
tcp6       0      0 :::42037                :::*                    LISTEN      17016/java          
tcp6       0      0 :::35352                :::*                    LISTEN      13322/java          
tcp6       0      0 10.10.34.224:9092      :::*                    LISTEN      13322/java          
tcp6       0      0 10.10.34.224:9093      :::*                    LISTEN      13322/java          
tcp6       0      0 :::40005                :::*                    LISTEN      13322/java          
tcp6       0      0 :::2181                 :::*                    LISTEN      17016/java
```

### 创建admin用户

```shell
# kafka-configs.sh --zookeeper 10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181 \
--alter --add-config 'SCRAM-SHA-256=[password=admin123],SCRAM-SHA-512=[password=admin123]' \
--entity-type users --entity-name admin

# kafka-configs.sh --zookeeper 10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181 \
--alter --add-config 'SCRAM-SHA-256=[password=nvadmin123],SCRAM-SHA-512=[password=nvadmin123]' \
--entity-type users --entity-name nvadmin
```

ACL权限控制：参考《kafka设置ACL权限验证》文档

## 配置客户端认证

`broker配置了认证，那么这个客户端工具连接broker需要携带认证信息，这里配置的就是客户端使用的用户名和密码`

### 创建文件kafka_client_jaas.conf

```shell
# cat <<'EOF' >  /data/kafka_2.13-2.8.0/config/kafka_client_jaas.conf
KafkaClient {
  org.apache.kafka.common.security.scram.ScramLoginModule required
  username="admin"
  password="admin123";
};
EOF
```

### 创建文件admin-client-configs.conf

`这里的设置要和broker配置的认证方式一致(server.properties)`

```shell
# cat << 'EOF' >  /data/kafka_2.13-2.8.0/config/admin_client-configs.conf
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";
EOF
```

### 修改kafka-topics.sh脚本

添加如下内容：
export KAFKA_OPTS="-Djava.security.auth.login.config=/data/kafka_2.13-2.8.0/config/kafka_client_jaas.conf

```shell
[root@ansible ~]# cd /data/kafka_2.13-2.8.0/bin/
[root@ansible bin]# cp kafka-topics.sh kafka-topics-admin.sh 
[root@ansible bin]# vim kafka-topics-admin.sh
#!/bin/bash
# ... ...
# 添加如下行
# export KAFKA_OPTS="-Djava.security.auth.login.config=/data/kafka_2.13-2.8.0/config/kafka_client_jaas.conf"

exec $(dirname $0)/kafka-run-class.sh -Djava.security.auth.login.config=/data/kafka_2.13-2.8.0/config/kafka_client_jaas.conf kafka.admin.TopicCommand "$@"
```

### 命令行工具测试创建主题：

```shell
# kafka-topics-admin.sh --create --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 --replication-factor 3  --partitions 2 --topic topic-test03 --command-config ../config/admin_client-configs.conf 
Created topic topic-test03.

# 查看主题
# kafka-topics-admin.sh --list --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 --command-config /data/kafka_2.13-2.8.0/config/admin_client-configs.conf 
__consumer_offsets
connect-configs
connect-offsets
connect-status
topic-test01
topic-test03
```

或者：

```shell
[root@ansible bin]# cat /data/kafka_2.13-2.8.0/config/topic-configs.conf 
#bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";

[root@ansible bin]# kafka-topics.sh --list --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 --command-config /data/kafka_2.13-2.8.0/config/topic-configs.conf 
__consumer_offsets
topic-test01
topic-test02
topic-test03
```

### 命令行工具测试生产和消费

#### 修改consumer.properties配置文件

```shell
# vim /data/kafka_2.13-2.8.0/config/consumer.properties 
# ... ...
bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";
```

#### 修改producer.properties配置文件

```shell
# vim /data/kafka_2.13-2.8.0/config/producer.properties 
bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";
```

#### 通过生产和消费者命令进行测试

生产者

```shell
# kafka-console-producer.sh --broker-list 10.10.34.227:9092,10.10.34.226:9092,10.10.34.224:9092 --topic topic-test03 --producer.config /data/kafka_2.13-2.8.0/config/producer.properties 
```

消费者

```shell
# kafka-console-consumer.sh --bootstrap-server 10.10.34.227:9092,10.10.34.226:9092,10.10.34.224:9092 --topic topic-test03 --consumer.config /data/kafka_2.13-2.8.0/config/consumer.properties 
```

<img src="./images/image-20220108233927622.png" style="zoom:80%;" />

### kafkacat/kcat 工具测试：

查看主题：

```shell
# kcat -b 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092  -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-512 -X sasl.username=admin -X sasl.password=admin123 -L
```

生产者：

```shell
[root@ansible ~]# echo AAAAA | kcat -b 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092  -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-512 -X sasl.username=admin -X sasl.password=admin123 -t topic-test01 -P
```

消费者：

```shell
[root@ansible ~]# kcat -b 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092  -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-512 -X sasl.username=admin -X sasl.password=admin123 -t topic-test01 -C
```

亦可写成：
用-F kafka.conf 指定配置文件，默认配置$HOME/.config/kafkacat.conf 

```shell
[root@ansible ~]# cat << EOF > cat kafka.conf 
security.protocol=SASL_PLAINTEXT
sasl.mechanisms=SCRAM-SHA-512
sasl.username=admin
sasl.password=admin123
EOF

# kcat -b 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092  -L -F kafka.conf 

# echo A=a | kafkacat -b 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 -F kafka.conf -t topic-test01 -P

# kcat -b 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 -F kafka.conf -t topic-test01 -C
```

## Kafka Connect

Kafka Connect运用用户快速定义并实现各种Connector(File,Jdbc,Hdfs等)，这些功能让大批量数据导入/导出Kafka很方便。

<img src="./images/image-20220108233927623.png" style="zoom:90%;" />

如图中所示，左侧的Sources负责从其他异构系统中读取数据并导入到Kafka中；右侧的Sinks是把Kafka中的数据写入到其他的系统中。

### 各种Kafka Connector

　　Kafka Connector很多，包括开源和商业版本的。如下列表中是常用的开源Connector

| Connectors       | References                                                   |
| ---------------- | ------------------------------------------------------------ |
| Jdbc             | [Source](https://github.com/apache/ignite/tree/master/modules/kafka), [Sink](https://github.com/apache/ignite/tree/master/modules/kafka) |
| Elastic Search   | [Sink1](https://github.com/ksenji/kafka-connect-es), [Sink2](https://github.com/hannesstockner/kafka-connect-elasticsearch), [Sink3](https://github.com/DataReply/kafka-connect-elastic-search-sink) |
| Cassandra        | [Source1](https://github.com/tuplejump/kafka-connect-cassandra), [Source 2](https://github.com/datamountaineer/stream-reactor/tree/master/kafka-connect-cassandra), [Sink1](https://github.com/tuplejump/kafka-connect-cassandra), [Sink2 ](https://github.com/datamountaineer/stream-reactor/tree/master/kafka-connect-cassandra) |
| MongoDB          | [Source](https://github.com/DataReply/kafka-connect-mongodb) |
| HBase            | [Sink](https://github.com/mravi/kafka-connect-hbase)         |
| Syslog           | [Source](https://github.com/jcustenborder/kafka-connect-syslog) |
| MQTT (Source)    | [Source](https://github.com/evokly/kafka-connect-mqtt)       |
| Twitter (Source) | [Source](https://github.com/rollulus/twitter-kafka-connect), [Sink](https://github.com/Eneco/kafka-connect-twitter) |
| S3               | [Sink1](https://github.com/qubole/streamx), [Sink2](https://github.com/DeviantArt/kafka-connect-s3) |

### 示例

FileConnector Demo

　本例演示如何使用Kafka Connect把Source(test.txt)转为流数据再写入到Destination(test.sink.txt)中。如下图所示：

<img src="./images/image-20220108233927624.png" alt="image-20220108233927624" style="zoom:80%;" />



本例使用到了两个Connector:

- FileStreamSource：从test.txt中读取并发布到Broker中
- FileStreamSink：从Broker中读取数据并写入到test.sink.txt文件中

　　其中的Source使用到的配置文件是${KAFKA_HOME}/config/connect-file-source.properties

```shell
# Broker使用到的配置文件是${KAFKA_HOME}/config/connect-standalone.properties
[root@ansible kafka_2.13-2.8.0]# cat config/connect-standalone.properties |egrep -v "^#"|grep -v "^$"
bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=true
value.converter.schemas.enable=true
offset.storage.file.filename=/tmp/connect.offsets
offset.flush.interval.ms=10000

# 其中的Source使用到的配置文件是${KAFKA_HOME}/config/connect-file-source.properties
[root@ansible kafka_2.13-2.8.0]# cat config/connect-console-source.properties |egrep -v "^#"|grep -v "^$"
name=local-console-source
connector.class=org.apache.kafka.connect.file.FileStreamSourceConnector
tasks.max=1
topic=connect-test
 
# 其中的Sink使用到的配置文件是${KAFKA_HOME}/config/connect-file-sink.properties
[root@ansible kafka_2.13-2.8.0]# cat config/connect-console-sink.properties | egrep -v "^#"|grep -v "^$"
name=local-console-sink
connector.class=org.apache.kafka.connect.file.FileStreamSinkConnector
tasks.max=1
topics=connect-test
```

#### 启动Source Connector和Sink Connector

```shell
[root@ansible kafka_2.13-2.8.0]# ./bin/connect-standalone.sh config/connect-standalone.properties config/connect-file-source.properties config/connect-file-sink.properties 

# 打开console-consumer
[root@ansible kafka_2.13-2.8.0]# kafka-console-consumer.sh --bootstrap-server 10.10.34.224:9092,10.10.34.227:9092,10.10.34.226:9092 --from-beginning  --topic connect-test
```

![image-20220109170653955](./images/image-20220109170653955.png)



<<<<<<< HEAD
配置kafka connect

```shell
bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";
plugin.path=/data/kafka/plugins,/data/kafka/connectors


[root@kafka-0 kafka]# grep -v "^$"  config/connect-distributed.properties |grep -v "^#"
=======
Kafka Connect

​```shell
[root@kafka-0 ~]# cat /data/kafka/config/connect-distributed.properties |grep -v "^$"|grep -v "^#"
>>>>>>> 2a9a359bf20dd6fa0ab68937b9c98fc5522f3983
bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";
group.id=connect-cluster
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=true
value.converter.schemas.enable=true
offset.storage.topic=connect-offsets
offset.storage.replication.factor=1
config.storage.topic=connect-configs
config.storage.replication.factor=1
status.storage.topic=connect-status
status.storage.replication.factor=1
offset.flush.interval.ms=10000
plugin.path=/data/kafka/plugins,/data/kafka/connectors
<<<<<<< HEAD

[root@kafka-1 bin]# mkdir -p /data/kafka/plugins /data/kafka/connectors

```
=======
listeners=https://10.10.34.224:8443
rest.advertised.listener=https
listeners.https.ssl.client.authentication=requested
listeners.https.ssl.truststore.location=/data/kafka/config/ssl/kafka.server.truststore.jks
listeners.https.ssl.truststore.password=nvkafka123
listeners.https.ssl.keystore.location=/data/kafka/config/ssl/kafka.server.keystore.jks
listeners.https.ssl.keystore.password=nvkafka123
listeners.https.ssl.key.password=nvkafka123
rest.extension.classes=org.apache.kafka.connect.rest.basic.auth.extension.BasicAuthSecurityRestExtension

```



#### HTTP Basic authentication

https://docs.confluent.io/platform/current/security/basic-auth.html

​```shell
[root@kafka-0 ~]# cat /data/kafka/bin/connect-distributed.sh 
#!/bin/bash
... ...

# 添加如下配置
export KAFKA_OPTS="-Djava.security.auth.login.config=/data/kafka/config/kafka_connect_jaas.conf"
exec $(dirname $0)/kafka-run-class.sh $EXTRA_ARGS org.apache.kafka.connect.cli.ConnectDistributed "$@"

[root@kafka-0 ~]# cat /data/kafka/config/kafka_connect_jaas.conf 
KafkaConnect {
    org.apache.kafka.connect.rest.basic.auth.extension.PropertyFileLoginModule required
    file="/data/kafka/config/ssl/connect.password";
};

[root@kafka-0 ~]# cat /data/kafka/config/ssl/connect.password 
admin:admin123

```



## ACL设置验证

```shell
sed -i '/uat-kafka/d' /etc/hosts
cat <<EOF >> /etc/hosts
10.10.34.247 uat-kafka-0 kafka-uat-0.novalocal
10.10.34.248 uat-kafka-1 kafka-uat-1.novalocal
10.10.34.249 uat-kafka-2 kafka-uat-2.novalocal
EOF
cat /etc/hosts

cat <<'EOF' > /data/kafka/config/server-acl.properties
broker.id=3
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
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=10.10.34.247:2181,10.10.34.248:2181,10.10.34.249:2181
zookeeper.connection.timeout.ms=18000
group.initial.rebalance.delay.ms=0

listeners=SASL_PLAINTEXT://:9092
advertised.listeners=SASL_PLAINTEXT://:9092
sasl.enabled.mechanisms=SCRAM-SHA-512
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
security.inter.broker.protocol=SASL_PLAINTEXT
#authorizer.class.name=kafka.security.auth.SimpleAclAuthorizer
authorizer.class.name=kafka.security.authorizer.AclAuthorizer
allow.everyone.if.no.acl.found=false
super.users=User:admin;User:nvadmin
delete.topic.enable=true
EOF

cat <<EOF > /data/kafka/config/kafka_server_jaas.conf 
KafkaServer {
   org.apache.kafka.common.security.scram.ScramLoginModule required
   username="admin"
   password="admin123";
};
EOF

/data/kafka/bin/kafka-server-start.sh /data/kafka/config/server-acl.properties


测试OK
#  kcat -b 10.10.34.247:9092 \
 -X security.protocol=SASL_PLAINTEXT \
 -X sasl.mechanisms=SCRAM-SHA-512 \
 -X sasl.username=admin \
 -X sasl.password=admin123 \
 -L -m 30
```

## SSL 设置验证

### 通过OpenSSL签发证书

```shell
[root@ansible CAROOT]# cat create_self-signed-cert.sh 
#!/bin/bash -e

help ()
{
    echo  ' ================================================================ '
    echo  ' --ssl-domain: 生成ssl证书需要的主域名，如不指定则默认为www.rancher.local，如果是ip访问服务，则可忽略；'
    echo  ' --ssl-trusted-ip: 一般ssl证书只信任域名的访问请求，有时候需要使用ip去访问server，那么需要给ssl证书添加扩展IP，多个IP用逗号隔开；'
    echo  ' --ssl-trusted-domain: 如果想多个域名访问，则添加扩展域名（SSL_TRUSTED_DOMAIN）,多个扩展域名用逗号隔开；'
    echo  ' --ssl-size: ssl加密位数，默认2048；'
    echo  ' --ssl-cn: 国家代码(2个字母的代号),默认CN;'
    echo  ' 使用示例:'
    echo  ' ./create_self-signed-cert.sh --ssl-domain=www.test.com --ssl-trusted-domain=www.test2.com \ '
    echo  ' --ssl-trusted-ip=1.1.1.1,2.2.2.2,3.3.3.3 --ssl-size=2048 --ssl-date=3650'
    echo  ' ================================================================'
}

case "$1" in
    -h|--help) help; exit;;
esac

if [[ $1 == '' ]];then
    help;
    exit;
fi

CMDOPTS="$*"
for OPTS in $CMDOPTS;
do
    key=$(echo ${OPTS} | awk -F"=" '{print $1}' )
    value=$(echo ${OPTS} | awk -F"=" '{print $2}' )
    case "$key" in
        --ssl-domain) SSL_DOMAIN=$value ;;
        --ssl-trusted-ip) SSL_TRUSTED_IP=$value ;;
        --ssl-trusted-domain) SSL_TRUSTED_DOMAIN=$value ;;
        --ssl-size) SSL_SIZE=$value ;;
        --ssl-date) SSL_DATE=$value ;;
        --ca-date) CA_DATE=$value ;;
        --ssl-cn) CN=$value ;;
    esac
done

# CA相关配置
CA_DATE=${CA_DATE:-3650}
CA_KEY=${CA_KEY:-cakey.pem}
CA_CERT=${CA_CERT:-cacerts.pem}
CA_DOMAIN="NV ROOT CA"

# ssl相关配置
SSL_CONFIG=${SSL_CONFIG:-$PWD/openssl.cnf}
SSL_DOMAIN=${SSL_DOMAIN:-'www.example.com'}
SSL_DATE=${SSL_DATE:-3650}
SSL_SIZE=${SSL_SIZE:-2048}

## 国家代码(2个字母的代号),默认CN;
CN=${CN:-CN}

SSL_KEY=$SSL_DOMAIN.key
SSL_CSR=$SSL_DOMAIN.csr
SSL_CERT=$SSL_DOMAIN.crt

echo -e "\033[32m ---------------------------- \033[0m"
echo -e "\033[32m       | 生成 SSL Cert |       \033[0m"
echo -e "\033[32m ---------------------------- \033[0m"

if [[ -e ./${CA_KEY} ]]; then
    echo -e "\033[32m ====> 1. 发现已存在CA私钥，备份"${CA_KEY}"为"${CA_KEY}"-bak，然后重新创建 \033[0m"
    #mv ${CA_KEY} "${CA_KEY}"-bak
    #openssl genrsa -out ${CA_KEY} ${SSL_SIZE}
else
    echo -e "\033[32m ====> 1. 生成新的CA私钥 ${CA_KEY} \033[0m"
    openssl genrsa -out ${CA_KEY} ${SSL_SIZE}
fi

if [[ -e ./${CA_CERT} ]]; then
    echo -e "\033[32m ====> 2. 发现已存在CA证书，先备份"${CA_CERT}"为"${CA_CERT}"-bak，然后重新创建 \033[0m"
    #mv ${CA_CERT} "${CA_CERT}"-bak
    #openssl req -x509 -sha256 -new -nodes -key ${CA_KEY} -days ${CA_DATE} -out ${CA_CERT} -subj "/C=${CN}/CN=${CA_DOMAIN}"
else
    echo -e "\033[32m ====> 2. 生成新的CA证书 ${CA_CERT} \033[0m"
    openssl req -x509 -sha256 -new -nodes -key ${CA_KEY} -days ${CA_DATE} -out ${CA_CERT} -subj "/C=${CN}/CN=${CA_DOMAIN}"
fi

echo -e "\033[32m ====> 3. 生成Openssl配置文件 ${SSL_CONFIG} \033[0m"
cat > ${SSL_CONFIG} <<EOM
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
EOM

if [[ -n ${SSL_TRUSTED_IP} || -n ${SSL_TRUSTED_DOMAIN} ]]; then
    cat >> ${SSL_CONFIG} <<EOM
subjectAltName = @alt_names
[alt_names]
EOM
    IFS=","
    dns=(${SSL_TRUSTED_DOMAIN})
    dns+=(${SSL_DOMAIN})
    for i in "${!dns[@]}"; do
      echo DNS.$((i+1)) = ${dns[$i]} >> ${SSL_CONFIG}
    done

    if [[ -n ${SSL_TRUSTED_IP} ]]; then
        ip=(${SSL_TRUSTED_IP})
        for i in "${!ip[@]}"; do
          echo IP.$((i+1)) = ${ip[$i]} >> ${SSL_CONFIG}
        done
    fi
fi

echo -e "\033[32m ====> 4. 生成服务SSL KEY ${SSL_KEY} \033[0m"
openssl genrsa -out ${SSL_KEY} ${SSL_SIZE}

echo -e "\033[32m ====> 5. 生成服务SSL CSR ${SSL_CSR} \033[0m"
openssl req -sha256 -new -key ${SSL_KEY} -out ${SSL_CSR} -subj "/C=${CN}/CN=${SSL_DOMAIN}" -config ${SSL_CONFIG}

echo -e "\033[32m ====> 6. 生成服务SSL CERT ${SSL_CERT} \033[0m"
openssl x509 -sha256 -req -in ${SSL_CSR} -CA ${CA_CERT} \
    -CAkey ${CA_KEY} -CAcreateserial -out ${SSL_CERT} \
    -days ${SSL_DATE} -extensions v3_req \
    -extfile ${SSL_CONFIG}

echo -e "\033[32m ====> 7. 证书制作完成 \033[0m"
echo
echo -e "\033[32m ====> 8. 以YAML格式输出结果 \033[0m"
echo "----------------------------------------------------------"
echo "ca_key: |"
cat $CA_KEY | sed 's/^/  /'
echo
echo "ca_cert: |"
cat $CA_CERT | sed 's/^/  /'
echo
echo "ssl_key: |"
cat $SSL_KEY | sed 's/^/  /'
echo
echo "ssl_csr: |"
cat $SSL_CSR | sed 's/^/  /'
echo
echo "ssl_cert: |"
cat $SSL_CERT | sed 's/^/  /'
echo

echo -e "\033[32m ====> 9. 附加CA证书到Cert文件 \033[0m"
cat ${CA_CERT} >> ${SSL_CERT}
echo "ssl_cert: |"
cat $SSL_CERT | sed 's/^/  /'
echo

echo -e "\033[32m ====> 10. 重命名服务证书 \033[0m"
echo "cp ${SSL_DOMAIN}.key tls.key"
cp ${SSL_DOMAIN}.key tls.key
echo "cp ${SSL_DOMAIN}.crt tls.crt"
cp ${SSL_DOMAIN}.crt tls.crt
```

### 证书转换

将.crt和.key转换为.jks证书

```shell
./create_self-signed-cert.sh --ssl-domain=kafka.example.com \
--ssl-trusted-ip=10.10.34.224,10.10.34.226,10.10.34.227 \
--ssl-size=2048 --ssl-date=3650

mkdir kafka
cp kafka.example.com.crt kafka.example.com.key cacerts.pem cakey.pem kafka/

# 根据server.crt和server.key生成pkcs12证书
openssl pkcs12 -export -in kafka.example.com.crt -inkey kafka.example.com.key \
-out kafkacert.p12 -name kafka -CAfile cacerts.pem

# 将上一步的kafkacert.p12证书转换为jks证书, deststorepass就是将来的storepass
keytool -importkeystore -v -srckeystore kafkacert.p12 -srcstoretype pkcs12 \
-srcstorepass kafka123 -destkeystore kafka.server.keystore.jks -deststoretype jks -deststorepass kafka123

keytool -importkeystore -srckeystore kafka.server.keystore.jks \
-destkeystore kafka.server.keystore.jks -deststoretype pkcs12

 keytool -list -v -keystore kafka.server.keystore.jks
 scp kafka.server.keystore.jks 10.10.34.224:/data/kafka/config/
 scp kafka.server.keystore.jks 10.10.34.226:/data/kafka/config/
 scp kafka.server.keystore.jks 10.10.34.227:/data/kafka/config/
 
 keytool -keystore kafka.server.truststore.jks -alias CARoot -importcert -file cacerts.pem 
 keytool -list -v -keystore kafka.server.truststore.jks
 scp kafka.server.truststore.jks  10.10.34.224:/data/kafka/config/
 scp kafka.server.truststore.jks  10.10.34.226:/data/kafka/config/
 scp kafka.server.truststore.jks  10.10.34.227:/data/kafka/config/
 
 keytool -keystore kafka.client.truststore.jks -alias CARoot -importcert -file cacerts.pem 
 keytool -list -v -keystore kafka.client.truststore.jks

systemctl restart kafka kafka-connect
systemctl status kafka kafka-connect

# cat <<EOF > ./ssl-user-config.properties 
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin123";

ssl.endpoint.identification.algorithm=
ssl.truststore.location=./kafka.client.truststore.jks
ssl.truststore.password=kafka123
EOF

kafka-topics.sh --list --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 \
 --command-config ./ssl-user-config.properties 
 
kafka-topics.sh --create --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 \
 --command-config ./ssl-user-config.properties --replication-factor 1 --partitions 1 --topic test-topic11
 
 
 $ curl -v https://admin:admin123@10.10.34.224:8443 --cacert /data/CAROOT/cacerts.pem 
* About to connect() to 10.10.34.224 port 8443 (#0)
*   Trying 10.10.34.224...
* Connected to 10.10.34.224 (10.10.34.224) port 8443 (#0)
* Initializing NSS with certpath: sql:/etc/pki/nssdb
*   CAfile: /data/CAROOT/cacerts.pem
  CApath: none
* SSL connection using TLS_DHE_RSA_WITH_AES_256_CBC_SHA256
* Server certificate:
* 	subject: CN=kafka.example.com,C=CN
* 	start date: Jan 24 05:21:19 2022 GMT
* 	expire date: Jan 22 05:21:19 2032 GMT
* 	common name: kafka.example.com
* 	issuer: CN=NV ROOT CA,C=CN
* Server auth using Basic with user 'admin'
> GET / HTTP/1.1
> Authorization: Basic YWRtaW46YWRtaW4xMjM=
> User-Agent: curl/7.29.0
> Host: 10.10.34.224:8443
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Mon, 24 Jan 2022 07:31:58 GMT
< Content-Type: application/json
< Content-Length: 91
< Server: Jetty(9.4.39.v20210325)
< 
* Connection #0 to host 10.10.34.224 left intact
{"version":"2.8.0","commit":"ebb1d6e21cc92130","kafka_cluster_id":"Tm99FeZXRnaD_hYx6Aw8Kw"}
```

### 通过keytool签发证书

https://dzone.com/articles/kafka-security-with-sasl-and-acl

```shell
# 创建证书
keytool -keystore kafka.server.keystore.jks -alias localhost -keyalg RSA -validity 3650 -genkey
openssl req -new -x509 -keyout ca-key -out ca-cert -days  3650
keytool -keystore kafka.client.truststore.jks -alias CARoot -importcert -file ca-cert
keytool -keystore kafka.server.truststore.jks -alias CARoot -importcert -file ca-cert
keytool -keystore kafka.server.keystore.jks -alias localhost -certreq -file cert-file
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file -out cert-signed -days 3650 -CAcreateserial -passin pass:kafka123
keytool -keystore kafka.server.keystore.jks -alias CARoot -importcert -file ca-cert
keytool -keystore kafka.server.keystore.jks -alias localhost -importcert -file cert-signed

# 查看证书的内容
keytool -list -v -keystore server.keystore.jks  
```

### 配置kafka

```shell
# 添加本地解析
sed -i '/uat-kafka/d' /etc/hosts
cat <<EOF >> /etc/hosts
10.10.34.247 uat-kafka-0 kafka-uat-0.novalocal
10.10.34.248 uat-kafka-1 kafka-uat-1.novalocal
10.10.34.249 uat-kafka-2 kafka-uat-2.novalocal
EOF
cat /etc/hosts

cat <<'EOF' > /data/kafka/config/server-sasl-ssl.properties
broker.id=1
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
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=10.10.34.247:2181,10.10.34.248:2181,10.10.34.249:2181
zookeeper.connection.timeout.ms=18000
group.initial.rebalance.delay.ms=0

listeners=SASL_SSL://10.10.34.247:9092
advertised.listeners=SASL_SSL://10.10.34.247:9092

security.inter.broker.protocol=SASL_SSL
ssl.endpoint.identification.algorithm=
ssl.client.auth=required
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
sasl.enabled.mechanisms=SCRAM-SHA-512

ssl.truststore.location=/data/kafka/config/kafka.server.truststore.jks 
ssl.truststore.password=kafka123
ssl.keystore.location=/data/kafka/config/kafka.server.keystore.jks
ssl.keystore.password=kafka123
ssl.key.password=kafka123

# ACLs
authorizer.class.name=kafka.security.auth.SimpleAclAuthorizer
super.users=User:admin;User:nvadmin
allow.everyone.if.no.acl.found=false

delete.topic.enable=true
auto.create.topics.enable=false

# zookeeper SASL
zookeeper.set.acl=false

# With SASL & SSL encryption
scram-sha-512.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="admin" \
  password="admin123";
EOF

cat <<EOF > /data/kafka/config/kafka_server_jaas.conf 
KafkaServer {
   org.apache.kafka.common.security.scram.ScramLoginModule required
   username="admin"
   password="admin123";
};
EOF

/data/kafka/bin/kafka-server-start.sh  /data/kafka/config/server-sasl-ssl.properties

# kafka-configs.sh --zookeeper 10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181 \
--alter --add-config 'SCRAM-SHA-256=[password=admin123],SCRAM-SHA-512=[password=admin123]' \
--entity-type users --entity-name admin
```

### 测试创建主题、生产消费

```shell
# cat <<EOF > ./ssl-user-config.properties 
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin123";

ssl.endpoint.identification.algorithm=
ssl.truststore.location=./kafka.client.truststore.jks
ssl.truststore.password=kafka123
EOF

# kafka-topics.sh --create --bootstrap-server 10.10.34.247:9092,10.10.34.248:9092,10.10.34.249:9092 --command-config ./ssl-user-config.properties --replication-factor 1 --partitions 1 --topic test-topic05
Created topic test-topic05.

# kafka-topics.sh --list --bootstrap-server 10.10.34.247:9092,10.10.34.248:9092,10.10.34.249:9092 --command-config ./ssl-user-config.properties 
__consumer_offsets
connect-configs
connect-offsets
connect-status
test-topic05
topic-test01
topic-test03

#生产者
# kafka-console-producer.sh --broker-list 10.10.34.247:9092,10.10.34.248:9092,10.10.34.249:9092 --topic test-topic05 --producer.config ./ssl-user-config.properties 

#消费者
# kafka-console-consumer.sh --bootstrap-server 10.10.34.247:9092,10.10.34.248:9092,10.10.34.249:9092 --topic test-topic05 --consumer.config  ./ssl-user-config.properties 

# 配置kafkacat/kcat客户端测试
[root@ansible kafka]# cat kafka.conf 
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.username=admin
sasl.password=admin123
#metadata.broker.list=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
bootstrap.servers=10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092
#enable.ssl.certificate.verification=false
ssl.ca.location=./cacerts.crt
#ssl.certificate.location=
#ssl.key.location=./cacerts.key
#ssl.key.password=

[root@ansible kafka]# kcat -F kafka.conf  -L
% Reading configuration from file kafka.conf
Metadata for all topics (from broker 3: sasl_ssl://10.10.34.227:9092/3):
 3 brokers:
  broker 2 at 10.10.34.226:9092
  broker 3 at 10.10.34.227:9092
  broker 1 at 10.10.34.224:9092 (controller)
 17 topics:
  topic "topic-test09" with 2 partitions:
    partition 0, leader 3, replicas: 3,2,1, isrs: 3,1,2
    partition 1, leader 1, replicas: 1,3,2, isrs: 3,1,2
```

## kafka connect 配置

```shell
[root@uat-kafka-0 kafka-uat]# egrep -v "^#|^$" /data/kafka/config/connect-distributed.properties 
bootstrap.servers=10.10.34.247:9092,10.10.34.248:9092,10.10.34.249:9092
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin123";
ssl.endpoint.identification.algorithm=
ssl.truststore.location=/data/kafka/config/kafka.server.truststore.jks 
ssl.truststore.password=kafka123

group.id=connect-cluster
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=true
value.converter.schemas.enable=true
offset.storage.topic=connect-offsets
offset.storage.replication.factor=1
config.storage.topic=connect-configs
config.storage.replication.factor=1
status.storage.topic=connect-status
status.storage.replication.factor=1
offset.flush.interval.ms=10000

plugin.path=/data/kafka/plugins,/data/kafka/connectors

listeners=https://10.10.34.247:8443
rest.advertised.listener=https
listeners.https.ssl.client.authentication=required
listeners.https.ssl.truststore.location=/data/kafka/config/kafka.server.truststore.jks
listeners.https.ssl.truststore.password=kafka123
listeners.https.ssl.keystore.location=/data/kafka/config/kafka.server.keystore.jks
listeners.https.ssl.keystore.password=kafka123
listeners.https.ssl.key.password=kafka123
rest.extension.classes=org.apache.kafka.connect.rest.basic.auth.extension.BasicAuthSecurityRestExtension

vim  /data/kafka/bin/connect-distributed.sh 
... ...
export KAFKA_OPTS="-Djava.security.auth.login.config=$base_dir/../config/kafka_connect_jaas.conf"

cat <<EOF > /data/kafka/config/kafka_connect_jaas.conf
KafkaConnect {
    org.apache.kafka.connect.rest.basic.auth.extension.PropertyFileLoginModule required
    file="/data/kafka/config/connect.password";
};
EOF

cat <<EOF >/data/kafka/config/connect.password 
admin:admin123
EOF

/data/kafka/bin/connect-distributed.sh /data/kafka/config/connect-distributed.properties

[root@ansible kafka-uat]# curl -k  https://10.10.34.247:8443/
{"version":"2.8.0","commit":"ebb1d6e21cc92130","kafka_cluster_id":"OmbmUAJwTHG3tq1R5TGSIw"}

[root@ansible kafka-uat]# curl -k  https://10.10.34.247:8443/
User cannot access the resource.

[root@ansible kafka-uat]# curl -k  https://admin:admin123@10.10.34.247:8443/
{"version":"2.8.0","commit":"ebb1d6e21cc92130","kafka_cluster_id":"OmbmUAJwTHG3tq1R5TGSIw"}

# curl https://admin:admin123@10.10.34.249:8443/ -k -v
* About to connect() to 10.10.34.249 port 8443 (#0)
*   Trying 10.10.34.249...
* Connected to 10.10.34.249 (10.10.34.249) port 8443 (#0)
* Initializing NSS with certpath: sql:/etc/pki/nssdb
* skipping SSL peer certificate verification
* SSL connection using TLS_DHE_RSA_WITH_AES_256_CBC_SHA256
* Server certificate:
* 	subject: CN=localhost,OU=IT,O=NV,L=SH,ST=SH,C=CN
* 	start date: Jan 22 05:50:12 2022 GMT
* 	expire date: Jan 20 05:50:12 2032 GMT
* 	common name: localhost
* 	issuer: OU=IT,O=NV,L=SH,ST=SH,C=CN
* Server auth using Basic with user 'admin'
> GET / HTTP/1.1
> Authorization: Basic YWRtaW46YWRtaW4xMjM=
> User-Agent: curl/7.29.0
> Host: 10.10.34.249:8443
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Sat, 22 Jan 2022 08:25:24 GMT
< Content-Type: application/json
< Content-Length: 91
< Server: Jetty(9.4.39.v20210325)
< 
* Connection #0 to host 10.10.34.249 left intact
{"version":"2.8.0","commit":"ebb1d6e21cc92130","kafka_cluster_id":"OmbmUAJwTHG3tq1R5TGSIw"}

curl --cacert cert.pem https://admin:admin123@10.10.34.84:8443/connector-plugins
```

### 配置kafka-connect服务

```shell
[root@kafka-0 ~]# chown -R app:app /data/kafka

[root@kafka-0 ~]# cat <<EOF > /etc/systemd/system/kafka-connect.service 
[Unit]
Description=Apache Kafka Connect
After=network.target kafka.service schema-registry.service

[Service]
Type=forking
User=app
Group=app
Environment=PATH=/usr/local/jdk1.8.0_202/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/root/bin
Environment="LOG_DIR=/data/kafka/logs"
ExecStart=/data/kafka/bin/connect-distributed.sh -daemon /data/kafka/config/connect-distributed.properties

# 只要不是通过systemctl stop来停止服务，任何情况下都必须要重启服务，默认值为no
Restart=always
# 重启间隔，比如某次异常后，等待5(s)再进行启动，默认值0.1(s)
RestartSec=10
# StartLimitInterval: 无限次重启，默认是10秒内如果重启超过5次则不再重启，设置为0表示不限次数重启
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart  kafka-connect
systemctl enable  kafka-connect
systemctl status kafka-connect
```





>>>>>>> 7f3fab57a57b2c1859faccf9ddbbe5f255e97cbb:kafka安装配置.md
