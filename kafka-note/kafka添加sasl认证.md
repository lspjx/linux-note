# kafka添加SASL认证(集群的话需要每个节点都配置)

kafka集群信息

| ip地址      | kafka端口 | zk端口 |
| ----------- | --------- | ------ |
| 10.10.20.2 | 9092      | 2181   |
| 10.10.20.3 | 9092      | 2181   |
| 10.10.20.7 | 9092      | 2181   |

请先安装java和openssl.

## Zookeeper配置

首先进入Zookeeper /data/zookeeper/conf目录,给zoo.cfg 添加SASL认证

新添加的两行，用来支持SASL认证。

```shell
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/data/zookeeper/data
clientPort=2181
#maxClientCnxns=60
#新添加的两行在这里
authProvider.1=org.apache.zookeeper.server.auth.SASLAuthenticationProvider
requireClientAuthScheme=sasl

server.1=10.10.20.2:2888:3888
server.2=10.10.20.3:2888:3888
server.3=10.10.20.7:2888:3888

```

#### 创建Zookeeper认证文件

cd /data/zookeeper/conf

```shell
cat >> zookeeper_jaas.conf<<EOF
Server {
org.apache.zookeeper.server.auth.DigestLoginModule required
user_super="super1234"
user_kafka="kafka1234";
};
EOF
```

这里要对这两个参数说明一下：user_super="super1234"这句配置的是超级用户，在Zookeeper里面超级用户默认就是super，后面引号里设置的则是它的密码super1234。因此下面的user_kafka="kafka1234"设置的是Kafka连接Zookeeper要用的账户和密码，这个账户和密码在后面Kafka的配置中还要用，请先记住这点。其意思就是，一个叫做kafka的账户名，密码是kafka1234。前面的user_就是为了识别这个配置是一个账户名用的

启动时加载认证文件
cd /data/zookeeper/bin ,创建一个新的启动脚本，用于Zookeeper启动时加载认证文件。注意这里的文件路径和启动路径都是在/bin下的，如果你配置的东西不在这里，要修改路径。

```shell
cat >> zookeeper-start.sh<<EOF
export JVMFLAGS="-Djava.security.auth.login.config=/data/zookeeper/conf/zookeeper_jaas.conf -Dzookeeper.4lw.commands.whitelist=*"
./zkServer.sh start &
EOF
```

然后使用命令chmod +x zookeeper-start.sh给脚本文件赋权。

启动zookeeper: cd /data/zookeeper/bin ;sh zookeeper-start.sh



# kafka配置

#### 给kafka配置文件server.properties添加SASL认证

```shell
############################     基础配置如下    ##############################
broker.id=1
#默认监控端口，设置9092使用SASL_PLAINTEXT协议
listeners=SASL_PLAINTEXT://10.10.20.2:9092
#advertised.listeners控制生产者与消费者接入的端口，如果不设置默认都用listeners，设置9092使用SASL_PLAINTEXT协议
advertised.listeners=SASL_PLAINTEXT://10.10.20.2:9092
log.dirs=/data/kafka/logs
zookeeper.connect=10.10.20.2:2181,10.10.20.3:2181,10.10.20.7:2181
############################     SASL/SCRAM相关配置如下    ##############################
#Broker内部联络使用的security协议
security.inter.broker.protocol=SASL_PLAINTEXT
#Broker内部联络使用的sasl协议，这里也可以配置多个，比如SCRAM-SHA-512,SCRAM-SHA-256并列使用
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
#Broker允许使用的sasl协议，这里也可以配多个PLAIN,SCRAM-SHA-512,SCRAM-SHA-256
sasl.enabled.mechanisms=PLAIN,SCRAM-SHA-512

#设置zookeeper是否使用ACL
zookeeper.set.acl=true
#设置ACL类(低于 2.4.0 版本推荐使用 SimpleAclAuthorizer)
#authorizer.class.name=kafka.security.auth.SimpleAclAuthorizer
#设置ACL类(高于 2.4.0 版本推荐使用 AclAuthorizer)
authorizer.class.name=kafka.security.authorizer.AclAuthorizer
#设置Kafka超级用户账号，这两个分别对应zookeeper_jaas.conf中的user_super="super1234"和user_kafka="kafka1234";
super.users=User:admin;User:kafka

########################    其他辅助配置，笔者推荐的重要配置   #######################
#每条最大消息设置为3MB，超过此size会报错，可以自由调整
replica.fetch.max.bytes=3145728
message.max.bytes=3145728
#默认的备份数量，可以自由调整
default.replication.factor=2
#默认的partion数量，可以自由调整
num.partitions=3
#是否允许彻底删除topic，低版本这里设置为false则是隐藏topic
delete.topic.enable=true
#如果topic不存在，是否允许创建一个新的。这里特别推荐设置为false，否则可能会因为手滑多出很多奇奇怪怪的topic出来
auto.create.topics.enable=false





```



