# Nacos集群数据同步

​		当我们有服务进行注册以后，会写入注册信息同时会触发**ClientChangedEvent**事件，通过这个事件，就会开始进行Nacos的集群数据同步，当然这其中只有一个Nacos节点来处理对应的客户端请求，其实这其中还涉及到一个**负责节点**和**非负责节点**

## 负责节点

​	这是首先我们要查看的是**DistroClientDataProcessor**（客户端数据一致性处理器）类型，这个类型会处理当前节点负责的Client，那我们要查看其中的**syncToAllServer**方法。

```java
//DistroClientDataProcessor
private void syncToAllServer(ClientEvent event) {
    Client client = event.getClient();
    // 判断客户端是否为空，是否是临时实例，判断是否是负责节点
    if (null == client || !client.isEphemeral() || !clientManager.isResponsibleClient(client)) {
        return;
    }
    if (event instanceof ClientEvent.ClientDisconnectEvent) {
        // 客户端断开连接
        DistroKey distroKey = new DistroKey(client.getClientId(), TYPE);
        distroProtocol.sync(distroKey, DataOperation.DELETE);
    } else if (event instanceof ClientEvent.ClientChangedEvent) {
        // 客户端新增/修改
        DistroKey distroKey = new DistroKey(client.getClientId(), TYPE);
        distroProtocol.sync(distroKey, DataOperation.CHANGE);
    }
}
```

​	distroProtocol会循环所有其他nacos节点，提交一个异步任务，这个异步任务会延迟1s，其实这里我们就可以看到这里涉及到客户端的断开和客户端的新增和修改，对于Delete操作，由**DistroSyncDeleteTask**处理，对于Change操作，由**DistroSyncChangeTask**处理，这里我们从**DistroSyncChangeTask**来看

```java
public class DistroSyncChangeTask extends AbstractDistroExecuteTask {
    
    private static final DataOperation OPERATION = DataOperation.CHANGE;
    
    public DistroSyncChangeTask(DistroKey distroKey, DistroComponentHolder distroComponentHolder) {
        super(distroKey, distroComponentHolder);
    }
    
    @Override
    protected DataOperation getDataOperation() {
        return OPERATION;
    }
    
    // 无回调
    @Override
    protected boolean doExecute() {
        String type = getDistroKey().getResourceType();
        DistroData distroData = getDistroData(type);
        if (null == distroData) {
            Loggers.DISTRO.warn("[DISTRO] {} with null data to sync, skip", toString());
            return true;
        }
        return getDistroComponentHolder().findTransportAgent(type)
                .syncData(distroData, getDistroKey().getTargetServer());
    }
    
    // 有回调
    @Override
    protected void doExecuteWithCallback(DistroCallback callback) {
        String type = getDistroKey().getResourceType();
        DistroData distroData = getDistroData(type);
        if (null == distroData) {
            Loggers.DISTRO.warn("[DISTRO] {} with null data to sync, skip", toString());
            return;
        }
        getDistroComponentHolder().findTransportAgent(type)
                .syncData(distroData, getDistroKey().getTargetServer(), callback);
    }
    
    @Override
    public String toString() {
        return "DistroSyncChangeTask for " + getDistroKey().toString();
    }
    
    // 从DistroClientDataProcessor获取DistroData
    private DistroData getDistroData(String type) {
        DistroData result = getDistroComponentHolder().findDataStorage(type).getDistroData(getDistroKey());
        if (null != result) {
            result.setType(OPERATION);
        }
        return result;
    }
}
```

​	获取到的DistroData，其实是从ClientManager实时获取Client。

```java
// DistroClientDataProcessor
@Override
public DistroData getDistroData(DistroKey distroKey) {
    Client client = clientManager.getClient(distroKey.getResourceKey());
    if (null == client) {
        return null;
    } 
    // 把生成的同步数据放入到数组中
    byte[] data = ApplicationUtils.getBean(Serializer.class).serialize(client.generateSyncData());
    return new DistroData(distroKey, data);
}
```

