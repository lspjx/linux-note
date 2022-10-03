https://docs.confluent.io/platform/current/kafka/authorization.html


配置环境变量
```
# cat <<'EOF' > /etc/profile.d/kafka.sh 
#!/bin/bash

export PATH=$PATH:/data/kafka/bin
export ZK_SER="10.10.34.247:2181,10.10.34.248:2181,10.10.34.249:2181"
EOF

source /etc/profile.d/kafka.sh 
```

创建主题：
```
# kafka-topics.sh --zookeeper ${ZK_SER} \
--create --replication-factor 3 --partitions 3 --topic topic-test01
```
删除主题：
```
# kafka-topics.sh --zookeeper ${ZK_SER} --delete --topic topic-test01
```
列出主题：
```
# kafka-topics.sh --zookeeper ${ZK_SER} --list
```

创建用户：
```
# kafka-configs.sh --zookeeper ${ZK_SER} \
--alter --add-config 'SCRAM-SHA-256=[password=test-user-pwd],SCRAM-SHA-512=[password=test-user-pwd]' \
--entity-type users --entity-name test-user01
```


删除用户
```
# kafka-configs.sh --zookeeper ${ZK_SER} \
--alter --delete-config 'SCRAM-SHA-256,SCRAM-SHA-512' \
--entity-type users --entity-name test-user01
```


