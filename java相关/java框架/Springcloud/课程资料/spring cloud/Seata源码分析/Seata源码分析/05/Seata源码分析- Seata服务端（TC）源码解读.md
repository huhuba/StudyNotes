# Seata源码分析- Seata服务端（TC）源码解读

上节课我们已经分析到了SQL语句最终的执行器，但是再往下分析之前，我们需要先来分析一下TM客户端与TC端通讯以后，TC端的具体操作

## 服务端表解释

我们的Seata服务端在应用的时候需要准备三张表，那么这三张表分别代表的意思就是

1. branch_table 分支事务表
2. global_table 全局事务表
3. lock_table 全局锁表

客户端请求服务端以后，我们就需要把对应的全局事务包括分支事务和全局锁全部存放到这里。

![image-20220311185545970](image-20220311185545970-1647008601419.png)

## TC服务端启动入口

那么我们任何的Java工程启动都需要主函数main，所以我们就从这里入手，首先在seata源码工程中搜索这个入口

![image-20220311175232256](image-20220311175232256.png)

这里我们看Server.java这里就是启动入口，在这个入口中找到协调者，因为TC整体的操作就是协调整体的全局事务

```java
// 协调协调者
DefaultCoordinator coordinator = new DefaultCoordinator(nettyRemotingServer);
```

## 全局事务开始方法分析

然后进入到其中我们可以看到很多的全局事务处理的方法

```java
// 处理全局事务开始
@Override
protected void doGlobalBegin(GlobalBeginRequest request, GlobalBeginResponse response, RpcContext rpcContext)
    throws TransactionException {
    // 响应客户端XID
    response.setXid(core.begin(rpcContext.getApplicationId(), rpcContext.getTransactionServiceGroup(),
                               request.getTransactionName(), request.getTimeout()));
    if (LOGGER.isInfoEnabled()) {
        LOGGER.info("Begin new global transaction applicationId: {},transactionServiceGroup: {}, transactionName: {},timeout:{},xid:{}",
                    rpcContext.getApplicationId(), rpcContext.getTransactionServiceGroup(), request.getTransactionName(), request.getTimeout(), response.getXid());
    }
}

// 处理全局提交
@Override
protected void doGlobalCommit(GlobalCommitRequest request, GlobalCommitResponse response, RpcContext rpcContext)
    throws TransactionException {
    MDC.put(RootContext.MDC_KEY_XID, request.getXid());
    response.setGlobalStatus(core.commit(request.getXid()));
}

// 处理全局回滚
@Override
protected void doGlobalRollback(GlobalRollbackRequest request, GlobalRollbackResponse response,
                                RpcContext rpcContext) throws TransactionException {
    MDC.put(RootContext.MDC_KEY_XID, request.getXid());
    response.setGlobalStatus(core.rollback(request.getXid()));
}
.....
```

在这其中我们首先关注doGlobalBegin方法中的core.begin()方法，来看一下具体操作

```java
@Override
public String begin(String applicationId, String transactionServiceGroup, String name, int timeout)
    throws TransactionException {
    // 创建全局事务Session
    GlobalSession session = GlobalSession.createGlobalSession(applicationId, transactionServiceGroup, name,
                                                              timeout);
    MDC.put(RootContext.MDC_KEY_XID, session.getXid());

    // 为Session中添加回调监听 SessionHolder.getRootSessionManager()去获取一个全局Session管理器DataBaseSessionManager
    // 观察者设计模式
    session.addSessionLifecycleListener(SessionHolder.getRootSessionManager());

    // 全局事务开启
    session.begin();

    // transaction start event
    eventBus.post(new GlobalTransactionEvent(session.getTransactionId(), GlobalTransactionEvent.ROLE_TC,
                                             session.getTransactionName(), applicationId, transactionServiceGroup, session.getBeginTime(), null, session.getStatus()));

    return session.getXid();
}
```

在向下我们要关注一下全局Session管理器DataBaseSessionManager，进入到getRootSessionManager()方法中

```java
/**
* Gets root session manager.
* 获取一个全局Session管理器
* @return the root session manager
*/
public static SessionManager getRootSessionManager() {
    if (ROOT_SESSION_MANAGER == null) {
        throw new ShouldNeverHappenException("SessionManager is NOT init!");
    }
    return ROOT_SESSION_MANAGER;
}
```

这个管理器如何生成的那，我们可以看一下init初始化方法

```java
public static void init(String mode) {
    if (StringUtils.isBlank(mode)) {
        mode = CONFIG.getConfig(ConfigurationKeys.STORE_MODE);
    }
    // 判断Seata模式，当前为DB
    StoreMode storeMode = StoreMode.get(mode);
    if (StoreMode.DB.equals(storeMode)) {
        // 通过SPI机制读取SessionManager接口实现类，读取的是META-INF.service目录，在通过反射机制创建对象DataBaseSessionManager
        ROOT_SESSION_MANAGER = EnhancedServiceLoader.load(SessionManager.class, StoreMode.DB.getName());
        ASYNC_COMMITTING_SESSION_MANAGER = EnhancedServiceLoader.load(SessionManager.class, StoreMode.DB.getName(),
....
                                                                      
}
```

读取的文件

![image-20220311182615967](image-20220311182615967.png)

再回到begin方法中，我们就知道DataBaseSessionManager是如何创建的，包括下面这一步就是创建DataBaseSessionManager

```java
// 观察者设计模式，创建DataBaseSessionManager
 session.addSessionLifecycleListener(SessionHolder.getRootSessionManager());
```

但是此时有一个问题，就是我们的init方法在哪里调用的拿，其实我们回到Server中，我们发现在构建默认协调者之前就调用了init方法，说明在执行处理全局事务开始之前，就已经创建好了这个SessionManager了