​	AbstractClient继承了Client，同时给DistroClientDataProcessorClient提供Client的注册信息，包括客户端注册了哪些namespace，哪些group，哪些service，哪些instance。

```java
// AbstractClient
@Override
public ClientSyncData generateSyncData() {
    List<String> namespaces = new LinkedList<>();
    List<String> groupNames = new LinkedList<>();
    List<String> serviceNames = new LinkedList<>();
    List<InstancePublishInfo> instances = new LinkedList<>();
    for (Map.Entry<Service, InstancePublishInfo> entry : publishers.entrySet()) {
        namespaces.add(entry.getKey().getNamespace());
        groupNames.add(entry.getKey().getGroup());
        serviceNames.add(entry.getKey().getName());
        instances.add(entry.getValue());
    }
    return new ClientSyncData(getClientId(), namespaces, groupNames, serviceNames, instances);
}
```

​	这里我们在回过头来看syncData方法，这个方法实际上是由**DistroClientTransportAgent**封装为**DistroDataRequest**调用其他Nacos节点。

```java
//DistroClientTransportAgent
@Override
public boolean syncData(DistroData data, String targetServer) {
    if (isNoExistTarget(targetServer)) {
        return true;
    }
    DistroDataRequest request = new DistroDataRequest(data, data.getType());
    Member member = memberManager.find(targetServer);
    if (checkTargetServerStatusUnhealthy(member)) {
        Loggers.DISTRO.warn("[DISTRO] Cancel distro sync caused by target server {} unhealthy", targetServer);
        return false;
    }
    try {
        Response response = clusterRpcClientProxy.sendRequest(member, request);
        return checkResponse(response);
    } catch (NacosException e) {
        Loggers.DISTRO.error("[DISTRO-FAILED] Sync distro data failed! ", e);
    }
    return false;
}
```

## 非负责节点

​	当负责节点将数据发送给非负责节点以后，将要处理发送过来的Client数据。这里我们要看**DistroClientDataProcessor.processData**方法

```java
@Override
public boolean processData(DistroData distroData) {
    switch (distroData.getType()) {
        case ADD:
        case CHANGE:
            ClientSyncData clientSyncData = ApplicationUtils.getBean(Serializer.class)
                .deserialize(distroData.getContent(), ClientSyncData.class);
            //处理同步数据
            handlerClientSyncData(clientSyncData);
            return true;
        case DELETE:
            String deleteClientId = distroData.getDistroKey().getResourceKey();
            Loggers.DISTRO.info("[Client-Delete] Received distro client sync data {}", deleteClientId);
            clientManager.clientDisconnected(deleteClientId);
            return true;
        default:
            return false;
    }
}
```

​	然后来查看具体处理方法handlerClientSyncData

```java
private void handlerClientSyncData(ClientSyncData clientSyncData) {
    Loggers.DISTRO.info("[Client-Add] Received distro client sync data {}", clientSyncData.getClientId());
    // 同步客户端连接
    clientManager.syncClientConnected(clientSyncData.getClientId(), clientSyncData.getAttributes());
    // 获取Client（此时注册到的是ConnectionBasedClient）
    Client client = clientManager.getClient(clientSyncData.getClientId());
    // 更新Client数据
    upgradeClient(client, clientSyncData);
}
```

​	DistroClientDataProcessor的**upgradeClient**方法，更新Client里的注册表信息，发布对应事件

