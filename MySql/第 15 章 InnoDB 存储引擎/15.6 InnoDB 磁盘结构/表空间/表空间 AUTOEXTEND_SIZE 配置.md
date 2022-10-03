
默认情况下，当 file-per-table 或通用表空间需要额外空间时，表空间会根据以下规则增量扩展：

- 如果表空间的大小小于一个范围，则一次扩展一页。
- 如果表空间的大小大于 1 个扩展区但小于 32 个扩展区，则一次扩展一个扩展区。
- 如果表空间的大小超过 32 个扩展区，则一次扩展四个扩展区。

有关范围大小的信息，请参阅 [第 15.11.2 节，“文件空间管理”](https://dev.mysql.com/doc/refman/8.0/en/innodb-file-space.html)。

从 MySQL 8.0.23 开始，文件每表或通用表空间的扩展量可通过指定 `AUTOEXTEND_SIZE`选项进行配置。配置更大的扩展大小可以帮助避免碎片并促进大量数据的摄取。

要配置 file-per-table 表空间的扩展大小，请在or 语句 中指定`AUTOEXTEND_SIZE`大小 ：[`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)[`ALTER TABLE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)

```sql
CREATE TABLE t1 (c1 INT) AUTOEXTEND_SIZE = 4M;
ALTER TABLE t1 AUTOEXTEND_SIZE = 8M;
```

要配置通用表空间的扩展大小，请在or 语句 中指定`AUTOEXTEND_SIZE`大小 ：[`CREATE TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/create-tablespace.html)[`ALTER TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/alter-tablespace.html)

```sql
CREATE TABLESPACE ts1 AUTOEXTEND_SIZE = 4M;
ALTER TABLESPACE ts1 AUTOEXTEND_SIZE = 8M;
```

笔记

该`AUTOEXTEND_SIZE`选项也可以在创建撤消表空间时使用，但撤消表空间的扩展行为不同。有关更多信息，请参阅 [第 15.6.3.4 节，“撤消表空间”](https://dev.mysql.com/doc/refman/8.0/en/innodb-undo-tablespaces.html)。

该`AUTOEXTEND_SIZE`设置必须是 4M 的倍数。指定`AUTOEXTEND_SIZE`不是 4M 倍数的设置会返回错误。

默认设置为 0，这`AUTOEXTEND_SIZE`会导致根据上述默认行为扩展表空间。

MySQL 8.0.23 中最大`AUTOEXTEND_SIZE`设置为 64M。从 MySQL 8.0.24 开始，最大设置为 4GB。

最小`AUTOEXTEND_SIZE`设置取决于`InnoDB`页面大小，如下表所示：

| InnoDB 页面大小 | 最小 AUTOEXTEND_SIZE |
| :-------------- | :------------------- |
| `4K`            | `4M`                 |
| `8K`            | `4M`                 |
| `16K`           | `4M`                 |
| `32K`           | `8M`                 |
| `64K`           | `16M`                |

默认`InnoDB`页面大小为 16K（16384 字节）。要确定`InnoDB`您的 MySQL 实例的页面大小，请查询 [`innodb_page_size`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_page_size)设置：

```sql
mysql> SELECT @@GLOBAL.innodb_page_size;
+---------------------------+
| @@GLOBAL.innodb_page_size |
+---------------------------+
|                     16384 |
+---------------------------+
```

当`AUTOEXTEND_SIZE`更改表空间的设置时，随后发生的第一个扩展会将表空间大小增加到 `AUTOEXTEND_SIZE`设置的倍数。后续扩展具有配置的大小。

当使用非零`AUTOEXTEND_SIZE`设置创建 file-per-table 或通用表空间时，表空间将初始化为指定 `AUTOEXTEND_SIZE`大小。

[`ALTER TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/alter-tablespace.html)不能用于配置`AUTOEXTEND_SIZE`file-per-table 表空间。[`ALTER TABLE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)必须使用。

对于在 file-per-table 表空间中创建的表， 仅当它配置为非零值时才 [`SHOW CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/show-create-table.html)显示该 选项。`AUTOEXTEND_SIZE`

要确定`AUTOEXTEND_SIZE`任何 `InnoDB`表空间，请查询该 [`INFORMATION_SCHEMA.INNODB_TABLESPACES`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-innodb-tablespaces-table.html) 表。例如：

```sql
mysql> SELECT NAME, AUTOEXTEND_SIZE FROM INFORMATION_SCHEMA.INNODB_TABLESPACES 
       WHERE NAME LIKE 'test/t1';
+---------+-----------------+
| NAME    | AUTOEXTEND_SIZE |
+---------+-----------------+
| test/t1 |         4194304 |
+---------+-----------------+

mysql> SELECT NAME, AUTOEXTEND_SIZE FROM INFORMATION_SCHEMA.INNODB_TABLESPACES 
       WHERE NAME LIKE 'ts1';
+------+-----------------+
| NAME | AUTOEXTEND_SIZE |
+------+-----------------+
| ts1  |         4194304 |
+------+-----------------+
```

笔记

An `AUTOEXTEND_SIZE`of 0 是默认设置，表示根据上述默认表空间扩展行为扩展表空间。