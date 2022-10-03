#### 15.6.3.2 File-Per-Table 表空间



file-per-table 表空间包含单个 `InnoDB`表的数据和索引，并存储在文件系统中的单个数据文件中。

File-per-table 表空间特性在本节的以下主题下进行描述：

- [File-Per-Table 表空间配置](https://dev.mysql.com/doc/refman/8.0/en/innodb-file-per-table-tablespaces.html#innodb-file-per-table-configuration)
- [File-Per-Table 表空间数据文件](https://dev.mysql.com/doc/refman/8.0/en/innodb-file-per-table-tablespaces.html#innodb-file-per-table-data-files)
- [File-Per-Table 表空间优势](https://dev.mysql.com/doc/refman/8.0/en/innodb-file-per-table-tablespaces.html#innodb-file-per-table-advantages)
- [File-Per-Table 表空间的缺点](https://dev.mysql.com/doc/refman/8.0/en/innodb-file-per-table-tablespaces.html#innodb-file-per-table-disadvantages)

##### File-Per-Table 表空间配置

`InnoDB`默认情况下在 file-per-table 表空间中创建表。此行为由 [`innodb_file_per_table`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_file_per_table)变量控制。禁用[`innodb_file_per_table`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_file_per_table) 导致`InnoDB`在系统表空间中创建表。

可以在选项文件中指定[`innodb_file_per_table`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_file_per_table) 设置，也可以在运行时使用 [`SET GLOBAL`](https://dev.mysql.com/doc/refman/8.0/en/set-variable.html)语句配置设置。在运行时更改设置需要足够的权限来设置全局系统变量。请参见[第 5.1.9.1 节，“系统变量权限”](https://dev.mysql.com/doc/refman/8.0/en/system-variable-privileges.html)。

选项文件：

```ini
[mysqld]
innodb_file_per_table=ON
```

[`SET GLOBAL`](https://dev.mysql.com/doc/refman/8.0/en/set-variable.html)在运行时 使用：

```sql
mysql> SET GLOBAL innodb_file_per_table=ON;
```

##### File-Per-Table 表空间数据文件

```
.ibd`在 MySQL 数据目录下的模式目录 中的数据文件中创建一个 file-per-table 表空间 。该`.ibd`文件以表 ( `*`table_name`*.ibd`) 命名。例如，在 MySQL 数据目录下的目录下 `test.t1` 创建table 的数据文件：`test
mysql> USE test;

mysql> CREATE TABLE t1 (
   id INT PRIMARY KEY AUTO_INCREMENT,
   name VARCHAR(100)
 ) ENGINE = InnoDB;

$> cd /path/to/mysql/data/test
$> ls
t1.ibd
```

您可以使用该语句的`DATA DIRECTORY`子句 [`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)在数据目录之外隐式创建一个 file-per-table 表空间数据文件。有关更多信息，请参阅 [第 15.6.1.2 节，“在外部创建表”](https://dev.mysql.com/doc/refman/8.0/en/innodb-create-table-external.html)。

##### File-Per-Table 表空间优势

File-per-table 表空间与共享表空间（如系统表空间或通用表空间）相比具有以下优点。

- 在截断或删除在 file-per-table 表空间中创建的表后，磁盘空间将返回给操作系统。截断或删除存储在共享表空间中的表会在共享表空间数据文件中创建只能用于 `InnoDB`数据的可用空间。换句话说，共享表空间数据文件在表被截断或删除后不会缩小。
- [`ALTER TABLE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html) 对位于共享表空间中的表执行 表复制操作会增加表空间占用的磁盘空间量。此类操作可能需要与表中的数据加上索引一样多的额外空间。该空间不会像 file-per-table 表空间那样释放回操作系统。
- [`TRUNCATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/truncate-table.html)在驻留在 file-per-table 表空间中的表上执行时性能更好。
- File-per-table 表空间数据文件可以在单独的存储设备上创建，用于 I/O 优化、空间管理或备份目的。请参阅 [第 15.6.1.2 节，“在外部创建表”](https://dev.mysql.com/doc/refman/8.0/en/innodb-create-table-external.html)。
- 您可以从另一个 MySQL 实例导入驻留在 file-per-table 表空间中的表。请参阅 [第 15.6.1.3 节，“导入 InnoDB 表”](https://dev.mysql.com/doc/refman/8.0/en/innodb-table-import.html)。
- 在 file-per-table 表空间中创建的表支持与系统表空间不支持的行格式相关的`DYNAMIC`功能 `COMPRESSED`。请参阅 [第 15.10 节，“InnoDB 行格式”](https://dev.mysql.com/doc/refman/8.0/en/innodb-row-format.html)。
- 当发生数据损坏、备份或二进制日志不可用或 MySQL 服务器实例无法重新启动时，存储在单个表空间数据文件中的表可以节省时间并提高成功恢复的机会。
- 在 file-per-table 表空间中创建的表可以使用 MySQL Enterprise Backup 快速备份或恢复，而不会中断其他 `InnoDB`表的使用。这对于备份计划不同或需要较少备份的表很有用。有关详细信息，请参阅[进行部分备份](https://dev.mysql.com/doc/mysql-enterprise-backup/8.0/en/partial.html)。
- File-per-table 表空间允许通过监视表空间数据文件的大小来监视文件系统上的表大小。
- [`innodb_flush_method`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_flush_method)当设置为 时，常见的 Linux 文件系统不允许并发写入单个文件，例如共享表空间数据文件 `O_DIRECT`。因此，将 file-per-table 表空间与此设置结合使用时，可能会提高性能。
- 共享表空间中的表的大小受 64TB 表空间大小限制。相比之下，每个 file-per-table 表空间的大小限制为 64TB，这为各个表的大小增长提供了充足的空间。

##### File-Per-Table 表空间的缺点

与系统表空间或通用表空间等共享表空间相比，File-per-table 表空间具有以下缺点。

- 使用 file-per-table 表空间，每个表可能都有未使用的空间，只能由同一个表的行使用，如果管理不当，可能会导致空间浪费。
- `fsync`操作是在多个 file-per-table 数据文件而不是单个共享表空间数据文件上执行的。由于 `fsync`操作是针对每个文件的，因此无法组合多个表的写入操作，这可能会导致`fsync` 操作总数增加。
- [**mysqld**](https://dev.mysql.com/doc/refman/8.0/en/mysqld.html)必须为每个 file-per-table 表空间保留一个打开的文件句柄，如果您在 file-per-table 表空间中有许多表，这可能会影响性能。
- 当每个表都有自己的数据文件时，需要更多的文件描述符。
- 可能会出现更多碎片，这可能会阻碍 [`DROP TABLE`](https://dev.mysql.com/doc/refman/8.0/en/drop-table.html)表扫描性能。然而，如果碎片是被管理的，file-per-table 表空间可以提高这些操作的性能。
- 删除驻留在每表文件表空间中的表时会扫描缓冲池，这对于大型缓冲池可能需要几秒钟。使用广泛的内部锁执行扫描，这可能会延迟其他操作。
- 该 [`innodb_autoextend_increment`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoextend_increment) 变量定义了用于在自动扩展共享表空间文件变满时扩展其大小的增量大小，不适用于 file-per-table 表空间文件，无论 [`innodb_autoextend_increment`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoextend_increment) 设置如何，这些文件都会自动扩展。最初的 file-per-table 表空间扩展是少量的，之后扩展以 4MB 为增量发生。