列出entity配置描述
```
# kafka-configs.sh --zookeeper ${ZK_SER} \
--entity-type users --entity-name test-user01  --describe  # 查看 test-user01 信息

#  kafka-configs.sh --zookeeper ${ZK_SER} --entity-type users  --describe  # 查看 所有用户 信息
或者：
# kafka-configs.sh --zookeeper localhost:2181 --entity-type users --describe 
```
例子：
```
# kafka-configs.sh --zookeeper ${ZK_SER} --entity-type users --entity-name test-user01  --describe
Warning: --zookeeper is deprecated and will be removed in a future version of Kafka.
Use --bootstrap-server instead to specify a broker to connect to.
Configs for user-principal 'test-user01' are SCRAM-SHA-512=salt=NmQyZnR0a3dzcmluZzBrMGk4eXp2ZW5tcQ==,stored_key=A1t5hNtbam1Ecz+ldT4+Mi/xryEIGFmS00Z6fud15a39+2ef9XW2mWperILWFf43echA0lp2srprMVjZdhpF4g==,server_key=rvV0VEOeByTNPTAuGwDpyFodK1GQ2UUS56JBe26NQxLUX5/2VuB71tu0Y0vzK7KVOcaLTacMrW9QkJ3OBmudMw==,iterations=4096,SCRAM-SHA-256=salt=bGttY2Q5aWRia2E3b3QzODV3aDBzMzNodw==,stored_key=myxDH2nhrPR1qrMcTreAZKPMNdJQgSoQXmRoYxleWCc=,server_key=ewX6Ax9pvc4sGNULZI//07Rv2u09ZRBlnZypSitCkYo=,iterations=4096

#  kafka-configs.sh --zookeeper ${ZK_SER} --entity-type users  --describe
Warning: --zookeeper is deprecated and will be removed in a future version of Kafka.
Use --bootstrap-server instead to specify a broker to connect to.
Configs for user-principal 'admin' are SCRAM-SHA-512=salt=czgzbWYyb2YzamhncWJ5M2J5cTJrMXZkNA==,stored_key=jRLqixjK42cjjlS1r5FQJztHt2DxemAWr1WNtkSw02dSWfIAKGxt3AWJAvc8knqfiim16Geoo/9zz5Xx/vsBqg==,server_key=0bJ/zK2Yj6EtTxedmzHFSmjSLHqBnPrIs5AefVrNQC2m0Vf2ptrQnd/eIDIcdXRGt4W+I+NHjB9FD7UpEwrBWQ==,iterations=4096,SCRAM-SHA-256=salt=YjE0ZjY4bnF4M3VuZXpqMXJ1NzlvdWpqZQ==,stored_key=QN8t2t6nvEoPapdKrbK2gWJc85dJ+cu44XtVmM3Q0XM=,server_key=l3jUaeKT3jvrC29j1QSApDd2ppADN6zb/TyYISufleE=,iterations=4096
Configs for user-principal 'testuser1' are SCRAM-SHA-512=salt=ZDdzdG85YWR2MHE0d2Q3c3g4Y3c4a3lmdQ==,stored_key=RR2JqmB2E84/YD8Xi4CQ616V4wjSdgwnzKowl0Xs/+ws+vZTdx0cTCEfV4vj4emmhTwgqCgoSbFXgdtfbT414A==,server_key=EG/vkz181Y00Rcmf6mC3IyeaDmpV/GhRdHEjqs3nenibRcD2KJgA83KqvK5gDMmGCcverZqJRHxX5DtJTYs+vg==,iterations=4096,SCRAM-SHA-256=salt=eGZzOXF3MnZhcHJlMjdzbWR2bHZzNXd0Mw==,stored_key=qDonJiWVsN8RoWx5OdqgvY7C5A5Ph5bNc9r82eiQHHY=,server_key=/sqfXcN5emH9SpLpoKgCsSl1GgqfFzhZFQ3QNAZCf4w=,iterations=4096
Configs for user-principal 'tom' are SCRAM-SHA-512=salt=bXBxOHl4Z3c5b2duY3ZrejdpNDgzbXcxdA==,stored_key=+nplMOZp0x80oEEKpFqFAYrx6ppAvzZIDH5gNd255j98SnAIiwBQXTt78g+ifaQpzx+RbqWyrtCcBPYUiMNq/g==,server_key=yGw+prVenljFDxzEnYoHzRZnE6BjFYUYIUDgTLlhxeVOcwIk4tov1MMEA3KFIH41AX7BdUu810JSH8wrdrCpcQ==,iterations=4096,SCRAM-SHA-256=salt=ZDFscWpxNTJ3bW5jdDlrcTl5cmVwdnZlcA==,stored_key=G1qKj9FKESXSStkOAfSaGoU11jHvAg4XIbbySMfAA0c=,server_key=F440CQ2wyVOuo+enbZ9D4y3bXFnjEC0r3Q5rgfdwFfw=,iterations=4096
Configs for user-principal 'testuser2' are SCRAM-SHA-256=salt=a2FhdDlpYjVvbHQxMWR2cHR1NTB6b3N1YQ==,stored_key=PJQT+Z6rhuaQ8Nfv37LgWGZtrOTePuAHHOffhHFVaLI=,server_key=F++cWhtd8xrNbcPYhRloMg7HfQgJsL4Zvs3AtRapVgs=,iterations=4096
Configs for user-principal 'test-user01' are SCRAM-SHA-512=salt=NmQyZnR0a3dzcmluZzBrMGk4eXp2ZW5tcQ==,stored_key=A1t5hNtbam1Ecz+ldT4+Mi/xryEIGFmS00Z6fud15a39+2ef9XW2mWperILWFf43echA0lp2srprMVjZdhpF4g==,server_key=rvV0VEOeByTNPTAuGwDpyFodK1GQ2UUS56JBe26NQxLUX5/2VuB71tu0Y0vzK7KVOcaLTacMrW9QkJ3OBmudMw==,iterations=4096,SCRAM-SHA-256=salt=bGttY2Q5aWRia2E3b3QzODV3aDBzMzNodw==,stored_key=myxDH2nhrPR1qrMcTreAZKPMNdJQgSoQXmRoYxleWCc=,server_key=ewX6Ax9pvc4sGNULZI//07Rv2u09ZRBlnZypSitCkYo=,iterations=4096

```

ACL设置用户读写权限：
设置用户读权限：
```
# kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties \
zookeeper.connect=${ZK_SER} \
--add --allow-principal User:test-user01 --operation Read --topic topic-test01

Adding ACLs for resource `ResourcePattern(resourceType=TOPIC, name=topic-test01, patternType=LITERAL)`: 
 	(principal=User:test-user01, host=*, operation=READ, permissionType=ALLOW) 

Current ACLs for resource `ResourcePattern(resourceType=TOPIC, name=topic-test01, patternType=LITERAL)`: 
 	(principal=User:test-user01, host=*, operation=READ, permissionType=ALLOW) 

```
如果未指明 allow-host 则对所有IP授权；

创建Group：
```
# kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties \
zookeeper.connect=${ZK_SER} \
--add --allow-principal User:test-user01  \
--group test-group
```


