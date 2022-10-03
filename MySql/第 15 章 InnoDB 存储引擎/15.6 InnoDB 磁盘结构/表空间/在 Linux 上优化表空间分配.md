#### 15.6.3.8 在 Linux 上优化表空间空间分配



从 MySQL 8.0.22 开始，您可以优化如何`InnoDB` 在 Linux 上为 file-per-table 和通用表空间分配空间。默认情况下，当需要额外空间时， `InnoDB`将页面分配给表空间并将 NULL 物理写入这些页面。如果频繁分配新页面，此行为可能会影响性能。从 MySQL 8.0.22 开始，您可以 [`innodb_extend_and_initialize`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_extend_and_initialize)在 Linux 系统上禁用以避免将 NULL 物理写入新分配的表空间页面。禁用时 [`innodb_extend_and_initialize`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_extend_and_initialize)，使用调用将空间分配给表空间文件 `posix_fallocate()`，这会保留空间而无需物理写入 NULL。

使用 `posix_fallocate()`调用分配页面时，默认情况下扩展大小很小，并且通常一次只分配几个页面，这可能会导致碎片并增加随机 I/O。为避免此问题，请在启用`posix_fallocate()`调用时增加表空间扩展大小。`AUTOEXTEND_SIZE`使用该选项可以将表空间扩展大小增加到 4GB 。有关更多信息，请参阅[第 15.6.3.9 节，“表空间 AUTOEXTEND_SIZE 配置”](https://dev.mysql.com/doc/refman/8.0/en/innodb-tablespace-autoextend-size.html)。

`InnoDB`在分配新的表空间页面之前写入重做日志记录。如果页面分配操作被中断，则在恢复期间从重做日志记录中重放该操作。（从重做日志记录重放的页面分配操作将 NULL 物理写入新分配的页面。）在分配页面之前写入重做日志记录，而不管[`innodb_extend_and_initialize`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_extend_and_initialize) 设置如何。

在非 Linux 系统和 Windows 上，`InnoDB` 将新页面分配给表空间并将 NULL 物理写入这些页面，这是默认行为。尝试 [`innodb_extend_and_initialize`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_extend_and_initialize)在这些系统上禁用会返回以下错误：

此平台不支持更改 innodb_extend_and_initialize。回退到默认值。