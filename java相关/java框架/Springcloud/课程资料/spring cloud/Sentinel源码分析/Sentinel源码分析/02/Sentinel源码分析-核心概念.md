# Sentinel核心概念

Sentinel作为ali开源的一款轻量级流控框架，**主要以流量为切入点，从流量控制、熔断降级、系统负载保护等多个维度来帮助用户保护服务的稳定性**。相比于Hystrix，Sentinel的设计更加简单，在 Sentinel中资源定义和规则配置是分离的，也就是说用户可以先通过Sentinel API给对应的业务逻辑定义资源（埋点），然后在需要的时候再配置规则，通过这种组合方式，极大的增加了Sentinel流控的灵活性。

引入Sentinel带来的性能损耗非常小。只有在业务单机量级超过25W QPS的时候才会有一些显著的影响（5% - 10% 左右），单机QPS不太大的时候损耗几乎可以忽略不计。

Sentinel提供两种埋点方式：

- try-catch 方式（通过 SphU.entry(...)），用户在 catch 块中执行异常处理 

- if-else 方式（通过 SphO.entry(...)），当返回 false 时执行异常处理 

## 工作流程

在此之前，需要先了解一下Sentinel的工作流程

![sentinel-slot-chain-architecture](sentinel-slot-chain-architecture.png)

在 Sentinel里面，所有的资源都对应一个资源名称（resourceName），每次资源调用都会创建一个 Entry 对象。Entry 可以通过对主流框架的适配自动创建，也可以通过注解的方式或调用 SphU API 显式创建。Entry 创建的时候，同时也会创建一系列功能插槽（slot chain），这些插槽有不同的职责，例如默认情况下会创建一下7个插槽：

- NodeSelectorSlot 负责收集资源的路径，并将这些资源的调用路径，以树状结构存储起来，用于根据调用路径来限流降级；
- ClusterBuilderSlot 则用于存储资源的统计信息以及调用者信息，例如该资源的 RT, QPS, thread count 等等，这些信息将用作为多维度限流，降级的依据，对应簇点链路；
- StatisticSlot 则用于记录、统计不同纬度的 runtime 指标监控信息；
- FlowSlot 则用于根据预设的限流规则以及前面 slot 统计的状态，来进行流量控制，对应流控规则；
- AuthoritySlot 则根据配置的黑白名单和调用来源信息，来做黑白名单控制，对应授权规则；
- DegradeSlot 则通过统计信息以及预设的规则，来做熔断降级，对应熔断规则；
- SystemSlot 则通过系统的状态，例如 load1 等，来控制总的入口流量，对应系统规则；

重要的概念：

- slot chain：插槽
- Node：根节点
- Context：对资源操作时的上下文环境，每个资源操作(`针对Resource进行的entry/exit`)必须属于一个Context，如果程序中未指定Context，会创建name为"sentinel_default_context"的默认Context。一个Context生命周期内可能有多个资源操作，Context生命周期内的最后一个资源exit时会清理该Context，这也预示这真个Context生命周期的结束。
- Entry：表示一次资源操作，内部会保存当前调用信息。在一个Context生命周期中多次资源操作，也就是对应多个Entry，这些Entry形成parent/child结构保存在Entry实例中



## 官方案例演示

我们先从官方文档提供的演示代码来进行分析

![image-20211118223922490](image-20211118223922490.png)

我们来改写一下，如果只有一个资源情况如下

```java
package demo;

import com.alibaba.csp.sentinel.Entry;
import com.alibaba.csp.sentinel.SphU;
import com.alibaba.csp.sentinel.context.ContextUtil;
import com.alibaba.csp.sentinel.slots.block.BlockException;

public class ContextDemo {
    public void ContextUtil(){
        //创建一个来自appA访问的Context
        //Context的名称为entrance1
        ContextUtil.enter("entrance1", "appA");
        // Entry就是一个资源操作对象
        Entry nodeA = null;
        try {
            //获取资源resource的entry
            nodeA = SphU.entry("resource1");//后续会展开这个位置
            // 如果代码走到这个位置，说明当前资源的请求通过了流控，可以继续进行相关业务处理
        } catch (BlockException e) {
            // 如果没有通过走到了这里，就表示请求被限流，这里进行降级操作
            e.printStackTrace();
        }finally {
            if (nodeA != null) {
                nodeA.exit();
            }
        }
        //释放Context
        ContextUtil.exit();
    }
}
```

多个资源的情况

```java
public class ContextDemo {
    public void ContextUtil(){
        //创建一个来自appA访问的Context
        //Context的名称为entrance1
        ContextUtil.enter("entrance1", "appA");
        // Entry就是一个资源操作对象
        Entry nodeA = null;
        Entry nodeB = null;
        try {
            //获取资源resource1的entry
            nodeA = SphU.entry("resource1");
            // 如果代码走到这个位置，说明当前资源的请求通过了流控，可以继续进行相关业务处理

            //获取资源resource2的entry
            nodeB = SphU.entry("resource2");
            // 如果代码走到这个位置，说明当前资源的请求通过了流控，可以继续进行相关业务处理
        } catch (BlockException e) {
            // 如果没有通过走到了这里，就表示请求被限流，这里进行降级操作
            e.printStackTrace();
        }finally {
            if (nodeA != null) {
                nodeA.exit();
            }
            if (nodeB != null) {
                nodeB.exit();
            }
        }
        //释放Context
        ContextUtil.exit();
    }
}
```

