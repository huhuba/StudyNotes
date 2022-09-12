# Sentinel源码解析-ClusterBuilderSlot解析

上节课我们分析了SlotChain入口和NodeSelectorSlot那么这节课分析ClusterBuilderSlot

## 官方定义

ClusterBuilderSlot：则用于存储资源的统计信息以及调用者信息，例如该资源的 RT, QPS, thread count 等等，这些信息将用作为多维度限流，降级的依据；

那我们来进行分析，首先我们先看上节课分析到的位置

```java
//NodeSelectorSlot.entry()
@Override
public void entry(Context context, ResourceWrapper resourceWrapper, Object obj, int count, boolean prioritized, Object... args)
    throws Throwable {
    // 从缓存中获取，创建DefaultNode
    DefaultNode node = map.get(context.getName());
    // 双重判断，如果判断为空
    if (node == null) {
        synchronized (this) {
            node = map.get(context.getName());
            if (node == null) {
                // 创建一个DefaultNode并且放入到缓存中
                node = new DefaultNode(resourceWrapper, null);
                HashMap<String, DefaultNode> cacheMap = new HashMap<String, DefaultNode>(map.size());
                cacheMap.putAll(map);
                cacheMap.put(context.getName(), node);
                map = cacheMap;
                // Build invocation tree
                // 将新建的Node添加到调用树中
                ((DefaultNode) context.getLastNode()).addChild(node);
            }

        }
    }

    context.setCurNode(node);
    // 触发下一个节点
    fireEntry(context, resourceWrapper, node, count, prioritized, args);
}
```

再触发下一个节点以后，调用的是父级AbstractLinkedProcessorSlot.fireEntry()方法，然后next调用transformEntry

```java
@Override
public void fireEntry(Context context, ResourceWrapper resourceWrapper, Object obj, int count, boolean prioritized, Object... args)
    throws Throwable {
    if (next != null) {
        // 调用下一个节点
        next.transformEntry(context, resourceWrapper, obj, count, prioritized, args);
    }
}
//next就代表循环到下一个节点所以这里调用entry的就是ClusterBuilderSlot
@SuppressWarnings("unchecked")
void transformEntry(Context context, ResourceWrapper resourceWrapper, Object o, int count, boolean prioritized, Object... args)
        throws Throwable {
        T t = (T)o;
        entry(context, resourceWrapper, t, count, prioritized, args);
    }
```

## ClusterBuilderSlot

```java
// ClusterBuilderSlot.entry
@Override
public void entry(Context context, ResourceWrapper resourceWrapper, DefaultNode node, int count,
                  boolean prioritized, Object... args)
    throws Throwable {
    if (clusterNode == null) {
        synchronized (lock) {
            if (clusterNode == null) {
                // Create the cluster node.
                clusterNode = new ClusterNode(resourceWrapper.getName(), resourceWrapper.getResourceType());
                // key为资源 value为ClusterNode
                HashMap<ResourceWrapper, ClusterNode> newMap = new HashMap<>(Math.max(clusterNodeMap.size(), 16));
                newMap.putAll(clusterNodeMap);
                newMap.put(node.getId(), clusterNode);

                clusterNodeMap = newMap;
            }
        }
    }
 	// 添加节点
    node.setClusterNode(clusterNode);

    /*
         * if context origin is set, we should get or create a new {@link Node} of
         * the specific origin.
         */
    // 确认资源的来源
    if (!"".equals(context.getOrigin())) {
        Node originNode = node.getClusterNode().getOrCreateOriginNode(context.getOrigin());
        context.getCurEntry().setOriginNode(originNode);
    }

    fireEntry(context, resourceWrapper, node, count, prioritized, args);
}
```

## 总结：

ClusterNode作用就是与DefaultNode进行关联，即不同的DefaultNode都关联了一个ClusterNode，这样我们在不同上下文中都可以拿到当前资源一个总的流量统计情况。





