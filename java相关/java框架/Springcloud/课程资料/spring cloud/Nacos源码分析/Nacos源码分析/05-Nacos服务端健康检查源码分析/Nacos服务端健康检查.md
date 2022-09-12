# Nacos服务端健康检查

## 长连接

概念：长连接，指在一个连接上可以连续发送多个[数据包](https://baike.baidu.com/item/数据包/489739)，在连接保持期间，如果没有数据包发送，需要双方发链路检测包

注册中心客户端2.0之后使用gRPC代替http，会与服务端建立长连接，但仍然保留了对旧http客户端的支持。

**NamingClientProxy**接口负责底层通讯，调用服务端接口。有三个实现类：

- **NamingClientProxyDelegate**：代理类，对所有NacosNamingService中的方法进行**代理**，根据实际情况选择http或gRPC协议请求服务端。
- **NamingGrpcClientProxy**：底层通讯基于gRPC长连接。
- **NamingHttpClientProxy**：底层通讯基于http短连接。使用的都是老代码基本没改，原来1.0NamingProxy重命名过来的。

以客户端**服务注册**为例，**NamingClientProxyDelegate**代理了registerService方法。

```java
// NacosNamingService.java
private NamingClientProxy clientProxy; // NamingClientProxyDelegate
public void registerInstance(String serviceName, String groupName, Instance instance) throws NacosException {
    NamingUtils.checkInstanceIsLegal(instance);
    clientProxy.registerService(serviceName, groupName, instance);
}
```

NamingClientProxyDelegate会**根据instance实例是否是临时节点而选择不同的协议**。

​	临时instance：gRPC

​	持久instance：http

```java
public class NamingClientProxyDelegate implements NamingClientProxy {
   private final NamingHttpClientProxy httpClientProxy;
   private final NamingGrpcClientProxy grpcClientProxy;
   @Override
    public void registerService(String serviceName, String groupName, Instance instance) throws NacosException {
      getExecuteClientProxy(instance).registerService(serviceName, groupName, instance);
    }
  // 临时节点，走grpc长连接；持久节点，走http短连接
  private NamingClientProxy getExecuteClientProxy(Instance instance) {
      return instance.isEphemeral() ? grpcClientProxy : httpClientProxy;
  }
}
```



## 健康检查

​	在之前的1.x版本中临时实例走Distro协议内存存储，客户端向注册中心发送心跳来维持自身healthy状态，持久实例走Raft协议持久化存储，服务端定时与客户端建立tcp连接做健康检查。

​	但是2.0版本以后持久化实例没有什么变化，但是2.0临时实例不在使用心跳，而是通过长连接是否存活来判断实例是否健康。

**ConnectionManager**负责管理所有客户端的长连接。

**每3s**检测所有超过**20s没发生过通讯**的客户端，向客户端发起**ClientDetectionRequest探测请求**，如果客户端在**1s内成功响应，则检测通过**，否则执行unregister方法移除Connection。

**如果客户端持续与服务端通讯，服务端是不需要主动探活的**

```java
//ConnectionManager.java
Map<String, Connection> connections = new ConcurrentHashMap<String, Connection>();
@PostConstruct
public void start() {

    // 启动不健康连接排除功能.
    RpcScheduledExecutor.COMMON_SERVER_EXECUTOR.scheduleWithFixedDelay(new Runnable() {
        @Override
        public void run() {
            try {

                int totalCount = connections.size();
                Loggers.REMOTE_DIGEST.info("Connection check task start");
                MetricsMonitor.getLongConnectionMonitor().set(totalCount);
                //统计过时（20s）连接
                Set<Map.Entry<String, Connection>> entries = connections.entrySet();
                int currentSdkClientCount = currentSdkClientCount();
                boolean isLoaderClient = loadClient >= 0;
                int currentMaxClient = isLoaderClient ? loadClient : connectionLimitRule.countLimit;
                int expelCount = currentMaxClient < 0 ? 0 : Math.max(currentSdkClientCount - currentMaxClient, 0);

                Loggers.REMOTE_DIGEST
                    .info("Total count ={}, sdkCount={},clusterCount={}, currentLimit={}, toExpelCount={}",
                          totalCount, currentSdkClientCount, (totalCount - currentSdkClientCount),
                          currentMaxClient + (isLoaderClient ? "(loaderCount)" : ""), expelCount);

                List<String> expelClient = new LinkedList<>();

                Map<String, AtomicInteger> expelForIp = new HashMap<>(16);

                //1. calculate expel count  of ip.
                for (Map.Entry<String, Connection> entry : entries) {

                    Connection client = entry.getValue();
                    String appName = client.getMetaInfo().getAppName();
                    String clientIp = client.getMetaInfo().getClientIp();
                    if (client.getMetaInfo().isSdkSource() && !expelForIp.containsKey(clientIp)) {
                        //get limit for current ip.
                        int countLimitOfIp = connectionLimitRule.getCountLimitOfIp(clientIp);
                        if (countLimitOfIp < 0) {
                            int countLimitOfApp = connectionLimitRule.getCountLimitOfApp(appName);
                            countLimitOfIp = countLimitOfApp < 0 ? countLimitOfIp : countLimitOfApp;
                        }
                        if (countLimitOfIp < 0) {
                            countLimitOfIp = connectionLimitRule.getCountLimitPerClientIpDefault();
                        }

                        if (countLimitOfIp >= 0 && connectionForClientIp.containsKey(clientIp)) {
                            AtomicInteger currentCountIp = connectionForClientIp.get(clientIp);
                            if (currentCountIp != null && currentCountIp.get() > countLimitOfIp) {
                                expelForIp.put(clientIp, new AtomicInteger(currentCountIp.get() - countLimitOfIp));
                            }
                        }
                    }
                }

                Loggers.REMOTE_DIGEST
                    .info("Check over limit for ip limit rule, over limit ip count={}", expelForIp.size());

                if (expelForIp.size() > 0) {
                    Loggers.REMOTE_DIGEST.info("Over limit ip expel info, {}", expelForIp);
                }

                Set<String> outDatedConnections = new HashSet<>();
                long now = System.currentTimeMillis();
                //2.get expel connection for ip limit.
                for (Map.Entry<String, Connection> entry : entries) {
                    Connection client = entry.getValue();
                    String clientIp = client.getMetaInfo().getClientIp();
                    AtomicInteger integer = expelForIp.get(clientIp);
                    if (integer != null && integer.intValue() > 0) {
                        integer.decrementAndGet();
                        expelClient.add(client.getMetaInfo().getConnectionId());
                        expelCount--;
                    } else if (now - client.getMetaInfo().getLastActiveTime() >= KEEP_ALIVE_TIME) {
                        outDatedConnections.add(client.getMetaInfo().getConnectionId());
                    }

                }

                //3. if total count is still over limit.
                if (expelCount > 0) {
                    for (Map.Entry<String, Connection> entry : entries) {
                        Connection client = entry.getValue();
                        if (!expelForIp.containsKey(client.getMetaInfo().clientIp) && client.getMetaInfo()
                            .isSdkSource() && expelCount > 0) {
                            expelClient.add(client.getMetaInfo().getConnectionId());
                            expelCount--;
                            outDatedConnections.remove(client.getMetaInfo().getConnectionId());
                        }
                    }
                }

                String serverIp = null;
                String serverPort = null;
                if (StringUtils.isNotBlank(redirectAddress) && redirectAddress.contains(Constants.COLON)) {
                    String[] split = redirectAddress.split(Constants.COLON);
                    serverIp = split[0];
                    serverPort = split[1];
                }

                for (String expelledClientId : expelClient) {
                    try {
                        Connection connection = getConnection(expelledClientId);
                        if (connection != null) {
                            ConnectResetRequest connectResetRequest = new ConnectResetRequest();
                            connectResetRequest.setServerIp(serverIp);
                            connectResetRequest.setServerPort(serverPort);
                            connection.asyncRequest(connectResetRequest, null);
                            Loggers.REMOTE_DIGEST
                                .info("Send connection reset request , connection id = {},recommendServerIp={}, recommendServerPort={}",
                                      expelledClientId, connectResetRequest.getServerIp(),
                                      connectResetRequest.getServerPort());
                        }

                    } catch (ConnectionAlreadyClosedException e) {
                        unregister(expelledClientId);
                    } catch (Exception e) {
                        Loggers.REMOTE_DIGEST.error("Error occurs when expel connection, expelledClientId:{}", expelledClientId, e);
                    }
                }

                //4.client active detection.
                Loggers.REMOTE_DIGEST.info("Out dated connection ,size={}", outDatedConnections.size());
                //异步请求所有需要检测的连接
                if (CollectionUtils.isNotEmpty(outDatedConnections)) {
                    Set<String> successConnections = new HashSet<>();
                    final CountDownLatch latch = new CountDownLatch(outDatedConnections.size());
                    for (String outDateConnectionId : outDatedConnections) {
                        try {
                            Connection connection = getConnection(outDateConnectionId);
                            if (connection != null) {
                                ClientDetectionRequest clientDetectionRequest = new ClientDetectionRequest();
                                connection.asyncRequest(clientDetectionRequest, new RequestCallBack() {
                                    @Override
                                    public Executor getExecutor() {
                                        return null;
                                    }

                                    @Override
                                    public long getTimeout() {
                                        return 1000L;
                                    }

                                    @Override
                                    public void onResponse(Response response) {
                                        latch.countDown();
                                        if (response != null && response.isSuccess()) {
                                            connection.freshActiveTime();
                                            successConnections.add(outDateConnectionId);
                                        }
                                    }

                                    @Override
                                    public void onException(Throwable e) {
                                        latch.countDown();
                                    }
                                });

                                Loggers.REMOTE_DIGEST
                                    .info("[{}]send connection active request ", outDateConnectionId);
                            } else {
                                latch.countDown();
                            }

                        } catch (ConnectionAlreadyClosedException e) {
                            latch.countDown();
                        } catch (Exception e) {
                            Loggers.REMOTE_DIGEST
                                .error("[{}]Error occurs when check client active detection ,error={}",
                                       outDateConnectionId, e);
                            latch.countDown();
                        }
                    }

                    latch.await(3000L, TimeUnit.MILLISECONDS);
                    Loggers.REMOTE_DIGEST
                        .info("Out dated connection check successCount={}", successConnections.size());
					// 对于没有成功响应的客户端，执行unregister移出
                    for (String outDateConnectionId : outDatedConnections) {
                        if (!successConnections.contains(outDateConnectionId)) {
                            Loggers.REMOTE_DIGEST
                                .info("[{}]Unregister Out dated connection....", outDateConnectionId);
                            unregister(outDateConnectionId);
                        }
                    }
                }

                //reset loader client

                if (isLoaderClient) {
                    loadClient = -1;
                    redirectAddress = null;
                }

                Loggers.REMOTE_DIGEST.info("Connection check task end");

            } catch (Throwable e) {
                Loggers.REMOTE.error("Error occurs during connection check... ", e);
            }
        }
    }, 1000L, 3000L, TimeUnit.MILLISECONDS);

}

//注销（移出）连接方法
public synchronized void unregister(String connectionId) {
    Connection remove = this.connections.remove(connectionId);
    if (remove != null) {
        String clientIp = remove.getMetaInfo().clientIp;
        AtomicInteger atomicInteger = connectionForClientIp.get(clientIp);
        if (atomicInteger != null) {
            int count = atomicInteger.decrementAndGet();
            if (count <= 0) {
                connectionForClientIp.remove(clientIp);
            }
        }
        remove.close();
        Loggers.REMOTE_DIGEST.info("[{}]Connection unregistered successfully. ", connectionId);
        clientConnectionEventListenerRegistry.notifyClientDisConnected(remove);
    }
}
```

移除connection后，继承ClientConnectionEventListener的**ConnectionBasedClientManager**会移除Client，发布**ClientDisconnectEvent事件**。

```java
@Override
public boolean clientDisconnected(String clientId) {
    Loggers.SRV_LOG.info("Client connection {} disconnect, remove instances and subscribers", clientId);
    ConnectionBasedClient client = clients.remove(clientId);
    if (null == client) {
        return true;
    }
    client.release();
    NotifyCenter.publishEvent(new ClientEvent.ClientDisconnectEvent(client));
    return true;
}
```

ClientDisconnectEvent会触发几个事件：

**1）Distro协议**：同步移除的client数据

**2）清除两个索引缓存**：ClientServiceIndexesManager中Service与发布Client的关系；ServiceStorage中Service与Instance的关系

**3）服务订阅**：ClientDisconnectEvent会**间接触发ServiceChangedEvent事件**，将服务变更通知客户端。