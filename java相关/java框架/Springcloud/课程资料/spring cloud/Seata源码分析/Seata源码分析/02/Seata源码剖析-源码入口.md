# Seata源码剖析-源码入口

## Seata客户端启动

首先一个Seata的客户端启动一般分为几个流程：

1. 自动加载各种Bean及配置信息
2. 初始化TM
3. 初始化RM（具体服务）
4. 初始化分布式事务客户端完成，代理数据源
5. 连接TC（Seata服务端），注册RM，注册TM
6. 开启全局事务

在这个其中，就会涉及到几个核心的类型，首先我们需要来看配置类型GlobalTransactionAutoConfiguration

所以我们直接通过官方案例引入的Seata包，找到SpringBoot项目在启动的时候自动扫描加载类型的spring.factories，然后找到GlobalTransactionAutoConfiguration（Seata自动配置类）

## 全局事务扫描类源码

这个类型的核心点，就是加载配置，注入相关的Bean

```java
/**
 * seata自动配置类
 */
@Configuration
@EnableConfigurationProperties(SeataProperties.class)
public class GlobalTransactionAutoConfiguration {

	private final ApplicationContext applicationContext;

	private final SeataProperties seataProperties;

	public GlobalTransactionAutoConfiguration(ApplicationContext applicationContext,
			SeataProperties seataProperties) {
		this.applicationContext = applicationContext;
		this.seataProperties = seataProperties;
	}
	// 注入全局事务扫描器
	@Bean
	public GlobalTransactionScanner globalTransactionScanner() {

		String applicationName = applicationContext.getEnvironment()
				.getProperty("spring.application.name");

		String txServiceGroup = seataProperties.getTxServiceGroup();

		if (StringUtils.isEmpty(txServiceGroup)) {
			txServiceGroup = applicationName + "-fescar-service-group";
			seataProperties.setTxServiceGroup(txServiceGroup);
		}
		// 构建全局扫描器，传入参数：应用名、事务分组名，失败处理器
		return new GlobalTransactionScanner(applicationName, txServiceGroup);
	}
}

```

## GlobalTransactionScanner全局事务扫描器

在这其中我们要关心的是GlobalTransactionScanner这个类型，这个类型扫描@GlobalTransactional注解，并对代理方法进行拦截增强事务的功能。

![image-20220221231318290](image-20220221231318290.png)

这里给大家展示了当前GlobalTransactionScanner的类关系图，其中我们现在继承了Aop的AbstractAutoProxyCreator类型，在这其中有一个重点方法，其实这个方法就是判断Bean对象是否需要代理，是否需要增强

```java
protected Object wrapIfNecessary(Object bean, String beanName, Object cacheKey) {
    if (beanName != null && this.targetSourcedBeans.contains(beanName)) {
        return bean;
    }
    if (Boolean.FALSE.equals(this.advisedBeans.get(cacheKey))) {
        return bean;
    }
    if (isInfrastructureClass(bean.getClass()) || shouldSkip(bean.getClass(), beanName)) {
        this.advisedBeans.put(cacheKey, Boolean.FALSE);
        return bean;
    }

    // Create proxy if we have advice.
    Object[] specificInterceptors = getAdvicesAndAdvisorsForBean(bean.getClass(), beanName, null);
    if (specificInterceptors != DO_NOT_PROXY) {
        this.advisedBeans.put(cacheKey, Boolean.TRUE);
        Object proxy = createProxy(
            bean.getClass(), beanName, specificInterceptors, new SingletonTargetSource(bean));
        this.proxyTypes.put(cacheKey, proxy.getClass());
        return proxy;
    }

    this.advisedBeans.put(cacheKey, Boolean.FALSE);
    return bean;
}
```

当然这是父类提供的方法，那子类继承之后重写此方法，完成了定制化的效果，定义不同的代理对象

```java
@Override
protected Object wrapIfNecessary（奈色色瑞）(Object bean, String beanName, Object cacheKey) {
    try {
        // 加锁防止并发
        synchronized (PROXYED_SET) {
            if (PROXYED_SET.contains(beanName)) {
                return bean;
            }
            interceptor = null;
            //check TCC proxy
            // 检查是否是TCC模式
            if (TCCBeanParserUtils.isTccAutoProxy(bean, beanName, applicationContext)) {
                //TCC interceptor, proxy bean of sofa:reference/dubbo:reference, and LocalTCC
                // 如果是：添加TCC拦截器
                interceptor = new TccActionInterceptor(TCCBeanParserUtils.getRemotingDesc(beanName));
                ConfigurationCache.addConfigListener(ConfigurationKeys.DISABLE_GLOBAL_TRANSACTION,
                                                     (ConfigurationChangeListener)interceptor);
            } else {
                // 不是TCC模式
                Class<?> serviceInterface = SpringProxyUtils.findTargetClass(bean);
                Class<?>[] interfacesIfJdk = SpringProxyUtils.findInterfaces(bean);

                // 判断是否有相关事务注解，如果没有就不代理
                if (!existsAnnotation(new Class[]{serviceInterface})
                    && !existsAnnotation(interfacesIfJdk)) {
                    return bean;
                }

                // 当发现存在全局事务注解标注的Bean，添加拦截器
                if (globalTransactionalInterceptor == null) {
                    // 添加拦截器
                    globalTransactionalInterceptor = new GlobalTransactionalInterceptor(failureHandlerHook);
                    ConfigurationCache.addConfigListener(
                        ConfigurationKeys.DISABLE_GLOBAL_TRANSACTION,
                        (ConfigurationChangeListener)globalTransactionalInterceptor);
                }
                interceptor = globalTransactionalInterceptor;
            }

            LOGGER.info("Bean[{}] with name [{}] would use interceptor [{}]", bean.getClass().getName(), beanName, interceptor.getClass().getName());
            // 检查是否是代理对象
            if (!AopUtils.isAopProxy(bean)) {
                // 不是调用Spring代理（父级）
                bean = super.wrapIfNecessary(bean, beanName, cacheKey);
            } else {
                // 已经是代理对象，反射获取代理类中的已经存在的拦截器组合，然后添加到该集合当中
                AdvisedSupport advised = SpringProxyUtils.getAdvisedSupport(bean);
                Advisor[] advisor = buildAdvisors(beanName, getAdvicesAndAdvisorsForBean(null, null, null));
                for (Advisor avr : advisor) {
                    advised.addAdvisor(0, avr);
                }
            }
            // 将Bean添加到Set中
            PROXYED_SET.add(beanName);
            return bean;
        }
    } catch (Exception exx) {
        throw new RuntimeException(exx);
    }
}
```



