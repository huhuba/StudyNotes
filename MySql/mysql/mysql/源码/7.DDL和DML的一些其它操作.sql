-- 创建表：
create table t_student(
        sno int(6) primary key auto_increment, 
        sname varchar(5) not null, 
        sex char(1) default '男' check(sex='男' || sex='女'),
        age int(3) check(age>=18 and age<=50),
        enterdate date,
        classname varchar(10),
        email varchar(15) unique
);
-- 添加数据：
insert into t_student values (null,'张三','男',21,'2023-9-1','java01班','zs@126.com');
insert into t_student values (null,'李四','男',21,'2023-9-1','java01班','ls@126.com');
insert into t_student values (null,'露露','男',21,'2023-9-1','java01班','ll@126.com');

-- 查看学生表：
select * from t_student;

-- 添加一张表：快速添加：结构和数据跟t_student 都是一致的
create table t_student2
as
select * from t_student;

select * from t_student2;


-- 快速添加，结构跟t_student一致，数据没有：
create table t_student3
as
select * from t_student where 1=2;

select * from t_student3;

-- 快速添加：只要部分列，部分数据：
create table t_student4
as
select sno,sname,age from t_student where sno = 2;

select * from t_student4;

-- 删除数据操作 :清空数据
delete from t_student;
truncate table t_student;

