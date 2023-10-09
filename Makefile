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
	sudo apt-get install git-all pcp
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

.PHONY: alp
alp:
	alp ltsv --file=${ALP_LOG} --nosave-pos --pos /tmp/alp.pos --sort $(ALP_SORT) --reverse -o $(ALP_FORMAT) -m $(ALP_API_GROUP) --qs-ignore-values

.PHONY: alpsave
alpsave:
	alp ltsv --file=${ALP_LOG} --pos /tmp/alp.pos --dump /tmp/alp.dump --sort $(ALP_SORT) --reverse -o $(ALP_FORMAT) -m $(ALP_API_GROUP)

.PHONY: alpload
alpload:
	alp ltsv --load /tmp/alp.dump --sort $(ALP_SORT) --reverse -o $(ALP_FORMAT)

.PHONY: alp-upstream
alp-upstream:
	alp ltsv --file=${ALP_UPSTREAM_LOG} --nosave-pos --pos /tmp/alp.pos --sort $(ALP_SORT) --reverse -o $(ALP_FORMAT) -m ${ALP_API_GROUP}

.PHONY: alp-delete
alp-delete:
	sudo rm $(ALP_LOG)
	sudo rm $(ALP_UPSTREAM_LOG)

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

# SlowQueryの収集
.PHONY: exec-slowlog
exec-slowlog:
# ログファイルを作成
	$(eval LOG_DIR := $(shell date '+%H-%M-%S'))
	mkdir ${BENCH_LOG}/${LOG_DIR}
# MySQLのログファイルを削除
	sudo rm -f $(SLOW_LOG)
# スロークエリの集計
#	sudo query-digester -duration ${BENCH_DURATION}
	sudo cp $(SLOW_LOG) ${BENCH_LOG}/${LOG_DIR}
	sudo chown -R isucon:isucon ${BENCH_LOG}/${LOG_DIR}
	pt-query-digest ${BENCH_LOG}/${LOG_DIR}/* > ${BENCH_LOG}/${LOG_DIR}/slow_log.txt

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

# ベンチマークのコマンド登録(★要修正)
.PHONY: setup-bench
setup-bench:
	sudo install ~/benchmarker/bin/benchmarker /usr/local/bin

# ベンチマークの実行
.PHONY: start-bench
start-bench:
# ベンチマークの起動(★要修正)
	benchmarker -target localhost:443 -tls | tee ${BENCH_LOG}/${LOG_DIR}/bench_logs.log

# 計測用のコマンド
.PHONY: exec-bench
exec-bench:
# ログファイルを作成
	$(eval LOG_DIR := $(shell date '+%H-%M-%S'))
	mkdir ${BENCH_LOG}/${LOG_DIR}
	touch ${BENCH_LOG}/${LOG_DIR}/bench_logs.log
# Nginxのログファイルを削除
	sudo rm -f $(ALP_LOG)
	sudo systemctl reload nginx
# MySQLのログファイルを削除
	sudo rm -f $(SLOW_LOG)
# APPのログファイルを初期化
	rm ${APP_LOGS}/*
	touch ${APP_LOGS}/app_access.log ${APP_LOGS}/app.log
# スロークエリの集計
#	sudo query-digester -duration ${BENCH_DURATION} &
# top, dstatによる集計
	top -c -b -n ${BENCH_DURATION} -d ${BENCH_TOP_COUNT_DURATION} > ${BENCH_LOG}/${LOG_DIR}/top.log &
	pcp dstat -tclmdrn -C 0,1,2,3,total --output ${BENCH_LOG}/${LOG_DIR}/dstat.csv > /dev/null 2>&1 &
# ベンチマークの起動(★要修正)
#	benchmarker -target localhost:443 -tls | tee ${BENCH_LOG}/${LOG_DIR}/bench_logs.log
	sleep ${BENCH_DURATION}
# ログファイルを作業ディレクトリにコピー
	sudo cp $(ALP_LOG) ${BENCH_LOG}/${LOG_DIR}
	sudo cp $(SLOW_LOG) ${BENCH_LOG}/${LOG_DIR}
	sudo cp ${APP_LOGS}/* ${BENCH_LOG}/${LOG_DIR}
# 監視プロセスを削除(pcp dstat)
	ps | grep python3| awk '{ print "kill -9", $$1}'| sh
# topをプロセスごとに集計
	grep PID ${BENCH_LOG}/${LOG_DIR}/top.log | head -n 1 > ${BENCH_LOG}/${LOG_DIR}/top_mysql.txt
	grep mysqld ${BENCH_LOG}/${LOG_DIR}/top.log >> ${BENCH_LOG}/${LOG_DIR}/top_mysql.txt
	grep PID ${BENCH_LOG}/${LOG_DIR}/top.log | head -n 1 > ${BENCH_LOG}/${LOG_DIR}/top_app.txt
	grep ${APP_NAME} ${BENCH_LOG}/${LOG_DIR}/top.log >> ${BENCH_LOG}/${LOG_DIR}/top_app.txt
	grep PID ${BENCH_LOG}/${LOG_DIR}/top.log | head -n 1 > ${BENCH_LOG}/${LOG_DIR}/top_nginx.txt
	grep nginx ${BENCH_LOG}/${LOG_DIR}/top.log >> ${BENCH_LOG}/${LOG_DIR}/top_nginx.txt
# SlowQueryの出力
	sudo cp $(SLOW_LOG) ${BENCH_LOG}/${LOG_DIR}
	sudo chown -R isucon:isucon ${BENCH_LOG}/${LOG_DIR}
	pt-query-digest ${BENCH_LOG}/${LOG_DIR}/* > ${BENCH_LOG}/${LOG_DIR}/slow_log.txt
# alpの計測
	alp ltsv --file=${ALP_LOG} --nosave-pos --pos /tmp/alp.pos --sort $(ALP_SORT) --reverse -o $(ALP_FORMAT) -m $(ALP_API_GROUP) --qs-ignore-values > ${BENCH_LOG}/${LOG_DIR}/alp.txt
