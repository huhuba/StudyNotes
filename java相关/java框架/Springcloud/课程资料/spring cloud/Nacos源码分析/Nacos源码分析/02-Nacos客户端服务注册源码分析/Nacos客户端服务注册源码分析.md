# Nacos客户端服务注册源码分析

## 服务注册信息

​	我们从Nacos-Client开始说起，那么说到客户端就涉及到服务注册，我们先了解一下Nacos客户端都会将什么信息传递给服务器，我们直接从Nacos Client项目的NamingTest说起

```java
public class NamingTest {
    
    @Test
    public void testServiceList() throws Exception {
        //设置Nacos  Server连接信息
        Properties properties = new Properties();
        properties.put(PropertyKeyConst.SERVER_ADDR, "127.0.0.1:8848");
        properties.put(PropertyKeyConst.USERNAME, "nacos");
        properties.put(PropertyKeyConst.PASSWORD, "nacos");
        //设置实例自身的信息
        Instance instance = new Instance();
        instance.setIp("1.1.1.1");
        instance.setPort(800);
        instance.setWeight(2);
        //设置元信息
        Map<String, String> map = new HashMap<String, String>();
        map.put("netType", "external");
        map.put("version", "2.0");
        instance.setMetadata(map);
    
        NamingService namingService = NacosFactory.createNamingService(properties);
        namingService.registerInstance("nacos.test.1", instance);
        
        ThreadUtils.sleep(5000L);
        
        List<Instance> list = namingService.getAllInstances("nacos.test.1");
        
        System.out.println(list);
        
        ThreadUtils.sleep(30000L);
        //        ExpressionSelector expressionSelector = new ExpressionSelector();
        //        expressionSelector.setExpression("INSTANCE.metadata.registerSource = 'dubbo'");
        //        ListView<String> serviceList = namingService.getServicesOfServer(1, 10, expressionSelector);
        
    }
}
```

​	其实这就是客户端注册的一个测试类，它模仿了一个真实的服务注册进Nacos的过程，包括NacosServer连接、实例的创建、实例属性的赋值、注册实例，所以在这个其中包含了服务注册的核心代码，仅从此处的代码分析，可以看出，Nacos注册服务实例时，包含了两大类信息：Nacos Server连接信息和实例信息。



### Nacos Server连接信息

Nacos Server连接信息，存储在Properties当中，包含以下信息：

- Server地址：Nacos服务器地址，属性的key为serverAddr；
- 用户名：连接Nacos服务的用户名，属性key为username，默认值为nacos；
- 密码：连接Nacos服务的密码，属性key为password，默认值为nacos；



### 实例信息

注册实例信息用Instance对象承载，注册的实例信息又分两部分：实例基础信息和元数据。

**实例基础信息包括**：

- instanceId：实例的唯一ID；
- ip：实例IP，提供给消费者进行通信的地址；
- port： 端口，提供给消费者访问的端口；
- weight：权重，当前实例的权限，浮点类型（默认1.0D）；
- healthy：健康状况，默认true；
- enabled：实例是否准备好接收请求，默认true；
- ephemeral：实例是否为瞬时的，默认为true；
- clusterName：实例所属的集群名称；
- serviceName：实例的服务信息；

Instance类包含了实例的基础信息之外，还包含了用于**存储元数据的metadata**（描述数据的数据），类型为HashMap，从当前这个Demo中我们可以得知存放了两个数据：

- netType：顾名思义，网络类型，这里的值为external，也就是外网的意思；
- version：版本，Nacos的版本，这里是2.0这个大版本。

除了Demo中这些“自定义”的信息，在Instance类中还定义了一些默认信息，这些信息通过get方法提供：

