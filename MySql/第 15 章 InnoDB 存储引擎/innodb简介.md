## 15.1 InnoDB 简介

- [15.1.1 使用 InnoDB 表的好处](https://dev.mysql.com/doc/refman/8.0/en/innodb-benefits.html)
- [15.1.2 InnoDB 表的最佳实践](https://dev.mysql.com/doc/refman/8.0/en/innodb-best-practices.html)
- [15.1.3 验证 InnoDB 是默认存储引擎](https://dev.mysql.com/doc/refman/8.0/en/innodb-check-availability.html)
- [15.1.4 使用 InnoDB 进行测试和基准测试](https://dev.mysql.com/doc/refman/8.0/en/innodb-benchmarking.html)



`InnoDB`是一种兼顾高可靠性和高性能的通用存储引擎。在 MySQL 8.0 中，`InnoDB`是默认的 MySQL 存储引擎。除非您配置了不同的默认存储引擎，否则发出[`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)不带`ENGINE` 子句的语句会创建一个`InnoDB`表。

### InnoDB 的主要优势

- 其 DML 操作遵循 ACID 模型，具有提交、回滚和崩溃恢复功能的事务以保护用户数据。请参阅[第 15.2 节，“InnoDB 和 ACID 模型”](https://dev.mysql.com/doc/refman/8.0/en/mysql-acid.html)。
- 行级锁定和 Oracle 风格的一致性读取提高了多用户并发性和性能。请参阅 [第 15.7 节，“InnoDB 锁定和事务模型”](https://dev.mysql.com/doc/refman/8.0/en/innodb-locking-transaction-model.html)。
- `InnoDB`表在磁盘上排列数据以优化基于主键的查询。每个 `InnoDB`表都有一个称为聚集索引的主键索引，它组织数据以最小化主键查找的 I/O。请参阅[第 15.6.2.1 节，“聚集索引和二级索引”](https://dev.mysql.com/doc/refman/8.0/en/innodb-index-types.html)。
- 为了保持数据完整性，`InnoDB`支持 `FOREIGN KEY`约束。使用外键检查插入、更新和删除以确保它们不会导致相关表之间的不一致。请参见 [第 13.1.20.5 节，“外键约束”](https://dev.mysql.com/doc/refman/8.0/en/create-table-foreign-keys.html)。



**表 15.1 InnoDB 存储引擎特性**

| 特征                                                        | 支持                                                         |
| :---------------------------------------------------------- | :----------------------------------------------------------- |
| **B树索引**                                                 | 是的                                                         |
| **备份/时间点恢复**（在服务器中实现，而不是在存储引擎中。） | 是的                                                         |
| **集群数据库支持**                                          | 不                                                           |
| **聚集索引**                                                | 是的                                                         |
| **压缩数据**                                                | 是的                                                         |
| **数据缓存**                                                | 是的                                                         |
| **加密数据**                                                | 是（通过加密函数在服务器中实现；在 MySQL 5.7 及更高版本中，支持静态数据加密。） |
| **外键支持**                                                | 是的                                                         |
| **全文检索索引**                                            | 是（MySQL 5.6 及更高版本提供对 FULLTEXT 索引的支持。）       |
| **地理空间数据类型支持**                                    | 是的                                                         |
| **地理空间索引支持**                                        | 是（MySQL 5.7 及更高版本提供对地理空间索引的支持。）         |
| **哈希索引**                                                | 否（InnoDB 在内部使用哈希索引来实现其自适应哈希索引功能。）  |
| **索引缓存**                                                | 是的                                                         |
| **锁定粒度**                                                | 排                                                           |
| **MVCC**                                                    | 是的                                                         |
| **复制支持**（在服务器中实现，而不是在存储引擎中。）        | 是的                                                         |
| **存储限制**                                                | 64TB                                                         |
| **T-树索引**                                                | 不                                                           |
| **交易**                                                    | 是的                                                         |
| **更新数据字典的统计信息**                                  | 是的                                                         |

| 特征 | 支持 |
| :--- | :--- |
|      |      |



要比较`InnoDB`MySQL 提供的其他存储引擎的特性，请参阅[第 16 章，](https://dev.mysql.com/doc/refman/8.0/en/storage-engines.html)[*替代存储引擎中的*](https://dev.mysql.com/doc/refman/8.0/en/storage-engines.html)*存储引擎特性*表 。

### InnoDB 增强功能和新功能

有关`InnoDB`增强功能和新功能的信息，请参阅：

- [第 1.3 节，“MySQL 8.0 中的新增](https://dev.mysql.com/doc/refman/8.0/en/mysql-nutshell.html)功能”中 的`InnoDB`增强列表 。
- 发行 [说明](https://dev.mysql.com/doc/relnotes/mysql/8.0/en/)。

### 其他 InnoDB 信息和资源

- 有关`InnoDB`- 相关的术语和定义，请参阅[MySQL 词汇表](https://dev.mysql.com/doc/refman/8.0/en/glossary.html)。
- 有关专用于`InnoDB`存储引擎的论坛，请参阅 [MySQL Forums::InnoDB](http://forums.mysql.com/list.php?22)。
- `InnoDB`在与 MySQL 相同的 GNU GPL 许可证第 2 版（1991 年 6 月）下发布。有关 MySQL 许可的更多信息，请参阅 http://www.mysql.com/company/legal/licensing/。