说完kafka配置，在 /data/kafka/config，我们还需要在启动的时候加载一个认证文件。

```shell
cat >> /data/kafka/config/kafka-broker-jaas.conf <<EOF
KafkaServer {
    org.apache.kafka.common.security.scram.ScramLoginModule required
    username="admin"
    password="admin1234";
};
Client {
    org.apache.zookeeper.server.auth.DigestLoginModule required
    username="kafka"
    password="kafka1234";
};
EOF
```

这里要解释一下这两块的内容：首先KafkaServer这里配置的是Kafka服务器本身的超级账户admin和其密码，使用的是ScramLoginModule模式，也就是标题的登陆认证方式。直接使用这个超级账户登陆，整个Kafka集群就相当于对你打开了大门。需要设计一些Kafka工具的时候可以使用，所以好好保存不要泄露了。后面配置的Client是用来登陆Zookeeper使用的，也就是上面我们配置到zookeeper_jaas.conf 文件中的user_kafka="kafka1234"一行所对应的，这里看到登陆Zookeeper要用的账户就是kafka，密码就是kafka1234。这点设计的比较绕，需要多理解理解。





#### 启动时加载认证文件

```shell
cat >> /data/kafka/start.sh <<EOF
export KAFKA_OPTS="-Djava.security.auth.login.config=/data/kafka/config/kafka-broker-jaas.conf"
export JMX_PORT=9999
export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
/data/kafka/bin/kafka-server-start.sh /data/kafka/config/server.properties &
EOF
```



第一行`KAFKA_OPTS`配置的是加载的认证文件的路径；第二行`JMX_PORT`是监控端口，可以不配置；第三行`KAFKA_HEAP_OPTS`是配置启动占用内存的，随意调整，也可以不配置用默认的；第四行执行Kafka开始脚本和做好的配置文件。

给Zookeeper中添加超级账户
完成以后跳转到Kafka的/bin目录下，用自带的kafka-configs.sh脚本把Kafka服务器的超级账户添加到Zookeeper中，因为目前(Kafka 2.8.0)来说Kafka账号密码还是存在Zookeeper上的。这一步不需要Kafka启动，但是Zookeeper要启动。

启动zookeeper

```sh
cd /data/zookeeper/bin;sh zookeeper-start.sh
```



```shell
#输入命令创建超级用户
sh kafka-configs.sh --zookeeper 10.10.20.2:2181,10.10.20.3:2181,10.10.20.7:2181 --alter --add-config 'SCRAM-SHA-512=[password=admin1234]' --entity-type users --entity-name admin


```

启动类配置认证文件
当上述步骤都配置完毕以后有些/bin目录下的命令（比如kafka-console-producer.sh）都不能直接使用了，需要带着用户名密码才可以，这就给我们做一些简单的测试造成了很大的麻烦。我们可以通过在启动类中配置认证文件，从而跳过用户名密码的输入，这一步就是让Kafka服务器识别SASL/PLAIN的认证方式。具体做法就是vi kafka-run-class.sh打开这个脚本，然后把下面的一行贴进去，文件开头，文件末尾都可以，不要贴到循环或者if条件语句中就行。保存退出就可以准备启动了，再次提醒认证文件路径要写对。

```sh
cat >> /data/kafka/bin/kafka-run-class.sh <<EOF
KAFKA_OPTS="-Djava.security.auth.login.config=/data/kafka/config/kafka-broker-jaas.conf"
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
sh kafka-configs.sh --zookeeper 10.10.20.2:2181,10.10.20.3:2181,10.10.20.7:2181 --alter --add-config 'SCRAM-SHA-512=[password=easy1234]' --entity-type users --entity-name easy
添加账号写权限：
sh kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties zookeeper.connect=10.10.20.2:2181,10.10.20.3:2181,10.10.20.7:2181 --add --allow-principal User:easy --operation Read --topic my-topic
添加账号读权限：
sh kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties zookeeper.connect=10.10.20.2:2181,10.10.20.3:2181,10.10.20.7:2181 --add --allow-principal User:easy --operation Read --topic my-topic
创建Group：
sh kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties zookeeper.connect=10.10.20.2:2181,10.10.20.3:2181,10.10.20.7:2181 --add --allow-principal User:easy  --group aaa

```

如果要删除，只需要把--add换成--remove即可



连接kafka使用两个账户

admin/admin1234

kafka/kafka1234































