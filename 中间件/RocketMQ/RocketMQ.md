# 顺序消息的一致性

##1.如果一个Broker掉线，那么此时队列总数是否会发化？

如果发生变化，那么同一个 ShardingKey 的消息就会发送到不同的队列上，造成乱序。如果不发生变化，那消息将会发送到掉线Broker的队列上，必然是失败的。因此 Apache RocketMQ 提供了两种模式，如果要保证**严格顺序**而不是**可用性**，创建 Topic 是要指定 ```-o``` 参数（--order）为true，表示顺序消息:

```shell
> sh bin/mqadmin updateTopic -c DefaultCluster -t TopicTest -o true -n 127.0.0.1:9876
create topic to 127.0.0.1:10911 success.
TopicConfig [topicName=TopicTest, readQueueNums=8, writeQueueNums=8, perm=RW-, topicFilterType=SINGLE_TAG, topicSysFlag=0, order=true, attributes=null]
```

其次要保证NameServer中的配置 ```orderMessageEnable``` 和 ```returnOrderTopicConfigToBroker``` 必须是 true。如果上述任意一个条件不满足，则是保证可用性而不是严格顺序。

### 1.什么是严格顺序？什么是可用性？

# 批量发送消息

## 1.吞吐率（吞吐率是什么意思？）

​	https://blog.csdn.net/fengyuyeguirenenen/article/details/124091482

## 2.需要注意的是批量消息的大小不能超过 1MiB（否则需要自行分割），其次同一批 batch 中 topic 必须相同。

​	https://www.jianshu.com/p/b63a25801b3c

# 事务消息

##1.为啥先发送一个半事务消息，后续状态等待本地事务的执行结果判断commint或者rollback，而不是等待本地事务执行成功以后在发送消息？



# 消费者

## 1.冷读是什么意思？



## 2.push消费

###1.死信队列:所有死信队列都在同一个Topic下吗？

