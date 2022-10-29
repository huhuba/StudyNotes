-- 学生表删除：
drop table t_student;
-- 班级表删除：
drop table t_class;

-- 注意：先删除主表，再删除从表。

-- 先创建父表：班级表：
create table t_class(
	cno int(4) primary key auto_increment,
	cname varchar(10) not null,
	room char(4)
)
-- 可以一次性添加多条记录：
insert into t_class values (null,'java001','r803'),(null,'java002','r416'),(null,'大数据001','r103');

-- 添加学生表，添加外键约束：
create table t_student(
        sno int(6) primary key auto_increment, 
        sname varchar(5) not null, 
        classno int(4),-- 取值参考t_class表中的cno字段，不要求字段名字完全重复，但是类型长度定义 尽量要求相同。
				constraint fk_stu_classno foreign key (classno) references t_class (cno)
);
-- 可以一次性添加多条记录：
insert into t_student values (null,'张三',1),(null,'李四',1),(null,'王五',2),(null,'朱六',3);

-- 查看班级表和学生表：
select * from t_class;
select * from t_student;



-- 删除班级2：如果直接删除的话肯定不行因为有外键约束：
-- 加入外键策略：
-- 策略1：no action 不允许操作
-- 通过操作sql来完成：
-- 先把班级2的学生对应的班级 改为null 
update t_student set classno = null where classno = 2;
-- 然后再删除班级2：
delete from t_class where cno = 2;

-- 策略2：cascade 级联操作：操作主表的时候影响从表的外键信息：
-- 先删除之前的外键约束：
alter table t_student drop foreign key fk_stu_classno;
-- 重新添加外键约束：
alter table t_student add constraint fk_stu_classno foreign key (classno) references t_class (cno) on update cascade on delete cascade;
-- 试试更新：
update t_class set cno = 5 where cno = 3;
-- 试试删除：
delete from t_class where cno = 5;

-- 策略3：set null  置空操作：
-- 先删除之前的外键约束：
alter table t_student drop foreign key fk_stu_classno;
-- 重新添加外键约束：
alter table t_student add constraint fk_stu_classno foreign key (classno) references t_class (cno) on update set null on delete set null;

-- 试试更新：
update t_class set cno = 8 where cno = 1;

-- 注意：
-- 1. 策略2 级联操作  和  策略2 的  删除操作  可以混着使用：

alter table t_student add constraint fk_stu_classno foreign key (classno) references t_class (cno) on update cascade on delete set null ;



-- 2.应用场合：
-- （1）朋友圈删除，点赞。留言都删除  --  级联操作
-- （2）解散班级，对应的学生 置为班级为null就可以了，-- set null