查看主题ACL权限
```
# kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties \
zookeeper.connect=${ZK_SER} --list --topic topic-test01
Current ACLs for resource `ResourcePattern(resourceType=TOPIC, name=topic-test01, patternType=LITERAL)`: 
 	(principal=User:test-user01, host=*, operation=READ, permissionType=ALLOW) 
```
查看用户ACL权限
```
# kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties \
zookeeper.connect=${ZK_SER} --list  User:test-user01
Current ACLs for resource `ResourcePattern(resourceType=TOPIC, name=topic-test01, patternType=LITERAL)`: 
 	(principal=User:test-user01, host=*, operation=READ, permissionType=ALLOW) 

```

删除用户权限：
删除之前配置的ACL权限配置，需要提供至少一个以下资源对象：topic、cluster、group或者delegation-token
```
# kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties \
zookeeper.connect=${ZK_SER} \
--remove --allow-principal User:test-user01 --operation Read --topic topic-test01
```


#############
```
[root@kafka-uat-0 ~]# kafka-topics.sh --zookeeper ${ZK_SER} \
> --create --replication-factor 3 --partitions 3 --topic topic-test01
Created topic topic-test01.

[root@kafka-uat-0 ~]# kafka-topics.sh --zookeeper ${ZK_SER} --list
topic-test01

[root@kafka-uat-0 ~]# kafka-configs.sh --zookeeper ${ZK_SER} \
> --alter --add-config 'SCRAM-SHA-256=[password=test-user-pwd],SCRAM-SHA-512=[password=test-user-pwd]' \
> --entity-type users --entity-name test-user01
Warning: --zookeeper is deprecated and will be removed in a future version of Kafka.
Use --bootstrap-server instead to specify a broker to connect to.
Completed updating config for entity: user-principal 'test-user01'.

[root@kafka-uat-0 ~]# kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties zookeeper.connect=${ZK_SER} --list  User:test-user01


```
####################

消费者连接测试
对消费者进行授权

在客户端操作：
```
export BROKER_SER="10.10.34.247:9093,10.10.34.248:9093,10.10.34.249:9093"

kcat -b ${BROKER_SER} -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256 \
-X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01 -L

[root@ansible ~]# export BROKER_SER="10.10.34.247:9093,10.10.34.248:9093,10.10.34.249:9093"
[root@ansible ~]# kcat -b ${BROKER_SER} -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256 \
> -X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01 -L
Metadata for topic-test01 (from broker 2: sasl_plaintext://10.10.34.248:9093/2):
 3 brokers:
  broker 2 at 10.10.34.248:9093
  broker 3 at 10.10.34.249:9093
  broker 1 at 10.10.34.247:9093 (controller)
 1 topics:
  topic "topic-test01" with 0 partitions: Broker: Topic authorization failed

报错说没有权限，

给用户设置ACL读权限Read
[root@kafka-uat-0 ~]# kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties \
 zookeeper.connect=${ZK_SER} \
 --add --allow-principal User:test-user01 --operation Read --topic topic-test01
Adding ACLs for resource `ResourcePattern(resourceType=TOPIC, name=topic-test01, patternType=LITERAL)`: 
 	(principal=User:test-user01, host=*, operation=READ, permissionType=ALLOW) 

Current ACLs for resource `ResourcePattern(resourceType=TOPIC, name=topic-test01, patternType=LITERAL)`: 
 	(principal=User:test-user01, host=*, operation=READ, permissionType=ALLOW) 

可以查看主题：
[root@ansible ~]# kcat -b ${BROKER_SER} -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256 \
 -X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01 -L
Metadata for topic-test01 (from broker 1: sasl_plaintext://10.10.34.247:9093/1):
 3 brokers:
  broker 2 at 10.10.34.248:9093
  broker 3 at 10.10.34.249:9093
  broker 1 at 10.10.34.247:9093 (controller)
 1 topics:
  topic "topic-test01" with 3 partitions:
    partition 0, leader 1, replicas: 1,2,3, isrs: 1,2,3
    partition 1, leader 2, replicas: 2,3,1, isrs: 2,3,1
    partition 2, leader 3, replicas: 3,1,2, isrs: 3,1,2


```