```java
public long getInstanceHeartBeatInterval() {
    return getMetaDataByKeyWithDefault(PreservedMetadataKeys.HEART_BEAT_INTERVAL,
                                       Constants.DEFAULT_HEART_BEAT_INTERVAL);
}

public long getInstanceHeartBeatTimeOut() {
    return getMetaDataByKeyWithDefault(PreservedMetadataKeys.HEART_BEAT_TIMEOUT,
                                       Constants.DEFAULT_HEART_BEAT_TIMEOUT);
}

public long getIpDeleteTimeout() {
    return getMetaDataByKeyWithDefault(PreservedMetadataKeys.IP_DELETE_TIMEOUT,
                                       Constants.DEFAULT_IP_DELETE_TIMEOUT);
}

public String getInstanceIdGenerator() {
    return getMetaDataByKeyWithDefault(PreservedMetadataKeys.INSTANCE_ID_GENERATOR,
                                       Constants.DEFAULT_INSTANCE_ID_GENERATOR);
}
```

上面的get方法在需要元数据默认值时会被用到：

- preserved.heart.beat.interval：心跳间隙的key，默认为5s，也就是默认5秒进行一次心跳；
- preserved.heart.beat.timeout：心跳超时的key，默认为15s，也就是默认15秒收不到心跳，实例将会标记为不健康；
- preserved.ip.delete.timeout：实例IP被删除的key，默认为30s，也就是30秒收不到心跳，实例将会被移除；
- preserved.instance.id.generator：实例ID生成器key，默认为simple；

这些都是Nacos默认提供的值，也就是当前实例注册时会告诉Nacos Server说：我的心跳间隙、心跳超时等对应的值是多少，你按照这个值来判断我这个实例是否健康。

有了这些信息，我们基本是已经知道注册实例时需要传递什么参数，需要配置什么参数了。

## NamingService接口

​	NamingService接口是Nacos命名服务对外提供的一个统一接口，看对应的源码就可以发现，它提供了大量实例相关的接口方法：

- 服务实例注册

  ```java
  void registerInstance(...) throws NacosException;
  ```

- 服务实例注销

  ```java
  void deregisterInstance(...) throws NacosException;
  ```

- 获取服务实例列表

  ```java
  List<Instance> getAllInstances(...) throws NacosException;
  ```

- 查询健康服务实例

  ```java
  List<Instance> selectInstances(...) throws NacosException;
  ```

- 查询集群中健康的服务实例

  ```java
  List<Instance> selectInstances(....List<String> clusters....)throws NacosException;
  ```

- 使用负载均衡策略选择一个健康的服务实例

  ```java
  Instance selectOneHealthyInstance(...) throws NacosException;
  ```

- 订阅服务事件

  ```java
  void subscribe(...) throws NacosException;
  ```

- 取消订阅服务事件

  ```java
  void unsubscribe(...) throws NacosException;
  ```

- 获取所有（或指定）服务名称

  ```java
  ListView<String> getServicesOfServer(...) throws NacosException;
  ```

- 获取所有订阅的服务

  ```java
   List<ServiceInfo> getSubscribeServices() throws NacosException;
  ```

- 获取Nacos服务的状态

  ```java
  String getServerStatus();
  ```

- 主动关闭服务

  ```java
  void shutDown() throws NacosException
  ```

在这些方法中提供了大量的重载方法，应用于不同场景和不同类型实例或服务的筛选，所以我们只需要在不同的情况下使用不同的方法即可。

NamingService的实例化是通过NamingFactory类和上面的Nacos服务信息，从代码中可以看出这里采用了反射机制来实例化NamingService，具体的实现类为NacosNamingService：

```java
//NamingFactory
public static NamingService createNamingService(Properties properties) throws NacosException {
    try {
        Class<?> driverImplClass = Class.forName("com.alibaba.nacos.client.naming.NacosNamingService");
        Constructor constructor = driverImplClass.getConstructor(Properties.class);
        return (NamingService) constructor.newInstance(properties);
    } catch (Throwable e) {
        throw new NacosException(NacosException.CLIENT_INVALID_PARAM, e);
    }
}
```

## NacosNamingService的实现

​	在示例代码中使用了NamingService的registerInstance方法来进行服务实例的注册，该方法接收两个参数，服务名称和实例对象。这个方法的最大作用是设置了当前实例的分组信息。我们知道，在Nacos中，通过Namespace、group、Service、Cluster等一层层的将实例进行环境的隔离。在这里设置了默认的分组为“DEFAULT_GROUP”。

