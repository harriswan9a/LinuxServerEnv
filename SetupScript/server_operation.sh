#!/bin/bash
source script_lib

gitlab_user=spencer
gitlab_passwd=12345678
gitlab_port=3000
gitlab_ext_url=git.ce.com.tw
gitlab_url_prefix=http://$gitlab_user:$gitlab_passwd@$gitlab_ext_url:$gitlab_port

go_version=1.11.1
go_container_name=my-golang

function clone_server()
{
	echo 'clone server...'
	
	pushd $PWD
	cd ../
	mkdir Server
	cd Server
	git clone $gitlab_url_prefix/cegame/src/server.git src
	git clone $gitlab_url_prefix/cegame/env.git env
	popd
}

function setup_server_firewall()
{
	firewall-cmd --permanent --zone=public --add-port=12201/tcp
	firewall-cmd --permanent --zone=public --add-port=12301/tcp
	firewall-cmd --permanent --zone=public --add-port=12401/tcp
	firewall-cmd --permanent --zone=public --add-port=12501/tcp
	firewall-cmd --reload
}

function build_server()
{
	echo 'build server...'
	
	go_host_src=/root/Server/src
	go_container_src=/go/src
	go_host_env=/root/Server/env
	go_container_env=/go/env
	build_script_name=server_do_build.sh
	
	pushd $PWD
	cd /root/Server/src
	git pull
	cd /root/Server/env
	git pull
	popd

	docker run -it --rm \
		-e "TZ=Asia/Taipei" \
		-v $go_host_src:$go_container_src \
		-v $go_host_env:$go_container_env \
		-v $(pwd)/$build_script_name:/go/$build_script_name \
		--name $go_container_name golang:$go_version \
		./$build_script_name
}

function commit_server()
{
	echo 'commit server...'
	
	pushd $PWD
	cd /root/Server/env
	commit_comment="[src] add. linux server 上版。"
	askDefault "commit comment" "commit_comment"
	git commit -m "$commit_comment"
	git push origin master
	popd
}

function start_server()
{
	echo 'start server...'
	
	server_host_env=/root/Server/env/server/linux
	server_container_env=/Server
	sleep_secs=2

	rm -rf $server_host_env/logs

	docker run --detach --rm \
		-e "TZ=Asia/Taipei" \
		-v $server_host_env:$server_container_env \
		--publish 12201:12201 \
		--name data_server --init golang:latest \
		/bin/sh -c "cd $server_container_env/data_server && ./dataserver.out"
	sleep $sleep_secs

	docker run --detach --rm \
		-e "TZ=Asia/Taipei" \
		-v $server_host_env:$server_container_env \
		--publish 12301:12301 \
		--name login_server --init golang:latest \
		/bin/sh -c "cd $server_container_env/login_server && ./loginserver.out"
	sleep $sleep_secs

	docker run --detach --rm \
		-e "TZ=Asia/Taipei" \
		-v $server_host_env:$server_container_env \
		--publish 12401:12401 \
		--name lobby_server --init golang:latest \
		/bin/sh -c "cd $server_container_env/lobby_server && ./lobbyserver.out"
	sleep $sleep_secs

	docker run --detach --rm \
		-e "TZ=Asia/Taipei" \
		-v $server_host_env:$server_container_env \
		--publish 12501:12501 \
		--name game_server --init golang:latest \
		/bin/sh -c "cd $server_container_env/game_server && ./gameserver.out"
}

function stop_server()
{
	echo 'stop server...'
	
	docker stop data_server
	docker stop login_server
	docker stop lobby_server
	docker stop game_server
}

function menu()
{
	time=$(date '+%Y-%m-%d %H:%M:%S')
	printc C_GREEN "================================================================\n"
	printc C_GREEN "= server operation"
	printc C_WHITE " (IP: $static_ip, time: $time)\n"
	printc C_GREEN "================================================================\n"
	printc C_CYAN "  1. clone server\n"
	printc C_CYAN "  2. setup server firewall\n"
	printc C_CYAN "  11. build server\n"
	printc C_CYAN "  12. commit server\n"
	printc C_CYAN "  21. start server\n"
	printc C_CYAN "  22. stop server\n"
	printc C_CYAN "  q. Exit\n"
	while true; do
		read -p "Please Select:" cmd
		case $cmd in
			1)
				clone_server
				return 0;;
			2)
				setup_server_firewall
				return 0;;
			11)
				build_server
				return 0;;
			12)
				commit_server
				return 0;;
			21)
				start_server
				return 0;;
			22)
				stop_server
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