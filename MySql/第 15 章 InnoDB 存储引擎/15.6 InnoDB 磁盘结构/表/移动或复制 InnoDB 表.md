#### 15.6.1.4 移动或复制 InnoDB 表



本节介绍将部分或全部 `InnoDB`表移动或复制到不同服务器或实例的技术。例如，您可以将整个 MySQL 实例移动到更大、更快的服务器；您可以将整个 MySQL 实例克隆到新的副本服务器；您可以将单个表复制到另一个实例以开发和测试应用程序，或者复制到数据仓库服务器以生成报告。

在 Windows 上，`InnoDB`始终在内部以小写形式存储数据库和表名。要将二进制格式的数据库从 Unix 移动到 Windows 或从 Windows 移动到 Unix，请使用小写名称创建所有数据库和表。一种方便的方法是 在创建任何数据库或表之前将以 下行添加到您的或文件的`[mysqld]`部分 ：`my.cnf``my.ini`

```ini
[mysqld]
lower_case_table_names=1
```

笔记

禁止 [`lower_case_table_names`](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_lower_case_table_names)使用与初始化服务器时使用的设置不同的设置来启动服务器。

移动或复制`InnoDB`表格的技术包括：

- [导入表](https://dev.mysql.com/doc/refman/8.0/en/innodb-migration.html#copy-tables-import)
- [MySQL 企业备份](https://dev.mysql.com/doc/refman/8.0/en/innodb-migration.html#copy-tables-meb)
- [复制数据文件（冷备份方法）](https://dev.mysql.com/doc/refman/8.0/en/innodb-migration.html#copy-tables-cold-backup)
- [从逻辑备份恢复](https://dev.mysql.com/doc/refman/8.0/en/innodb-migration.html#copy-tables-logical-backup)

##### 导入表

驻留在每表文件表空间中的表可以从另一个 MySQL 服务器实例或使用可 *传输表空间*功能的备份导入。请参阅 [第 15.6.1.3 节，“导入 InnoDB 表”](https://dev.mysql.com/doc/refman/8.0/en/innodb-table-import.html)。

##### MySQL 企业备份

MySQL Enterprise Backup 产品可让您备份正在运行的 MySQL 数据库，同时尽可能减少对操作的干扰，同时生成一致的数据库快照。当 MySQL Enterprise Backup 正在复制表时，可以继续读取和写入。此外，MySQL Enterprise Backup 可以创建压缩备份文件，并备份表的子集。结合 MySQL 二进制日志，您可以执行时间点恢复。MySQL Enterprise Backup 包含在 MySQL Enterprise 订阅中。

有关 MySQL 企业备份的更多详细信息，请参阅 [第 30.2 节，“MySQL 企业备份概述”](https://dev.mysql.com/doc/refman/8.0/en/mysql-enterprise-backup.html)。

##### 复制数据文件（冷备份方法）

您只需复制[第 15.18.1 节“InnoDB 备份”](https://dev.mysql.com/doc/refman/8.0/en/innodb-backup.html)`InnoDB`中“冷备份”下列出的所有相关文件即可移动数据库 。

`InnoDB`数据和日志文件在具有相同浮点数格式的所有平台上都是二进制兼容的。如果浮点格式不同但您的表中没有使用 [`FLOAT`](https://dev.mysql.com/doc/refman/8.0/en/floating-point-types.html)或 [`DOUBLE`](https://dev.mysql.com/doc/refman/8.0/en/floating-point-types.html)数据类型，则过程相同：只需复制相关文件即可。

当您移动或复制 file-per-table`.ibd` 文件时，源系统和目标系统上的数据库目录名称必须相同。存储在 `InnoDB`共享表空间中的表定义包括数据库名称。存储在表空间文件中的事务 ID 和日志序列号也因数据库而异。

要将`.ibd`文件和关联表从一个数据库移动到另一个数据库，请使用以下[`RENAME TABLE`](https://dev.mysql.com/doc/refman/8.0/en/rename-table.html)语句：

```sql
RENAME TABLE db1.tbl_name TO db2.tbl_name;
```



如果你有一个文件的“干净”备份 `.ibd`，你可以将它恢复到它起源的 MySQL 安装，如下所示：

1. 自从您复制文件后，该表不得被删除或截断`.ibd`，因为这样做会更改存储在表空间中的表 ID。

2. 发出此[`ALTER TABLE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)语句以删除当前`.ibd`文件：

   ```sql
   ALTER TABLE tbl_name DISCARD TABLESPACE;
   ```

3. 将备份`.ibd`文件复制到正确的数据库目录。

4. 发出此[`ALTER TABLE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)语句以告知`InnoDB`对表使用新 `.ibd`文件：

   ```sql
   ALTER TABLE tbl_name IMPORT TABLESPACE;
   ```

   笔记

   该[`ALTER TABLE ... IMPORT TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)功能不对导入的数据强制执行外键约束。

在这种情况下，“干净” `.ibd` 文件备份是满足以下要求的备份：

- 文件中的事务没有未提交的修改 `.ibd`。
- 文件中没有未合并的插入缓冲区条目 `.ibd`。
- Purge 已从 `.ibd`文件中删除所有带有删除标记的索引记录。
- [**mysqld**](https://dev.mysql.com/doc/refman/8.0/en/mysqld.html)已将文件的所有修改页面从缓冲池刷新 `.ibd`到文件。

`.ibd`您可以使用以下方法 制作干净的备份文件：

1. 停止来自[**mysqld**](https://dev.mysql.com/doc/refman/8.0/en/mysqld.html)服务器的所有活动并提交所有事务。
2. 等到[`SHOW ENGINE INNODB STATUS`](https://dev.mysql.com/doc/refman/8.0/en/show-engine.html)显示数据库中没有活动事务，主线程状态 `InnoDB`为`Waiting for server activity`。然后，您可以制作该文件的副本 `.ibd`。

另一种制作文件干净副本的方法 `.ibd`是使用 MySQL Enterprise Backup 产品：

1. 使用 MySQL Enterprise Backup 备份 `InnoDB`安装。
2. 在备份上启动第二个[**mysqld**](https://dev.mysql.com/doc/refman/8.0/en/mysqld.html)服务器并让它清理备份中的`.ibd`文件。

##### 从逻辑备份恢复

您可以使用诸如[**mysqldump**](https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html)之类的实用程序来执行逻辑备份，它会生成一组 SQL 语句，可以执行这些语句来重现原始数据库对象定义和表数据以传输到另一个 SQL 服务器。使用此方法，格式是否不同或您的表是否包含浮点数据都无关紧要。

要提高此方法的性能，请 [`autocommit`](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_autocommit)在导入数据时禁用。仅在导入整个表或表的段后执行提交。