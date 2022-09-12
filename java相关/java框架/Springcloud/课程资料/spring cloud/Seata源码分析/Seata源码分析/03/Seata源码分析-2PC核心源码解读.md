# Seata源码分析-2PC核心源码解读

## 2PC提交源码流程

上节课我们分析到了GlobalTransactionalInterceptor全局事务拦截器，一旦执行拦截器，我们就会进入到其中的invoke方法，在这其中会做一些@GlobalTransactional注解的判断，如果有注解以后，会执行全局事务和全局锁，那么在执行全局事务的时候会调用handleGlobalTransaction全局事务处理器，这里主要是获取事务信息

```java
Object handleGlobalTransaction(final MethodInvocation methodInvocation,
                               final GlobalTransactional globalTrxAnno) throws Throwable {
    boolean succeed = true;
    try {
        return transactionalTemplate.execute(new TransactionalExecutor() {
            @Override
            public Object execute() throws Throwable {
                return methodInvocation.proceed();
            }

            // 获取事务名称，默认获取方法名
            public String name() {
                String name = globalTrxAnno.name();
                if (!StringUtils.isNullOrEmpty(name)) {
                    return name;
                }
                return formatMethod(methodInvocation.getMethod());
            }

            /**
                 * 解析GlobalTransactional注解属性，封装为对象
                 * @return
                 */
            @Override
            public TransactionInfo getTransactionInfo() {
                // reset the value of timeout
                // 获取超时时间，默认60秒
                int timeout = globalTrxAnno.timeoutMills();
                if (timeout <= 0 || timeout == DEFAULT_GLOBAL_TRANSACTION_TIMEOUT) {
                    timeout = defaultGlobalTransactionTimeout;
                }

                // 构建事务信息对象
                TransactionInfo transactionInfo = new TransactionInfo();
                transactionInfo.setTimeOut(timeout);// 超时时间
                transactionInfo.setName(name()); // 事务名称
                transactionInfo.setPropagation(globalTrxAnno.propagation());// 事务传播
                transactionInfo.setLockRetryInternal(globalTrxAnno.lockRetryInternal());// 校验或占用全局锁重试间隔
                transactionInfo.setLockRetryTimes(globalTrxAnno.lockRetryTimes());// 校验或占用全局锁重试次数
                Set<RollbackRule> rollbackRules = new LinkedHashSet<>();
                // 其他构建信息
                for (Class<?> rbRule : globalTrxAnno.rollbackFor()) {
                    rollbackRules.add(new RollbackRule(rbRule));
                }
                for (String rbRule : globalTrxAnno.rollbackForClassName()) {
                    rollbackRules.add(new RollbackRule(rbRule));
                }
                for (Class<?> rbRule : globalTrxAnno.noRollbackFor()) {
                    rollbackRules.add(new NoRollbackRule(rbRule));
                }
                for (String rbRule : globalTrxAnno.noRollbackForClassName()) {
                    rollbackRules.add(new NoRollbackRule(rbRule));
                }
                transactionInfo.setRollbackRules(rollbackRules);
                return transactionInfo;
            }
        });
    } catch (TransactionalExecutor.ExecutionException e) {
        // 执行异常
        TransactionalExecutor.Code code = e.getCode();
        switch (code) {
            case RollbackDone:
                throw e.getOriginalException();
            case BeginFailure:
                succeed = false;
                failureHandler.onBeginFailure(e.getTransaction(), e.getCause());
                throw e.getCause();
            case CommitFailure:
                succeed = false;
                failureHandler.onCommitFailure(e.getTransaction(), e.getCause());
                throw e.getCause();
            case RollbackFailure:
                failureHandler.onRollbackFailure(e.getTransaction(), e.getOriginalException());
                throw e.getOriginalException();
            case RollbackRetrying:
                failureHandler.onRollbackRetrying(e.getTransaction(), e.getOriginalException());
                throw e.getOriginalException();
            default:
                throw new ShouldNeverHappenException(String.format("Unknown TransactionalExecutor.Code: %s", code));
        }
    } finally {
        if (degradeCheck) {
            EVENT_BUS.post(new DegradeCheckEvent(succeed));
        }
    }
}
```

