
查看主题：
root@ubuntu-01:~# export BROKER_SER="10.10.34.247:9093,10.10.34.248:9093,10.10.34.249:9093"
root@ubuntu-01:~# kafkacat -b ${BROKER_SER} -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256 -X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01 -L
Metadata for topic-test01 (from broker 3: sasl_plaintext://10.10.34.249:9093/3):
 3 brokers:
  broker 2 at 10.10.34.248:9093
  broker 3 at 10.10.34.249:9093 (controller)
  broker 1 at 10.10.34.247:9093
 1 topics:
  topic "topic-test01" with 3 partitions:
    partition 0, leader 1, replicas: 1,2,3, isrs: 2,3,1
    partition 1, leader 2, replicas: 2,3,1, isrs: 2,3,1
    partition 2, leader 3, replicas: 3,1,2, isrs: 3,2,1

生产：
root@ubuntu-01:~# echo A=1 | kafkacat -b ${BROKER_SER} -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256  -X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01 -P

消费：
root@ubuntu-01:~# kafkacat -b ${BROKER_SER} -X security.protocol=SASL_PLAINTEXT -X sasl.mechanisms=SCRAM-SHA-256  -X sasl.username=test-user01 -X sasl.password=test-user-pwd -t topic-test01 -C
A=1
abc=1
abc=1
ABC=123
% Reached end of topic topic-test01 [0] at offset 1
% Reached end of topic topic-test01 [1] at offset 2
% Reached end of topic topic-test01 [2] at offset 1

亦写成：
默认配置$HOME/.config/kafkacat.conf 非默认配置用-F kafka.conf 指定配置文件

root@ubuntu-01:~# mkdir $HOME/.config/
root@ubuntu-01:~# cat << EOF > $HOME/.config/kafkacat.conf
security.protocol=SASL_PLAINTEXT
sasl.mechanisms=SCRAM-SHA-256
sasl.username=test-user01
sasl.password=test-user-pwd
EOF

查看主题：
root@ubuntu-01:~# kafkacat -b ${BROKER_SER} -L
% Reading configuration from file kafka.conf
Metadata for all topics (from broker 3: sasl_plaintext://10.10.34.249:9093/3):
 3 brokers:
  broker 2 at 10.10.34.248:9093
  broker 3 at 10.10.34.249:9093 (controller)
  broker 1 at 10.10.34.247:9093
 1 topics:
  topic "topic-test01" with 3 partitions:
    partition 0, leader 1, replicas: 1,2,3, isrs: 2,3,1
    partition 1, leader 2, replicas: 2,3,1, isrs: 2,3,1
    partition 2, leader 3, replicas: 3,1,2, isrs: 3,2,1


生产：
root@ubuntu-01:~# echo Aa=11 | kafkacat -b ${BROKER_SER} -t topic-test01 -P

消费：
root@ubuntu-01:~# kafkacat -b ${BROKER_SER} -t topic-test01 -C
ABC=123
Aa=11
abc=1
abc=1
A=1
% Reached end of topic topic-test01 [2] at offset 2
% Reached end of topic topic-test01 [1] at offset 2
% Reached end of topic topic-test01 [0] at offset 1

