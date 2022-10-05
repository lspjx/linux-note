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



## 安装与部署Doris


#### 操作系统安装要求

##### 设置系统最大打开文件句柄数

```text
vi /etc/security/limits.conf 
* soft nofile 65536
* hard nofile 65536
```

##### 时钟同步

Doris 的元数据要求时间精度要小于5000ms，所以所有集群所有机器要进行时钟同步，避免因为时钟问题引发的元数据不一致导致服务出现异常。

##### 关闭交换分区（swap）

Linux交换分区会给Doris带来很严重的性能问题，需要在安装之前禁用交换分区

##### Liunx文件系统

这里我们推荐使用ext4文件系统，在安装操作系统的时候，请选择ext4文件系统。

#### 开发测试环境

| 模块     | CPU  | 内存  | 磁盘                 | 网络     | 实例数量 |
| -------- | ---- | ----- | -------------------- | -------- | -------- |
| Frontend | 8核+ | 8GB+  | SSD 或 SATA，10GB+ * | 千兆网卡 | 1        |
| Backend  | 8核+ | 16GB+ | SSD 或 SATA，50GB+ * | 千兆网卡 | 1-3 *    |

#### 生产环境

| 模块     | CPU   | 内存  | 磁盘                     | 网络     | 实例数量（最低要求） |
| -------- | ----- | ----- | ------------------------ | -------- | -------------------- |
| Frontend | 16核+ | 64GB+ | SSD 或 RAID 卡，100GB+ * | 万兆网卡 | 1-5 *                |
| Backend  | 16核+ | 64GB+ | SSD 或 SATA，100G+ *     | 万兆网卡 | 10-100 *             |

> 注1：
>
> 1. FE 的磁盘空间主要用于存储元数据，包括日志和 image。通常从几百 MB 到几个 GB 不等。
> 2. BE 的磁盘空间主要用于存放用户数据，总磁盘空间按用户总数据量 * 3（3副本）计算，然后再预留额外 40% 的空间用作后台 compaction 以及一些中间数据的存放。
> 3. 一台机器上可以部署多个 BE 实例，但是**只能部署一个 FE**。如果需要 3 副本数据，那么至少需要 3 台机器各部署一个 BE 实例（而不是1台机器部署3个BE实例）。**多个FE所在服务器的时钟必须保持一致（允许最多5秒的时钟偏差）**
> 4. 测试环境也可以仅适用一个 BE 进行测试。实际生产环境，BE 实例数量直接决定了整体查询延迟。
> 5. 所有部署节点关闭 Swap。

> 注2：FE 节点的数量
>
> 1. FE 角色分为 Follower 和 Observer，（Leader 为 Follower 组中选举出来的一种角色，以下统称 Follower）。
> 2. FE 节点数据至少为1（1 个 Follower）。当部署 1 个 Follower 和 1 个 Observer 时，可以实现读高可用。当部署 3 个 Follower 时，可以实现读写高可用（HA）。
> 3. Follower 的数量**必须**为奇数，Observer 数量随意。
> 4. 根据以往经验，当集群可用性要求很高时（比如提供在线业务），可以部署 3 个 Follower 和 1-3 个 Observer。如果是离线业务，建议部署 1 个 Follower 和 1-3 个 Observer。

- **通常我们建议 10 ~ 100 台左右的机器，来充分发挥 Doris 的性能（其中 3 台部署 FE（HA），剩余的部署 BE）**
- **当然，Doris的性能与节点数量及配置正相关。在最少4台机器（一台 FE，三台 BE，其中一台 BE 混部一个 Observer FE 提供元数据备份），以及较低配置的情况下，依然可以平稳的运行 Doris。**
- **如果 FE 和 BE 混部，需注意资源竞争问题，并保证元数据目录和数据目录分属不同磁盘。**

#### Broker 部署

Broker 是用于访问外部数据源（如 hdfs）的进程。通常，在每台机器上部署一个 broker 实例即可。

#### 网络需求

Doris 各个实例直接通过网络进行通讯。以下表格展示了所有需要的端口

