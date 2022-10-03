



# Hadoop 3.x高可用集群部署

## HA集群规划

准备3个节点，节点角色规划如下：

| Host   | IP           | 组件                                                         |
| :----- | ------------ | ------------------------------------------------------------ |
| node-0 | 10.10.34.57 | Zookeeper、NameNode、DataNode、NodeManage、ResourceManager、ZKFailoverController、journalnode |
| node-1 | 10.10.34.62 | Zookeeper、NameNode、DataNode、NodeManage、ResourceManager、ZKFailoverController、journalnode |
| node-2 | 10.10.34.63 | Zookeeper、NameNode、DataNode、NodeManage、ResourceManager、ZKFailoverController、journalnode |

节点规划说明：

zookeeper：集群需要至少3个节点，并且节点数为奇数个，可以部署在任意独立节点上，NameNode及ResourceManager依赖zookeeper进行主备选举和切换
NameNode：至少需要2个节点，一主多备，可以部署在任意独立节点上，用于管理HDFS的名称空间和数据块映射，依赖zookeeper和zkfc实现高可用和自动故障转移，并且依赖journalnode实现状态同步
ZKFailoverController：即zkfc，在所有NameNode节点上启动，用于监视和管理NameNode状态，参与故障转移
DataNode： 至少需要3个节点，因为hdfs默认副本数为3，可以部署在任意独立节点上，用于实际数据存储
ResourceManager：至少需要2个节点，一主多备，可以部署在任意独立节点上，依赖zookeeper实现高可用和自动故障转移，用于资源分配和调度
NodeManage： 部署在所有DataNode节点上，用于节点资源管理和监控
journalnode： 至少需要3个节点，并且节点数为奇数个，可以部署在任意独立节点上，用于主备NameNode状态信息同步
————————————————

创建data分区

```shell
yum -y install bash-completion lvm2
pvcreate /dev/vdb
vgcreate vgdata /dev/vdb
lvcreate -l 100%VG -n lvdata vgdata
mkfs.xfs /dev/mapper/vgdata-lvdata
grep "data" /etc/fstab || echo "/dev/mapper/vgdata-lvdata  /data  xfs  defaults   0 0" >> /etc/fstab
mkdir /data && mount -a && df -h /data
```

环境优化：

```shell
adduser -m app -G wheel
echo app@123 |passwd --stdin app
chown -R app:app /data
```

配置ssh免密

```shell
su - app
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
scp -r  ~/.ssh app@node-2:~/
scp -r  ~/.ssh app@node-1:~/
```

添加本地解析

```shell
cat <<EOF >> /etc/hosts
10.10.34.57 node-0
10.10.34.62 node-1
10.10.34.63 node-2
EOF
```

配置本地源

```shell
cat <<EOF > /etc/yum.repos.d/CentOS-Base.repo 
[Bash]
name=CentOS-7-Base
failovermethod=priority
baseurl=http://mirrors.example.com/centos/7.9
gpgcheck=1
gpgkey=http://mirrors.example.com/centos/7.9/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-7-extras
failovermethod=priority
baseurl=http://mirrors.example.com/centos/extras
gpgcheck=1
gpgkey=http://mirrors.example.com/centos/7.9/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-7-updates
failovermethod=priority
baseurl=http://mirrors.example.com/centos/updates
gpgcheck=1
gpgkey=http://mirrors.example.com/centos/7.9/RPM-GPG-KEY-CentOS-7
EOF

cat <<EOF > /etc/yum.repos.d/epel.repo 
[epel]
name=Extra Packages for Enterprise Linux 7 - $basearch
baseurl=http://mirrors.example.com/centos/epel
failovermethod=priority
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
EOF

sudo yum clean all && yum repolist
```



## 安装JDK

```shell
wget http://10.10.34.22/software/jdk-8u202-linux-x64.tar.gz
tar -xvf jdk-8u202-linux-x64.tar.gz -C /usr/local/
ln -sv /usr/local/jdk1.8.0_202 /usr/local/jdk

# 添加到环境变量PATH
cat <<'EOF' > /etc/profile.d/jdk.sh
export JAVA_HOME=/usr/local/jdk
export JRE_HOME=$JAVA_HOME/jre
export PATH=$PATH:$JAVA_HOME/bin
export CLASSPATH=.:$JAVA_HOME/lib:$JRE_HOME/lib
EOF
source /etc/profile 

java -version
```

### 安装zookeeper集群

