#### 15.6.1.1 创建 InnoDB 表



`InnoDB`使用 [`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)语句创建表；例如：

```sql
CREATE TABLE t1 (a INT, b CHAR (20), PRIMARY KEY (a)) ENGINE=InnoDB;
```

当定义为默认存储引擎时，`ENGINE=InnoDB`不需要 该子句，默认情况下。`InnoDB`但是， 如果要在默认存储引擎不存在或未知的不同 MySQL 服务器实例上重播该语句，则该`ENGINE`子句很有用 。您可以通过发出以下语句来确定 MySQL 服务器实例上的默认存储引擎： [`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)`InnoDB`

```sql
mysql> SELECT @@default_storage_engine;
+--------------------------+
| @@default_storage_engine |
+--------------------------+
| InnoDB                   |
+--------------------------+
```

`InnoDB`默认情况下，表是在 file-per-table 表空间中创建的。要`InnoDB` 在`InnoDB`系统表空间中创建表，请在创建表之前禁用该[`innodb_file_per_table`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_file_per_table) 变量。要在通用表空间中创建 `InnoDB`表，请使用 [`CREATE TABLE ... TABLESPACE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)语法。有关更多信息，请参阅 [第 15.6.3 节，“表空间”](https://dev.mysql.com/doc/refman/8.0/en/innodb-tablespace.html)。

##### 行格式



表的行格式`InnoDB`决定了其行在磁盘上的物理存储方式。 `InnoDB`支持四种行格式，每种都有不同的存储特性。支持的行格式包括 `REDUNDANT`、`COMPACT`、 `DYNAMIC`和`COMPRESSED`。行`DYNAMIC`格式是默认值。有关行格式特征的信息，请参阅 [第 15.10 节，“InnoDB 行格式”](https://dev.mysql.com/doc/refman/8.0/en/innodb-row-format.html)。

该[`innodb_default_row_format`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_default_row_format) 变量定义了默认的行格式。也可以使用 or语句`ROW_FORMAT`中的 table 选项显式定义表的行格式。请参阅 [定义表格的行格式](https://dev.mysql.com/doc/refman/8.0/en/innodb-row-format.html#innodb-row-format-defining)。 `CREATE TABLE``ALTER TABLE`

##### 主键



建议您为创建的每个表定义一个主键。选择主键列时，选择具有以下特征的列：

- 最重要的查询引用的列。
- 永远不会留空的列。
- 从不具有重复值的列。
- 插入后很少更改值的列。

例如，在包含人员信息的表中，您不会在其上创建主键，`(firstname, lastname)`因为可以有多个人具有相同的姓名，姓名列可能留空，有时人们会更改姓名。由于有如此多的约束，通常没有一组明显的列可用作主键，因此您创建一个具有数字 ID 的新列作为主键的全部或部分。您可以声明一个 [自动增量](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_auto_increment)列，以便在插入行时自动填充升序值：

```sql
# The value of ID can act like a pointer between related items in different tables.
CREATE TABLE t5 (id INT AUTO_INCREMENT, b CHAR (20), PRIMARY KEY (id));

# The primary key can consist of more than one column. Any autoinc column must come first.
CREATE TABLE t6 (id INT AUTO_INCREMENT, a INT, b CHAR (20), PRIMARY KEY (id,a));
```

有关自动增量列的更多信息，请参阅 [第 15.6.1.6 节，“InnoDB 中的 AUTO_INCREMENT 处理”](https://dev.mysql.com/doc/refman/8.0/en/innodb-auto-increment-handling.html)。

尽管表可以在不定义主键的情况下正常工作，但主键涉及性能的许多方面，并且对于任何大型或经常使用的表来说都是至关重要的设计方面。建议您始终在[`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)语句中指定主键。如果您创建表，加载数据，然后运行 [`ALTER TABLE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)以添加主键，则该操作比创建表时定义主键要慢得多。有关主键的更多信息，请参阅[第 15.6.2.1 节，“聚集索引和二级索引”](https://dev.mysql.com/doc/refman/8.0/en/innodb-index-types.html)。

##### 查看 InnoDB 表属性



要查看表的属性`InnoDB`，请发出以下[`SHOW TABLE STATUS`](https://dev.mysql.com/doc/refman/8.0/en/show-table-status.html) 语句：

```sql
mysql> SHOW TABLE STATUS FROM test LIKE 't%' \G;
*************************** 1. row ***************************
           Name: t1
         Engine: InnoDB
        Version: 10
     Row_format: Dynamic
           Rows: 0
 Avg_row_length: 0
    Data_length: 16384
Max_data_length: 0
   Index_length: 0
      Data_free: 0
 Auto_increment: NULL
    Create_time: 2021-02-18 12:18:28
    Update_time: NULL
     Check_time: NULL
      Collation: utf8mb4_0900_ai_ci
       Checksum: NULL
 Create_options: 
        Comment:
```

有关[`SHOW TABLE STATUS`](https://dev.mysql.com/doc/refman/8.0/en/show-table-status.html)输出的信息，请参阅 [第 13.7.7.38 节，“SHOW TABLE STATUS 语句”](https://dev.mysql.com/doc/refman/8.0/en/show-table-status.html)。

您还可以通过查询信息模式系统表 来访问`InnoDB`表属性：`InnoDB`

```sql
mysql> SELECT * FROM INFORMATION_SCHEMA.INNODB_TABLES WHERE NAME='test/t1' \G
*************************** 1. row ***************************
     TABLE_ID: 1144
         NAME: test/t1
         FLAG: 33
       N_COLS: 5
        SPACE: 30
   ROW_FORMAT: Dynamic
ZIP_PAGE_SIZE: 0
   SPACE_TYPE: Single
 INSTANT_COLS: 0
```

有关更多信息，请参阅 [第 15.15.3 节，“InnoDB INFORMATION_SCHEMA 模式对象表”](https://dev.mysql.com/doc/refman/8.0/en/innodb-information-schema-system-tables.html)。