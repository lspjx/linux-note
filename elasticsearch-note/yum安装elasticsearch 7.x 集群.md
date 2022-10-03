1、下载安装包

```shell
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.10.0-x86_64.rpm
yum localinstall elasticsearch-7.10.0-x86_64.rpm
```

2、安装jdk
```shell
yum install -y java-11-openjdk
```

3、修改配置文件

```shell
Elasticsearch 配置选项：
使用 /etc/elasticsearch/elasticsearch.yml：
path.data：存储数据的目录路径（用逗号分隔多个位置），默认值：/var/lib/elasticsearch
path.log：日志文件的路径，默认值：/var/log/elasticsearch
cluster.name：弹性搜索集群的名称，默认值：my-application
node.name：Elasticsearch 使用 node.name 作为 Elasticsearch 特定实例的人类可读标识符，因此它包含在许多 API 的响应中。它默认为 Elasticsearch 启动时机器拥有的主机名，但可以使用 node.name 在 elasticsearch.yml 中显式配置。
network.host：默认情况下，Elasticsearch 只绑定到环回地址——例如 127.0.0.1 和 [::1]。这足以在服务器上运行单个开发节点，为了与其他服务器上的节点形成集群，您的节点需要使用 network.host 绑定到非环回地址：<HOST_IP_ADDRESS>
http.port：Elasticsearch 默认使用 9200 端口，您可以使用 http.port:<CUSTOM_PORT> 更改默认端口
discovery.seed_hosts：传递一个初始主机列表以在该节点启动时执行发现。默认值：127.0.0.1，[::1]。
cluster.initial_master_nodes：使用一组初始的主机合格节点引导集群。
bootstrap.memory_lock：启动时锁定内存
gateway.recover_after_nodes：在整个集群重新启动后阻止初始恢复，直到启动 N 个节点

使用 /etc/sysconfig/elasticsearch：
JAVA_HOME：设置要使用的自定义 Java 路径。
MAX_OPEN_FILES：打开文件的最大数量，默认为 65535。
MAX_LOCKED_MEMORY：最大锁定内存大小。如果您使用 elasticsearch.yml 中的 bootstrap.memory_lock 选项，请设置为无限制。
MAX_MAP_COUNT：一个进程可能拥有的最大内存映射区域数。如果您使用 mmapfs 作为索引存储类型，请确保将其设置为较高的值。有关更多信息，请查看有关 max_map_count 的 linux 内核文档。这是在启动 Elasticsearch 之前通过 sysctl 设置的。默认为 262144。
ES_PATH_CONF：配置文件目录（需要包含elasticsearch.yml、jvm.options、log4j2.properties文件）；默认为 /etc/elasticsearch。
ES_JAVA_OPTS：您可能想要应用的任何其他 JVM 系统属性。
ES_HOME：Elasticsearch 主目录，默认值：/usr/share/elasticsearch
PID_DIR：Elasticsearch PID 目录，默认值：/var/run/elasticsearch
RESTART_ON_UPGRADE：配置包升级重启，默认值：false。
```



master节点配置
```shell
# cat /etc/elasticsearch/elasticsearch.yml 
cluster.name: es-cluster-test
node.name: es-master01
path.data: /data/elasticsearch/data
path.logs: /data/elasticsearch/logs
bootstrap.memory_lock: true
network.host: 192.168.26.10
http.port: 9200
discovery.seed_hosts: ["es-master01", "es-master02", "es-master03"]
cluster.initial_master_nodes: ["es-master01", "es-master02", "es-master03"]
node.master: true      # master节点配置
node.data: false
node.ingest: true
node.voting_only: false
node.ml: false
xpack.ml.enabled: true
cluster.remote.connect: false
```
data节点配置
```shell
# cat /etc/elasticsearch/elasticsearch.yml 
cluster.name: es-cluster-test
node.name: es-data01
path.data: /data/elasticsearch/data
path.logs: /data/elasticsearch/logs
bootstrap.memory_lock: true
network.host: 192.168.26.15
http.port: 9200
discovery.seed_hosts: ["es-master01", "es-master02", "es-master03"]
cluster.initial_master_nodes: ["es-master01", "es-master02", "es-master03"]
node.master: false 
node.data: true        # data节点配置
node.ingest: false
node.voting_only: false
node.ml: false
xpack.ml.enabled: true
cluster.remote.connect: false
```
jvm设置
```shell
# vi /etc/elasticsearch/jvm.options
-Xms2g  # 设置50%的物理内存, 最多不超过32G
-Xmx2g

# vi /etc/sysconfig/elasticsearch
MAX_LOCKED_MEMORY=unlimited
```

4、启动服务
```shell
systemctl start elasticsearch.service
```

报错：
```shell
[1] bootstrap checks failed
[1]: memory locking requested for elasticsearch process but memory is not locked
```
解决方法：

参考：https://www.elastic.co/guide/en/elasticsearch/reference/current/setting-system-settings.html#systemd

```shell
# vim /usr/lib/systemd/system/elasticsearch.service
[Service]
... ...
LimitMEMLOCK=infinity

# systemctl daemon-reload 
# systemctl restart elasticsearch.service 
```

```shell
# curl -XGET http://192.168.26.10:9200/_cat/allocation?v&pretty
# curl -XGET http://192.168.26.10:9200/_cat/nodes?v
```



参考：

https://www.golinuxcloud.com/setup-configure-elasticsearch-cluster-7-linux/
https://www.digitalocean.com/community/tutorials/how-to-set-up-a-production-elasticsearch-cluster-on-centos-7#set-discovery-hosts


 ```
节点类型

master-eligible nodes: 主节点负责集群管理，包括索引创建/删除和跟踪集群中的节点，这使得它有资格被选为控制集群的主节点。
data node: 数据节点包含实际的索引数据。他们处理文档上的所有索引和搜索操作
ingest node：已node.ingest设置为 true（默认）的节点。摄取节点能够将摄取管道应用到文档，以便在索引之前转换和丰富文档。
Tribe node：部落节点一次可以读写多个集群
machine learning node：将 xpack.ml.enabled 和 node.ml 设置为 true 的节点，这是 Elasticsearch 默认分发中的默认行为。
co-ordinating nodes:：协调节点是接收请求的节点。它将查询发送到需要执行查询的所有分片，收集结果，并将它们发送回客户端
voting-only master-eligible nodes: A voting-only master-eligible node is a node that participates in master elections but which will not act as the cluster's elected master node.
voting-only node: 仅投票节点可以作为选举中的决胜局。
 ```

```shell
## -------------------------
## Get Elasticsearch details
## -------------------------

## Get elasticsearch cluster details
curl -XGET 'localhost:9200/_cluster/stats?human&pretty'

## Get elasticsearch cluster health
curl -XGET 'localhost:9200/_cluster/health?pretty'

## Get elasticsearch node details
curl -XGET 'localhost:9200/_cat/nodes?pretty'
curl -XGET 'localhost:9200/_nodes/stats?human&pretty'

## Get a specific node details
curl -XGET 'localhost:9200/_nodes/mynode1/stats?pretty'

## Get master node details
curl -XGET 'localhost:9200/_cat/master?v&pretty'

## Get all running tasks
curl -XGET 'localhost:9200/_cat/tasks?v&pretty'
curl -XGET 'localhost:9200/_tasks?pretty'

## Get cluster pending tasks
curl -XGET 'localhost:9200/_cluster/pending_tasks?pretty'

## Get all elasticsearch index names
curl -XGET 'localhost:9200/_cat/indices'

## Get shard details
curl -XGET 'localhost:9200/_cat/shards?pretty'
```

