#### 15.6.2.4 InnoDB 全文索引



全文索引在基于文本的列（[`CHAR`](https://dev.mysql.com/doc/refman/8.0/en/char.html)、 [`VARCHAR`](https://dev.mysql.com/doc/refman/8.0/en/char.html)或 [`TEXT`](https://dev.mysql.com/doc/refman/8.0/en/blob.html)列）上创建，以加快对这些列中包含的数据的查询和 DML 操作。

全文索引被定义为语句的一部分 或使用 或[`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)添加到现有表中。 [`ALTER TABLE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)[`CREATE INDEX`](https://dev.mysql.com/doc/refman/8.0/en/create-index.html)

[`MATCH() ... AGAINST`](https://dev.mysql.com/doc/refman/8.0/en/fulltext-search.html#function_match)使用语法 执行全文搜索。有关使用信息，请参阅 [第 12.10 节，“全文搜索功能”](https://dev.mysql.com/doc/refman/8.0/en/fulltext-search.html)。

`InnoDB`全文索引在本节的以下主题下进行描述：

- [InnoDB全文索引设计](https://dev.mysql.com/doc/refman/8.0/en/innodb-fulltext-index.html#innodb-fulltext-index-design)
- [InnoDB 全文索引表](https://dev.mysql.com/doc/refman/8.0/en/innodb-fulltext-index.html#innodb-fulltext-index-tables)
- [InnoDB 全文索引缓存](https://dev.mysql.com/doc/refman/8.0/en/innodb-fulltext-index.html#innodb-fulltext-index-cache)
- [InnoDB 全文索引 DOC_ID 和 FTS_DOC_ID 列](https://dev.mysql.com/doc/refman/8.0/en/innodb-fulltext-index.html#innodb-fulltext-index-docid)
- [InnoDB 全文索引删除处理](https://dev.mysql.com/doc/refman/8.0/en/innodb-fulltext-index.html#innodb-fulltext-index-deletion)
- [InnoDB 全文索引事务处理](https://dev.mysql.com/doc/refman/8.0/en/innodb-fulltext-index.html#innodb-fulltext-index-transaction)
- [监控 InnoDB 全文索引](https://dev.mysql.com/doc/refman/8.0/en/innodb-fulltext-index.html#innodb-fulltext-index-monitoring)

##### InnoDB全文索引设计

`InnoDB`全文索引采用倒排索引设计。倒排索引存储单词列表，并且对于每个单词，该单词出现的文档列表。为了支持邻近搜索，还存储每个单词的位置信息，作为字节偏移量。

##### InnoDB 全文索引表

创建`InnoDB`全文索引时，会创建一组索引表，如下例所示：

```sql
mysql> CREATE TABLE opening_lines (
       id INT UNSIGNED AUTO_INCREMENT NOT NULL PRIMARY KEY,
       opening_line TEXT(500),
       author VARCHAR(200),
       title VARCHAR(200),
       FULLTEXT idx (opening_line)
       ) ENGINE=InnoDB;

mysql> SELECT table_id, name, space from INFORMATION_SCHEMA.INNODB_TABLES
       WHERE name LIKE 'test/%';
+----------+----------------------------------------------------+-------+
| table_id | name                                               | space |
+----------+----------------------------------------------------+-------+
|      333 | test/fts_0000000000000147_00000000000001c9_index_1 |   289 |
|      334 | test/fts_0000000000000147_00000000000001c9_index_2 |   290 |
|      335 | test/fts_0000000000000147_00000000000001c9_index_3 |   291 |
|      336 | test/fts_0000000000000147_00000000000001c9_index_4 |   292 |
|      337 | test/fts_0000000000000147_00000000000001c9_index_5 |   293 |
|      338 | test/fts_0000000000000147_00000000000001c9_index_6 |   294 |
|      330 | test/fts_0000000000000147_being_deleted            |   286 |
|      331 | test/fts_0000000000000147_being_deleted_cache      |   287 |
|      332 | test/fts_0000000000000147_config                   |   288 |
|      328 | test/fts_0000000000000147_deleted                  |   284 |
|      329 | test/fts_0000000000000147_deleted_cache            |   285 |
|      327 | test/opening_lines                                 |   283 |
+----------+----------------------------------------------------+-------+
```

前六个索引表包含倒排索引，称为辅助索引表。当传入的文档被标记化时，各个单词（也称为 “标记”）连同位置信息和相关联的 `DOC_ID`. 根据单词第一个字符的字符集排序权重，单词在六个索引表中被完全排序和分区。

倒排索引被划分为六个辅助索引表，以支持并行索引创建。默认情况下，两个线程对单词和相关数据进行标记、排序和插入到索引表中。执行此工作的线程数可使用该 [`innodb_ft_sort_pll_degree`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_ft_sort_pll_degree) 变量进行配置。在大型表上创建全文索引时，请考虑增加线程数。

辅助索引表名称以 . 为前缀 `fts_`和后缀 。每个辅助索引表通过辅助索引表名称中与索引表的 匹配的十六进制值与索引表相关联 。例如，表 的 是 ，其十六进制值为 0x147。如上例所示，“ 147 ”十六进制值出现在与表关联的辅助索引表的名称中。 `index_*`#`*``table_id``table_id``test/opening_lines``327``test/opening_lines`

`index_id`表示全文索引 的十六进制值也出现在辅助索引表名称中。例如，在辅助表名 `test/fts_0000000000000147_00000000000001c9_index_1`中，十六进制值`1c9`的十进制值是 457。表上定义的索引`opening_lines`( `idx`) 可以通过在 [`INFORMATION_SCHEMA.INNODB_INDEXES`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-innodb-indexes-table.html) 表中查询该值 (457) 来识别。

```sql
mysql> SELECT index_id, name, table_id, space from INFORMATION_SCHEMA.INNODB_INDEXES
       WHERE index_id=457;
+----------+------+----------+-------+
| index_id | name | table_id | space |
+----------+------+----------+-------+
|      457 | idx  |      327 |   283 |
+----------+------+----------+-------+
```

[如果在file-per-table 表](https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_file_per_table)空间 中创建主表，则索引表存储在它们自己 的表 空间中。否则，索引表将存储在索引表所在的表空间中。

上例中显示的其他索引表称为普通索引表，用于删除处理和存储全文索引的内部状态。与为每个全文索引创建的倒排索引表不同，这组表对于在特定表上创建的所有全文索引是通用的。

即使删除全文索引，也会保留公共索引表。删除全文索引时， `FTS_DOC_ID`会保留为该索引创建的列，因为删除该`FTS_DOC_ID` 列将需要重建先前索引的表。需要公共索引表来管理 `FTS_DOC_ID`列。

- `fts_*_deleted`和 `fts_*_deleted_cache`

  包含已删除但其数据尚未从全文索引中删除的文档的文档 ID (DOC_ID)。`fts_*_deleted_cache`是表的内存版本`fts_*_deleted` 。

- `fts_*_being_deleted`和 `fts_*_being_deleted_cache`

  包含已删除且当前正在从全文索引中删除其数据的文档的文档 ID (DOC_ID)。该 `fts_*_being_deleted_cache`表是该表的内存版本 `fts_*_being_deleted`。

- `fts_*_config`

  存储有关全文索引的内部状态的信息。最重要的是，它存储 `FTS_SYNCED_DOC_ID`，它标识已解析并刷新到磁盘的文档。在崩溃恢复的情况下，`FTS_SYNCED_DOC_ID` 值用于标识尚未刷新到磁盘的文档，以便可以重新解析文档并将其添加回全文索引缓存。要查看此表中的数据，请查询该 [`INFORMATION_SCHEMA.INNODB_FT_CONFIG`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-innodb-ft-config-table.html) 表。

##### InnoDB 全文索引缓存

插入文档时，将对其进行标记化，并将单个单词和相关数据插入到全文索引中。这个过程，即使对于小文档，也可能导致对辅助索引表的大量小插入，从而使对这些表的并发访问成为争用点。为避免此问题，`InnoDB`请使用全文索引缓存来临时缓存最近插入的行的索引表插入。这种内存缓存结构保持插入，直到缓存已满，然后将它们批量刷新到磁盘（到辅助索引表）。您可以查询 [`INFORMATION_SCHEMA.INNODB_FT_INDEX_CACHE`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-innodb-ft-index-cache-table.html) 表以查看最近插入的行的标记化数据。

缓存和批量刷新行为避免了对辅助索引表的频繁更新，这可能导致在繁忙的插入和更新时间出现并发访问问题。批处理技术还避免了同一个词的多次插入，并最大限度地减少了重复条目。不是单独刷新每个单词，而是将相同单词的插入合并并作为单个条目刷新到磁盘，从而提高插入效率，同时保持辅助索引表尽可能小。

该[`innodb_ft_cache_size`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_ft_cache_size) 变量用于配置全文索引缓存大小（基于每个表），这会影响刷新全文索引缓存的频率。[`innodb_ft_total_cache_size`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_ft_total_cache_size) 您还可以使用该变量 为给定实例中的所有表定义全局全文索引缓存大小限制 。

全文索引缓存存储与辅助索引表相同的信息。但是，全文索引缓存仅缓存最近插入的行的标记化数据。已经刷新到磁盘（到辅助索引表）的数据在查询时不会被带回全文索引缓存。直接查询辅助索引表中的数据，将辅助索引表中的结果与全文索引缓存中的结果合并后返回。

##### InnoDB 全文索引 DOC_ID 和 FTS_DOC_ID 列

`InnoDB`使用称为 的唯一文档标识符将`DOC_ID`全文索引中的单词映射到该单词出现的文档记录。映射需要`FTS_DOC_ID`索引表上的列。如果`FTS_DOC_ID`未定义列，则在创建全文索引时`InnoDB`自动添加隐藏 列。`FTS_DOC_ID`下面的示例演示了这种行为。

下表定义不包含 `FTS_DOC_ID`列：

```sql
mysql> CREATE TABLE opening_lines (
       id INT UNSIGNED AUTO_INCREMENT NOT NULL PRIMARY KEY,
       opening_line TEXT(500),
       author VARCHAR(200),
       title VARCHAR(200)
       ) ENGINE=InnoDB;
```

当您使用语法在表上创建全文索引时 `CREATE FULLTEXT INDEX`，将返回警告，报告`InnoDB`正在重建表以添加`FTS_DOC_ID` 列。

```sql
mysql> CREATE FULLTEXT INDEX idx ON opening_lines(opening_line);
Query OK, 0 rows affected, 1 warning (0.19 sec)
Records: 0  Duplicates: 0  Warnings: 1

mysql> SHOW WARNINGS;
+---------+------+--------------------------------------------------+
| Level   | Code | Message                                          |
+---------+------+--------------------------------------------------+
| Warning |  124 | InnoDB rebuilding table to add column FTS_DOC_ID |
+---------+------+--------------------------------------------------+
```

使用 [`ALTER TABLE`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)向没有 `FTS_DOC_ID`列的表添加全文索引时返回相同的警告。如果您当时创建全文索引[`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)且未指定`FTS_DOC_ID`列， 则`InnoDB`添加隐藏 `FTS_DOC_ID`列，而不会发出警告。

与在已加载数据的表上创建全文索引相比，在 time 定义`FTS_DOC_ID`列 成本更低。[`CREATE TABLE`](https://dev.mysql.com/doc/refman/8.0/en/create-table.html)如果`FTS_DOC_ID` 在加载数据之前在表上定义了列，则不必重建表及其索引来添加新列。如果您不关心`CREATE FULLTEXT INDEX`性能，请忽略该 `FTS_DOC_ID`列以便 `InnoDB`为您创建它。 `InnoDB`创建一个隐藏 `FTS_DOC_ID`列以及该列上的唯一索引 ( `FTS_DOC_ID_INDEX`) `FTS_DOC_ID`。如果要创建自己的`FTS_DOC_ID`列，则必须将列定义为`BIGINT UNSIGNED NOT NULL`并命名 `FTS_DOC_ID`（全部大写），如下例所示：

笔记

该`FTS_DOC_ID`列不需要定义为`AUTO_INCREMENT`列，但这样做可以使加载数据更容易。

```sql
mysql> CREATE TABLE opening_lines (
       FTS_DOC_ID BIGINT UNSIGNED AUTO_INCREMENT NOT NULL PRIMARY KEY,
       opening_line TEXT(500),
       author VARCHAR(200),
       title VARCHAR(200)
       ) ENGINE=InnoDB;
```

如果您选择自己定义`FTS_DOC_ID`列，则您有责任管理该列以避免空值或重复值。`FTS_DOC_ID`值不能被重用，这意味着`FTS_DOC_ID` 值必须不断增加。

或者，您可以在列上创建所需的唯一 `FTS_DOC_ID_INDEX`（全部大写） `FTS_DOC_ID`。

```sql
mysql> CREATE UNIQUE INDEX FTS_DOC_ID_INDEX on opening_lines(FTS_DOC_ID);
```

如果您不创建`FTS_DOC_ID_INDEX`， `InnoDB`则会自动创建它。

笔记

`FTS_DOC_ID_INDEX`不能定义为降序索引，因为`InnoDB`SQL 解析器不使用降序索引。

`FTS_DOC_ID`最大使用值和新 值 之间的允许差距 `FTS_DOC_ID`为 65535。

为避免重建表，`FTS_DOC_ID` 删除全文索引时会保留该列。

##### InnoDB 全文索引删除处理

删除具有全文索引列的记录可能会导致辅助索引表中的大量小删除，从而使对这些表的并发访问成为争用点。为避免此问题，每当从索引表中删除记录时`DOC_ID`，已删除文档的记录都会记录在特殊 `FTS_*_DELETED`表中，并且索引记录保留在全文索引中。在返回查询结果之前，`FTS_*_DELETED`使用表中的信息过滤掉已删除的`DOC_ID`s。这种设计的好处是删除速度快且成本低。缺点是删除记录后索引的大小不会立即减小。要删除已删除记录的全文索引条目，`OPTIMIZE TABLE`请在索引表上 运行[`innodb_optimize_fulltext_only=ON`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_optimize_fulltext_only) 以重建全文索引。有关更多信息，请参阅 [优化 InnoDB 全文索引](https://dev.mysql.com/doc/refman/8.0/en/fulltext-fine-tuning.html#fulltext-optimize)。

##### InnoDB 全文索引事务处理

`InnoDB`全文索引由于其缓存和批处理行为而具有特殊的事务处理特性。具体来说，全文索引的更新和插入是在事务提交时处理的，这意味着全文搜索只能看到提交的数据。下面的示例演示了这种行为。全文搜索仅在提交插入的行后返回结果。

```sql
mysql> CREATE TABLE opening_lines (
       id INT UNSIGNED AUTO_INCREMENT NOT NULL PRIMARY KEY,
       opening_line TEXT(500),
       author VARCHAR(200),
       title VARCHAR(200),
       FULLTEXT idx (opening_line)
       ) ENGINE=InnoDB;

mysql> BEGIN;

mysql> INSERT INTO opening_lines(opening_line,author,title) VALUES
       ('Call me Ishmael.','Herman Melville','Moby-Dick'),
       ('A screaming comes across the sky.','Thomas Pynchon','Gravity\'s Rainbow'),
       ('I am an invisible man.','Ralph Ellison','Invisible Man'),
       ('Where now? Who now? When now?','Samuel Beckett','The Unnamable'),
       ('It was love at first sight.','Joseph Heller','Catch-22'),
       ('All this happened, more or less.','Kurt Vonnegut','Slaughterhouse-Five'),
       ('Mrs. Dalloway said she would buy the flowers herself.','Virginia Woolf','Mrs. Dalloway'),
       ('It was a pleasure to burn.','Ray Bradbury','Fahrenheit 451');

mysql> SELECT COUNT(*) FROM opening_lines WHERE MATCH(opening_line) AGAINST('Ishmael');
+----------+
| COUNT(*) |
+----------+
|        0 |
+----------+

mysql> COMMIT;

mysql> SELECT COUNT(*) FROM opening_lines WHERE MATCH(opening_line) AGAINST('Ishmael');
+----------+
| COUNT(*) |
+----------+
|        1 |
+----------+
```

##### 监控 InnoDB 全文索引



您可以通过查询下表 来监控和检查`InnoDB`全文索引 的特殊文本处理方面：`INFORMATION_SCHEMA`

- [`INNODB_FT_CONFIG`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-innodb-ft-config-table.html)
- [`INNODB_FT_INDEX_TABLE`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-innodb-ft-index-table-table.html)
- [`INNODB_FT_INDEX_CACHE`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-innodb-ft-index-cache-table.html)
- [`INNODB_FT_DEFAULT_STOPWORD`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-innodb-ft-default-stopword-table.html)
- [`INNODB_FT_DELETED`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-innodb-ft-deleted-table.html)
- [`INNODB_FT_BEING_DELETED`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-innodb-ft-being-deleted-table.html)

[`INNODB_INDEXES`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-innodb-indexes-table.html) 您还可以通过查询和 查看全文索引和表的基本信息[`INNODB_TABLES`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-innodb-tables-table.html)。

有关更多信息，请参阅 [第 15.15.4 节，“InnoDB INFORMATION_SCHEMA FULLTEXT 索引表”](https://dev.mysql.com/doc/refman/8.0/en/innodb-information-schema-fulltext_index-tables.html)。