```java
SessionHolder.init(parameterParser.getStoreMode());

// 默认协调者
DefaultCoordinator coordinator = new DefaultCoordinator(nettyRemotingServer);
```

好了此时分析清楚如何得到这个SessionManager以后，我们在回过头来看代码session.begin()位置

```java
@Override
public String begin(String applicationId, String transactionServiceGroup, String name, int timeout)
    throws TransactionException {
    // 创建全局事务Session
    GlobalSession session = GlobalSession.createGlobalSession(applicationId, transactionServiceGroup, name,
                                                              timeout);
    MDC.put(RootContext.MDC_KEY_XID, session.getXid());

    // 为Session中添加回调监听 SessionHolder.getRootSessionManager()去获取一个全局Session管理器DataBaseSessionManager
    // 观察者设计模式，创建DataBaseSessionManager
    session.addSessionLifecycleListener(SessionHolder.getRootSessionManager());

    // 全局事务开始
    session.begin();

    // transaction start event
    eventBus.post(new GlobalTransactionEvent(session.getTransactionId(), GlobalTransactionEvent.ROLE_TC,
                                             session.getTransactionName(), applicationId, transactionServiceGroup, session.getBeginTime(), null, session.getStatus()));

    return session.getXid();
}
```

session.begin()

```java
@Override
public void begin() throws TransactionException {
    // 声明全局事务开始
    this.status = GlobalStatus.Begin;
    // 开始时间
    this.beginTime = System.currentTimeMillis();
    // 激活全局事务
    this.active = true;
    // 将SessionManager放入到集合中，调用onBegin方法
    for (SessionLifecycleListener lifecycleListener : lifecycleListeners) {
        lifecycleListener.onBegin(this);
    }
}
```

这里我们来看一下 onBegin方法，调用的是父级的方法，在这其中我们要关注addGlobalSession方法，但是要注意，这里我们用的是db模式所以调用的是db模式的DateBaseSessionManager

```java
@Override
public void onBegin(GlobalSession globalSession) throws TransactionException {
    addGlobalSession(globalSession);
}
```

![image-20220311184728236](image-20220311184728236.png)

```java
@Override
public void addGlobalSession(GlobalSession session) throws TransactionException {
    if (StringUtils.isBlank(taskName)) {
        // 写入session
        boolean ret = transactionStoreManager.writeSession(LogOperation.GLOBAL_ADD, session);
        if (!ret) {
            throw new StoreException("addGlobalSession failed.");
        }
    } else {
        boolean ret = transactionStoreManager.writeSession(LogOperation.GLOBAL_UPDATE, session);
        if (!ret) {
            throw new StoreException("addGlobalSession failed.");
        }
    }
}
```

然后我们来看写入这里

```java
@Override
public boolean writeSession(LogOperation logOperation, SessionStorable session) {
    // 第一次进入一定是写入
    if (LogOperation.GLOBAL_ADD.equals(logOperation)) {
        return logStore.insertGlobalTransactionDO(SessionConverter.convertGlobalTransactionDO(session));
    } else if (LogOperation.GLOBAL_UPDATE.equals(logOperation)) {
        return logStore.updateGlobalTransactionDO(SessionConverter.convertGlobalTransactionDO(session));
    } else if (LogOperation.GLOBAL_REMOVE.equals(logOperation)) {
        return logStore.deleteGlobalTransactionDO(SessionConverter.convertGlobalTransactionDO(session));
    } else if (LogOperation.BRANCH_ADD.equals(logOperation)) {
        return logStore.insertBranchTransactionDO(SessionConverter.convertBranchTransactionDO(session));
    } else if (LogOperation.BRANCH_UPDATE.equals(logOperation)) {
        return logStore.updateBranchTransactionDO(SessionConverter.convertBranchTransactionDO(session));
    } else if (LogOperation.BRANCH_REMOVE.equals(logOperation)) {
        return logStore.deleteBranchTransactionDO(SessionConverter.convertBranchTransactionDO(session));
    } else {
        throw new StoreException("Unknown LogOperation:" + logOperation.name());
    }
}
```

因为我们第一次调用一定是写入，所以此时我们应该查看insertGlobalTransactionDO，此方法的作用就是写入全局事务表中global_table 

```java
@Override
public boolean insertGlobalTransactionDO(GlobalTransactionDO globalTransactionDO) {
    String sql = LogStoreSqlsFactory.getLogStoreSqls(dbType).getInsertGlobalTransactionSQL(globalTable);
    Connection conn = null;
    PreparedStatement ps = null;
    try {
        conn = logStoreDataSource.getConnection();
        conn.setAutoCommit(true);
        ps = conn.prepareStatement(sql);
        ps.setString(1, globalTransactionDO.getXid());
        ps.setLong(2, globalTransactionDO.getTransactionId());
        ps.setInt(3, globalTransactionDO.getStatus());
        ps.setString(4, globalTransactionDO.getApplicationId());
        ps.setString(5, globalTransactionDO.getTransactionServiceGroup());
        String transactionName = globalTransactionDO.getTransactionName();
        transactionName = transactionName.length() > transactionNameColumnSize ? transactionName.substring(0,
                                                                                                           transactionNameColumnSize) : transactionName;
        ps.setString(6, transactionName);
        ps.setInt(7, globalTransactionDO.getTimeout());
        ps.setLong(8, globalTransactionDO.getBeginTime());
        ps.setString(9, globalTransactionDO.getApplicationData());
        return ps.executeUpdate() > 0;
    } catch (SQLException e) {
        throw new StoreException(e);
    } finally {
        IOUtil.close(ps, conn);
    }
}
```

我们可以查看GlobalTransactionDO实体类的属性，和global_table 的字段进行比对，就能看出其中道理。

