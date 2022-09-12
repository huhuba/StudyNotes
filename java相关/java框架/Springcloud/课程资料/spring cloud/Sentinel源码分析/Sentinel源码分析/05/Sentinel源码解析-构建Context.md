# Sentinel源码解析-构建Context

我们继续分析当前这个类型中的InternalContextUtil.internalEnter(Constants.CONTEXT_DEFAULT_NAME);方法

```java
/**
* This class is used for skip context name checking.
此类型是用于跳过Context名称的检测
*/
private final static class InternalContextUtil extends ContextUtil {
    static Context internalEnter(String name) {
        // 从这里继续跟踪
        return trueEnter(name, "");
    }

    static Context internalEnter(String name, String origin) {
        return trueEnter(name, origin);
    }
}
```

首先这里要明确一下，一个Context的组成实际上需要name(名称)和origin(来源)，所以方法上传入这两个参数

```java
protected static Context trueEnter(String name, String origin) {
    // 从当前线程中获取当前context名称
    Context context = contextHolder.get();
    // 如果当前context为空
    if (context == null) {
        // 从缓存中获取，当前缓存中key值为：Context名称，value值为：EntranceNode
        // （因为后续创建的是EntranceNode），需要它的原因是因为构建Context需要EntranceNode
        Map<String, DefaultNode> localCacheNameMap = contextNameNodeMap;
        // 在缓存中获取EntranceNode
        DefaultNode node = localCacheNameMap.get(name);
        // 如果node为空
        if (node == null) {
            // 当前缓存的size>Context的最大数量，返回NULL_Context类型
            if (localCacheNameMap.size() > Constants.MAX_CONTEXT_NAME_SIZE) {
                setNullContext();
                return NULL_CONTEXT;
            } else {
                // 加锁
                LOCK.lock();
                try {
                    node = contextNameNodeMap.get(name);
                    // 这里两次判断是采用了双重检测锁的机制：为了防止并发创建
                    if (node == null) {
                          // 当前缓存的size>Context的最大数量，返回NULL_Context类型
                        if (contextNameNodeMap.size() > Constants.MAX_CONTEXT_NAME_SIZE) {
                            setNullContext();
                            return NULL_CONTEXT;
                        } else {
                            // node赋值为EntranceNode
                            node = new EntranceNode(new StringResourceWrapper(name, EntryType.IN), null);
                            // Add entrance node.
                            // 将新建的EntranceNode添加到ROOT中
                            Constants.ROOT.addChild(node);
                            // 将新建的EntranceNode添加到缓存中
                            Map<String, DefaultNode> newMap = new HashMap<>(contextNameNodeMap.size() + 1);
                            newMap.putAll(contextNameNodeMap);
                            newMap.put(name, node);
                            contextNameNodeMap = newMap;
                        }
                    }
                } finally {
                    LOCK.unlock();
                }
            }
        }
        // 将name和node封装成Context
        context = new Context(node, name);
        // 设定来源
        context.setOrigin(origin);
        // 将context写入到当前线程中
        contextHolder.set(context);
    }
	// 返回Context
    return context;
}
```



