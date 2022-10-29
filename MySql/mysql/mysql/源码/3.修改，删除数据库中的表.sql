-- 查看数据：
select * from t_student;

-- 修改表的结构：
-- 增加一列：
alter table t_student add score double(5,2) ; -- 5:总位数  2：小数位数 
update t_student set score = 123.5678 where sno = 1 ;

-- 增加一列（放在最前面）
alter table t_student add score double(5,2) first;

-- 增加一列（放在sex列的后面）
alter table t_student add score double(5,2) after sex;

-- 删除一列：
alter table t_student drop score;

-- 修改一列：
alter table t_student modify score float(4,1); -- modify修改是列的类型的定义，但是不会改变列的名字
alter table t_student change score score1 double(5,1); -- change修改列名和列的类型的定义

-- 删除表：
drop table t_student;