#### 15.6.1.3 导入 InnoDB 表



本节介绍如何使用可 *传输表空间*功能导入表，该功能允许导入位于 file-per-table 表空间中的表、分区表或单个表分区。您可能想要导入表的原因有很多：

- 在非生产 MySQL 服务器实例上运行报告以避免在生产服务器上增加额外负载。
- 将数据复制到新的副本服务器。
- 从备份的表空间文件中恢复表。
- 作为一种比导入转储文件更快的移动数据方式，这需要重新插入数据和重建索引。
- 将数据移动到具有更适合您的存储要求的存储介质的服务器。例如，您可以将繁忙的表移至 SSD 设备，或将大型表移至大容量 HDD 设备。

本节中的以下主题描述了 可*传输表空间功能：*

- [先决条件](https://dev.mysql.com/doc/refman/8.0/en/innodb-table-import.html#innodb-table-import-prerequsites)
- [导入表](https://dev.mysql.com/doc/refman/8.0/en/innodb-table-import.html#innodb-table-import-example)
- [导入分区表](https://dev.mysql.com/doc/refman/8.0/en/innodb-table-import.html#innodb-table-import-partitioned-table)
- [导入表分区](https://dev.mysql.com/doc/refman/8.0/en/innodb-table-import.html#innodb-table-import-partitions)
- [限制](https://dev.mysql.com/doc/refman/8.0/en/innodb-table-import.html#innodb-table-import-limitations)
- [使用说明](https://dev.mysql.com/doc/refman/8.0/en/innodb-table-import.html#innodb-table-import-usage-notes)
- [内件](https://dev.mysql.com/doc/refman/8.0/en/innodb-table-import.html#innodb-table-import-internals)

##### 先决条件

- 该[`innodb_file_per_table`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_file_per_table) 变量必须启用，默认情况下是启用的。
- 表空间的页面大小必须与目标 MySQL 服务器实例的页面大小相匹配。 `InnoDB`页面大小由 [`innodb_page_size`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_page_size)变量定义，该变量在初始化 MySQL 服务器实例时配置。
- 如果表有外键关系， [`foreign_key_checks`](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_foreign_key_checks)执行前必须禁用`DISCARD TABLESPACE`。此外，您应该在同一逻辑时间点导出所有与外键相关的表，因为 [`ALTER TABLE ... IMPORT TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)不会对导入的数据实施外键约束。为此，请停止更新相关表，提交所有事务，获取表上的共享锁，然后执行导出操作。
- 从另一个 MySQL 服务器实例导入表时，两个 MySQL 服务器实例必须具有通用可用性 (GA) 状态并且必须是相同的版本。否则，表必须在导入它的同一个 MySQL 服务器实例上创建。
- `DATA DIRECTORY`如果表是通过在语句中指定子句在 外部目录中创建的[`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)，则您在目标实例上替换的表必须使用相同的`DATA DIRECTORY` 子句定义。如果子句不匹配，则会报告架构不匹配错误。要确定源表是否使用`DATA DIRECTORY`子句定义，请使用 [`SHOW CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/show-create-table.html)查看表定义。有关使用该 `DATA DIRECTORY`子句的信息，请参阅 [第 15.6.1.2 节，“在外部创建表”](https://dev.mysql.com/doc/refman/8.0/en/innodb-create-table-external.html)。
- 如果`ROW_FORMAT`未在表定义中明确定义或 `ROW_FORMAT=DEFAULT`使用选项， [`innodb_default_row_format`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_default_row_format) 则源实例和目标实例上的设置必须相同。否则，当您尝试导入操作时会报告架构不匹配错误。用于 [`SHOW CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/show-create-table.html)检查表定义。用于[`SHOW VARIABLES`](https://dev.mysql.com/doc/refman/8.0/en/show-variables.html)检查 [`innodb_default_row_format`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_default_row_format) 设置。有关相关信息，请参阅 [定义表格的行格式](https://dev.mysql.com/doc/refman/8.0/en/innodb-row-format.html#innodb-row-format-defining)。

##### 导入表

此示例演示如何导入驻留在 file-per-table 表空间中的常规非分区表。

1. 在目标实例上，创建一个与您要导入的表具有相同定义的表。（您可以使用[`SHOW CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/show-create-table.html)语法获取表定义。）如果表定义不匹配，则尝试导入操作时会报告架构不匹配错误。

   ```sql
   mysql> USE test;
   mysql> CREATE TABLE t1 (c1 INT) ENGINE=INNODB;
   ```

2. 在目标实例上，丢弃刚刚创建的表的表空间。（导入前必须丢弃接收表的表空间。）

   ```sql
   mysql> ALTER TABLE t1 DISCARD TABLESPACE;
   ```

3. 在源实例上，运行 [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)以静默您要导入的表。当表被停顿时，表上只允许只读事务。

   ```sql
   mysql> USE test;
   mysql> FLUSH TABLES t1 FOR EXPORT;
   ```

   [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)确保对命名表的更改刷新到磁盘，以便在服务器运行时可以制作二进制表副本。[`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)运行时， 在 表的模式目录中`InnoDB`生成一个 元数据文件。`.cfg`该`.cfg`文件包含在导入操作期间用于模式验证的元数据。

   笔记

   在操作运行时，执行的连接 [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)必须保持打开状态；否则， `.cfg`文件将被删除，因为在连接关闭时释放锁。

4. 将`.ibd`文件和 `.cfg`元数据文件从源实例复制到目标实例。例如：

   ```terminal
   $> scp /path/to/datadir/test/t1.{ibd,cfg} destination-server:/path/to/datadir/test
   ```

   必须在释放共享锁之前复制文件和文件，如下一步 所述`.ibd`。 `.cfg`

   笔记

   如果您要从加密表空间导入表，则 除了 元数据文件之外，还会`InnoDB`生成一个 文件。该 文件必须与该 文件一起复制到目标实例。该 文件包含一个传输密钥和一个加密的表空间密钥。导入时， 使用传输密钥解密表空间密钥。有关相关信息，请参阅 [第 15.13 节，“InnoDB 静态数据加密”](https://dev.mysql.com/doc/refman/8.0/en/innodb-data-encryption.html)。 `.cfp``.cfg``.cfp``.cfg``.cfp``InnoDB`

5. 在源实例上，用于 释放语句 [`UNLOCK TABLES`](https://dev.mysql.com/doc/refman/8.0/en/lock-tables.html)获取的锁 ：[`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)

   ```sql
   mysql> USE test;
   mysql> UNLOCK TABLES;
   ```

   该[`UNLOCK TABLES`](https://dev.mysql.com/doc/refman/8.0/en/lock-tables.html)操作还会删除该 `.cfg`文件。

6. 在目标实例上，导入表空间：

   ```sql
   mysql> USE test;
   mysql> ALTER TABLE t1 IMPORT TABLESPACE;
   ```

##### 导入分区表

此示例演示如何导入分区表，其中每个表分区驻留在每个表的文件表空间中。

1. 在目标实例上，创建一个与要导入的分区表具有相同定义的分区表。（您可以使用 [`SHOW CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/show-create-table.html)语法获取表定义。）如果表定义不匹配，则尝试导入操作时会报告架构不匹配错误。

   ```sql
   mysql> USE test;
   mysql> CREATE TABLE t1 (i int) ENGINE = InnoDB PARTITION BY KEY (i) PARTITIONS 3;
   ```

   在该 目录中， 三个分区中的每一个都有一个表空间文件。 `/*`datadir`*/test``.ibd`

   ```terminal
   mysql> \! ls /path/to/datadir/test/
   t1#p#p0.ibd  t1#p#p1.ibd  t1#p#p2.ibd
   ```

2. 在目标实例上，丢弃分区表的表空间。（在导入操作之前，必须丢弃接收表的表空间。）

   ```sql
   mysql> ALTER TABLE t1 DISCARD TABLESPACE;
   ```

   分区表的三个表空间`.ibd`文件从 目录中丢弃。 `/*`datadir`*/test`

3. 在源实例上，运行 [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)以静默您要导入的分区表。当表被停顿时，表上只允许只读事务。

   ```sql
   mysql> USE test;
   mysql> FLUSH TABLES t1 FOR EXPORT;
   ```

   [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)确保对命名表的更改刷新到磁盘，以便在服务器运行时可以进行二进制表副本。[`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)运行时， 在 表的模式目录中为每个表的表空间文件`InnoDB`生成 `.cfg`元数据文件。

   ```terminal
   mysql> \! ls /path/to/datadir/test/
   t1#p#p0.ibd  t1#p#p1.ibd  t1#p#p2.ibd
   t1#p#p0.cfg  t1#p#p1.cfg  t1#p#p2.cfg
   ```

   这些`.cfg`文件包含在导入表空间时用于模式验证的元数据。 [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)只能在表上运行，不能在单个表分区上运行。

4. 将`.ibd`和 `.cfg`文件从源实例模式目录复制到目标实例模式目录。例如：

   ```terminal
   $>scp /path/to/datadir/test/t1*.{ibd,cfg} destination-server:/path/to/datadir/test
   ```

   和 文件必须在释放共享锁之前复制，如下一步所述 `.ibd`。`.cfg`

   笔记

   如果您从加密表空间导入表， 除了 元数据文件之外，还会`InnoDB`生成一个 文件。文件必须与文件一起复制到目标 实例 。这些 文件包含一个传输密钥和一个加密的表空间密钥。导入时， 使用传输密钥解密表空间密钥。有关相关信息，请参阅 [第 15.13 节，“InnoDB 静态数据加密”](https://dev.mysql.com/doc/refman/8.0/en/innodb-data-encryption.html)。 `.cfp``.cfg``.cfp``.cfg``.cfp``InnoDB`

5. 在源实例上，用于 [`UNLOCK TABLES`](https://dev.mysql.com/doc/refman/8.0/en/lock-tables.html)释放以下获取的锁 [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)：

   ```sql
   mysql> USE test;
   mysql> UNLOCK TABLES;
   ```

6. 在目标实例上，导入分区表的表空间：

   ```sql
   mysql> USE test;
   mysql> ALTER TABLE t1 IMPORT TABLESPACE;
   ```

##### 导入表分区

此示例演示如何导入单个表分区，其中每个分区驻留在一个 file-per-table 表空间文件中。

在以下示例中，导入了四分区表的 两个分区 (`p2` 和)。`p3`

1. 在目标实例上，创建一个与要从中导入分区的分区表具有相同定义的分区表。（您可以使用[`SHOW CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/show-create-table.html)语法获取表定义。）如果表定义不匹配，则尝试导入操作时会报告架构不匹配错误。

   ```sql
   mysql> USE test;
   mysql> CREATE TABLE t1 (i int) ENGINE = InnoDB PARTITION BY KEY (i) PARTITIONS 4;
   ```

   在该 目录中， 四个分区中的每一个都有一个表空间文件。 `/*`datadir`*/test``.ibd`

   ```terminal
   mysql> \! ls /path/to/datadir/test/
   t1#p#p0.ibd  t1#p#p1.ibd  t1#p#p2.ibd t1#p#p3.ibd
   ```

2. 在目标实例上，丢弃您打算从源实例导入的分区。（在导入分区之前，您必须从接收分区表中丢弃相应的分区。）

   ```sql
   mysql> ALTER TABLE t1 DISCARD PARTITION p2, p3 TABLESPACE;
   ```

   两个废弃分区的表空间`.ibd`文件将从目标实例的目录中删除 ，留下以下文件： `/*`datadir`*/test`

   ```terminal
   mysql> \! ls /path/to/datadir/test/
   t1#p#p0.ibd  t1#p#p1.ibd
   ```

   笔记

   当[`ALTER TABLE ... DISCARD PARTITION ... TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)在子分区表上运行时，允许分区和子分区表名称。指定分区名称时，该分区的子分区将包含在操作中。

3. 在源实例上，运行 [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)以静默分区表。当表被停顿时，表上只允许只读事务。

   ```sql
   mysql> USE test;
   mysql> FLUSH TABLES t1 FOR EXPORT;
   ```

   [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)确保对命名表的更改刷新到磁盘，以便在实例运行时可以进行二进制表副本。[`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)运行时， 为 表的模式目录中的每个表的表空间文件 `InnoDB`生成一个 元数据文件。`.cfg`

   ```terminal
   mysql> \! ls /path/to/datadir/test/
   t1#p#p0.ibd  t1#p#p1.ibd  t1#p#p2.ibd t1#p#p3.ibd
   t1#p#p0.cfg  t1#p#p1.cfg  t1#p#p2.cfg t1#p#p3.cfg
   ```

   这些`.cfg`文件包含在导入操作期间用于模式验证的元数据。 [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)只能在表上运行，不能在单个表分区上运行。

4. 将分区和分区的`.ibd`和 `.cfg`文件 从源实例架构目录复制到目标实例架构目录。 `p2``p3`

   ```terminal
   $> scp t1#p#p2.ibd t1#p#p2.cfg t1#p#p3.ibd t1#p#p3.cfg destination-server:/path/to/datadir/test
   ```

   和 文件必须在释放共享锁之前复制，如下一步所述 `.ibd`。`.cfg`

   笔记

   如果您要从加密表空间导入分区，则除了 元数据文件之外，还会`InnoDB`生成一个 文件。文件必须与文件一起复制到目标 实例 。这些 文件包含一个传输密钥和一个加密的表空间密钥。导入时， 使用传输密钥解密表空间密钥。有关相关信息，请参阅 [第 15.13 节，“InnoDB 静态数据加密”](https://dev.mysql.com/doc/refman/8.0/en/innodb-data-encryption.html)。 `.cfp``.cfg``.cfp``.cfg``.cfp``InnoDB`

5. 在源实例上，用于 [`UNLOCK TABLES`](https://dev.mysql.com/doc/refman/8.0/en/lock-tables.html)释放以下获取的锁 [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)：

   ```sql
   mysql> USE test;
   mysql> UNLOCK TABLES;
   ```

6. 在目标实例上，导入表分区 `p2`和`p3`：

   ```sql
   mysql> USE test;
   mysql> ALTER TABLE t1 IMPORT PARTITION p2, p3 TABLESPACE;
   ```

   笔记

   当[`ALTER TABLE ... IMPORT PARTITION ... TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)在子分区表上运行时，允许分区和子分区表名称。指定分区名称时，该分区的子分区将包含在操作中。

##### 限制

- 可*传输表空间*功能仅支持驻留在 file-per-table 表空间中的表。驻留在系统表空间或通用表空间中的表不支持它。共享表空间中的表不能被停顿。

- [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)具有`FULLTEXT`索引的表不支持，因为无法刷新全文搜索辅助表。导入带有`FULLTEXT`索引的表后，运行 [`OPTIMIZE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/optimize-table.html)以重建 `FULLTEXT`索引。或者，在导出操作之前删除 `FULLTEXT`索引并在目标实例上导入表后重新创建索引。

- 由于`.cfg`元数据文件的限制，在导入分区表时不会报告分区类型或分区定义差异的架构不匹配。报告列差异。

- 在 MySQL 8.0.19 之前，索引键部分排序顺序信息不会存储到`.cfg`表空间导入操作期间使用的元数据文件中。因此，索引键部分的排序顺序被假定为升序，这是默认值。因此，如果导入操作中涉及的一个表是使用 DESC 索引键部分排序顺序定义的，而另一个表没有定义，则记录可能会以意外的顺序排序。解决方法是删除并重新创建受影响的索引。有关索引键部分排序顺序的信息，请参阅[第 13.1.15 节，“CREATE INDEX 语句”](https://dev.mysql.com/doc/refman/8.0/en/create-index.html)。

  文件格式在 MySQL 8.0.19 中更新，`.cfg`包括索引键部分排序信息。上述问题不影响 MySQL 8.0.19 服务器实例或更高版本之间的导入操作。

##### 使用说明

- 除了包含立即添加或删除的列的表外， [`ALTER TABLE ... IMPORT TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)不需要 `.cfg`元数据文件来导入表。但是，在没有文件的情况下导入时不会执行元数据检查`.cfg`，并且会发出类似于以下内容的警告：

  ```none
  Message: InnoDB: IO Read error: (2, No such file or directory) Error opening '.\
  test\t.cfg', will attempt to import without schema verification
  1 row in set (0.00 sec)
  ```

  `.cfg` 只有在没有预期架构不匹配并且表不包含任何立即添加或删除的列时，才应考虑 导入没有元数据文件的表。在无法访问元数据的崩溃恢复场景中，无需文件即可导入的功能`.cfg`可能很有用。

  尝试导入包含在`ALGORITHM=INSTANT`不使用`.cfg`文件的情况下添加或删除的列的表可能会导致未定义的行为。

- 在 Windows 上，`InnoDB`以小写形式在内部存储数据库、表空间和表名。为避免在 Linux 和 Unix 等区分大小写的操作系统上出现导入问题，请使用小写名称创建所有数据库、表空间和表。确保名称以小写形式创建的一种便捷方法是 [`lower_case_table_names`](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_lower_case_table_names)在初始化服务器之前设置为 1。（禁止 [`lower_case_table_names`](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_lower_case_table_names) 使用与初始化服务器时使用的设置不同的设置来启动服务器。）

  ```none
  [mysqld]
  lower_case_table_names=1
  ```

- 在子分区表上运行时 [`ALTER TABLE ... DISCARD PARTITION ... TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)， [`ALTER TABLE ... IMPORT PARTITION ... TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)允许使用分区和子分区表名称。指定分区名称时，该分区的子分区将包含在操作中。

##### 内件

以下信息描述了在表导入过程中写入错误日志的内部信息和消息。

何时[`ALTER TABLE ... DISCARD TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)在目标实例上运行：

- 表被锁定在 X 模式。
- 表空间与表分离。

何时 [`FLUSH TABLES ... FOR EXPORT`](https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-for-export-with-list)在源实例上运行：

- 为导出而刷新的表被锁定在共享模式。
- 清除协调器线程已停止。
- 脏页同步到磁盘。
- 表元数据被写入二进制 `.cfg`文件。

此操作的预期错误日志消息：

```none
[Note] InnoDB: Sync to disk of '"test"."t1"' started.
[Note] InnoDB: Stopping purge
[Note] InnoDB: Writing table metadata to './test/t1.cfg'
[Note] InnoDB: Table '"test"."t1"' flushed to disk
```

何时[`UNLOCK TABLES`](https://dev.mysql.com/doc/refman/8.0/en/lock-tables.html)在源实例上运行：

- 二进制`.cfg`文件被删除。
- 正在导入的一个或多个表上的共享锁被释放并重新启动清除协调器线程。

此操作的预期错误日志消息：

```none
[Note] InnoDB: Deleting the meta-data file './test/t1.cfg'
[Note] InnoDB: Resuming purge
```

当[`ALTER TABLE ... IMPORT TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)在目标实例上运行时，导入算法对正在导入的每个表空间执行以下操作：

- 检查每个表空间页面是否损坏。
- 每个页面上的空间 ID 和日志序列号 (LSN) 都会更新。
- 为标题页验证标志并更新 LSN。
- Btree 页面已更新。
- 页面状态设置为脏，以便将其写入磁盘。

此操作的预期错误日志消息：

```none
[Note] InnoDB: Importing tablespace for table 'test/t1' that was exported
from host 'host_name'
[Note] InnoDB: Phase I - Update all pages
[Note] InnoDB: Sync to disk
[Note] InnoDB: Sync to disk - done!
[Note] InnoDB: Phase III - Flush changes to disk
[Note] InnoDB: Phase IV - Flush complete
```

笔记

`.ibd`您可能还会收到一个表空间被丢弃的警告（如果您丢弃了目标表的表空间）和一条消息，指出由于缺少文件 而无法计算统计信息：

```none
[Warning] InnoDB: Table "test"."t1" tablespace is set as discarded.
7f34d9a37700 InnoDB: cannot calculate statistics for table
"test"."t1" because the .ibd file is missing. For help, please refer to
http://dev.mysql.com/doc/refman/8.0/en/innodb-troubleshooting.html
```