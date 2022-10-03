# kafka添加SASL_SSL认证(集群的话需要每个节点都配置)

kafka集群信息

| ip地址        | kafka端口 | zk端口 |
| ------------- | --------- | ------ |
| 10.10.34.224 | 9092      | 2181   |
| 10.10.34.226 | 9092      | 2181   |
| 10.10.34.227 | 9092      | 2181   |

zk配置文件

```shell
cat >> /data/zookeeper/confzoo.cfg <<EOF
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/data/zookeeper/data
clientPort=2181
server.1=10.10.34.224:2888:3888
server.2=10.10.34.226:2888:3888
server.3=10.10.34.227:2888:3888
EOF
```

启动zk

```shell
cd /data/zookeeper/bin/
./zkServer.sh start
```

```shell
停止zk:cd /data/zookeeper/bin/
./zkServer.sh stop
```

在/data/ssl目录生成ca证书（脚本如下）密码设置成统一的一个（本次设置密码为kafka123）

```shell
[root@kafka-0 ssl]# keytool -keystore server.keystore.jks -alias localhost -validity 3650 -genkey  #生成证书
Enter keystore password:  
Re-enter new password: 
What is your first and last name?
  [Unknown]:  localhost
What is the name of your organizational unit?
  [Unknown]:  nv-kafka
What is the name of your organization?
  [Unknown]:  shanghai
What is the name of your City or Locality?
  [Unknown]:  shanghai
What is the name of your State or Province?
  [Unknown]:  nv
What is the two-letter country code for this unit?
  [Unknown]:  nv
Is CN=localhost, OU=nv-kafka, O=shanghai, L=shanghai, ST=nv, C=nv correct?
  [no]:  yes
keytool -list -v -keystore server.keystore.jks  #来验证生成证书的内容
openssl req -new -x509 -keyout ca-key -out ca-cert -days 3650  #生成CA
将生成的CA添加到**clients' truststore（客户的信任库）**，以便client可以信任这个CA:

keytool -keystore server.truststore.jks -alias CARoot -import -file ca-cert 
keytool -keystore client.truststore.jks -alias CARoot -import -file ca-cert 



keytool -keystore server.keystore.jks -alias localhost -certreq -file cert-file 
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file -out cert-signed -days 3650 -CAcreateserial -passin pass:kafka123
keytool -keystore server.keystore.jks -alias CARoot -import -file ca-cert 
keytool -keystore server.keystore.jks -alias localhost -import -file cert-signed 
```



```shell
#!/bin/bash
#Step 1
keytool -keystore server.keystore.jks -alias localhost -validity 3650 -keyalg RSA -genkey
#Step 2
openssl req -new -x509 -keyout ca-key -out ca-cert -days 3650
keytool -keystore server.truststore.jks -alias CARoot -import -file ca-cert
keytool -keystore client.truststore.jks -alias CARoot -import -file ca-cert
#Step 3
keytool -keystore server.keystore.jks -alias localhost -certreq -file cert-file
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file -out cert-signed -days 3650 -CAcreateserial -passin pass:kafka123
keytool -keystore server.keystore.jks -alias CARoot -import -file ca-cert
keytool -keystore server.keystore.jks -alias localhost -import -file cert-signed
```

```shell
[root@kafka-0 config]# ll /data/ssl/
total 36
-rw-r--r-- 1 app app 1415 Jan 14 11:56 ca-cert
-rw-r--r-- 1 app app   17 Jan 14 12:01 ca-cert.srl
-rw-r--r-- 1 app app 1834 Jan 14 11:56 ca-key
-rw-r--r-- 1 app app 1571 Jan 14 12:00 cert-file
-rw-r--r-- 1 app app 1984 Jan 14 12:01 cert-signed
-rw-r--r-- 1 app app 1066 Jan 14 11:58 client.truststore.jks
-rw-r--r-- 1 app app 4220 Jan 14 12:02 server.keystore.jks
-rw-r--r-- 1 app app 1066 Jan 14 11:58 server.truststore.jks

```



# kafka配置



#### 给kafka配置文件server.properties添加SASL认证

```shell
cat >> /data/kafka/config/server.properties <<EOF
#sasl_ssl
listeners=SASL_SSL://10.10.34.224:9092
advertised.listeners=SASL_SSL://10.10.34.224:9092
security.inter.broker.protocol=SASL_SSL
sasl.enabled.mechanisms=PLAIN
sasl.mechanism.inter.broker.protocol=PLAIN
authorizer.class.name=kafka.security.auth.SimpleAclAuthorizer
#allow.everyone.if.no.acl.found=true
ssl.keystore.location=/data/ssl/server.keystore.jks
ssl.keystore.password=kafka123
ssl.key.password=kafka123
ssl.truststore.location=/data/ssl/server.truststore.jks
ssl.truststore.password=kafka123
ssl.endpoint.identification.algorithm=

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
#listeners=SASL_PLAINTEXT://10.10.34.224:9092
#advertised.listeners=SASL_PLAINTEXT://10.10.34.224:9092
sasl.enabled.mechanisms=SCRAM-SHA-512
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
#security.inter.broker.protocol=SASL_PLAINTEXT
#authorizer.class.name=kafka.security.auth.SimpleAclAuthorizer
#authorizer.class.name=kafka.security.authorizer.AclAuthorizer
allow.everyone.if.no.acl.found=false
super.users=User:admin;User:nvadmin
delete.topic.enable=true
auto.create.topics.enable=false
EOF





```