| 实例名称 | 端口名称               | 默认端口 | 通讯方向                     | 说明                                                 |
| -------- | ---------------------- | -------- | ---------------------------- | ---------------------------------------------------- |
| BE       | be_port                | 9060     | FE --> BE                    | BE 上 thrift server 的端口，用于接收来自 FE 的请求   |
| BE       | webserver_port         | 8040     | BE <--> BE                   | BE 上的 http server 的端口                           |
| BE       | heartbeat_service_port | 9050     | FE --> BE                    | BE 上心跳服务端口（thrift），用于接收来自 FE 的心跳  |
| BE       | brpc_port              | 8060     | FE <--> BE, BE <--> BE       | BE 上的 brpc 端口，用于 BE 之间通讯                  |
| FE       | http_port              | 8030     | FE <--> FE，用户 <--> FE     | FE 上的 http server 端口                             |
| FE       | rpc_port               | 9020     | BE --> FE, FE <--> FE        | FE 上的 thrift server 端口，每个fe的配置需要保持一致 |
| FE       | query_port             | 9030     | 用户 <--> FE                 | FE 上的 mysql server 端口                            |
| FE       | edit_log_port          | 9010     | FE <--> FE                   | FE 上的 bdbje 之间通信用的端口                       |
| Broker   | broker_ipc_port        | 8000     | FE --> Broker, BE --> Broker | Broker 上的 thrift server，用于接收请求              |

> 注：
>
> 1. 当部署多个 FE 实例时，要保证 FE 的 http_port 配置相同。
> 2. 部署前请确保各个端口在应有方向上的访问权限。

#### IP 绑定 

因为有多网卡的存在，或因为安装过 docker 等环境导致的虚拟网卡的存在，同一个主机可能存在多个不同的 ip。当前 Doris 并不能自动识别可用 IP。所以当遇到部署主机上有多个 IP 时，必须通过 priority_networks 配置项来强制指定正确的 IP。

priority_networks 是 FE 和 BE 都有的一个配置，配置项需写在 fe.conf 和 be.conf 中。该配置项用于在 FE 或 BE 启动时，告诉进程应该绑定哪个IP。示例如下：

```
priority_networks=10.1.3.0/24
```

这是一种 [CIDR](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing) 的表示方法。FE 或 BE 会根据这个配置项来寻找匹配的IP，作为自己的 localIP。

**注意**：当配置完 priority_networks 并启动 FE 或 BE 后，只是保证了 FE 或 BE 自身的 IP 进行了正确的绑定。而在使用 ADD BACKEND 或 ADD FRONTEND 语句中，也需要指定和 priority_networks 配置匹配的 IP，否则集群无法建立。举例：

BE 的配置为：`priority_networks=10.1.3.0/24`

但是在 ADD BACKEND 时使用的是：`ALTER SYSTEM ADD BACKEND "192.168.0.1:9050";`

则 FE 和 BE 将无法正常通信。

这时，必须 DROP 掉这个添加错误的 BE，重新使用正确的 IP 执行 ADD BACKEND。

FE 同理。

BROKER 当前没有，也不需要 priority_networks 这个选项。Broker 的服务默认绑定在 0.0.0.0 上。只需在 ADD BROKER 时，执行正确可访问的 BROKER IP 即可。

#### 表名大小写敏感性设置

doris默认为表名大小写敏感，如有表名大小写不敏感的需求需在集群初始化时进行设置。表名大小写敏感性在集群初始化完成后不可再修改。

