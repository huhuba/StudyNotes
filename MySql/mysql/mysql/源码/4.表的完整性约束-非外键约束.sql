/*
建立一张用来存储学生信息的表
字段包含学号、姓名、性别，年龄、入学日期、班级，email等信息

约束：
建立一张用来存储学生信息的表
字段包含学号、姓名、性别，年龄、入学日期、班级，email等信息
【1】学号是主键 = 不能为空 +  唯一 ，主键的作用：可以通过主键查到唯一的一条记录【2】如果主键是整数类型，那么需要自增
【3】姓名不能为空
【4】Email唯一
【5】性别默认值是男
【6】性别只能是男女
【7】年龄只能在18-50之间
*/
-- 创建数据库表：
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
--  1048 - Column 'sname' cannot be null 不能为null
-- 3819 - Check constraint 't_student_chk_1' is violated. 违反检查约束
insert into t_student values (1,'张三','男',21,'2023-9-1','java01班','zs@126.com');
-- 1062 - Duplicate entry '1' for key 't_student.PRIMARY' 主键重复
-- > 1062 - Duplicate entry 'ls@126.com' for key 't_student.email' 违反唯一约束
insert into t_student values (2,'李四','男',21,'2023-9-1','java01班','ls@126.com');
insert into t_student values (3,'露露','男',21,'2023-9-1','java01班','ls@126.com');
-- 如果主键没有设定值，或者用null.default都可以完成主键自增的效果
insert into t_student (sname,enterdate) values ('菲菲','2029-4-5');
insert into t_student values (null,'小明','男',21,'2023-9-1','java01班','xm@126.com');
insert into t_student values (default,'小刚','男',21,'2023-9-1','java01班','xg@126.com');
-- 如果sql报错，可能主键就浪费了，后续插入的主键是不连号的，我们主键也不要求连号的
insert into t_student values (null,'小明','男',21,'2023-9-1','java01班','oo@126.com');
-- 查看数据：
select * from t_student;




-- 删除表：
drop table t_student;
-- 创建数据库表：
create table t_student(
        sno int(6) auto_increment, 
        sname varchar(5) not null, 
        sex char(1) default '男',
        age int(3),
        enterdate date,
        classname varchar(10),
        email varchar(15),
				constraint pk_stu primary key (sno),  -- pk_stu 主键约束的名字
				constraint ck_stu_sex check (sex = '男' || sex = '女'),
				constraint ck_stu_age check (age >= 18 and age <= 50),
				constraint uq_stu_email unique (email)
);

-- 添加数据：
insert into t_student values (1,'张三','男',21,'2023-9-1','java01班','zs@126.com');
-- > 3819 - Check constraint 'ck_stu_sex' is violated.
-- > 3819 - Check constraint 'ck_stu_age' is violated.
-- > 1062 - Duplicate entry 'zs@126.com' for key 't_student.uq_stu_email'
insert into t_student values (3,'李四','男',21,'2023-9-1','java01班','zs@126.com');

-- 查看数据：
select * from t_student;






-- 删除表：
drop table t_student;
-- 创建数据库表：
create table t_student(
        sno int(6), 
        sname varchar(5) not null, 
        sex char(1) default '男',
        age int(3),
        enterdate date,
        classname varchar(10),
        email varchar(15)
);

-- > 1075 - Incorrect table definition; there can be only one auto column and it must be defined as a key
-- 错误的解决办法：就是auto_increment去掉


-- 在创建表以后添加约束：
alter table t_student add constraint pk_stu primary key (sno) ; -- 主键约束
alter table t_student modify sno int(6) auto_increment; -- 修改自增条件
alter table t_student add constraint ck_stu_sex check (sex = '男' || sex = '女');
alter table t_student add constraint ck_stu_age check (age >= 18 and age <= 50);
alter table t_student add constraint uq_stu_email unique (email);

-- 查看表结构：
desc t_student;














