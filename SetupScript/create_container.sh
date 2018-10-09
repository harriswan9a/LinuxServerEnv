#!/bin/bash
source script_lib

redis_container_name=my-redis
mysql_passwd=1234
mysql_container_name=my-mysql
mysql_docker_file_path=/root/DockerArea/MySQL/

getInnerIP static_ip

function create_redis()
{
	echo 'create redis container...'
	
	docker run --detach --publish 6379:6379 --name $redis_container_name redis
	docker exec -it $redis_container_name bash -c "redis-server --version"
}

function create_mysql()
{
	# https://medium.com/@lvthillo/customize-your-mysql-database-in-docker-723ffd59d8fb
	echo 'create MySQL container...'
	
	pushd $PWD
	cd $mysql_docker_file_path
	docker build -t my-mysql .
	docker run --detach --publish 3306:3306 -e MYSQL_ROOT_PASSWORD=$mysql_passwd --name $mysql_container_name my-mysql
	docker exec -it $mysql_container_name bash -c "mysql -V"
	popd
}

function test_redis()
{
	echo 'test redis container...'
	
	docker exec -it $redis_container_name bash -c "redis-cli ping"
}

function test_mysql()
{
	echo 'test mysql container...'
	
	mysql_test_sql="\
show databases;\
use casino;\
show tables;\
select * from acc limit 10;\
"
	mysql_test_command="mysql -uroot -p"$mysql_passwd" -e '"$mysql_test_sql"'"
	docker exec -it $mysql_container_name bash -c "$mysql_test_command"
}

function fix_mysql()
{
	echo 'fix mysql container...'
	
	mysql_fix_sql="\
alter user root@'localhost' identified with mysql_native_password by '"$mysql_passwd"';\
alter user root@'%' identified with mysql_native_password by '"$mysql_passwd"';\
"
	mysql_fix_command="mysql -uroot -p"$mysql_passwd" -e \""$mysql_fix_sql"\""
	docker exec -it $mysql_container_name bash -c "$mysql_fix_command"
	
	mysql_test_sql="\
select * from mysql.user where User='root';\
"
	mysql_test_command="mysql -uroot -p"$mysql_passwd" -e \""$mysql_test_sql"\""
	docker exec -it $mysql_container_name bash -c "$mysql_test_command"
}

function menu()
{
	time=$(date '+%Y-%m-%d %H:%M:%S')
	printc C_GREEN "================================================================\n"
	printc C_GREEN "= create containers"
	printc C_WHITE " (IP: $static_ip, 目前時間: $time)\n"
	printc C_GREEN "================================================================\n"
	printc C_CYAN "  1. redis\n"
	printc C_CYAN "  2. mysql\n"
	printc C_CYAN "  11. test redis\n"
	printc C_CYAN "  12. test mysql\n"
	printc C_CYAN "  21. fix mysql\n"
	printc C_CYAN "  q. Exit\n"
	while true; do
		read -p "Please Select:" cmd
		case $cmd in
			1)
				create_redis
				return 0;;
			2)
				create_mysql
				return 0;;
			11)
				test_redis
				return 0;;
			12)
				test_mysql
				return 0;;
			21)
				fix_mysql
				return 0;;
			[Qq]* )
				return 1;;
			* ) 
				echo "Please enter number or q to exit.";;
		esac
	done
}

while menu
do
	echo
done