详细参见 [变量](https://doris.apache.org/zh-CN/docs/advanced/variables##支持的变量) 中关于`lower_case_table_names`变量的介绍。

## 集群部署

### 手动部署

#### 下载安装包

https://doris.apache.org/zh-CN/docs/install/install-deploy
https://www.starrocks.com/zh-CN/download/community

https://github.com/StarRocks/starrocks
https://docs.starrocks.io/zh-cn/2.2/quick_start/Deploy

#### 解压安装包

```shell
tar -xvf StarRocks-2.3.2.tar.gz -C /opt
ln -sv /opt/StarRocks-2.3.2 /opt/starrocks
```

#### FE 部署

##### 配置 FE
配置文件 conf/fe.conf：
```shell
# 元数据目录
meta_dir = ${STARROCKS_HOME}/meta
# JVM配置
JAVA_OPTS = "-Xmx8192m -XX:+UseMembar -XX:SurvivorRatio=8 -XX:MaxTenuringThreshold=7 -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:+CMSClassUnloadingEnabled -XX:-CMSParallelRemarkEnabled -XX:CMSInitiatingOccupancyFraction=80 -XX:SoftRefLRUPolicyMSPerMB=0 -Xloggc:$STARROCKS_HOME/log/fe.gc.log"
```

```shell
# grep -Ev "^$|^#" /opt/starrocks/fe/conf/fe.conf 
LOG_DIR = ${STARROCKS_HOME}/log
DATE = "$(date +%Y%m%d-%H%M%S)"
JAVA_OPTS="-Dlog4j2.formatMsgNoLookups=true -Xmx512m -XX:+UseMembar -XX:SurvivorRatio=8 -XX:MaxTenuringThreshold=7 -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:+CMSClassUnloadingEnabled -XX:-CMSParallelRemarkEnabled -XX:CMSInitiatingOccupancyFraction=80 -XX:SoftRefLRUPolicyMSPerMB=0 -Xloggc:$STARROCKS_HOME/log/fe.gc.log.$DATE"

sys_log_level = INFO
meta_dir = /data/starrocks/fe/meta
http_port = 8030
rpc_port = 9020
query_port = 9030
edit_log_port = 9010
mysql_service_nio_enabled = true
priority_networks = 192.168.2.0/24

# mkdir -p /data/starrocks/fe/meta
```
1. 配置文件为 conf/fe.conf。其中注意：`meta_dir`是元数据存放位置。默认值为 `${DORIS_HOME}/doris-meta`。需**手动创建**该目录。

     **注意：生产环境强烈建议单独指定目录不要放在Doris安装目录下，最好是单独的磁盘（如果有SSD最好），测试开发环境可以使用默认配置**

2. fe.conf 中 JAVA_OPTS 默认 java 最大堆内存为 4GB，**建议生产环境调整至 8G 以上**。

##### 开启防火墙
```shell
firewall-cmd --permanent --add-port=8000-9060/tcp 
firewall-cmd --reload
```
##### 启动 FE 进程
```shell
bin/start_fe.sh --daemon
```
FE进程启动进入后台执行。日志默认存放在 log/ 目录下。如启动失败，可以通过查看 log/fe.log 或者 log/fe.out 查看错误信息。

##### 通过浏览器访问
- 使用浏览器访问 `FE ip:http_port`（默认 8030），打开 StarRocks 的 WebUI， 用户名为 root， 密码为空。

#### 使用 MySQL 客户端访问 FE
StarRocks 可通过 Mysql 客户端进行连接，使用 Add/Drop 命令添加/删除 fe/be 节点，实现对集群的 [扩容/缩容](https://docs.starrocks.io/zh-cn/2.2/administration/Scale_up_down) 操作。

##### 第一步: 安装 mysql 客户端，版本建议 5.5+(如果已经安装，可忽略此步)：

```shell
Ubuntu：sudo apt-get install mysql-client
Centos：sudo yum install mysql-client
```

##### 第二步: FE 进程启动后，使用 mysql 客户端连接 FE 实例：

```sql
# mysql -h 127.0.0.1 -P9030 -uroot
```

注意：这里默认 root 用户密码为空，端口为 fe/conf/fe.conf 中的 query_port 配置项，默认为 9030

#####  第三步: 查看 FE 状态：

```plaintext
mysql> SHOW PROC '/frontends'\G
*************************** 1. row ***************************
             Name: 192.168.2.121_9010_1664874142461
               IP: 192.168.2.121
      EditLogPort: 9010
         HttpPort: 8030
        QueryPort: 9030
          RpcPort: 9020
             Role: FOLLOWER
         IsMaster: false
        ClusterId: 100222780
             Join: true
            Alive: true
ReplayedJournalId: 1641
    LastHeartbeat: 2022-10-04 17:35:42
         IsHelper: true
           ErrMsg: 
        StartTime: 2022-10-04 17:11:59
          Version: 2.3.2-dbc89ae
```

**Role** 为 **FOLLOWER** 说明这是一个能参与选主的 FE；
**IsMaster** 为 **true**，说明该 FE 当前为主节点。

如果 MySQL 客户端连接不成功，请查看 log/fe.warn.log 日志文件，确认问题。由于是初次启动，如果在操作过程中遇到任何意外问题，都可以删除并重新创建 FE 的元数据目录，再从头开始操作。

#### BE 部署

##### 修改 BE 的配置
```shell
# mkdir -p /data/starrocks/be/data{1,2,3}

# grep -Ev "^$|^#" /opt/starrocks/be/conf/be.conf 
sys_log_level = INFO
be_port = 9060
webserver_port = 8040
heartbeat_service_port = 9050
brpc_port = 8060
storage_root_path = /data/starrocks/be/data1,medium:HDD;/data/starrocks/be/data2,medium:HDD;/data/starrocks/be/data3
default_rowset_type = beta
```

修改 be/conf/be.conf。主要是配置 `storage_root_path`：数据存放目录。默认在be/storage下，需要**手动创建**该目录。多个路径之间使用英文状态的分号 `;` 分隔（**最后一个目录后不要加 `;`**）。可以通过路径区别存储目录的介质，HDD或SSD。可以添加容量限制在每个路径的末尾，通过英文状态逗号`,`隔开。
如果用户不是SSD和HDD磁盘混合使用的情况，不需要按照如下示例一和示例二的配置方法配置，只需指定存储目录即可；也不需要修改FE的默认存储介质配置。

示例1如下：
**注意：如果是SSD磁盘要在目录后面加上`.SSD`,HDD磁盘在目录后面加`.HDD`**
`storage_root_path=/home/disk1/doris.HDD;/home/disk2/doris.SSD;/home/disk2/doris`

**说明**
- /home/disk1/doris.HDD，表示存储介质是HDD;
- /home/disk2/doris.SSD，表示存储介质是SSD；
- /home/disk2/doris，存储介质默认为HDD

示例2如下：
**注意：不论HDD磁盘目录还是SSD磁盘目录，都无需添加后缀，storage_root_path参数里指定medium即可**
`storage_root_path=/home/disk1/doris,medium:hdd;/home/disk2/doris,medium:ssd`

**说明**
- /home/disk1/doris,medium:hdd，表示存储介质是HDD;
- /home/disk2/doris,medium:ssd，表示存储介质是SSD;

- BE webserver_port端口配置
 如果 be 部署在 hadoop 集群中，注意调整 be.conf 中的 `webserver_port = 8040` ,以免造成端口冲突

- 在 FE 中添加所有 BE 节点
 BE 节点需要先在 FE 中添加，才可加入集群。可以使用 mysql-client([下载MySQL 5.7](https://dev.mysql.com/downloads/mysql/5.7.html)) 连接到 FE：
 `./mysql-client -h fe_host -P query_port -uroot`

其中 fe_host 为 FE 所在节点 ip；query_port 在 fe/conf/fe.conf 中的；默认使用 root 账户，无密码登录。
```shell
# mysql -h 127.0.0.1 -P9030 -uroot
```

##### 添加 BE 节点到集群
通过MySQL 客户端连接到 FE 之后执行下面的 SQL，将 BE 添加到集群中
```sql
ALTER SYSTEM ADD BACKEND "be_host_ip:heartbeat_service_port";

# mysql -h 127.0.0.1 -P9030 -uroot
mysql> ALTER SYSTEM ADD BACKEND "node01:9050";
mysql> show proc '/backends';
```
1. be_host_ip：这里是你 BE 的 IP 地址，和你在 `be.conf` 里的 `priority_networks` 匹配
2. heartbeat_service_port：这里是你 BE 的心跳上报端口，和你在 `be.conf` 里的 `heartbeat_service_port` 匹配，默认是 `9050`

##### 启动 BE
```shell
bin/start_be.sh --daemon
```
BE 进程将启动并进入后台执行。日志默认存放在 be/log/ 目录下。如启动失败，可以通过查看 be/log/be.log 或者 be/log/be.out 查看错误信息。

##### 查看BE状态
使用 mysql-client 连接到 FE，并执行 `SHOW PROC '/backends';` 查看 BE 运行情况。如一切正常，`isAlive` 列应为 `true`。
```shell
mysql> SHOW PROC '/backends'\G
*************************** 1. row ***************************
            BackendId: 10028
              Cluster: default_cluster
                   IP: 192.168.2.123
        HeartbeatPort: 9050
               BePort: 9060
             HttpPort: 8040
             BrpcPort: 8060
        LastStartTime: 2022-10-04 16:57:50
        LastHeartbeat: 2022-10-04 17:34:52
                Alive: true
 SystemDecommissioned: false
ClusterDecommissioned: false
            TabletNum: 3
     DataUsedCapacity: .000 
        AvailCapacity: 140.152 GB
        TotalCapacity: 140.908 GB
              UsedPct: 0.54 %
       MaxDiskUsedPct: 0.54 %
               ErrMsg: 
              Version: 2.3.2-dbc89ae
               Status: {"lastSuccessReportTabletsTime":"2022-10-04 17:34:51"}
    DataTotalCapacity: 140.152 GB
          DataUsedPct: 0.00 %
             CpuCores: 2
```

#### Broker 部署（可选）

Broker 以插件的形式，独立于 Doris 部署。如果需要从第三方存储系统导入数据，需要部署相应的 Broker，默认提供了读取 HDFS 、对象存储的 fs_broker。fs_broker 是无状态的，建议每一个 FE 和 BE 节点都部署一个 Broker。

配置文件为 apache_hdfs_broker/conf/apache_hdfs_broker.conf

> 注意：Broker 没有也不需要 priority_networks 参数，Broker 的服务默认绑定在 0.0.0.0 上，只需要在 ADD BROKER 时，填写正确可访问的 Broker IP 即可。

如果有特殊的 hdfs 配置，复制线上的 hdfs-site.xml 到 conf 目录下

启动 broker：

```shell
./apache_hdfs_broker/bin/start_broker.sh --daemon
```

添加 broker 节点到集群中：

```sql
MySQL> ALTER SYSTEM ADD BROKER broker "node01:8000","node02:8000","node03:8000";
```

查看 broker 状态：

```plaintext
mysql> SHOW PROC "/brokers"\G
*************************** 1. row ***************************
          Name: broker
            IP: 192.168.2.122
          Port: 8000
         Alive: true
 LastStartTime: 2022-10-04 17:25:45
LastUpdateTime: 2022-10-04 17:26:00
        ErrMsg: 
*************************** 2. row ***************************
          Name: broker
            IP: 192.168.2.123
          Port: 8000
         Alive: true
 LastStartTime: 2022-10-04 17:25:55
LastUpdateTime: 2022-10-04 17:26:00
        ErrMsg: 
*************************** 3. row ***************************
          Name: broker
            IP: 192.168.2.121
          Port: 8000
         Alive: true
 LastStartTime: 2022-10-04 17:25:35
LastUpdateTime: 2022-10-04 17:26:00
        ErrMsg: 
3 rows in set (0.01 sec)

```

Alive 为 true 代表状态正常。



## 扩容缩容

### FE扩缩容

StarRocks 有两种 FE 节点：Follower 和 Observer。Follower参与选举投票和写入，Observer只用来同步日志，扩展读性能。

FE扩缩容时要注意：

- Follower FE(包括Master)的数量必须为奇数，建议部署3个，组成高可用(HA)模式即可。
- 当 FE 处于高可用部署时（1个Master，2个Follower），建议通过增加 Observer FE 来扩展 FE 的读服务能力。当然也可以继续增加 Follower FE，但几乎是不必要的。
- 通常一个 FE 节点可以应对 10-20 台 BE 节点。建议总的 FE 节点数量在 10 个以下。而3个即可满足绝大部分需求。

#### FE扩容

部署好FE节点，启动完成服务。

```sql
bin/start_fe.sh --helper "fe_host:edit_log_port" --daemon ;
--fe_host为master节点的ip

# bin/start_fe.sh --helper "node01:9010" --daemon
```

通过命令扩容FE节点。

```sql
alter system add follower "fe_host:edit_log_port";
alter system add observer "fe_host:edit_log_port";

alter system add follower "node02:9010";
alter system add observer "node03:9010";
```

#### FE缩容

缩容和扩容命令类似

```sql
alter system drop follower "fe_host:edit_log_port";
alter system drop observer "fe_host:edit_log_port";
```

扩缩容完成后可以通过 `show proc '/frontends';`查看节点信息

### BE扩缩容

BE 扩缩容后，StarRocks 会自动根据负载情况，进行数据均衡，期间不影响使用。

#### BE扩容

- 运行命令进行扩容

```sql
alter system add backend 'be_host:be_heartbeat_service_port';

alter system add backend "node02:9050";
alter system add backend "node03:9050";
```

- 运行命令查看BE状态

```sql
show proc '/backends';
```

#### BE缩容

缩容BE有两种方式： DROP和DECOMMISSION。

DROP会立刻删除BE节点，丢失的副本由FE调度补齐；DECOMMISSION先保证副本补齐，然后再下掉BE节点。DECOMMISSION方式更加友好一点，建议采用这种方式进行缩容。

二者的命令类似：

- `alter system decommission backend "be_host:be_heartbeat_service_port";`
- `alter system drop backend "be_host:be_heartbeat_service_port";`

Drop backend是一个危险操作所以需要二次确认后执行

- `alter system drop backend "be_host:be_heartbeat_service_port";`

FE和BE扩容之后的状态，也可以通过查看[集群状态](https://docs.starrocks.io/zh-cn/2.2/administration/Cluster_administration#确认集群健康状态)一节中的页面进行查看。





## 常见问题

如果使用了supervisord，遇到句柄数错误，可以通过修改supervisord的minfds参数解决。

```shell
vim /etc/supervisord.conf

minfds=65535                 ; (min. avail startup file descriptors;default 1024)
```



## 创建数据表

1. 创建一个数据库

```sql
create database demo;
```

1. 创建数据表

```sql
use demo;

CREATE TABLE IF NOT EXISTS demo.expamle_tbl
(
    `user_id` LARGEINT NOT NULL COMMENT "用户id",
    `date` DATE NOT NULL COMMENT "数据灌入日期时间",
    `city` VARCHAR(20) COMMENT "用户所在城市",
    `age` SMALLINT COMMENT "用户年龄",
    `sex` TINYINT COMMENT "用户性别",
    `last_visit_date` DATETIME REPLACE DEFAULT "1970-01-01 00:00:00" COMMENT "用户最后一次访问时间",
    `cost` BIGINT SUM DEFAULT "0" COMMENT "用户总消费",
    `max_dwell_time` INT MAX DEFAULT "0" COMMENT "用户最大停留时间",
    `min_dwell_time` INT MIN DEFAULT "99999" COMMENT "用户最小停留时间"
)
AGGREGATE KEY(`user_id`, `date`, `city`, `age`, `sex`)
DISTRIBUTED BY HASH(`user_id`) BUCKETS 1
PROPERTIES (
    "replication_allocation" = "tag.location.default: 1"
);
```

1. 示例数据

```text
10000,2017-10-01,北京,20,0,2017-10-01 06:00:00,20,10,10
10000,2017-10-01,北京,20,0,2017-10-01 07:00:00,15,2,2
10001,2017-10-01,北京,30,1,2017-10-01 17:05:45,2,22,22
10002,2017-10-02,上海,20,1,2017-10-02 12:59:12,200,5,5
10003,2017-10-02,广州,32,0,2017-10-02 11:20:00,30,11,11
10004,2017-10-01,深圳,35,0,2017-10-01 10:00:15,100,3,3
10004,2017-10-03,深圳,35,0,2017-10-03 10:20:22,11,6,6
```

将上面的数据保存在一个test.csv文件中。

1. 导入数据

这里我们通过Stream load 方式将上面保存到文件中的数据导入到我们刚才创建的表里。

```text
curl  --location-trusted -u root: -T test.csv -H "column_separator:," http://127.0.0.1:8030/api/demo/expamle_tbl/_stream_load
```

- -T test.csv : 这里是我们刚才保存的数据文件，如果路径不一样，请指定完整路径
- -u root : 这里是用户名密码，我们使用默认用户root，密码是空
- 127.0.0.1:8030 : 分别是 fe 的 ip 和 http_port

执行成功之后我们可以看到下面的返回信息

```json
# curl  --location-trusted -u root: -T test.csv -H "column_separator:," http://127.0.0.1:8030/api/demo/expamle_tbl/_stream_load
{
    "TxnId": 10,
    "Label": "073af582-6d2c-4ca0-a9d2-7e8632ceee29",
    "Status": "Success",
    "Message": "OK",
    "NumberTotalRows": 7,
    "NumberLoadedRows": 7,
    "NumberFilteredRows": 0,
    "NumberUnselectedRows": 0,
    "LoadBytes": 399,
    "LoadTimeMs": 332,
    "BeginTxnTimeMs": 13,
    "StreamLoadPutTimeMs": 73,
    "ReadDataTimeMs": 0,
    "WriteDataTimeMs": 167,
    "CommitAndPublishTimeMs": 77
}
```

1. `NumberLoadedRows`: 表示已经导入的数据记录数
2. `NumberTotalRows`: 表示要导入的总数据量
3. `Status` :Success 表示导入成功

到这里我们已经完成的数据导入，下面就可以根据我们自己的需求对数据进行查询分析了。

## 查询数据

我们上面完成了建表，输数据导入，下面我们就可以体验 Doris 的数据快速查询分析能力。

```sql
mysql> select * from expamle_tbl;
+---------+------------+--------+------+------+---------------------+------+----------------+----------------+
| user_id | date       | city   | age  | sex  | last_visit_date     | cost | max_dwell_time | min_dwell_time |
+---------+------------+--------+------+------+---------------------+------+----------------+----------------+
| 10000   | 2017-10-01 | 北京   |   20 |    0 | 2017-10-01 07:00:00 |   35 |             10 |              2 |
| 10001   | 2017-10-01 | 北京   |   30 |    1 | 2017-10-01 17:05:45 |    2 |             22 |             22 |
| 10002   | 2017-10-02 | 上海   |   20 |    1 | 2017-10-02 12:59:12 |  200 |              5 |              5 |
| 10003   | 2017-10-02 | 广州   |   32 |    0 | 2017-10-02 11:20:00 |   30 |             11 |             11 |
| 10004   | 2017-10-01 | 深圳   |   35 |    0 | 2017-10-01 10:00:15 |  100 |              3 |              3 |
| 10004   | 2017-10-03 | 深圳   |   35 |    0 | 2017-10-03 10:20:22 |   11 |              6 |              6 |
+---------+------------+--------+------+------+---------------------+------+----------------+----------------+
6 rows in set (0.02 sec)

mysql> select * from expamle_tbl where city='上海';
+---------+------------+--------+------+------+---------------------+------+----------------+----------------+
| user_id | date       | city   | age  | sex  | last_visit_date     | cost | max_dwell_time | min_dwell_time |
+---------+------------+--------+------+------+---------------------+------+----------------+----------------+
| 10002   | 2017-10-02 | 上海   |   20 |    1 | 2017-10-02 12:59:12 |  200 |              5 |              5 |
+---------+------------+--------+------+------+---------------------+------+----------------+----------------+
1 row in set (0.05 sec)

mysql> select city, sum(cost) as total_cost from expamle_tbl group by city;
+--------+------------+
| city   | total_cost |
+--------+------------+
| 广州   |         30 |
| 上海   |        200 |
| 北京   |         37 |
| 深圳   |        111 |
+--------+------------+
4 rows in set (0.05 sec)
```