在这其中，我们要关注一个重点方法execute()

其实这个方法主要的作用就是，执行事务的流程，大概一下几点：

1. 获取事务信息
2. 开始执行全局事务
3. 发生异常全局回滚，各个数据通过undo_log表进行事务补偿
4. 全局事务提交
5. 清除所有资源

这个位置是非常核心的一个位置，因为我们所有的业务进来以后都会走这个位置。

这其中的第三步和第四步就是在向TC（Seata-Server）发起全局事务的提交/回滚

```java
//TransactionalTemplate.java
public Object execute(TransactionalExecutor business) throws Throwable {
    // 1. Get transactionInfo
    // 获取事务信息
    TransactionInfo txInfo = business.getTransactionInfo();
    if (txInfo == null) {
        throw new ShouldNeverHappenException("transactionInfo does not exist");
    }
    // 1.1 Get current transaction, if not null, the tx role is 'GlobalTransactionRole.Participant'.
    // 获取当前事务，主要获取Xid
    GlobalTransaction tx = GlobalTransactionContext.getCurrent();

    // 1.2 Handle the transaction propagation.
    // 根据配置的不同事务传播行为，执行不同的逻辑
    Propagation propagation = txInfo.getPropagation();
    SuspendedResourcesHolder suspendedResourcesHolder = null;
    try {
        switch (propagation) {
            case NOT_SUPPORTED:
                // If transaction is existing, suspend it.
                if (existingTransaction(tx)) {
                    suspendedResourcesHolder = tx.suspend();
                }
                // Execute without transaction and return.
                return business.execute();
            case REQUIRES_NEW:
                // If transaction is existing, suspend it, and then begin new transaction.
                if (existingTransaction(tx)) {
                    suspendedResourcesHolder = tx.suspend();
                    tx = GlobalTransactionContext.createNew();
                }
                // Continue and execute with new transaction
                break;
            case SUPPORTS:
                // If transaction is not existing, execute without transaction.
                if (notExistingTransaction(tx)) {
                    return business.execute();
                }
                // Continue and execute with new transaction
                break;
            case REQUIRED:
                // If current transaction is existing, execute with current transaction,
                // else continue and execute with new transaction.
                break;
            case NEVER:
                // If transaction is existing, throw exception.
                if (existingTransaction(tx)) {
                    throw new TransactionException(
                        String.format("Existing transaction found for transaction marked with propagation 'never', xid = %s"
                                      , tx.getXid()));
                } else {
                    // Execute without transaction and return.
                    return business.execute();
                }
            case MANDATORY:
                // If transaction is not existing, throw exception.
                if (notExistingTransaction(tx)) {
                    throw new TransactionException("No existing transaction found for transaction marked with propagation 'mandatory'");
                }
                // Continue and execute with current transaction.
                break;
            default:
                throw new TransactionException("Not Supported Propagation:" + propagation);
        }

        // 1.3 If null, create new transaction with role 'GlobalTransactionRole.Launcher'.
        // 当前没有事务，则创建一个新的事务
        if (tx == null) {
            tx = GlobalTransactionContext.createNew();
        }

        // set current tx config to holder
        GlobalLockConfig previousConfig = replaceGlobalLockConfig(txInfo);

        try {
            // 2. If the tx role is 'GlobalTransactionRole.Launcher', send the request of beginTransaction to TC,
            //    else do nothing. Of course, the hooks will still be triggered.
            // 开始执行全局事务
            beginTransaction(txInfo, tx);

            Object rs;
            try {
                // Do Your Business
                // 执行当前业务逻辑：
                // 1. 在TC注册当前分支事务，TC会在branch_table中插入一条分支事务数据
                // 2. 执行本地update语句，并在执行前后查询数据状态，并把数据前后镜像存入到undo_log表中
                // 3. 远程调用其他应用，远程应用接收到xid，也会注册分支事务，写入branch_table及本地undo_log表
                // 4. 会在lock_table表中插入全局锁数据（一个分支一条）
                rs = business.execute();
            } catch (Throwable ex) {
                // 3. The needed business exception to rollback.
                // 发生异常全局回滚，各个数据通过undo_log表进行事务补偿
                completeTransactionAfterThrowing(txInfo, tx, ex);
                throw ex;
            }

            // 4. everything is fine, commit.
            // 全局提交事务
            commitTransaction(tx);

            return rs;
        } finally {
            //5. clear
            // 清除所有资源
            resumeGlobalLockConfig(previousConfig);
            triggerAfterCompletion();
            cleanUp();
        }
    } finally {
        // If the transaction is suspended, resume it.
        if (suspendedResourcesHolder != null) {
            tx.resume(suspendedResourcesHolder);
        }
    }
}
```

