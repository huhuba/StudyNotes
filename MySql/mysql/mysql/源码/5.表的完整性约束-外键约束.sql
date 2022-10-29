-- 先创建父表：班级表：
create table t_class(
	cno int(4) primary key auto_increment,
	cname varchar(10) not null,
	room char(4)
)

-- 添加班级数据：
insert into t_class values (null,'java001','r803');
insert into t_class values (null,'java002','r416');
insert into t_class values (null,'大数据001','r103');

-- 可以一次性添加多条记录：
insert into t_class values (null,'java001','r803'),(null,'java002','r416'),(null,'大数据001','r103');

-- 查询班级表：
select * from t_class;
-- 学生表删除：
drop table t_student;
-- 创建子表,学生表：
create table t_student(
        sno int(6) primary key auto_increment, 
        sname varchar(5) not null, 
        classno int(4)  -- 取值参考t_class表中的cno字段，不要求字段名字完全重复，但是类型长度定义 尽量要求相同。
);

-- 添加学生信息：
insert into t_student values (null,'张三',1),(null,'李四',1),(null,'王五',2);

-- 查看学生表：
select * from t_student;



-- 出现问题：
-- 1.添加一个学生对应的班级编码为4：
insert into t_student values (null,'丽丽',4);
-- 2.删除班级2：
delete from t_class where cno = 2;

-- 出现问题的原因：
-- 因为你现在的外键约束，没用语法添加进去，现在只是逻辑上认为班级编号是外键，没有从语法上定义


-- 解决办法，添加外键约束：
-- 注意：外键约束只有表级约束，没有列级约束：
create table t_student(
        sno int(6) primary key auto_increment, 
        sname varchar(5) not null, 
        classno int(4),-- 取值参考t_class表中的cno字段，不要求字段名字完全重复，但是类型长度定义 尽量要求相同。
				constraint fk_stu_classno foreign key (classno) references t_class (cno)
);

create table t_student(
        sno int(6) primary key auto_increment, 
        sname varchar(5) not null, 
        classno int(4)
);
-- 在创建表以后添加外键约束：
alter table t_student add constraint fk_stu_classno foreign key (classno) references t_class (cno)


-- 上面的两个问题都解决了：
-- 添加学生信息：
-- > 1452 - Cannot add or update a child row: a foreign key constraint fails (`mytestdb`.`t_student`, CONSTRAINT `fk_stu_classno` FOREIGN KEY (`classno`) REFERENCES `t_class` (`cno`))
insert into t_student values (null,'张三',1),(null,'李四',1),(null,'王五',2);

-- 删除班级1：
-- 2.删除班级2：
insert into t_student values (null,'张三',3),(null,'李四',3),(null,'王五',3);
-- > 1451 - Cannot delete or update a parent row: a foreign key constraint fails (`mytestdb`.`t_student`, CONSTRAINT `fk_stu_classno` FOREIGN KEY (`classno`) REFERENCES `t_class` (`cno`))
delete from t_class where cno = 3;








