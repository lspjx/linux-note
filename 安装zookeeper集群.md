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

重启zk服务
```shell
/opt/zookeeper/bin/zkServer.sh stop
/opt/zookeeper/bin/zkServer.sh start 
/opt/zookeeper/bin/zkServer.sh status
```

#### [systemd]配置管理ZK服务

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

#### [supervison]管理Zookeeper服务
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
user=root
autostart=true
autorestart=true
startsecs=10
startretries=999
stopsignal=KILL
stopasgroup=true
log_stdout=true
log_stderr=true
logfile_maxbytes=1MB
logfile_backups=10
redirect_stderr=true
stdout_logfile=/var/log/supervisor/zookeeper.log
directory=/opt/zookeeper
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