## 如何发起全局事务

这个位置我们就看当前这个代码中的 beginTransaction(txInfo, tx);方法

```java
// 想TC发起请求，这里采用了模板模式
private void beginTransaction(TransactionInfo txInfo, GlobalTransaction tx) throws TransactionalExecutor.ExecutionException {
    try {
        triggerBeforeBegin();
        // 对TC发起请求
        tx.begin(txInfo.getTimeOut(), txInfo.getName());
        triggerAfterBegin();
    } catch (TransactionException txe) {
        throw new TransactionalExecutor.ExecutionException(tx, txe,
                                                           TransactionalExecutor.Code.BeginFailure);
    }
}	
```

那我们向下来看begin方法，那要注意，这里调用begin方法的是DefaultGlobalTransaction

```java
@Override
public void begin(int timeout, String name) throws TransactionException {
    //判断调用者是否是TM
    if (role != GlobalTransactionRole.Launcher) {
        assertXIDNotNull();
        if (LOGGER.isDebugEnabled()) {
            LOGGER.debug("Ignore Begin(): just involved in global transaction [{}]", xid);
        }
        return;
    }
    assertXIDNull();
    String currentXid = RootContext.getXID();
    if (currentXid != null) {
        throw new IllegalStateException("Global transaction already exists," +
                                        " can't begin a new global transaction, currentXid = " + currentXid);
    }
    // 获取Xid
    xid = transactionManager.begin(null, null, name, timeout);
    status = GlobalStatus.Begin;
    RootContext.bind(xid);
    if (LOGGER.isInfoEnabled()) {
        LOGGER.info("Begin new global transaction [{}]", xid);
    }
}
```

在向下来看begin方法，这时候使用的是(默认事务管理者)DefaultTransactionManager.begin，来真正的获取xid，其中就是传入事务的相关信息，最终TC端返回对应的全局事务Xid。

```java
@Override
public String begin(String applicationId, String transactionServiceGroup, String name, int timeout)
    throws TransactionException {
    GlobalBeginRequest request = new GlobalBeginRequest();
    request.setTransactionName(name);
    request.setTimeout(timeout);
    // 发送请求得到响应
    GlobalBeginResponse response = (GlobalBeginResponse) syncCall(request);
    if (response.getResultCode() == ResultCode.Failed) {
        throw new TmTransactionException(TransactionExceptionCode.BeginFailed, response.getMsg());
    }
    //返回Xid
    return response.getXid();
}
```

这里采用的是Netty的通讯方式

```java
private AbstractTransactionResponse syncCall(AbstractTransactionRequest request) throws TransactionException {
    try {
        // 通过Netty发送请求
        return (AbstractTransactionResponse) TmNettyRemotingClient.getInstance().sendSyncRequest(request);
    } catch (TimeoutException toe) {
        throw new TmTransactionException(TransactionExceptionCode.IO, "RPC timeout", toe);
    }
}
```

图解地址：https://www.processon.com/view/link/6213d58f1e0853078013c58f