生产者连接测试
对生产者进行授权(回车提交消费, “Ctrl+D”退出)
```
[root@ansible ~]# kcat -b ${BROKER_SER} -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256 \
 -X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01 -P
AAA=123


% Delivery failed for message: Broker: Topic authorization failed
报错说没有权限，

[root@ansible ~]# kcat -b ${BROKER_SER} -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256  -X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01 -C
% Reached end of topic topic-test01 [1] at offset 0
% Reached end of topic topic-test01 [2] at offset 0
% Reached end of topic topic-test01 [0] at offset 0


给用户设置ACL写权限Write
[root@kafka-uat-0 ~]# kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties \
 zookeeper.connect=${ZK_SER} \
 --add --allow-principal User:test-user01 --operation Write --topic topic-test01
Adding ACLs for resource `ResourcePattern(resourceType=TOPIC, name=topic-test01, patternType=LITERAL)`: 
 	(principal=User:test-user01, host=*, operation=WRITE, permissionType=ALLOW) 

Current ACLs for resource `ResourcePattern(resourceType=TOPIC, name=topic-test01, patternType=LITERAL)`: 
 	(principal=User:test-user01, host=*, operation=WRITE, permissionType=ALLOW)
	(principal=User:test-user01, host=*, operation=READ, permissionType=ALLOW) 

[root@kafka-uat-0 ~]# kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties \
> zookeeper.connect=${ZK_SER} --list  User:test-user01
Current ACLs for resource `ResourcePattern(resourceType=TOPIC, name=topic-test01, patternType=LITERAL)`: 
 	(principal=User:test-user01, host=*, operation=WRITE, permissionType=ALLOW)
	(principal=User:test-user01, host=*, operation=READ, permissionType=ALLOW) 

再次生产
[root@ansible ~]# kcat -b ${BROKER_SER} -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256 \
>  -X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01 -P
ABC=123
(回车提交消费, “Ctrl+D”退出)

消费：
[root@ansible ~]# export BROKER_SER="10.10.34.247:9093,10.10.34.248:9093,10.10.34.249:9093"
[root@ansible ~]# kcat -b ${BROKER_SER} -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256 \
>  -X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01 -C
ABC=123
% Reached end of topic topic-test01 [1] at offset 0
% Reached end of topic topic-test01 [0] at offset 0
% Reached end of topic topic-test01 [2] at offset 1
```

配置
kafkacat 使用的是librdkafka的配置，使用时可以通过 '-F'指定配置文件。
比如 SASL_PLAINTEXT登录，新建一个配置文件, 如 kafka.conf
```
export BROKER_SER="10.10.20.2:9092,10.10.20.3:9092,10.10.20.7:9092"

kcat -b ${BROKER_SER} -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-512 \
-X sasl.username=admin -X sasl.password=admin1234 -t topic-test01 -L

可以写成：
cat << EOF > kafka.conf
security.protocol=SASL_PLAINTEXT
sasl.mechanisms=SCRAM-SHA-512
sasl.username=admin
sasl.password=admin1234
EOF

kcat -b ${BROKER_SER} -F kafka.conf -L


SYNOPSIS
     kafkacat -C | -P | -L -t topic [-p partition] -b brokers [, ...] [-D delim] [-K delim] [-c cnt] [-X list] [-X prop=val] [-X dump]
              [-d dbg [, ...]] [-q] [-v] [-Z] [specific options]
     kafkacat -C [generic options] [-o offset] [-e] [-O] [-u] [-J] [-f fmtstr]
     kafkacat -P [generic options] [-z snappy | gzip] [-p -1] [file [...]]
     kafkacat -L [generic options] [-t topic]


root@ubuntu-01:~# echo abc=1 | kafkacat -b 10.10.34.247:9093,10.10.34.248:9093,10.10.34.249:9093  -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256 -X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01   -P

root@ubuntu-01:~# kafkacat -b 10.10.34.247:9093,10.10.34.248:9093,10.10.34.249:9093  -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256 -X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01  -C
ABC=123
abc=1
% Reached end of topic topic-test01 [2] at offset 1
% Reached end of topic topic-test01 [0] at offset 0
% Reached end of topic topic-test01 [1] at offset 1

root@ubuntu-01:~# kafkacat -b 10.10.34.247:9093,10.10.34.248:9093,10.10.34.249:9093  -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256 -X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01  -p 2 -o 1 -e  
% Auto-selecting Consumer mode (use -P or -C to override)
% Reached end of topic topic-test01 [2] at offset 1: exiting

```