```java
@Override
public void registerInstance(String serviceName, Instance instance) throws NacosException {
    registerInstance(serviceName, Constants.DEFAULT_GROUP, instance);
}
```

紧接着调用的registerInstance方法如下，这个方法实现了两个功能：

​	第一，检查心跳时间设置的对不对（心跳默认为5秒）

​	第二，通过NamingClientProxy这个代理来执行服务注册操作

```java
@Override
public void registerInstance(String serviceName, String groupName, Instance instance) throws NacosException {
    NamingUtils.checkInstanceIsLegal(instance);//检查心跳
    clientProxy.registerService(serviceName, groupName, instance);//通过代理执行服务注册操作
}
```

通过clientProxy我们发现NamingClientProxy这个代理接口的具体实现是有NamingClientProxyDelegate来完成的，这个可以从NacosNamingService构造方法中来看出。

```java
public NacosNamingService(Properties properties) throws NacosException {
    init(properties);
}
```

初始化在init方法中

```java
private void init(Properties properties) throws NacosException {
    ValidatorUtils.checkInitParam(properties);
    this.namespace = InitUtils.initNamespaceForNaming(properties);
    InitUtils.initSerialization();
    InitUtils.initWebRootContext(properties);
    initLogName(properties);

    this.changeNotifier = new InstancesChangeNotifier();
    NotifyCenter.registerToPublisher(InstancesChangeEvent.class, 16384);
    NotifyCenter.registerSubscriber(changeNotifier);
    this.serviceInfoHolder = new ServiceInfoHolder(namespace, properties);
    this.clientProxy = new NamingClientProxyDelegate(this.namespace, serviceInfoHolder, properties, changeNotifier);//在这里进行了初始化，并看出使用的是NamingClientProxyDelegate来完成的
}
```

## NamingClientProxyDelegate中实现

根据上方的分析和源码的阅读，我们可以发现NamingClientProxy调用registerService实际上调用的就是NamingClientProxyDelegate的对应方法：

```java
@Override
public void registerService(String serviceName, String groupName, Instance instance) throws NacosException {
    getExecuteClientProxy(instance).registerService(serviceName, groupName, instance);
}
```

真正调用注册服务的并不是代理实现类，而是根据当前实例是否为瞬时对象，来选择对应的客户端代理来进行请求的：

如果当前实例为瞬时对象，则采用gRPC协议（NamingGrpcClientProxy）进行请求，否则采用http协议（NamingHttpClientProxy）进行请求。默认为瞬时对象，也就是说，2.0版本中默认采用了gRPC协议进行与Nacos服务进行交互。

```java
private NamingClientProxy getExecuteClientProxy(Instance instance) {
    return instance.isEphemeral() ? grpcClientProxy : httpClientProxy;
}
```



## NamingGrpcClientProxy中实现

关于gRPC协议（NamingGrpcClientProxy），我们后续在做展开，我们主要关注一下registerService方法实现，这里其实做了两件事情

1. 缓存当前注册的实例信息用于恢复，缓存的数据结构为ConcurrentMap<String, Instance>，key为“serviceName@@groupName”，value就是前面封装的实例信息。
2. 另外一件事就是封装了参数，基于gRPC进行服务的调用和结果的处理。

```java
@Override
public void registerService(String serviceName, String groupName, Instance instance) throws NacosException {
    NAMING_LOGGER.info("[REGISTER-SERVICE] {} registering service {} with instance {}", namespaceId, serviceName,
                       instance);
    redoService.cacheInstanceForRedo(serviceName, groupName, instance);//缓存数据
    doRegisterService(serviceName, groupName, instance);//基于gRPC进行服务的调用
}
```



## 总结流程

汇总流程图：

![Nacos](3925826fc42846198ae5cd9a025550f4~tplv-k3u1fbpfcp-watermark.awebp)

 