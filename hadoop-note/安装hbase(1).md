## 安装hbase

```shell
####安装zookeeper##
tar xf apache-zookeeper-3.6.2-bin.tar.gz -C /data
mv /data/apache-zookeeper-3.6.2-bin /data/zookeeper
cd /data/zookeeper/conf/
mv zoo_sample.cfg zoo.cfg
mkdir /data/zookeeper/data
sed -i "s#/tmp/zookeeper#/data/zookeeper/data#" zoo.cfg

cat >> zoo.cfg <<EOF
server.1=172.16.2.145:2888:3888
server.2=172.16.2.146:2888:3888
server.3=172.16.2.147:2888:3888
EOF

read -p "请输入序号，集群第1台服务器填1，第2台服务器填2，第3台服务器填3：" number
echo $number > /data/zookeeper/data/myid

cd /data/zookeeper/bin
./zkServer.sh start
echo "###已完成zookeeper集群部署###"
echo "查看当前状态："
/data/zookeeper/bin/zkServer.sh status
echo "停止zookeeper  /data/zookeeper/bin/zkServer.sh stop"
```

使用外部zookeeper集群，需要hbase上修改配置hbase-site.xml，改为true.

完全分布式配置要求您将 `hbase.cluster.distributed`属性设置为`true`. 通常，它`hbase.rootdir`被配置为指向一个高可用的 HDFS 文件系统。

```shell
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>hdfs://namenode.example.org:8020/hbase</value>
  </property>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>node-a.example.com,node-b.example.com,node-c.example.com</value>
  </property>
</configuration>
```



```shell
##############安装jdk##############
tar -xf jdk-8u202-linux-x64.tar.gz -C /usr/local/
ln -sv /usr/local/jdk1.8.0_202 /usr/local/jdk
cat >> /etc/profile << 'EOF'
export JAVA_HOME=/usr/local/jdk
export JAVA_BIN=/usr/local/jdk/bin
export PATH=$PATH:$JAVA_HOME/bin
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
EOF
source /etc/profile
java -version
```

```shell
##########单机模式部署 ##10.10.34.35节点部署##############
tar -xf hbase-3.0.0-alpha-2-bin.tar.gz
cd /data/hbase-3.0.0-alpha-2/bin/
./start-hbase.sh  #启动hbase
登录验证
[root@hbase-0 bin]# ./hbase shell
2022-01-19T16:30:57,490 WARN  [main] util.NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
HBase Shell
Use "help" to get list of supported commands.
Use "exit" to quit this interactive shell.
For Reference, please visit: http://hbase.apache.org/book.html#shell
Version 3.0.0-alpha-2, r314e924e960d0d5c0c5e8ec436c75aaa6190b4c1, Sun Dec 19 12:54:15 UTC 2021
Took 0.0011 seconds                                                                                                                                                      
hbase:001:0> 

##停止hbase###
./bin/stop-hbase.sh
stopping hbase....................
###web ui界面访问####
http://10.10.34.35:16010/
```

## 分布式部署

| Node Name | Master | ZooKeeper | RegionServer | 外网ip       | 内网IP       |
| :-------- | :----- | :-------- | :----------- | ------------ | ------------ |
| node-a    | yes    | yes       | no           | 10.10.34.35 | 172.16.2.145 |
| node-b    | backup | yes       | yes          | 10.10.34.37 | 172.16.2.146 |
| node-c    | backup | yes       | yes          | 10.10.34.39 | 172.16.2.147 |

```shell
配置无密码 SSH 访问
node-a需要能够登录node-b和node-c（和自身）才能启动守护进程。完成此操作的最简单方法是在所有主机上使用相同的用户名，并配置从其他主机到其他主机的无密码 SSH 登录node-a

node-a，生成密钥对。
ssh-keygen -t rsa
cd /root/.ssh/
cat id_rsa.pub >> authorized_keys
ssh-copy-id root@172.16.2.146
ssh-copy-id root@172.16.2.147
node-b，生成密钥对
ssh-keygen -t rsa
cd /root/.ssh/
cat id_rsa.pub >> authorized_keys
ssh-copy-id root@172.16.2.145
ssh-copy-id root@172.16.2.147
node-c,生成秘钥对
ssh-keygen -t rsa
cd /root/.ssh/
cat id_rsa.pub >> authorized_keys
ssh-copy-id root@172.16.2.145
ssh-copy-id root@172.16.2.146

#####添加hosts文件解析主机名####
[root@hbase-0 bin]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.16.2.145 hbase-0   ###主机名自定义###
172.16.2.146 hbase-1
172.16.2.147 hbase-2
```

