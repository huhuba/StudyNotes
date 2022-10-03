#### 15.6.1.6 InnoDB 中的 AUTO_INCREMENT 处理



```
InnoDB`提供了一种可配置的锁定机制，可以显着提高向具有 `AUTO_INCREMENT`列的表添加行的 SQL 语句的可伸缩性和性能。要将 `AUTO_INCREMENT`机制用于 `InnoDB`表， `AUTO_INCREMENT`必须将列定义为某个索引的第一列或唯一列，以便可以对表执行等效的索引查找以获得最大列值。索引不需要是or ，但为了避免 列中的重复值，建议使用这些索引类型。 `SELECT MAX(*`ai_col`*)``PRIMARY KEY``UNIQUE``AUTO_INCREMENT
```

本节介绍`AUTO_INCREMENT`锁定模式、不同锁定模式设置的使用含义 `AUTO_INCREMENT`以及如何 `InnoDB`初始化 `AUTO_INCREMENT`计数器。

- [InnoDB AUTO_INCREMENT 锁定模式](https://dev.mysql.com/doc/refman/8.0/en/innodb-auto-increment-handling.html#innodb-auto-increment-lock-modes)
- [InnoDB AUTO_INCREMENT 锁定模式使用含义](https://dev.mysql.com/doc/refman/8.0/en/innodb-auto-increment-handling.html#innodb-auto-increment-lock-mode-usage-implications)
- [InnoDB AUTO_INCREMENT 计数器初始化](https://dev.mysql.com/doc/refman/8.0/en/innodb-auto-increment-handling.html#innodb-auto-increment-initialization)
- [笔记](https://dev.mysql.com/doc/refman/8.0/en/innodb-auto-increment-handling.html#innodb-auto-increment-notes)

##### InnoDB AUTO_INCREMENT 锁定模式



本节介绍`AUTO_INCREMENT` 用于生成自增值的锁定模式，以及每种锁定模式如何影响复制。自动增量锁定模式在启动时使用该 [`innodb_autoinc_lock_mode`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode) 变量进行配置。

以下术语用于描述 [`innodb_autoinc_lock_mode`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode) 设置：

- “ [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)-like ” 语句

  在表中生成新行的所有语句，包括 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)、 [`INSERT ... SELECT`](https://dev.mysql.com/doc/refman/8.0/en/insert-select.html)、[`REPLACE`](https://dev.mysql.com/doc/refman/8.0/en/replace.html)、 [`REPLACE ... SELECT`](https://dev.mysql.com/doc/refman/8.0/en/replace.html)和[`LOAD DATA`](https://dev.mysql.com/doc/refman/8.0/en/load-data.html)。包括“ simple-inserts ”、 “ bulk-inserts ”和“ mixed-mode ” 插入。

- “简单的插入”

  可以预先确定要插入的行数的语句（最初处理语句时）。这包括单行和多行 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)以及 [`REPLACE`](https://dev.mysql.com/doc/refman/8.0/en/replace.html)没有嵌套子查询但没有 [`INSERT ... ON DUPLICATE KEY UPDATE`](https://dev.mysql.com/doc/refman/8.0/en/insert-on-duplicate.html).

- “批量插入”

  预先不知道要插入的行数（以及所需的自动增量值的数量）的语句。这包括 [`INSERT ... SELECT`](https://dev.mysql.com/doc/refman/8.0/en/insert-select.html), [`REPLACE ... SELECT`](https://dev.mysql.com/doc/refman/8.0/en/replace.html)和[`LOAD DATA`](https://dev.mysql.com/doc/refman/8.0/en/load-data.html)语句，但不包括 plain `INSERT`。在处理每一行时，一次为一列 `InnoDB`分配新值。`AUTO_INCREMENT`

- “混合模式插入”

  这些是“简单插入”语句，为一些（但不是全部）新行指定自动增量值。下面是一个示例，其中 `c1`是 table 的 `AUTO_INCREMENT`列 `t1`：

  ```sql
  INSERT INTO t1 (c1,c2) VALUES (1,'a'), (NULL,'b'), (5,'c'), (NULL,'d');
  ```

  另一种类型的“混合模式插入”是 [`INSERT ... ON DUPLICATE KEY UPDATE`](https://dev.mysql.com/doc/refman/8.0/en/insert-on-duplicate.html)，在最坏的情况下实际上是 an[`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html) 后跟 a [`UPDATE`](https://dev.mysql.com/doc/refman/8.0/en/update.html)，其中为 `AUTO_INCREMENT`列分配的值可能会或可能不会在更新阶段使用。

[`innodb_autoinc_lock_mode`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode) 该变量 有三种可能的设置 。“传统”、“连续”或 “交错”锁定模式的设置分别为 0、1 或 2 。从 MySQL 8.0 开始，交错锁定模式 ( [`innodb_autoinc_lock_mode=2`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode)) 是默认设置。在 MySQL 8.0 之前，连续锁定模式是默认的 ( [`innodb_autoinc_lock_mode=1`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode))。

MySQL 8.0 中交错锁模式的默认设置反映了从基于语句的复制到基于行的复制作为默认复制类型的变化。基于语句的复制需要连续的自增锁模式，以确保给定的SQL语句序列以可预测和可重复的顺序分配自增值，而基于行的复制对SQL语句的执行顺序不敏感.

- `innodb_autoinc_lock_mode = 0` （“传统”锁定模式）

  [`innodb_autoinc_lock_mode`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode) 传统的锁定模式提供了与引入变量 之前相同的行为 。由于语义上可能存在差异，提供传统锁定模式选项是为了向后兼容、性能测试和解决“混合模式插入”问题。

  在这种锁定模式下，所有“ INSERT-like ”语句都会获得一个特殊的表级`AUTO-INC` 锁定，用于插入到具有 `AUTO_INCREMENT`列的表中。此锁通常保持到语句的末尾（而不是事务的末尾），以确保以可预测和可重复的顺序为给定的[`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html) 语句序列分配自动递增值，并确保自动递增值任何给定语句分配的都是连续的。

  在基于语句的复制的情况下，这意味着当在副本服务器上复制 SQL 语句时，自动增量列使用与源服务器上相同的值。多个 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)语句的执行结果是确定性的，副本复制与源上相同的数据。如果由多个语句生成的自动增量值[`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)交错，则两个并发 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)语句的结果将是不确定的，并且无法使用基于语句的复制可靠地传播到副本服务器。

  为了清楚起见，考虑一个使用此表的示例：

  ```sql
  CREATE TABLE t1 (
    c1 INT(11) NOT NULL AUTO_INCREMENT,
    c2 VARCHAR(10) DEFAULT NULL,
    PRIMARY KEY (c1)
  ) ENGINE=InnoDB;
  ```

  假设有两个事务正在运行，每个事务都将行插入到具有一 `AUTO_INCREMENT`列的表中。一个事务使用 [`INSERT ... SELECT`](https://dev.mysql.com/doc/refman/8.0/en/insert-select.html)插入 1000 行的语句，另一个事务使用插入一行的简单 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)语句：

  ```sql
  Tx1: INSERT INTO t1 (c2) SELECT 1000 rows from another table ...
  Tx2: INSERT INTO t1 (c2) VALUES ('xxx');
  ```

  `InnoDB`无法预先知道从 Tx1[`SELECT`](https://dev.mysql.com/doc/refman/8.0/en/select.html)中的 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)语句中检索了多少行，并且随着语句的进行，它一次分配一个自动增量值。使用表级锁，保持到语句末尾，一次只能执行一个 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)引用表的语句`t1`，并且不同语句生成自增数不会交错。Tx1 语句生成的自增值 [`INSERT ... SELECT`](https://dev.mysql.com/doc/refman/8.0/en/insert-select.html)是连续的，使用的（单个）自增值 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)Tx2 中的语句小于或大于用于 Tx1 的所有语句，具体取决于哪个语句首先执行。

  只要 SQL 语句在从二进制日志重放时（使用基于语句的复制时，或在恢复场景中）以相同的顺序执行，结果与 Tx1 和 Tx2 首次运行时的结果相同。因此，表级锁一直保持到语句结束，使得 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)使用自动增量的语句可以安全地用于基于语句的复制。但是，当多个事务同时执行插入语句时，这些表级锁会限制并发性和可伸缩性。

  在前面的示例中，如果没有表级锁，则用于 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)in Tx2 的自动增量列的值取决于语句执行的确切时间。如果 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)Tx2 在[`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)Tx1 运行时执行（而不是在它开始之前或完成之后），则两个 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)语句分配的特定自动增量值是不确定的，并且可能因运行而异。

  在 [连续](https://dev.mysql.com/doc/refman/8.0/en/innodb-auto-increment-handling.html#innodb-auto-increment-lock-mode-consecutive) 锁模式下，`InnoDB`可以避免对预先知道行数的 “简单插入”`AUTO-INC`语句使用表级锁 ，并且仍然为基于语句的复制保留确定性执行和安全性。

  如果您不使用二进制日志作为恢复或复制的一部分来重放 SQL 语句， 则可以使用[交错](https://dev.mysql.com/doc/refman/8.0/en/innodb-auto-increment-handling.html#innodb-auto-increment-lock-mode-interleaved) 锁模式来消除所有表级 `AUTO-INC`锁的使用，以获得更高的并发性和性能，但代价是允许自动中的间隙- 增加由语句分配的编号，并可能使同时执行的语句分配的编号交错。

- `innodb_autoinc_lock_mode = 1` （“连续”锁定模式）

  在这种模式下，“批量插入”使用特殊的 `AUTO-INC`表级锁并持有它直到语句结束。这适用于所有 [`INSERT ... SELECT`](https://dev.mysql.com/doc/refman/8.0/en/insert-select.html)、 [`REPLACE ... SELECT`](https://dev.mysql.com/doc/refman/8.0/en/replace.html)和[`LOAD DATA`](https://dev.mysql.com/doc/refman/8.0/en/load-data.html)语句。一次只能执行一个持有 `AUTO-INC`锁的语句。如果批量插入操作的源表与目标表不同，则`AUTO-INC`在对源表中选择的第一行进行共享锁之后，再对目标表进行锁定。如果批量插入操作的源和目标是同一个表，则`AUTO-INC`在所有选定行上获取共享锁后获取锁。

  “简单插入”（预先知道要插入的行数） `AUTO-INC`通过在互斥锁（一种轻量级锁）的控制下获得所需数量的自增值来避免表级锁在分配过程中保留，*直到*语句完成。`AUTO-INC`除非 `AUTO-INC`锁被另一个事务持有，否则不使用表级 锁。如果另一个事务持有一个 `AUTO-INC`锁，一个“简单插入”等待`AUTO-INC` 锁，就好像它是一个“批量插入”。

  这种锁定模式确保，在存在 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)预先不知道行数的语句（以及随着语句进行而分配自动递增编号的情况）的情况下，任何 “ [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)-like ” 语句分配的所有自动递增值都是连续的，并且操作对于基于语句的复制是安全的。

  简而言之，这种锁定模式显着提高了可伸缩性，同时可以安全地用于基于语句的复制。此外，与“传统” 锁定模式一样，任何给定语句分配的自动递增数字都是*连续*的。对于 任何使用自动增量的语句， 与“传统”模式相比，语义 *没有变化，但有一个重要例外。*

  例外情况是“混合模式插入”`AUTO_INCREMENT` ，其中用户为多行“简单插入”中的某些（但不是全部）行提供列的显式值 。对于此类插入，`InnoDB`分配比要插入的行数更多的自动增量值。但是，所有自动分配的值都是连续生成的（因此高于）最近执行的前一条语句生成的自动增量值。“多余”的数字会丢失。

- `innodb_autoinc_lock_mode = 2` （“交错”锁定模式）

  在这种锁模式下，没有 “ [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)-like ” 语句使用表级`AUTO-INC` 锁，可以同时执行多条语句。这是最快且最具可扩展性的锁定模式，但在从二进制日志重放 SQL 语句时使用基于语句的复制或恢复场景时 ，它 *并不安全。*

  在这种锁定模式下，自动递增值保证在所有并发执行 的“ [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)-like ” 语句中是唯一的并且单调递增。但是，由于多个语句可以同时生成数字（即，数字的分配在语句之间*交错*），为任何给定语句插入的行生成的值可能不是连续的。

  如果唯一执行的语句是“简单插入”，其中要插入的行数是提前知道的，那么除了 “混合模式插入”之外，为单个语句生成的数字中没有间隙。但是，当执行“批量插入”时，任何给定语句分配的自动增量值可能存在间隙。

##### InnoDB AUTO_INCREMENT 锁定模式使用含义

- 将自动增量与复制一起使用

  如果您使用基于语句的复制，请设置 [`innodb_autoinc_lock_mode`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode)为 0 或 1，并在源及其副本上使用相同的值。如果使用 [`innodb_autoinc_lock_mode`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode)= 2（“ interleaved ”）或源和副本不使用相同锁定模式的配置，则不能确保副本上的自动增量值与源上的值相同。

  如果您使用的是基于行或混合格式的复制，所有的自动增量锁定模式都是安全的，因为基于行的复制对 SQL 语句的执行顺序不敏感（并且混合格式使用基于行的对于基于语句的复制不安全的任何语句的复制）。

- “丢失”自动增量值和序列间隙

  在所有锁定模式（0、1 和 2）中，如果生成自增值的事务回滚，则这些自增值将“丢失”。一旦为自增列生成了值，无论 “ [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)-like ” 语句是否完成，以及包含的事务是否回滚，都无法回滚。这种丢失的值不会被重用。`AUTO_INCREMENT`因此，存储在表的列 中的值可能存在间隙 。

- `AUTO_INCREMENT`为列 指定 NULL 或 0

  在所有锁定模式（0、1 和 2）中，如果用户为 an 中的列指定 NULL 或 0，则将该 `AUTO_INCREMENT`行 视为未指定该值并为其生成一个新值。 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)`InnoDB`

- `AUTO_INCREMENT`为列 分配负值

  在所有锁定模式（0、1 和 2）中，如果为列分配负值，则自动递增机制的行为是未定义的`AUTO_INCREMENT` 。

- 如果`AUTO_INCREMENT`值变得大于指定整数类型的最大整数

  在所有锁定模式（0、1 和 2）中，如果值变得大于可以存储在指定整数类型中的最大整数，则自动递增机制的行为是未定义的。

- “批量插入” 的自动增量值的差距

  [`innodb_autoinc_lock_mode`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode) 设置为 0（ “ 传统”）或 1（“连续”）时，任何给定语句生成的自动增量值都是连续的，没有间隙，因为表级`AUTO-INC` 锁一直保持到语句结束，并且仅一次可以执行一个这样的语句。

  [`innodb_autoinc_lock_mode`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode) 设置为 2（ “ interleaved ”）时， “ bulk inserts ”生成的自动增量值可能存在间隙，但前提是同时执行 “ [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)-like ” 语句。

  对于锁定模式 1 或 2，连续语句之间可能会出现间隙，因为对于批量插入，可能不知道每个语句所需的自动增量值的确切数量，并且可能会高估。

- 由“混合模式插入” 分配的自动增量值

  考虑“混合模式插入”，其中 “简单插入”为某些（但不是全部）结果行指定自动增量值。这样的语句在锁定模式 0、1 和 2 中的行为不同。例如，假设`c1`是 table 的 `AUTO_INCREMENT`列 `t1`，并且最近自动生成的序列号是 100。

  ```sql
  mysql> CREATE TABLE t1 (
      -> c1 INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, 
      -> c2 CHAR(1)
      -> ) ENGINE = INNODB;
  ```

  现在，考虑以下“混合模式插入” 语句：

  ```sql
  mysql> INSERT INTO t1 (c1,c2) VALUES (1,'a'), (NULL,'b'), (5,'c'), (NULL,'d');
  ```

  [`innodb_autoinc_lock_mode`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode) 设置为 0（ “ 传统”）时，四个新行是：

  ```sql
  mysql> SELECT c1, c2 FROM t1 ORDER BY c2;
  +-----+------+
  | c1  | c2   |
  +-----+------+
  |   1 | a    |
  | 101 | b    |
  |   5 | c    |
  | 102 | d    |
  +-----+------+
  ```

  下一个可用的自动增量值是 103，因为自动增量值一次分配一个，而不是在语句执行开始时一次性分配。无论是否同时执行 “ [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)-like ” 语句（任何类型），这个结果都是正确的。

  [`innodb_autoinc_lock_mode`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode) 设置为 1（ “ 连续”），四个新行也是：

  ```sql
  mysql> SELECT c1, c2 FROM t1 ORDER BY c2;
  +-----+------+
  | c1  | c2   |
  +-----+------+
  |   1 | a    |
  | 101 | b    |
  |   5 | c    |
  | 102 | d    |
  +-----+------+
  ```

  但是，在这种情况下，下一个可用的自动增量值是 105，而不是 103，因为在处理语句时分配了四个自动增量值，但只使用了两个。无论是否同时执行 “ [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)-like ” 语句（任何类型），这个结果都是正确的。

  [`innodb_autoinc_lock_mode`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode) 设置为 2（ “ interleaved ”），四个新行是：

  ```sql
  mysql> SELECT c1, c2 FROM t1 ORDER BY c2;
  +-----+------+
  | c1  | c2   |
  +-----+------+
  |   1 | a    |
  |   x | b    |
  |   5 | c    |
  |   y | d    |
  +-----+------+
  ```

  *`x`*和 的值*`y`*是唯一的，并且比以前生成的任何行都大。*`x`*但是，和 的具体值 *`y`*取决于并发执行语句生成的自增值的数量。

  最后，考虑以下语句，当最近生成的序列号为 100 时发出：

  ```sql
  mysql> INSERT INTO t1 (c1,c2) VALUES (1,'a'), (NULL,'b'), (101,'c'), (NULL,'d');
  ```

  对于任何 [`innodb_autoinc_lock_mode`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_autoinc_lock_mode) 设置，此语句都会生成重复键错误 23000 ( `Can't write; duplicate key in table`)，因为为行分配了 101 并且行的 `(NULL, 'b')`插入 `(101, 'c')`失败。

- `AUTO_INCREMENT`在一系列 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)语句 中间 修改列值

  在 MySQL 5.7 及更早版本中，修改 语句`AUTO_INCREMENT`序列中间的列值[`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html) 可能会导致“重复条目” 错误。例如，如果您执行的 [`UPDATE`](https://dev.mysql.com/doc/refman/8.0/en/update.html)操作将`AUTO_INCREMENT`列值更改为大于当前最大自动增量值的值，[`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)则未指定未使用的自动增量值的后续操作可能会遇到“重复条目”错误。在 MySQL 8.0 及更高版本中，如果您修改 `AUTO_INCREMENT`将列值设置为大于当前最大自增值的值，新值将被持久化，后续 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)操作会从新的更大值开始分配自增值。下面的示例演示了此行为。

  ```sql
  mysql> CREATE TABLE t1 (
      -> c1 INT NOT NULL AUTO_INCREMENT,
      -> PRIMARY KEY (c1)
      ->  ) ENGINE = InnoDB;
  
  mysql> INSERT INTO t1 VALUES(0), (0), (3);
  
  mysql> SELECT c1 FROM t1;
  +----+
  | c1 |
  +----+
  |  1 |
  |  2 |
  |  3 |
  +----+
  
  mysql> UPDATE t1 SET c1 = 4 WHERE c1 = 1;
  
  mysql> SELECT c1 FROM t1;
  +----+
  | c1 |
  +----+
  |  2 |
  |  3 |
  |  4 |
  +----+
  
  mysql> INSERT INTO t1 VALUES(0);
  
  mysql> SELECT c1 FROM t1;
  +----+
  | c1 |
  +----+
  |  2 |
  |  3 |
  |  4 |
  |  5 |
  +----+
  ```

##### InnoDB AUTO_INCREMENT 计数器初始化



本节介绍如何`InnoDB`初始化 `AUTO_INCREMENT`计数器。

如果`AUTO_INCREMENT`为表指定列`InnoDB`，则内存中的表对象包含一个称为自动增量计数器的特殊计数器，用于为该列分配新值。

在 MySQL 5.7 及更早版本中，自动增量计数器存储在主内存中，而不是磁盘上。要在服务器重新启动后初始化自动增量计数器，`InnoDB`将在第一次插入包含 `AUTO_INCREMENT`列的表时执行与以下语句等效的语句。

```sql
SELECT MAX(ai_col) FROM table_name FOR UPDATE;
```

在 MySQL 8.0 中，这种行为发生了变化。当前最大的自动增量计数器值在每次更改时写入重做日志并保存到每个检查点的数据字典中。这些更改使当前最大的自动增量计数器值在服务器重新启动时保持不变。

在服务器正常关闭后重新启动时， `InnoDB`使用存储在数据字典中的当前最大自动增量值初始化内存中的自动增量计数器。

在崩溃恢复期间重新启动服务器时， `InnoDB`使用存储在数据字典中的当前最大自动增量值初始化内存中的自动增量计数器，并扫描重做日志以查找自上一个检查点以来写入的自动增量计数器值。如果重做记录的值大于内存中的计数器值，则应用重做记录的值。但是，在服务器意外退出的情况下，无法保证重用先前分配的自动增量值。每次当前最大自动增量值由于一个 [`INSERT`](https://dev.mysql.com/doc/refman/8.0/en/insert.html)或 [`UPDATE`](https://dev.mysql.com/doc/refman/8.0/en/update.html)操作时，新的值被写入重做日志，但如果在重做日志刷新到磁盘之前发生意外退出，则在服务器重新启动后初始化自增计数器时可以重用先前分配的值。

`InnoDB`使用等效 语句来初始化自动增量计数器 的唯一情况是在[导入](https://dev.mysql.com/doc/refman/8.0/en/innodb-table-import.html) 没有元数据文件的表时。否则，从元数据文件中读取当前最大的自动增量计数器值（如果存在）。除了计数器值初始化之外， 当尝试将计数器值设置为小于或等于使用`SELECT MAX(ai_col) FROM *`table_name`* FOR UPDATE``.cfg``.cfg``SELECT MAX(ai_col) FROM *`table_name`*``ALTER TABLE ... AUTO_INCREMENT = *`N`* FOR UPDATE`陈述。例如，您可能会在删除一些记录后尝试将计数器值设置为较小的值。在这种情况下，必须查表以确保新的计数器值不小于或等于当前的实际最大计数器值。

在 MySQL 5.7 及更早版本中，服务器重新启动会取消`AUTO_INCREMENT = N`table 选项的效果，该选项可在`CREATE TABLE`or `ALTER TABLE`语句中分别用于设置初始计数器值或更改现有计数器值。在 MySQL 8.0 中，服务器重启不会取消 `AUTO_INCREMENT = N`table 选项的效果。如果将自动增量计数器初始化为特定值，或者将自动增量计数器值更改为更大的值，则新值会在服务器重新启动时保持不变。

笔记

[`ALTER TABLE ... AUTO_INCREMENT = N`](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)只能将自增计数器值更改为大于当前最大值的值。

在 MySQL 5.7 和更早版本中，在[`ROLLBACK`](https://dev.mysql.com/doc/refman/8.0/en/commit.html) 操作后立即重新启动服务器可能会导致重用先前分配给回滚事务的自动增量值，从而有效地回滚当前最大的自动增量值。在 MySQL 8.0 中，当前最大的自动增量值被持久化，防止重复使用以前分配的值。

如果[`SHOW TABLE STATUS`](https://dev.mysql.com/doc/refman/8.0/en/show-table-status.html)语句在自动增量计数器初始化之前检查表，则`InnoDB`打开表并使用存储在数据字典中的当前最大自动增量值初始化计数器值。然后将该值存储在内存中以供以后的插入或更新使用。计数器值的初始化使用对持续到事务结束的表的正常排他锁定读取。`InnoDB`在为用户指定的自增值大于 0 的新创建的表初始化自增计数器时遵循相同的过程。

自增计数器初始化后，如果在插入行时未显式指定自增值，则会 `InnoDB`隐式递增计数器并将新值分配给列。如果插入显式指定自增列值的行，并且该值大于当前最大计数器值，则将计数器设置为指定值。

`InnoDB`只要服务器运行，就使用内存中的自动增量计数器。当服务器停止并重新启动时，`InnoDB`重新初始化自动增量计数器，如前所述。

该变量确定列值[`auto_increment_offset`](https://dev.mysql.com/doc/refman/8.0/en/replication-options-source.html#sysvar_auto_increment_offset) 的起点 。`AUTO_INCREMENT`默认设置为 1。

该[`auto_increment_increment`](https://dev.mysql.com/doc/refman/8.0/en/replication-options-source.html#sysvar_auto_increment_increment) 变量控制连续列值之间的间隔。默认设置为 1。

##### 笔记



当`AUTO_INCREMENT`整数列的值用完时，后续`INSERT`操作会返回重复键错误。这是一般的 MySQL 行为。