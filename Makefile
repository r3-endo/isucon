# ビルドして、サービスのリスタートを行う
# リスタートを行わないと反映されないので注意
ENV_FILE=isucon_env
include $(ENV_FILE)
GO_FILES=$(wildcard ${APP_DIR}/*.go)
########################################
# 初期セットアップ用
########################################

# 初期セットアップ
.PHONY: init-setup
init-setup:
# ログ用のディレクトリを作成する
	mkdir -p ${APP_LOGS} ${NGINX_CNF} ${MYSQL_CNF}
	touch ${APP_LOGS}/app_access.log ${APP_LOGS}/app.log
# 計測用のツールをダウンロードする(git-all, pt-query-digest, pcp(dtstat), memcached, graphviz(pprof用))
	sudo apt update
	sudo apt-get update
	sudo apt-get install git-all pcp unzip
	sudo apt install percona-toolkit memcached graphviz
# slow-logの出力先変更ツールを入れる
	git clone https://github.com/kazeburo/query-digester.git
	sudo install ~/query-digester/query-digester /usr/local/bin/
# alpコマンドをインストール
	wget https://github.com/tkuchiki/alp/releases/download/v1.0.8/alp_linux_amd64.zip
	unzip alp_linux_amd64.zip
	sudo install ./alp /usr/local/bin
# isuconユーザーの所属グループを追加(mysql, Nginx)
	sudo usermod -aG mysql isucon
	sudo usermod -aG adm isucon
	groups isucon
# TimeZoneを日本時間に変更
	sudo timedatectl set-timezone Asia/Tokyo
# Netdataをインストール
	wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && sh /tmp/netdata-kickstart.sh

# Gitのセットアップ
.PHONY: init-git
init-git:
	git config --global user.name "xxxx"
	git config --global user.email "xxxxxx@gmail.com"
	git init
	git add ${NGINX_CNF} ${MYSQL_CNF} ~/webapp/
	git commit -m "First Commit"

# サーバの構成情報確認
.PHONY: check-server
check-server:
	echo "########################################" > ~/server-setting.txt
	echo "# CPU Info" >> ~/server-setting.txt
	echo "########################################" >> ~/server-setting.txt
	lscpu >> ~/server-setting.txt
	echo "########################################" >> ~/server-setting.txt
	echo "# Memory Info" >> ~/server-setting.txt
	echo "########################################" >> ~/server-setting.txt
	free -h >> ~/server-setting.txt
	echo "########################################" >> ~/server-setting.txt
	echo "# Disk Info" >> ~/server-setting.txt
	echo "########################################" >> ~/server-setting.txt
	df -h >> ~/server-setting.txt
	echo "########################################" >> ~/server-setting.txt
	echo "# Service Info" >> ~/server-setting.txt
	echo "########################################" >> ~/server-setting.txt
	sudo systemctl list-units --type=service >> ~/server-setting.txt	
	echo "########################################" >> ~/server-setting.txt
	echo "# Mysql Info" >> ~/server-setting.txt
	echo "########################################" >> ~/server-setting.txt
	mysqld --version  >> ~/server-setting.txt
	echo "########################################" >> ~/server-setting.txt
	echo "# Nginx Info" >> ~/server-setting.txt
	echo "########################################" >> ~/server-setting.txt
	nginx -V 2>> ~/server-setting.txt
########################################
# Nginx用
########################################
.PHONY: init-nginx
init-nginx:
	sudo cp -r /etc/nginx/* ${NGINX_CNF}
	sudo chown -R isucon:isucon nginx
	git add ${NGINX_CNF}
	git commit -m "First Nginx Commit"

# nginxの設定反映
.PHONY: setup-nginx
setup-nginx:
	sudo cp -r ${NGINX_CNF}/* /etc/nginx
	sudo nginx -t
	sudo systemctl reload nginx

########################################
# Mysql用
########################################
# mysqlの設定ファイルを取得
.PHONY: init-mysql
init-mysql:
	sudo cp -r /etc/mysql/* ${MYSQL_CNF}
	sudo chown -R isucon:isucon mysql
	git add ${MYSQL_CNF}
	git commit -m "First Mysql Commit"

# mysqlの設定反映
.PHONY: setup-mysql
setup-mysql:
	sudo cp -r ${MYSQL_CNF}/* /etc/mysql
	sudo systemctl restart mysql

# mysqlの接続
.PHONY: connect-mysql
connect-mysql:
	mysql -h ${MYSQL_HOSTNAME} -u ${MYSQL_USER} -P${MYSQL_PORT} -p${MYSQL_PASS} ${MYSQL_DATABASE}

########################################
# Go用
########################################
# goのビルド
.PHONY: build-go
build-go:
	cd /home/isucon/webapp/go; \
	go build -o ${APP_NAME} *.go; \
	sudo service ${APP_NAME}.go restart

########################################
# Memcached用
########################################
# memcachedの設定反映
.PHONY: setup-memcached
setup-memcached:
	sudo service memcached restart

########################################
# Bench用
########################################

# 計測用のコマンド
.PHONY: exec-bench
exec-bench:
# ログファイルを作成
	$(eval LOG_DIR := $(shell date '+%m-%d-%H-%M-%S'))
	mkdir ${BENCH_LOG}/${LOG_DIR}
	touch ${BENCH_LOG}/${LOG_DIR}/bench_logs.log
# Nginxのログファイルを空にする
	sudo truncate -s 0 -c $(ALP_LOG)
# MySQLのログファイルを削除
	sudo rm -f $(SLOW_LOG)
	make setup-mysql
	sleep ${BENCH_DURATION}
# ログファイルを作業ディレクトリにコピー
	sudo cp $(ALP_LOG) ${BENCH_LOG}/${LOG_DIR}
	sudo cp $(SLOW_LOG) ${BENCH_LOG}/${LOG_DIR}
# SlowQueryの出力
	sudo cp $(SLOW_LOG) ${BENCH_LOG}/${LOG_DIR}
	sudo chown -R isucon:isucon ${BENCH_LOG}/${LOG_DIR}
	pt-query-digest ${BENCH_LOG}/${LOG_DIR}/* > ${BENCH_LOG}/${LOG_DIR}/slow_log.txt
# alpの計測
	alp ltsv --file=${ALP_LOG} --nosave-pos --pos /tmp/alp.pos --sort $(ALP_SORT) --reverse -o $(ALP_FORMAT) -m $(ALP_API_GROUP) --qs-ignore-values > ${BENCH_LOG}/${LOG_DIR}/alp.txt