```shell
wget http://10.10.34.22/software/apache-zookeeper-3.6.2-bin.tar.gz
tar xf apache-zookeeper-3.6.2-bin.tar.gz -C /data
mv /data/apache-zookeeper-3.6.2-bin /data/zookeeper
cp /data/zookeeper/conf/{zoo_sample.cfg,zoo.cfg}

cat <<EOF > /data/zookeeper/conf/zoo.cfg 
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/data/zookeeper/data
clientPort=2181

server.1=10.10.34.57:2888:3888
server.2=10.10.34.62:2888:3888
server.3=10.10.34.63:2888:3888
EOF

mkdir /data/zookeeper/data /data/zookeeper/logs
 

[app@node-0 conf]$ scp -r /data/zookeeper app@node-1:/data
[app@node-0 conf]$ scp -r /data/zookeeper app@node-2:/data

[app@node-1 ~]$ echo 2 > /data/zookeeper/data/myid
[app@node-2 ~]$ echo 3 > /data/zookeeper/data/myid


sudo cat <<'EOF' > /etc/systemd/system/zookeeper.service
[Unit]
Description=zookeeper.service
After=network.target

[Service]
Type=forking
User=app
Group=app
# 第一行设置日志目录，如果没有设置，默认是当前目录，对有的用户来说，可能没有权限。
Environment=ZOO_LOG_DIR=/data/zookeeper/logs
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/usr/local/jdk/bin:/root/bin
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
EOF

systemctl daemon-reload
systemctl restart zookeeper.service 
systemctl enable zookeeper.service
systemctl status  zookeeper.service
/data/zookeeper/bin/zkServer.sh status
```



## 安装Hadoop

```shell
# wget https://archive.apache.org/dist/hadoop/common/hadoop-3.2.2/hadoop-3.2.2.tar.gz
wget http://10.10.34.22/software/hadoop-3.2.2.tar.gz
tar -xvf hadoop-3.2.2.tar.gz -C /data
mv /data/hadoop-3.2.2 /data/hadoop

# 配置hadoop环境变量并分发hadoop环境变量
cat <<'EOF' > /etc/profile.d/hadoop.sh
export HADOOP_HOME=/data/hadoop
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
EOF
source /etc/profile
hadoop version

cat <<'EOF' >/data/hadoop/etc/hadoop/hadoop-env.sh
export HDFS_NAMENODE_OPTS="-XX:+UseParallelGC -Xmx4g"
export JAVA_HOME=$JAVA_HOME
export HADOOP_PID_DIR=$HADOOP_HOME/tmp/pids
export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_JOURNALNODE_USER=root
export HDFS_ZKFC_USER=root
EOF

cat  <<'EOF' >> /data/hadoop/etc/hadoop/yarn-env.sh
export YARN_REGISTRYDNS_SECURE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root
EOF

```

## 配置Hadoop

https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/ClusterSetup.html

```shell
$ tail -2 /data/hadoop/etc/hadoop/hadoop-env.sh 
export HDFS_NAMENODE_OPTS="-XX:+UseParallelGC -Xmx4g"
export JAVA_HOME=$JAVA_HOME


etc/hadoop/core-site.xml



```

### 修改core-site.xml

```shell
[app@node-0 hadoop]$ cat /data/hadoop/etc/hadoop/core-site.xml 
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
 ... ...
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
      <name>fs.defaultFS</name>
      <value>hdfs://mycluster</value>
    </property>
	
    <property>
      <name>hadoop.tmp.dir</name>
      <value>/data/hadoop/data</value>
    </property>

    <property>
      <name>io.file.buffer.size</name>
      <value>4096</value>
    </property>
    
    <property>
      <name>ha.zookeeper.quorum</name>
      <value>node-0:2181,node-1:2181,node-2:2181</value>
    </property>
</configuration>

```

配置说明：

fs.defaultFS 指定HDFS中NameNode的地址
hadoop.tmp.dir 指定hadoop运行时产生文件的存储目录，是其他临时目录的父目录
ha.zookeeper.quorum ZooKeeper地址列表，ZKFailoverController将在自动故障转移中使用这些地址。
io.file.buffer.size 在序列文件中使用的缓冲区大小，流文件的缓冲区为4K
 https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/core-default.xml

### 修改hdfs-site.xml配置文件

