## Zookeeper 安装

### 1、下载zk安装包
https://github.com/apache/zookeeper
https://zookeeper.apache.org/
https://zookeeper.apache.org/releases.html

## 2、安装jdk
参考：001-安装JDK
```shell
tar -xf jdk-8u333-linux-x64.tar.gz -C /opt
ln -sv /opt/jdk1.8.0_333 /opt/jdk

cat <<'EOF' > /etc/profile.d/jdk.sh
export JAVA_HOME=/opt/jdk
export JRE_HOME=$JAVA_HOME/jre
export PATH=$PATH:$JAVA_HOME/bin
export CLASSPATH=.:$JAVA_HOME/lib:$JRE_HOME/lib
EOF
source /etc/profile 

java -version
```

## 3、安装zookeeper
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

# node01
mkdir /data/zookeeper ; echo 1 > /data/zookeeper/myid
# node02
mkdir /data/zookeeper ; echo 2 > /data/zookeeper/myid
# node03
mkdir /data/zookeeper ; echo 3 > /data/zookeeper/myid
```

同步配置文件到其他服务器
```shell
rsync -arPv /opt/* node02:/opt/
rsync -arPv /opt/* node03:/opt/
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

停zk服务
```shell
/opt/zookeeper/bin/zkServer.sh stop
/opt/zookeeper/bin/zkServer.sh start 
/opt/zookeeper/bin/zkServer.sh status
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