说完kafka配置，在 /data/kafka/config，我们还需要在启动的时候加载一个认证文件。

```shell
cat >> /data/kafka/config/kafka_server_jaas.conf <<EOF
KafkaServer {
    org.apache.kafka.common.security.plain.PlainLoginModule required
    username="admin"
    password="admin123"
    user_admin="admin123";
 };
EOF
```



#### 启动时加载认证文件

```shell
cat >> /data/kafka/start.sh <<EOF
export KAFKA_OPTS="-Djava.security.auth.login.config=/data/kafka/config/kafka_server_jaas.conf.conf"
export JMX_PORT=9999
export KAFKA_HEAP_OPTS="-Xmx4G -Xms4G"
/data/kafka/bin/kafka-server-start.sh /data/kafka/config/server.properties &
EOF
```



第一行`KAFKA_OPTS`配置的是加载的认证文件的路径；第二行`JMX_PORT`是监控端口，可以不配置；第三行`KAFKA_HEAP_OPTS`是配置启动占用内存的，随意调整，也可以不配置用默认的；第四行执行Kafka开始脚本和做好的配置文件。

给Zookeeper中添加超级账户
完成以后跳转到Kafka的/bin目录下，用自带的kafka-configs.sh脚本把Kafka服务器的超级账户添加到Zookeeper中，因为目前(Kafka 2.8.0)来说Kafka账号密码还是存在Zookeeper上的。这一步不需要Kafka启动，但是Zookeeper要启动。

启动zookeeper:  systemctl start zookeeper.service

```shell
#输入命令创建超级用户
sh kafka-configs.sh --zookeeper 10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181 --alter --add-config 'SCRAM-SHA-512=[password=admin123]' --entity-type users --entity-name admin


```

启动类配置认证文件
当上述步骤都配置完毕以后有些/bin目录下的命令（比如kafka-console-producer.sh）都不能直接使用了，需要带着用户名密码才可以，这就给我们做一些简单的测试造成了很大的麻烦。我们可以通过在启动类中配置认证文件，从而跳过用户名密码的输入，这一步就是让Kafka服务器识别SASL/PLAIN的认证方式。具体做法就是vi kafka-run-class.sh打开这个脚本，然后把下面的一行贴进去，文件开头，文件末尾都可以，不要贴到循环或者if条件语句中就行。保存退出就可以准备启动了，再次提醒认证文件路径要写对。

```sh
cat >> /data/kafka/bin/kafka-run-class.sh <<EOF
KAFKA_OPTS="-Djava.security.auth.login.config=/data/kafka/config/kafka_server_jaas.conf"
EOF
```

启动kafka

```sh
chmod +x /data/kafka/start.sh;nohup /data/kafka/start.sh
```

以上步骤要在所有集群机器上做一遍，避免某个节点挂了整个服务不可用。



## 认证后赋权

配置好以后除了admin超级账户以外其他所有客户端都无法直接连接因此我们需要对账号进行赋权，可以参照以下命令执行。

```shell
创建账号：
sh kafka-configs.sh --zookeeper 10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181 --alter --add-config 'SCRAM-SHA-512=[password=easy1234]' --entity-type users --entity-name easy
添加账号写权限：
sh kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties zookeeper.connect=10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181 --add --allow-principal User:easy --operation Read --topic my-topic
添加账号读权限：
sh kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties zookeeper.connect=10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181 --add --allow-principal User:easy --operation Read --topic my-topic
创建Group：
sh kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties zookeeper.connect=10.10.34.224:2181,10.10.34.226:2181,10.10.34.227:2181 --add --allow-principal User:easy  --group aaa

```

如果要删除，只需要把--add换成--remove即可



管理员账户

admin/admin123



客户端访问配置admin-client-configs.conf

```shell
cat >> /data/kafka/config/admin-client-configs.conf <<EOF
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="admin" password="admin123";
ssl.keystore.location=/data/ssl/server.keystore.jks
ssl.keystore.password=kafka123
ssl.key.password=kafka123
ssl.truststore.location=/data/ssl/client.truststore.jks
ssl.truststore.password=kafka123
ssl.endpoint.identification.algorithm=
EOF
```

```shell
kafka-topics.sh --list --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 --command-config /data/kafka/config/admin-client-configs.conf  #列出主题
kafka-topics.sh --create --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 --replication-factor 3 --partitions 2 --topic test-117 --command-config /data/kafka/config/admin-client-configs.conf #创建一个新主题
kafka-topics.sh --describe --bootstrap-server 10.10.34.224:9092,10.10.34.226:9092,10.10.34.227:9092 --topic test-117 --command-config /data/kafka/config/admin-client-configs.conf #查询主题信息

```

