```shell
[app@node-0 hadoop]$ cat   /data/hadoop/etc/hadoop/hdfs-site.xml 
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
      <name>dfs.nameservices</name>
      <value>mycluster</value>
    </property>
	
    <property>
      <name>dfs.ha.namenodes.mycluster</name>
      <value>nn1,nn2,nn3</value>
    </property>
	
    <property>
      <name>dfs.namenode.rpc-address.mycluster.nn1</name>
      <value>node-0:8020</value>
    </property>
    <property>
      <name>dfs.namenode.rpc-address.mycluster.nn2</name>
      <value>node-1:8020</value>
    </property>
    <property>
      <name>dfs.namenode.rpc-address.mycluster.nn3</name>
      <value>node-2:8020</value>
    </property>	
	
    <property>
      <name>dfs.namenode.http-address.mycluster.nn1</name>
      <value>node-0:9870</value>
    </property>
    <property>
      <name>dfs.namenode.http-address.mycluster.nn2</name>
      <value>node-1:9870</value>
    </property>
    <property>
      <name>dfs.namenode.http-address.mycluster.nn3</name>
      <value>node-2:9870</value>
    </property>	
	
    <property>
      <name>dfs.replication</name>
      <value>3</value>
    </property>
    <property>
      <name>dfs.blocksize</name>
      <value>134217728</value>
    </property>
	
    <property>
      <name>dfs.namenode.name.dir</name>
      <value>file://${hadoop.tmp.dir}/hdfs/name</value>
    </property>
    <property>
      <name>dfs.datanode.data.dir</name>
      <value>file://${hadoop.tmp.dir}/hdfs/data</value>
    </property>

    <property>
      <name>dfs.namenode.shared.edits.dir</name>
      <value>qjournal://node-0:8485;node-1:8485;node-2:8485/mycluster</value>
    </property> 

    <property>
      <name>dfs.journalnode.edits.dir</name>
      <value>file://${hadoop.tmp.dir}/hdfs/journal</value>
    </property>
    
    <property>
      <name>dfs.client.failover.proxy.provider.mycluster</name>
      <value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
    </property>
	
    <property>
      <name>dfs.ha.automatic-failover.enabled</name>
      <value>true</value>
    </property>
    
    <property>
      <name>dfs.ha.fencing.methods</name>
      <value>sshfence</value>
    </property>
    <property>
      <name>dfs.ha.fencing.ssh.private-key-files</name>
      <value>/home/app/.ssh/id_rsa</value>
    </property>
    <property>
      <name>dfs.ha.fencing.ssh.connect-timeout</name>
      <value>30000</value>
    </property>
</configuration>

```

配置说明:

dfs.nameservices 配置命名空间，所有namenode节点配置在命名空间mycluster下
dfs.replication 指定dataNode存储block的副本数量，默认值是3个
dfs.blocksize 大型文件系统HDFS块大小为256MB，默认是128MB
dfs.namenode.rpc-address 各个namenode的 rpc通讯地址
dfs.namenode.http-address 各个namenode的http状态页面地址
dfs.namenode.name.dir 存放namenode名称表（fsimage）的目录
dfs.datanode.data.dir 存放datanode块的目录
dfs.namenode.shared.edits.dir HA集群中多个NameNode之间的共享存储上的目录。此目录将由活动服务器写入，由备用服务器读取，以保持名称空间的同步。
dfs.journalnode.edits.dir 存储journal edit files的目录
dfs.ha.automatic-failover.enabled 是否启用故障自动处理
dfs.ha.fencing.methods 处于故障状态的时候hadoop要防止脑裂问题，所以在standby机器切换到active后，hadoop还会试图通过内部网络的ssh连过去，并把namenode的相关进程给kill掉，一般是sshfence 就是ssh方式
dfs.ha.fencing.ssh.private-key-files 配置了 ssh用的 key 的位置
————————————————