```java
private void upgradeClient(Client client, ClientSyncData clientSyncData) {
    List<String> namespaces = clientSyncData.getNamespaces();
    List<String> groupNames = clientSyncData.getGroupNames();
    List<String> serviceNames = clientSyncData.getServiceNames();
    List<InstancePublishInfo> instances = clientSyncData.getInstancePublishInfos();
    Set<Service> syncedService = new HashSet<>();
    for (int i = 0; i < namespaces.size(); i++) {
        Service service = Service.newService(namespaces.get(i), groupNames.get(i), serviceNames.get(i));
        Service singleton = ServiceManager.getInstance().getSingleton(service);
        syncedService.add(singleton);
        InstancePublishInfo instancePublishInfo = instances.get(i);
        if (!instancePublishInfo.equals(client.getInstancePublishInfo(singleton))) {
            client.addServiceInstance(singleton, instancePublishInfo);
            NotifyCenter.publishEvent(
                new ClientOperationEvent.ClientRegisterServiceEvent(singleton, client.getClientId()));
        }
    }
    for (Service each : client.getAllPublishedService()) {
        if (!syncedService.contains(each)) {
            client.removeServiceInstance(each);
            NotifyCenter.publishEvent(
                new ClientOperationEvent.ClientDeregisterServiceEvent(each, client.getClientId()));
        }
    }
}
```

​	**注意：**这里要注意下此时的Client实现类ConnectionBasedClient，只不过它的isNative属性为false，这是非负责节点和负责节点的主要区别。	

​	其实判断当前nacos节点是否为负责节点的依据就是这个**isNative属性**，如果是客户端直接注册在这个nacos节点上的ConnectionBasedClient，它的isNative属性为true；如果是由Distro协议，同步到这个nacos节点上的ConnectionBasedClient，它的isNative属性为false。

​	那其实我们都知道2.x的版本以后使用了长连接，所以**通过长连接建立在哪个节点上，哪个节点就是责任节点，客户端也只会向这个责任节点发送请求**。



## Distro协议负责集群数据统一

​	Distro为了确保集群间数据一致，不仅仅依赖于数据发生改变时的实时同步，后台也有定时任务做数据同步。

​	在1.x版本中，责任节点每5s同步所有Service的Instance列表的摘要（md5）给非责任节点，非责任节点用对端传来的服务md5比对本地服务的md5，如果发生改变，需要反查责任节点。

​	在2.x版本中，对这个流程做了改造，责任节点会发送Client全量数据，非责任节点定时检测同步过来的Client是否过期，减少1.x版本中的反查。

​	责任节点每5s向其他节点发送DataOperation=VERIFY类型的DistroData，来维持非责任节点的Client数据不过期。

```java
//DistroVerifyTimedTask 
@Override
public void run() {
    try {
        // 所有其他节点
        List<Member> targetServer = serverMemberManager.allMembersWithoutSelf();
        if (Loggers.DISTRO.isDebugEnabled()) {
            Loggers.DISTRO.debug("server list is: {}", targetServer);
        }
        for (String each : distroComponentHolder.getDataStorageTypes()) {
            // 遍历向这些节点发送 Client.isNative=true的DistroData，type = VERIFY
            verifyForDataStorage(each, targetServer);
        }
    } catch (Exception e) {
        Loggers.DISTRO.error("[DISTRO-FAILED] verify task failed.", e);
    }
}
```

​	非责任节点每5s扫描isNative=false的client，如果client30s内没有被VERIFY的DistroData更新过续租时间，会删除这个同步过来的Client数据。

```java
//ConnectionBasedClientManager->ExpiredClientCleaner
private static class ExpiredClientCleaner implements Runnable {

    private final ConnectionBasedClientManager clientManager;

    public ExpiredClientCleaner(ConnectionBasedClientManager clientManager) {
        this.clientManager = clientManager;
    }

    @Override
    public void run() {
        long currentTime = System.currentTimeMillis();
        for (String each : clientManager.allClientId()) {
            ConnectionBasedClient client = (ConnectionBasedClient) clientManager.getClient(each);
            if (null != client && client.isExpire(currentTime)) {
                clientManager.clientDisconnected(each);
            }
        }
    }
} 
-------------------------------------------------------------------------------------------
@Override
public boolean isExpire(long currentTime) {
    // 判断30s内没有续租 认为过期
    return !isNative() && currentTime - getLastRenewTime() > ClientConfig.getInstance().getClientExpiredTime();
}
```



