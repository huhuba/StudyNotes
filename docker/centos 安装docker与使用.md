centos 安装 docker

https://docs.docker.com/engine/install/centos/

centos安装mysql

https://hub.docker.com/_/mysql

centos使用mysql;

https://www.jb51.net/article/257592.htm

~~~java

#以mysql为例
docker start  somename;  启动docker已经存在的容器
docker stop somename;    关闭docker正在运行的容器
docker pull somename; 拉取指定镜像
docker  create somename; 创建指定容器
docker  run --name somename  ...;
	例如：
	docker run --name mysql -e MYSQL_ROOT_PASSWORD=123456   -d mysql:lasted
	-d:后台运行
dockker run -d -p 33306:3306  ....:内外的端口映射，外(容器所在主机):33306,内(容器):3306        
docker rm  somename ;删除指定容器
docker rm <-f> 容器id - 删除容器
docker rmi <-f> 镜像名:<tags> - 删除镜像的指定版本
    ？？？容器和镜像，是什么关系。
 
docker rm -f somename;强制删除正在运行的容器
    镜像和容器的关系：镜像运行起来就成了容器，类似于java类和对象的关系，不过容器也是可以持久化的。
    镜像和容器的关系：https://blog.csdn.net/m0_58292366/article/details/125765732
    
docker images;显示所有的镜像
docker ps ;显示正在运行中的镜像；
docker ps -a;查看所有的容器
docker exec -it mysql bash;进入mysql容器中执行linux命令
    -it:以交互的方式执行命令
    


	
~~~