更多参数配置，请参考[hdfs-site.xml](http://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-hdfs/hdfs-default.xml)。

 https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-hdfs/hdfs-default.xml

### 修改mapred-site.xml配置文件

```shell
[app@node-0 hadoop]$ cat /data/hadoop/etc/hadoop/mapred-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
 <property>
      <name>mapreduce.framework.name</name>
      <value>yarn</value>
    </property>

    <property>
      <name>mapreduce.jobhistory.address</name>
      <value>0.0.0.0:10020</value>
    </property>
    <property>
      <name>mapreduce.jobhistory.webapp.address</name>
      <value>0.0.0.0:19888</value>
    </property>
</configuration>

```

配置说明

mapreduce.framework.name 设置MapReduce运行平台为yarn
mapreduce.jobhistory.address 历史服务器的地址
mapreduce.jobhistory.webapp.address 历史服务器页面的地址
更多配置信息，请参考https://hadoop.apache.org/docs/stable/hadoop-mapreduce-client/hadoop-mapreduce-client-core/mapred-default.xml。
————————————————

###  修改yarn-site.xml配置文件

Yarn的HA架构基本上和HDFS一样,也是通过zk选举RM来实现高可用，参考：[ResourceManagerHA](https://hadoop.apache.org/docs/current/hadoop-yarn/hadoop-yarn-site/ResourceManagerHA.html)

配置yarn-site.xml文件：

```shell
[app@node-0 hadoop]$ cat  /data/hadoop/etc/hadoop/yarn-site.xml 
<?xml version="1.0"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->
<configuration>

<!-- Site specific YARN configuration properties -->
    <property>
      <name>yarn.resourcemanager.ha.enabled</name>
      <value>true</value>
    </property>
    <property>
      <name>yarn.resourcemanager.cluster-id</name>
      <value>cluster1</value>
    </property>

    <property>
      <name>yarn.resourcemanager.recovery.enabled</name>
      <value>true</value>
    </property>
    <property>
      <name>yarn.resourcemanager.store.class</name>
      <value>org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore</value>
    </property>
	
    <property>
      <name>yarn.resourcemanager.ha.rm-ids</name>
      <value>rm1,rm2,rm3</value>
    </property>
    <property>
      <name>yarn.resourcemanager.hostname.rm1</name>
      <value>node-0</value>
    </property>
    <property>
      <name>yarn.resourcemanager.hostname.rm2</name>
      <value>node-1</value>
    </property>
    <property>
      <name>yarn.resourcemanager.hostname.rm3</name>
      <value>node-2</value>
    </property>
    <property>
      <name>yarn.resourcemanager.webapp.address.rm1</name>
      <value>node-0:8088</value>
    </property>
    <property>
      <name>yarn.resourcemanager.webapp.address.rm2</name>
      <value>node-1:8088</value>
    </property>
    <property>
      <name>yarn.resourcemanager.webapp.address.rm3</name>
      <value>node-2:8088</value>
    </property> 
   <property>
      <name>hadoop.zk.address</name>
      <value>node-0:2181,node-1:2181,node-2:2181</value>
    </property>

    <property>
      <name>yarn.nodemanager.aux-services</name>
      <value>mapreduce_shuffle</value>
    </property>
    <property>
      <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
      <value>org.apache.hadoop.mapred.ShuffleHandler</value>
    </property>
	
    <property>
      <name>yarn.log-aggregation-enable</name>
      <value>true</value>
    </property>
    <property>
      <name>yarn.log-aggregation.retain-seconds</name>
      <value>604800</value>
    </property>	
</configuration>

```

配置说明，更多配置信息，请参考[yarn-site.xml](http://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-common/yarn-default.xml)。

yarn.resourcemanager.hostname 配置yarn启动的主机名，也就是说配置在哪台虚拟机上就在那台虚拟机上进行启动
yarn.application.classpath 配置yarn执行任务调度的类路径，如果不配置，yarn虽然可以启动，但执行不了mapreduce。执行hadoop classpath命令,将出现的类路径放在标签里
————————————————

###  修改workers配置文件

```shell
[app@node-0 hadoop]$ cat <<EOF > /data/hadoop/etc/hadoop/workers 
node-0
node-1
node-2
EOF
```

配置说明

- workers 配置datanode工作的机器，而datanode主要是用来存放数据文件的

### 分发配置文件

分发配置文件到其他节点

```shell

```

## 启动hadoop服务

按以下顺序启动hadoop相关服务：

### 1、初始化zookeeper

格式化ZooKeeper集群，目的是在ZooKeeper集群上建立HA的相应节点，任意节点执行

```shell
hdfs zkfc -formatZK
```

验证zkfc是否格式化成功

```shell
$ /data/zookeeper/bin/zkCli.sh
[zk: localhost:2181(CONNECTED) 0]  ls /hadoop-ha 
[mycluster]

```

### 2、启动journalnode

在三节点分别启动journalnode

```shell
hdfs --daemon start journalnode
```

### 3、启动namenode

在其中一个namenode节点执行格式化，以在node-0节点为例

```shell
hdfs namenode -format
```

启动node-0节点nameNode

```shell
hdfs --daemon start namenode
```

将node-0节点上namenode的数据同步到其他nameNode节点，在node-1、node-2节点执行：

```shell
hdfs namenode -bootstrapStandby
```

启动node-1、node-2节点nameNode

```shell
hdfs --daemon start namenode
```


浏览器访问NameNode,当前所有NameNode都是standby状态：

http://ip:9870/

![image-20220218164412776](C:\Users\li.siping\AppData\Roaming\Typora\typora-user-images\image-20220218164412776.png)

### 4、启动datanode

```shell
hdfs --daemon start datanode
```



### 5、启动/停止所有其他服务，包括zkfc

```shell
/data/hadoop/sbin/start-all.sh

/data/hadoop/sbin/stop-all.sh
```

此时再次查看nameNode界面，发现已经选举出一个active节点:

![image-20220218164443774](C:\Users\li.siping\AppData\Roaming\Typora\typora-user-images\image-20220218164443774.png)

查看nn主备状态

```shell
[app@node-2 ~]$ hdfs haadmin -getServiceState nn2
standby
[app@node-2 ~]$ hdfs haadmin -getServiceState nn1
standby
[app@node-2 ~]$ hdfs haadmin -getServiceState nn3
active
```



查看rm主备状态

```shell
[app@node-0 ~]$ yarn rmadmin -getServiceState rm1
active
[app@node-0 ~]$ yarn rmadmin -getServiceState rm3
standby
[app@node-0 ~]$ yarn rmadmin -getServiceState rm2
standby

```

启动成功之后，使用jps可以看到各个节点的进程。

```shell
[app@node-0 ~]$ jps
16037 DataNode
16151 JournalNode
16408 ResourceManager
17624 Jps
15945 NameNode
16269 DFSZKFailoverController
8111 QuorumPeerMain
12975 NodeManager

[app@node-1 ~]$ jps
15665 DataNode
16116 DFSZKFailoverController
12405 NodeManager
15528 NameNode
15913 JournalNode
17594 Jps
5390 QuorumPeerMain
16575 ResourceManager

[app@node-2 ~]$ jps
14240 DataNode
14625 ResourceManager
7474 QuorumPeerMain
14466 DFSZKFailoverController
14148 NameNode
15476 Jps
9781 NodeManager
14350 JournalNode


```





使用systemd管理hadoop服务，所有节点配置

```shell
cat <<'EOF' > /etc/systemd/system/hadoop.service 
[Unit]  
Description=hadoop
After=syslog.target network.target remote-fs.target nss-lookup.target network-online.target
Requires=network-online.target
  
[Service]
Type=forking
User=app
Group=app
ExecStart=/data/hadoop/sbin/start-all.sh
ExecStop=/data/hadoop/sbin/stop-all.sh  
WorkingDirectory=/data/hadoop
TimeoutStartSec=1min
Restart=no
RestartSec=30
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart hadoop.service 
systemctl enable hadoop.service 


```



```shell
[app@node-2 ~]$ hdfs haadmin -getServiceState nn1
standby
[app@node-2 ~]$ hdfs haadmin -getServiceState nn2
standby
[app@node-2 ~]$ hdfs haadmin -getServiceState nn3
active


```



## 验证hadoop功能

hdfs测试

```shell
[app@node-1 ~]$ echo abc > a.txt
[app@node-1 ~]$ hadoop fs -put a.txt /a.txt
[app@node-1 ~]$  hdfs dfs -ls /
Found 2 items
-rw-r--r--   3 app supergroup          4 2022-02-18 17:05 /a.txt

```

### 验证HA高可用性

测试是否能够完成自动故障转移。

在master1节点active namenode上执行 jps ，确定namenode进程，kill 将其杀掉





```shell
[app@node-2 ~]$  curl http://node-0:9870/jmx?qry=Hadoop:service=NameNode,name=NameNodeStatus
{
  "beans" : [ {
    "name" : "Hadoop:service=NameNode,name=NameNodeStatus",
    "modelerType" : "org.apache.hadoop.hdfs.server.namenode.NameNode",
    "NNRole" : "NameNode",
    "HostAndPort" : "node-0:8020",
    "SecurityEnabled" : false,
    "LastHATransitionTime" : 0,
    "BytesWithFutureGenerationStamps" : 0,
    "SlowPeersReport" : null,
    "SlowDisksReport" : null,
    "State" : "standby"
  } ]
}
```

### 其他维护命令

如果手动方式启动可以执行以下命令：

```shell
#启动zkfc
hdfs --daemon start zkfc

#启动yarn
start-yarn.sh

#启动所有的HDFS服务
start-dfs.sh
stop-dfs.sh

#启动datanode
hdfs --daemon start datanode

#启动nodemanager
hdfs --daemon start nodemanager
```

https://blog.csdn.net/networken/article/details/116407042

