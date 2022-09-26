序

以前简单用过ActiveMQ但是公司项目上使用的是RocketMQ，所以准备多花点时间在这上面，搞懂项目的配置使用。

看了很多资料，先说说我自己对RocketMQ的简单理解。不管是我们写的消费者还是生产者都属于客户端，而我们需要安装RocketMQ，这是属于服务端。和ActivieMQ、zookeeper类似，消费者、生成者、服务端(NameServer)之间是采取观察者模式实现。

在操作系统上安装RocketMQ，启动服务端NameServer、启动Broker，书写Consumer代码，运行消费者。书写Producer代码，运行生产者。

基本简单逻辑是这样的，当然其中还有很多细节。平时在测试时我们都在window上使用，踩了点坑，成功完成。

安装运行

1、下载

建议下载发行版本，我试过自己编译，不知道为何报错了。

rocketmq-all-4.2.0-bin-release.zip

解压出来如下：

2、启动

NameServer

在启动之前需要配置系统环境，不然会报错。配置完成记得重启电脑

```
Please set the ROCKETMQ_HOME variable in your environment!
```

系统环境变量名：ROCKETMQ_HOME

每个人不一样，对比如上我的路径—-变量值：D:\rocketMQ

进入window命令窗口，进入bin目录下，执行

```
start mqnamesrv.cmd
```

如上则NameServer启动成功。使用期间，窗口不要关机。

Broker

同理，再次开一个命令窗口，进入bin目录下，输入

```
start mqbroker.cmd -n localhost:9876
```

如上的 ip+port 是NameServer的进程，因为Nameser安装启动在本地，所以这里的 ip 是 localhost。

运行如上命令，可能会报如下错误。找不到或无法加载主类

如果出此情况，打开bin-->runbroker.cmd，修改%CLASSPATH%成

```
"%CLASSPATH%"
```

保存再次执行如上命令。执行成功后，窗口并不会显示什么，只是一个空窗口，代表成功。

书写代码

依赖RocketMQ

```
<dependency><groupId>org.apache.rocketmq</groupId><artifactId>rocketmq-client</artifactId><version>4.2.0</version></dependency>
```

1、Consumer

```
public class Consumer {public static void main(String[] args) throws MQClientException {//这里填写group名字DefaultMQPushConsumer consumer = new DefaultMQPushConsumer("my-group-name-A");//NameServer地址consumer.setNamesrvAddr("localhost:9876");//1：topic名字 2：tag名字consumer.subscribe("topic-name-A", "tag-name-A");consumer.registerMessageListener(new MessageListenerConcurrently() {@Overridepublic ConsumeConcurrentlyStatus consumeMessage(List<MessageExt> msgs, ConsumeConcurrentlyContext context) {for (MessageExt msg : msgs) {System.out.println(new String(msg.getBody()));}return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;}});consumer.start();System.out.println("Consumer Started!");}}
```

先运行起来

2、Producer

注意匹配相应参数：`group topic tag`

```
public class Producer {public static void main(String[] args) throws MQClientException, RemotingException, InterruptedException, MQBrokerException {DefaultMQProducer producer = new DefaultMQProducer("my-group-name-A");producer.setNamesrvAddr("localhost:9876");producer.start();Message message = new Message("topic-name-A","tag-name-A","Message : My blog address guozh.net".getBytes());producer.send(message);System.out.println("Message sended");producer.shutdown();}}
```

再次运行 producer。

然后去 Consumer 看看是否收到消息。

监控平台

和其他的MQ一样，这里也提供了Window版本可视化的监控和 Linux监控。可以看到消息消费的具体情况，但是其实在实际开发过程中，Window显示的界面数据非常少，看不到多少内容。所以实际项目中都是看 Linux 数据。

我们这边项目看MQ消费情况也是在Linux上部署查看。

但是可以学习学习，为Linux的安装拓展画面感。

1、下载

rocketmq-console

其实这里提供了安装部署的方法，可以根据实际情况来

所以一步一步来吧，首先修改配置文件。修改application.properties，具体位置如下

```
rocketmq-console\src\main\resources
```

主要如上两处需要修改，平台部署的端口。我这里 8080 没被使用，这里就用 8080。下面是NameServer的启动位置，根据自己实际情况填写即可。

2、启动
首先，上面的 Tips 也说了，看看自己的Maven镜像是不是阿里云的，不然下载jar可能下载不下来或者很慢，这里不用说了。

进入命令窗口，进入rocketmq-console目录，执行。

```
mvn clean package -Dmaven.test.skip=true
```

Build成功后，再次执行

```
java -jar target/rocketmq-console-ng-1.0.0.jar
```

完成后，进入网址即可，比如我这是 localhost:8080

ok！完成，估计后面会好好的学习RocketMQ。