```shell
###node-a将运行主 master 和 ZooKeeper，下面操作在node-a执行##
tar -xf hbase-3.0.0-alpha-2-bin.tar.gz -C /data/
cat > /data/hbase-3.0.0-alpha-2/conf/regionservers <<EOF
172.16.2.146
172.16.2.147
EOF
###设置备 master#####
cat > /data/hbase-3.0.0-alpha-2/conf/backup-masters <<EOF  ##backup-masters文件默认不存在，需要自行创建####
172.16.2.146
172.16.2.147
EOF
###配置 hbase-site.xml###
vim /data/hbase-3.0.0-alpha-2/conf/hbase-site.xml 
<configuration>
·······  
  <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>172.16.2.145:2181,172.16.2.146:2181,172.16.2.147:2181</value>
  </property>
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>/data/zookeeper/data</value>
  </property>
  <property>
    <name>hbase.rootdir</name>
    <value>/data/hbase</value>  #如果关联外部hdfs可以写<value>hdfs://example0:8020/hbase</value>##
   </property>
</configuration>


```



```shell
cat hbase-site.xml   #官方参考配置

<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>example1,example2,example3</value>
    <description>The directory shared by RegionServers.
    </description>
  </property>
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>/export/zookeeper</value>
    <description>Property from ZooKeeper config zoo.cfg.
    The directory where the snapshot is stored.
    </description>
  </property>
  <property>
    <name>hbase.rootdir</name>
    <value>hdfs://example0:8020/hbase</value>
    <description>The directory shared by RegionServers.
    </description>
  </property>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
    <description>The mode the cluster will be in. Possible values are
      false: standalone and pseudo-distributed setups with managed ZooKeeper
      true: fully-distributed with unmanaged ZooKeeper Quorum (see hbase-env.sh)
    </description>
  </property>
</configuration>
```

```shell
cat hbase-env.sh #修改如下配置##
# The java implementation to use.
export JAVA_HOME=/usr/local/jdk/

# The maximum amount of heap to use. Default is left to JVM default.
export HBASE_HEAPSIZE=2G
# Tell HBase whether it should manage it's own instance of ZooKeeper or not.
export HBASE_MANAGES_ZK=false

####三节点都部署ntp与内网ntp服务器进行时间同步，确保集群时间保持一致#####
###HBase 集群对于时间的同步要求的比 HDFS 严格，所以，集群启动之前千万记住要进行 时间同步，要求相差不要超过 30s##
yum install -y ntp
[root@hbase-0 bin]# cat /etc/ntp.conf 
driftfile /var/lib/ntp/ntp.drift
statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable
server 10.10.34.36 iburst
server 10.10.34.228 iburst
restrict -4 default kod nomodify notrap nopeer noquery
restrict -6 default kod nomodify notrap nopeer noquery
tos orphan 8
restrict 127.0.0.1
restrict ::1
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
disable monitor

####最后可以使用 rsync 将conf目录的内容复制到集群的所有节点。####
cd /data/hbase-3.0.0-alpha-2/bin/
./start-hbase.sh  #启动hbase

### 单独启动各个模块命令 ####
cd /data/hbase-3.0.0-alpha-2/bin/
hbase-daemon.sh start master            ####启动HMaster进程
./hbase-daemon.sh start regionserver    ###启动HRegionServer进程
                                         
### web ui 界面访问 ####
http://10.10.34.35:16010/
```

