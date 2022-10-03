#### 15.6.1.5 将表从 MyISAM 转换为 InnoDB



如果您有[`MyISAM`](https://dev.mysql.com/doc/refman/8.0/en/myisam-storage-engine.html)要转换的表以[`InnoDB`](https://dev.mysql.com/doc/refman/8.0/en/innodb-storage-engine.html)获得更好的可靠性和可扩展性，请在转换前查看以下指南和提示。

笔记

在以前的 MySQL 版本中创建的分区`MyISAM`表与 MySQL 8.0 不兼容。此类表必须在升级之前准备好，通过删除分区或将它们转换为 `InnoDB`. 有关详细信息，请参阅 [第 24.6.2 节，“与存储引擎相关的分区限制”](https://dev.mysql.com/doc/refman/8.0/en/partitioning-limitations-storage-engines.html)。

- [调整 MyISAM 和 InnoDB 的内存使用情况](https://dev.mysql.com/doc/refman/8.0/en/converting-tables-to-innodb.html#innodb-convert-memory-usage)
- [处理过长或过短的事务](https://dev.mysql.com/doc/refman/8.0/en/converting-tables-to-innodb.html#innodb-convert-transactions)
- [处理死锁](https://dev.mysql.com/doc/refman/8.0/en/converting-tables-to-innodb.html#innodb-convert-deadlock)
- [存储布局](https://dev.mysql.com/doc/refman/8.0/en/converting-tables-to-innodb.html#innodb-convert-plan-storage)
- [转换现有表](https://dev.mysql.com/doc/refman/8.0/en/converting-tables-to-innodb.html#innodb-convert-convert)
- [克隆表的结构](https://dev.mysql.com/doc/refman/8.0/en/converting-tables-to-innodb.html#innodb-convert-clone)
- [传输数据](https://dev.mysql.com/doc/refman/8.0/en/converting-tables-to-innodb.html#innodb-convert-transfer)
- [存储要求](https://dev.mysql.com/doc/refman/8.0/en/converting-tables-to-innodb.html#innodb-convert-storage-requirements)
- [定义主键](https://dev.mysql.com/doc/refman/8.0/en/converting-tables-to-innodb.html#innodb-convert-primary-key)
- [应用程序性能注意事项](https://dev.mysql.com/doc/refman/8.0/en/converting-tables-to-innodb.html#innodb-convert-application-performance)
- [了解与 InnoDB 表关联的文件](https://dev.mysql.com/doc/refman/8.0/en/converting-tables-to-innodb.html#innodb-convert-understand-files)

##### 调整 MyISAM 和 InnoDB 的内存使用情况



当您从`MyISAM`表转换时，降低 [`key_buffer_size`](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_key_buffer_size)配置选项的值以释放不再需要缓存结果的内存。增加配置选项的值，该 选项执行为表[`innodb_buffer_pool_size`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_buffer_pool_size) 分配高速缓存的类似作用。[缓冲池](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_buffer_pool)`InnoDB`缓存表 数据和索引数据，加快查询查找速度，并将查询结果保存在内存中以供重用。有关缓冲池大小配置的指导，请参阅 [第 8.12.3.1 节，“MySQL 如何使用内存”](https://dev.mysql.com/doc/refman/8.0/en/memory-use.html)。 `InnoDB`

##### 处理过长或过短的事务



由于`MyISAM`表不支持 [事务](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_transaction)，您可能没有过多关注 [`autocommit`](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_autocommit)配置选项和[`COMMIT`](https://dev.mysql.com/doc/refman/8.0/en/commit.html)and [`ROLLBACK`](https://dev.mysql.com/doc/refman/8.0/en/commit.html) 语句。这些关键字对于允许多个会话同时读取和写入`InnoDB`表非常重要，从而在写入繁重的工作负载中提供显着的可扩展性优势。

当事务打开时，系统会保留事务开始时所见数据的快照，如果系统在杂散事务继续运行时插入、更新和删除数百万行，这可能会导致大量开销。因此，请注意避免运行时间过长的事务：

- 如果您使用[**mysql**](https://dev.mysql.com/doc/refman/8.0/en/mysql.html)会话进行交互式实验，请务必 在完成时[`COMMIT`](https://dev.mysql.com/doc/refman/8.0/en/commit.html)（完成更改）或 [`ROLLBACK`](https://dev.mysql.com/doc/refman/8.0/en/commit.html)（撤消更改）。关闭交互式会话，而不是让它们长时间打开，以避免意外地让交易长时间打开。
- 确保您的应用程序中的任何错误处理程序也 [`ROLLBACK`](https://dev.mysql.com/doc/refman/8.0/en/commit.html) 未完成更改或[`COMMIT`](https://dev.mysql.com/doc/refman/8.0/en/commit.html) 已完成更改。
- [`ROLLBACK`](https://dev.mysql.com/doc/refman/8.0/en/commit.html)是一个相对昂贵的操作，因为 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html), [`UPDATE`](https://dev.mysql.com/doc/refman/8.0/en/update.html)和 [`DELETE`](https://dev.mysql.com/doc/refman/8.0/en/delete.html)操作是在 之前写入`InnoDB`表的 [`COMMIT`](https://dev.mysql.com/doc/refman/8.0/en/commit.html)，期望大多数更改都成功提交并且很少回滚。在试验大量数据时，避免对大量行进行更改然后回滚这些更改。
- [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)当使用一系列语句 加载大量数据时 ，定期[`COMMIT`](https://dev.mysql.com/doc/refman/8.0/en/commit.html)获取结果以避免持续数小时的事务。在数据仓库的典型加载操作中，如果出现问题，您会截断表（使用[`TRUNCATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/truncate-table.html)）并从头开始，而不是执行 [`ROLLBACK`](https://dev.mysql.com/doc/refman/8.0/en/commit.html).

前面的提示可以节省在太长的事务期间可能浪费的内存和磁盘空间。当事务比应有的短时，问题是 I/O 过多。对于 each [`COMMIT`](https://dev.mysql.com/doc/refman/8.0/en/commit.html)，MySQL 确保每个更改都安全地记录到磁盘，这涉及一些 I/O。

- 对于`InnoDB`表上的大多数操作，您应该使用设置 [`autocommit=0`](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_autocommit)。从效率的角度来看，当您发出大量连续 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)的 [`UPDATE`](https://dev.mysql.com/doc/refman/8.0/en/update.html)、、或 [`DELETE`](https://dev.mysql.com/doc/refman/8.0/en/delete.html)语句时，这可以避免不必要的 I/O。[**从安全的角度来看，如果您在mysql**](https://dev.mysql.com/doc/refman/8.0/en/mysql.html)命令行或应用程序的异常处理程序中 出错，这允许您发出一条 [`ROLLBACK`](https://dev.mysql.com/doc/refman/8.0/en/commit.html) 语句来恢复丢失或乱码的数据。
- [`autocommit=1`](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_autocommit)`InnoDB`当运行一系列查询以生成报告或分析统计信息时，适用于 表。在这种情况下，没有与 [`COMMIT`](https://dev.mysql.com/doc/refman/8.0/en/commit.html)or 相关的 I/O 损失[`ROLLBACK`](https://dev.mysql.com/doc/refman/8.0/en/commit.html)，并且`InnoDB`可以 [自动优化只读工作负载](https://dev.mysql.com/doc/refman/8.0/en/innodb-performance-ro-txn.html)。
- 如果您进行了一系列相关更改，请一次性完成所有更改，最后一个 [`COMMIT`](https://dev.mysql.com/doc/refman/8.0/en/commit.html)。例如，如果您将相关的信息片段插入到多个表中，则[`COMMIT`](https://dev.mysql.com/doc/refman/8.0/en/commit.html) 在进行所有更改后执行一次。或者，如果您运行许多连续 语句，则在加载所有数据后[`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)执行单个 ；[`COMMIT`](https://dev.mysql.com/doc/refman/8.0/en/commit.html)如果你正在做数百万条 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)语句，也许通过 [`COMMIT`](https://dev.mysql.com/doc/refman/8.0/en/commit.html)每万或十万条记录来分割巨大的交易，这样交易就不会变得太大。
- 请记住，即使是一条[`SELECT`](https://dev.mysql.com/doc/refman/8.0/en/select.html) 语句也会打开一个事务，因此在交互式[**mysql**](https://dev.mysql.com/doc/refman/8.0/en/mysql.html) 会话中运行一些报告或调试查询之后，发出[`COMMIT`](https://dev.mysql.com/doc/refman/8.0/en/commit.html) 或关闭[**mysql**](https://dev.mysql.com/doc/refman/8.0/en/mysql.html)会话。

有关相关信息，请参阅 [第 15.7.2.2 节，“自动提交、提交和回滚”](https://dev.mysql.com/doc/refman/8.0/en/innodb-autocommit-commit-rollback.html)。

##### 处理死锁



您可能会在 MySQL 错误日志中看到有关“死锁”的 警告消息 ，或者 [`SHOW ENGINE INNODB STATUS`](https://dev.mysql.com/doc/refman/8.0/en/show-engine.html). [死锁](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_deadlock) 对于表来说不是一个严重的问题，`InnoDB`并且通常不需要任何纠正措施。当两个事务开始修改多个表，以不同的顺序访问这些表时，它们可能会达到一个状态，即每个事务都在等待另一个事务，并且两者都不能继续。当 启用[死锁检测](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_deadlock_detection) （默认）时，MySQL 会立即检测到这种情况并取消（[回滚](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_rollback)） “ smaller ”交易，允许对方继续。如果使用 [`innodb_deadlock_detect`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_deadlock_detect) 配置选项禁用死锁检测，则在发生死锁时`InnoDB`依靠 [`innodb_lock_wait_timeout`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_lock_wait_timeout)设置回滚事务。

无论哪种方式，您的应用程序都需要错误处理逻辑来重新启动由于死锁而被强制取消的事务。当您重新发出与以前相同的 SQL 语句时，原来的计时问题不再适用。其他交易已经完成并且您的交易可以继续，或者其他交易仍在进行中并且您的交易一直等到它完成。

如果死锁警告不断出现，您可以查看应用程序代码以以一致的方式重新排序 SQL 操作，或缩短事务。您可以使用 [`innodb_print_all_deadlocks`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_print_all_deadlocks)启用的选项进行测试，以查看 MySQL 错误日志中的所有死锁警告，而不仅仅是 [`SHOW ENGINE INNODB STATUS`](https://dev.mysql.com/doc/refman/8.0/en/show-engine.html)输出中的最后一个警告。

有关更多信息，请参阅[第 15.7.5 节，“InnoDB 中的死锁”](https://dev.mysql.com/doc/refman/8.0/en/innodb-deadlocks.html)。

##### 存储布局



要从`InnoDB`表中获得最佳性能，您可以调整许多与存储布局相关的参数。

当您转换`MyISAM`大型、频繁访问并保存重要数据的表时，请调查并考虑语句的and [`innodb_file_per_table`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_file_per_table)变量 [`innodb_page_size`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_page_size)以及 [`ROW_FORMAT` and`KEY_BLOCK_SIZE`子句](https://dev.mysql.com/doc/refman/8.0/en/innodb-row-format.html)[`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)。

在您最初的实验中，最重要的设置是 [`innodb_file_per_table`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_file_per_table)。当启用此设置（默认设置）时，新 表会在[file-per-table 表](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_file_per_table)`InnoDB`空间中隐式创建 。与系统表空间相比，file-per-table 表空间允许在表被截断或删除时由操作系统回收磁盘空间。File-per-table 表空间还支持 [DYNAMIC](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_dynamic_row_format)和 [COMPRESSED](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_compressed_row_format)行格式以及相关功能，例如表压缩、长可变长度列的有效页外存储和大索引前缀。有关详细信息，请参阅 `InnoDB`[第 15.6.3.2 节，“File-Per-Table 表空间”](https://dev.mysql.com/doc/refman/8.0/en/innodb-file-per-table-tablespaces.html)。

您还可以将`InnoDB`表存储在共享的通用表空间中，该表空间支持多个表和所有行格式。有关更多信息，请参阅 [第 15.6.3.3 节，“通用表空间”](https://dev.mysql.com/doc/refman/8.0/en/general-tablespaces.html)。

##### 转换现有表

要将非`InnoDB`表转换为使用，请 `InnoDB`使用[`ALTER TABLE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)：

```sql
ALTER TABLE table_name ENGINE=InnoDB;
```

##### 克隆表的结构

您可以创建`InnoDB`一个克隆 MyISAM 表的表，而不是[`ALTER TABLE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)用于执行转换，以便在切换之前并排测试旧表和新表。

```
InnoDB`创建具有相同列和索引定义 的空表。用于查看要使用的完整 语句。将子句 更改为. `SHOW CREATE TABLE *`table_name`*\G`[`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)`ENGINE``ENGINE=INNODB
```

##### 传输数据



要将大量数据传输到 `InnoDB`如上一节所示创建的空表中，请插入带有. `INSERT INTO *`innodb_table`* SELECT * FROM *`myisam_table`* ORDER BY *`primary_key_columns`*`

您还可以`InnoDB` 在插入数据后为表创建索引。从历史上看，创建新的二级索引是一项缓慢的操作 `InnoDB`，但现在您可以在加载数据后创建索引，而索引创建步骤的开销相对较小。

如果您`UNIQUE`对辅助键有限制，您可以通过在导入操作期间暂时关闭唯一性检查来加快表导入：

```sql
SET unique_checks=0;
... import operation ...
SET unique_checks=1;
```

对于大表，这可以节省磁盘 I/O，因为 `InnoDB`可以使用其 [更改缓冲区](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_change_buffer)将二级索引记录作为批处理写入。确保数据不包含重复键。 [`unique_checks`](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_unique_checks)允许但不要求存储引擎忽略重复键。

为了更好地控制插入过程，您可以分段插入大表：

```sql
INSERT INTO newtable SELECT * FROM oldtable
   WHERE yourkey > something AND yourkey <= somethingelse;
```

插入所有记录后，您可以重命名表。

在大表转换过程中，增加 `InnoDB`缓冲池的大小以减少磁盘 I/O。通常，推荐的缓冲池大小为系统内存的 50% 到 75%。您还可以增加 `InnoDB`日志文件的大小。

##### 存储要求



如果您打算 `InnoDB`在转换过程中为表中的数据制作多个临时副本，建议您在 file-per-table 表空间中创建表，以便在删除表时可以回收磁盘空间。当 [`innodb_file_per_table`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_file_per_table) 启用配置选项（默认）时，新创建 `InnoDB`的表将隐式创建在 file-per-table 表空间中。

无论是`MyISAM`直接转换表还是创建克隆`InnoDB`表，在此过程中请确保您有足够的磁盘空间来容纳新旧表。 **`InnoDB`表比表需要更多的磁盘空间`MyISAM`。** 如果[`ALTER TABLE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)操作空间不足，它会开始回滚，如果它是磁盘绑定的，则可能需要数小时。对于插入，`InnoDB`使用插入缓冲区将二级索引记录批量合并到索引中。这节省了大量的磁盘 I/O。对于回滚，没有使用这种机制，回滚可能需要比插入长 30 倍的时间。

在失控回滚的情况下，如果您的数据库中没有有价值的数据，最好终止数据库进程，而不是等待数百万磁盘 I/O 操作完成。有关完整过程，请参阅 [第 15.21.3 节，“强制 InnoDB 恢复”](https://dev.mysql.com/doc/refman/8.0/en/forcing-innodb-recovery.html)。

##### 定义主键



`PRIMARY KEY`子句是影响 MySQL 查询性能以及表和索引空间使用的关键因素 。主键唯一标识表中的一行。表中的每一行都应该有一个主键值，并且没有两行可以有相同的主键值。

这些是主键的指导方针，然后是更详细的解释。

- `PRIMARY KEY`为每个表 声明一个。`WHERE`通常，它是您在查找单行时 在子句中引用的最重要的列。
- `PRIMARY KEY`在原始语句中 声明子句[`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html) ，而不是稍后通过 [`ALTER TABLE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)语句添加。
- 仔细选择列及其数据类型。首选数字列而不是字符或字符串列。
- 如果没有另一个稳定的、唯一的、非空的数字列可供使用，请考虑使用自动增量列。
- 如果不确定主键列的值是否会改变，自动增量列也是一个不错的选择。更改主键列的值是一项昂贵的操作，可能涉及重新排列表内和每个二级索引内的数据。

考虑向任何还没有主键的表添加[主键。](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_primary_key)根据表格的最大投影大小使用最小的实用数值类型。这可以使每一行稍微更紧凑，这可以为大型表节省大量空间。如果表有任何 [二级索引](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_secondary_index)，则空间节省会成倍增加，因为主键值在每个二级索引条目中重复。除了减少磁盘上的数据大小外，小的主键还可以让更多的数据放入 [缓冲池](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_buffer_pool)，加快各种操作并提高并发性。

如果表在某个较长的列（例如 a ）上已有主键`VARCHAR`，请考虑添加一个新的无符号 `AUTO_INCREMENT`列并将主键切换到该列，即使查询中未引用该列也是如此。这种设计更改可以在二级索引中节省大量空间。您可以指定以前的主键列`UNIQUE NOT NULL`强制执行与子句相同的约束`PRIMARY KEY`，即防止所有这些列中出现重复值或空值。

如果您将相关信息分布在多个表中，通常每个表都使用相同的列作为其主键。例如，一个人事数据库可能有几个表，每个表都有一个员工编号的主键。一个销售数据库可能有一些表的主键是客户编号，而其他表的主键是订单号。由于使用主键的查找速度非常快，因此您可以为此类表构建高效的连接查询。

如果您`PRIMARY KEY`完全忽略该子句，MySQL 会为您创建一个不可见的子句。它是一个 6 字节的值，可能比您需要的要长，因此会浪费空间。因为它是隐藏的，所以您不能在查询中引用它。

##### 应用程序性能注意事项



的可靠性和可扩展性特性 `InnoDB`需要比等效`MyISAM`表更多的磁盘存储空间。您可以稍微更改列和索引定义，以获得更好的空间利用率，减少处理结果集时的 I/O 和内存消耗，以及更好的查询优化计划以有效利用索引查找。

如果您为主键设置数字 ID 列，请使用该值与任何其他表中的相关值交叉引用，尤其是对于[连接](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_join)查询。例如，与其接受国家名称作为输入并执行查询以搜索相同的名称，不如执行一次查找以确定国家 ID，然后执行其他查询（或单个连接查询）以跨多个表查找相关信息。与其将客户或目录项目编号存储为可能会占用多个字节的数字字符串，不如将其转换为数字 ID 以进行存储和查询。一个 4 字节的无符号 [`INT`](https://dev.mysql.com/doc/refman/8.0/en/integer-types.html)列可以索引超过 40 亿个项目（美国的含义是十亿：10 亿）。有关不同整数类型的范围，请参阅 [第 11.1.2 节，“整数类型（精确值） - INTEGER、INT、SMALLINT、TINYINT、MEDIUMINT、BIGINT”](https://dev.mysql.com/doc/refman/8.0/en/integer-types.html)。

##### 了解与 InnoDB 表关联的文件



`InnoDB`文件比文件需要更多的关注和计划`MyISAM`。

- 不得删除 代表[系统表空间的](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_system_tablespace)[ibdata 文件](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_ibdata_file)。 `InnoDB`
- [第 15.6.1.4 节，“移动或复制 InnoDB 表”](https://dev.mysql.com/doc/refman/8.0/en/innodb-migration.html)中描述了将表 移动或复制`InnoDB`到不同服务器的 方法。