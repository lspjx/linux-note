



## kafka优化

### JVM参数

建议将JVM的堆大小设置为4GB

关于GC，如果是JAVA 7：

如果CPU资源充裕建议使用CMS，-XX:+UseCurrentMarkSweepGC

如果不充裕则使用吞吐量收集器，-XX:+UseParallelGC

如果是JAVA 8就使用默认的G1收集器

综合上述，启动Kafka前设置如下环境变量参数

export KAFKA_HEAP_OPTS=--Xms6g  --Xmx6g
export KAFKA_JVM_PERFORMANCE_OPTS= -server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -Djava.awt.headless=true
上面的这些JVM设置都可以通过在kafka-server-start.sh脚本中完成

if [ "x$KAFKA_HEAP_OPTS" = "x" ]; then
    export KAFKA_HEAP_OPTS="-Xmx6G -Xms6G"
    export KAFKA_JVM_PERFORMANCE_OPTS= -server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -Djava.awt.headless=true

    export JMX_PORT="9999"

fi
当然上面的JVM设置你可以通过直接修改kafka-run-class.sh脚本来完成，如下所示：

# Memory options

if [ -z "$KAFKA_HEAP_OPTS" ]; then
  KAFKA_HEAP_OPTS="-Xmx256M"
fi

# JVM performance options

if [ -z "$KAFKA_JVM_PERFORMANCE_OPTS" ]; then
  KAFKA_JVM_PERFORMANCE_OPTS="-server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -Djava.awt.headless=true"
fi
Kafka的JMX设置
打开JMX端口方法1：

在kafka程序的bin目录下的kafka-server-start.sh启动脚本程序

if [ "x$KAFKA_HEAP_OPTS" = "x" ]; then
    export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
    export JMX_PORT="9999"  # 默认没有这一句，增加上

fi
打开JMX端口方法2：

或者直接在启动命令中增加export JMX_PORT=9988 kafka-server-start.sh -daemon ../config/server.properties

无论上面是什么方式，其实最终是由bin目录中的kafka-run-class.sh脚本来使用的，下面是该脚本的JMX设置

# JMX settings

if [ -z "$KAFKA_JMX_OPTS" ]; then
  KAFKA_JMX_OPTS="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false  -Dcom.sun.management.jmxremote.ssl=false "
fi

# JMX port to use

if [  $JMX_PORT ]; then
  KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Dcom.sun.management.jmxremote.port=$JMX_PORT "
fi
通过上面设置好之后使用hostname -i检查一下输出内容是否包含你要连接的IP地址，如果没有则修改/etc/hosts文件进行添加

如果发现依然连接不上但是telnet这个JMX端口可以连接，那么你就要修改上面的kafka-run-class.sh脚本中的内容

# JMX settings

 if [ -z "$KAFKA_JMX_OPTS" ]; then
 KAFKA_JMX_OPTS="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=[IP_ADDRESS]"
 fi

 # JMX port to use

 if [ $JMX_PORT ]; then
 KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Dcom.sun.management.jmxremote.port=$JMX_PORT "
 fi
增加-Djava.rmi.server.hostname=有些时候无法自动绑定尤其是多IP的时候，所以我们就需要手动绑定，如果hostname -i只有一个IP且就是需要被远程访问的IP，而且你的localhost可以解析到这个IP，那么不需要这个参数。