```shell
Start and stop a backup HBase Master (HMaster) server.

在同一硬件上运行多个 HMaster 实例在生产环境中没有意义，就像运行伪分布式集群对生产没有意义一样。此步骤仅用于测试和学习目的。
HMaster 服务器控制 HBase 集群。您最多可以启动 9 个备份 HMaster 服务器，算上主服务器，总共有 10 个 HMaster。要启动备份 HMaster，请使用local-master-backup.sh. 对于您要启动的每个备份主机，添加一个表示该主机的端口偏移量的参数。每个 HMaster 使用两个端口（默认为 16000 和 16010）。端口偏移量添加到这些端口，因此使用偏移量 2，备份 HMaster 将使用端口 16002 和 16012。以下命令使用端口 16002/16012、16003/16013 和 16005/16015 启动 3 个备份服务器。

$ ./bin/local-master-backup.sh start 2 3 5
要在不杀死整个集群的情况下杀死备份主服务器，您需要找到它的进程 ID (PID)。PID 存储在名称类似于/tmp/hbase-USER-X-master.pid的文件中。该文件的唯一内容是 PID。您可以使用该kill -9命令来终止该 PID。以下命令将杀死端口偏移为 1 的主节点，但保持集群运行：

$ cat /tmp/hbase-testuser-1-master.pid |xargs kill -9
启动和停止其他 RegionServer

HRegionServer 按照 HMaster 的指示管理其 StoreFiles 中的数据。通常，集群中的每个节点运行一个 HRegionServer。在同一系统上运行多个 HRegionServer 对伪分布式模式下的测试很有用。该local-regionservers.sh命令允许您运行多个 RegionServer。它的工作方式与local-master-backup.sh命令类似，因为您提供的每个参数都代表实例的端口偏移量。每个 RegionServer 需要两个端口，默认端口是 16020 和 16030。由于 HBase 版本 1.1.0，HMaster 不使用区域服务器端口，这留下了 10 个端口（16020 到 16029 和 16030 到 16039）用于 RegionServers。为了支持额外的 RegionServer，在运行脚本之前将环境变量 HBASE_RS_BASE_PORT 和 HBASE_RS_INFO_BASE_PORT 设置为适当的值local-regionservers.sh. 例如，对于基本端口的值 16200 和 16300，可以在服务器上支持 99 个额外的 RegionServer。以下命令启动另外四个 RegionServer，在从 16022/16032 开始的顺序端口（基本端口 16020/16030 加 2）上运行。

$ .bin/local-regionservers.sh start 2 3 4 5
要手动停止 RegionServer，请使用local-regionservers.sh带有stop参数和要停止的服务器偏移量的命令。

$ .bin/local-regionservers.sh stop 3
停止 HBase。

您可以使用bin/stop-hbase.sh命令以与快速入门过程中相同的方式停止 HBase 。
```

```shell
#####部署分布式hdfs集群#####
##节点之间免密钥登录，添加hosts，前面已做好###
tar -xf hadoop-3.2.2.tar.gz -C /data
mv hadoop-3.2.2 hadoop
####配置环境变量###
cat /etc/profile
export JAVA_HOME=/usr/local/jdk
export JAVA_BIN=/usr/local/jdk/bin
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
export HADOOP_HOME=/data/hadoop

source /etc/profile
##############################
cd /data/hadoop/etc/hadoop

[root@hbase-0 hadoop]# cat hdfs-site.xml 
·····
<configuration>
<property>
        <name>dfs.replication</name>
        <!--因为我搭建的有2台DataNode服务器，副本数设置为2-->
        <value>2</value>
    </property>       
<property>
  <name>dfs.namenode.http-address</name>   
  <value>hbase-0:50070</value>
</property>
    <property>
        <name>dfs.namenode.secondary.http-address</name>
        <!--指向另一台节点的线程上运行-->
        <value>hbase-1:50090</value>
    </property>
</configuration>

[root@hbase-0 hadoop]# cat core-site.xml 
····
<configuration>
    <property>
   <name>dfs.namenode.rpc-address</name>
   <value>hbase-0:8020</value>
    </property>    
    <property>
        <name>hadoop.tmp.dir</name>
        <!--修改文件保存的路径-->
        <value>/data/hdfs</value>
    </property>
</configuration>
###格式化namenode节点###
hdfs namenode -format
#####启动使用root用户###启动脚本需要添加几条配置####
在/data/hadoop/sbin目录下
start-dfs.sh和stop-dfs.sh文件，添加下列参数：

HDFS_DATANODE_USER=root
HADOOP_SECURE_DN_USER=hdfs
HDFS_NAMENODE_USER=root
HDFS_SECONDARYNAMENODE_USER=root


start-yarn.sh和stop-yarn.sh文件，添加下列参数：

YARN_RESOURCEMANAGER_USER=root
HADOOP_SECURE_DN_USER=yarn
YARN_NODEMANAGER_USER=root
```

```shell
scp -r /data/hadoop root@10.10.34.37:/data/
scp -r /data/hadoop root@10.10.34.39:/data/ 

###目录拷贝到其他节点####
scp /etc/profile root@10.10.34.37:/etc/
scp /etc/profile root@10.10.34.39:/etc/
```

```shell
####主节点NameNode启动hdfs####
start-dfs.sh
##查看###
[root@hbase-0 sbin]# jps
22550 QuorumPeerMain
10774 DataNode
1064 HMaster
10632 NameNode
12392 Jps

[root@hbase-1 /]# jps
11312 Jps
2946 HMaster
9927 SecondaryNameNode
23625 QuorumPeerMain
8922 DataNode
2815 HRegionServer

[root@hbase-2 conf]# jps
31377 HRegionServer
31506 HMaster
19752 QuorumPeerMain
5064 DataNode
7022 Jps
######web页面登录主节点查看####
http://10.10.34.35:50070/

```













