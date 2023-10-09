# 1. 事前準備

- Config にサーバ定義(/Users/user_name/.ssh/config 参照)
  ```txt
    Host Bench
    HostName 35.74.188.136
    User ubuntu
    IdentityFile ~/.ssh/isucon_key.pem
    port 22
    Host isucon1
    HostName 18.180.82.141
    User ubuntu
    IdentityFile ~/.ssh/isucon_key.pem
    port 22
    Host isucon2
    HostName 54.238.215.60
    User ubuntu
    IdentityFile ~/.ssh/isucon_key.pem
    port 22
    Host isucon3
    HostName 35.72.65.191
    User ubuntu
    IdentityFile ~/.ssh/isucon_key.pem
    port 22
  ```
- SSH ログイン
  ```bash
    ssh isucon
    su isucon
  ```

# 2. Makefile 作成(コマンドのショートカット用)

- Makefile の内容は以下。当日はパス等を編集すること。

  ```make
  # ビルドして、サービスのリスタートを行う
  # リスタートを行わないと反映されないので注意
  DEST=$(PWD)/【バイナリファイル名】
  COMPILER=go
  GO_FILES=$(wildcard ./*.go ./**/*.go)

  .PHONY: build
  build:
      cd /home/isucon/webapp/go; \
      @$(COMPILER) build -o $(DEST) -ldflags "-s -w" \
      sudo systemctl restart isucondition.go.service;
  # pprofのデータをwebビューで見る
  # サーバー上で sudo apt install graphvizが必要
  .PHONY: pprof
  pprof:
      go tool pprof -http=0.0.0.0:8080 /home/isucon/webapp/go/isucondition http://localhost:6060/debug/pprof/profile
  # mydql関連
  MYSQL_HOST="localhost"
  MYSQL_PORT=3306
  MYSQL_USER=isucon
  MYSQL_DBNAME=isucondition
  MYSQL_PASS=isucon
  MYSQL=mysql -h$(MYSQL_HOST) -P$(MYSQL_PORT) -u$(MYSQL_USER) -p$(MYSQL_PASS) $(MYSQL_DBNAME)
  SLOW_LOG=/tmp/slow-query.log
  # slow-wuery-logを取る設定にする
  # DBを再起動すると設定はリセットされる
  .PHONY: slow-on
  slow-on:
      -sudo rm $(SLOW_LOG)
      sudo systemctl restart mysql
      $(MYSQL) -e "set global slow_query_log_file = '$(SLOW_LOG)'; set global long_query_time = 0.001; set global slow_query_log = ON;"
  .PHONY: slow-off
  slow-off:
      $(MYSQL) -e "set global slow_query_log = OFF;"
  # mysqldumpslowを使ってslow wuery logを出力
  # オプションは合計時間ソート
  # このコマンドは 2 台目から叩かないと意味がない
  .PHONY: slow-show
  slow-show:
  sudo mysqldumpslow -s t $(SLOW_LOG) | head -n 20
  # alp
  ALPSORT=sum
  ALPM="/api/isu/.+/icon,/api/isu/.+/graph,/api/isu/.+/condition,/api/isu/[-a-z0-9]+,/api/condition/[-a-z0-9]+,/api/catalog/.+,/api/condition\?,/isu/........-....-.+"
  OUTFORMAT=count,method,uri,min,max,sum,avg,p99
  ALP_LOG=/var/log/nginx/access.log
  UPSTREAM_LOG=/var/log/nginx/upstream.log
  .PHONY: alp
  alp:
      sudo alp ltsv --file=/var/log/nginx/access.log --nosave-pos --pos /tmp/alp.pos --sort $(ALPSORT) --reverse -o $(OUTFORMAT) -m $(ALPM) -q
  .PHONY: alpsave
  alpsave:
      sudo alp ltsv --file=/var/log/nginx/access.log --pos /tmp/alp.pos --dump /tmp/alp.dump --sort $(ALPSORT) --reverse -o $(OUTFORMAT) -m $(ALPM) -q
  .PHONY: alpload
  alpload:
      sudo alp ltsv --load /tmp/alp.dump --sort $(ALPSORT) --reverse -o count,method,uri,min,max,sum,avg,p99 -q
  .PHONY: alp-upstream
  alp-upstream:
      sudo alp ltsv --file=/var/log/nginx/upstream.log --nosave-pos --pos /tmp/alp.pos --sort $(ALPSORT) --reverse -o $(OUTFORMAT) -m $(ALPM) -q
  .PHONY: alp-delete
  alp-delete:
      -sudo rm $(ALP_LOG)
      -sudo rm $(UPSTREAM_LOG)
  ```

# 3. alp(計測結果のフォーマット)

- インストール手順は以下
- `home/isucon`配下に以下のコマンド
  ```txt
  `wget https://github.com/tkuchiki/alp/releases/download/v1.0.8/alp_linux_amd64.zip`
  `unzip alp_linux_amd64.zip`
  `sudo install ./alp /usr/local/bin`
  `sudo vim /etc/nginx/nginx.conf`
   右記のリンクを参考にして、nginx.confを編集。https://github.com/Nagarei/isucon11-qualify-test/commit/b7e8f2667677831490d8e5966251633c14944015
  `sudo rm /var/log/nginx/access.log && sudo systemctl reload nginx`
  ```
- alp コマンド
  ```txt
   cat /var/log/nginx/access.log | alp ltsv
  ```

# 4. slow-query

- mysql にログイン。mySQl へのログインは env.sh を確認。
  ```txt
  mysql -h MYSQL_HOST -P MYSQL_PORT -u MYSQL_USER -pMYSQL_PASS MYSQL_DBNAME
  mysql -h localhost -P 3306 -u isucon -pisucon isucondition
  ```
- slow-query ログの出力先を以下のように設定
  ```txt
  # `SHOW GLOBAL VARIABLES LIKE '%slow_query%';`
  # `SET GLOBAL slow_query_log_file = '/tmp/slow-query.log';`
  ```

# 5. pprof

- main.go に以下２行追加
  ```go
  _"net/http/pprof"
  go func() {
      log.Print(http.ListenAndServe("localhost:6060", nil))
      }()
  ```
- pprof をインストール
  - パッケージをインストール
    - `go get -u github.com/google/pprof`
  - graphviz が必要なのでインストール
    - `sudo apt install graphviz`
  - pprof のコマンド実行(ベンチの起動中に実行すること)
    - `go tool pprof -http=localhost:1080 /home/isucon/webapp/go/isucondition http://localhost:6060/debug/pprof/profile`
  - ポートフォワードによりローカルから UI 確認(上記のコマンドの場合, 1080 ポートで起動する)
    - `ssh ubuntu@isucon -NfL 1080:localhost:1080`
- pprof の項目
  1. 「top」：実行時間と待ち時間を確認(cum-flat)
  2. 「peak」：システムが呼び出しているコード詳細確認
  3. 「source」：アプリケーションの行単位の実行時間計測

# 6. bench の実行

- bench 実行前
  ```sh
  make build (main.goのビルド)
  make slow-on (slow-queryの出力)
  make alp-delete
  ```
- bench 実行後
  ```sh
  make slow-show (スロークエリログの結果表示)
  make pprof (pprofを開く)
  make alp (alpのログ表示)
  ```

# 7. DB の向き先変更

- AWS
  - 接続先のポート(3306)を開ける
- MYSQL
  - `/etc/mysql/mariadb.conf.d/50-server.cnf`で接続元の IP が制限されている(localhost のみ)ので、設定を変更する
    ```txt
    # Instead of skip-networking the default is now to listen only on
    # localhost which is more compatible and is not less secure.
    # bind-address            = 127.0.0.1 (default)
    bind-address            = 0.0.0.0
    ```
  - 上記を実施後、mariaDB のサービスを再度立ち上げる
    - サービスの一覧を確認 `sudo systemctl list-units --type=service`
    - MariaDB のサービスを指定して再起動 `sudo systemctl restart mariadb.service`
  - Mysql のユーザーの接続が Localhost に制限されているので、任意の IP から接続できるようにする
    - `RENAME USER 'isucon'@'localhost' TO 'isucon'@'%';`
- App
  - DB の向き先を定義した環境変数を変更する(Private IP)
  ```go
  func NewMySQLConnectionEnv() *MySQLConnectionEnv {
  return &MySQLConnectionEnv{
    Host:     getEnv("MYSQL_HOST", "172.31.29.171"),
    //Host:     getEnv("MYSQL_HOST", "127.0.0.1"),
    Port:     getEnv("MYSQL_PORT", "3306"),
    User:     getEnv("MYSQL_USER", "isucon"),
    DBName:   getEnv("MYSQL_DBNAME", "isucondition"),
    Password: getEnv("MYSQL_PASS", "isucon"),
  }
  ```

# 8. Service 関連のコマンドまとめ

各サービスは systemctl コマンドで確認することができる。  
Service 関連のコマンドを一覧化する。

- Service の一覧を取得する
  - `sudo systemctl list-units --type=service`
- Sevice の再起動
  - `sudo systemctl restart [ServiceName]`
- Service の状態確認
  - `sudo systemctl status [ServiceName]`
- Service のログの確認
  - `journalctl --no-pager | grep -e [ServiceName]`
- System デーモンの設定ファイルの配置場所
  - `/etc/systemd/system/`
  - 設定例 (isucondition.go)

```txt
    [Unit]
    Description=isucondition.go
    After=network.target mysql.service cloud-config.service
    [Service]
    WorkingDirectory=/home/isucon/webapp/go/
    EnvironmentFile=/home/isucon/env.sh
    User=isucon
    Group=isucon
    ExecStart=/home/isucon/webapp/go/isucondition
    Restart   = no
    Type      = simple
    [Install]
    WantedBy=multi-user.target
```

- System デーモンに設定ファイルを反映させる
  - `sudo systemctl daemon-reload`

# 9. Nginx

- リバースプロキシの設定

```sh
# リバースプロキシの設定
isucon@ip-172-31-29-171:/etc/nginx/sites-available$ sudo vim isucondition.conf
# 振り分け先となるサーバを定義
upstream app {
    server 172.31.23.203:3000;
}
server {
    listen 443 ssl http2;
    ssl_certificate /etc/nginx/certificates/tls-cert.pem;
    ssl_certificate_key /etc/nginx/certificates/tls-key.pem;
    location / {
        proxy_set_header Host $http_host;
        proxy_pass http://127.0.0.1:3000;
    }
    # /api/condition配下のURLは、appで定義したサーバーに振る
    location /api/condition {
        proxy_set_header Host $http_host;
        proxy_pass http://app;
   }
}
```

- ログ出力・設定ファイルの読み込み

```sh
# Nginxの設定ファイル
isucon@ip-172-31-29-171:/etc/nginx$ less nginx.conf
user  www-data;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /run/nginx.pid;


events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    # alp用のログフォーマット
    log_format upstreamlog "time:$time_local"
                "\thost:$remote_addr"
                "\tforwardedfor:$http_x_forwarded_for"
                "\treq:$request"
                "\tstatus:$status"
                "\tmethod:$request_method"
                "\turi:$request_uri"
                "\tsize:$body_bytes_sent"
                "\treferer:$http_referer"
                "\tua:$http_user_agent"
                "\treqtime:$request_time"
                "\tcache:$upstream_http_x_cache"
                "\truntime:$upstream_http_x_runtime"
                "\tapptime:$upstream_response_time"
                "\tvhost:$host";

    log_format ltsv "time:$time_local"
                "\thost:$remote_addr"
                "\tforwardedfor:$http_x_forwarded_for"
                "\treq:$request"
                "\tstatus:$status"
                "\tmethod:$request_method"
                "\turi:$request_uri"
                "\tsize:$body_bytes_sent"
                "\treferer:$http_referer"
                "\tua:$http_user_agent"
                "\treqtime:$request_time"
                "\tcache:$upstream_http_x_cache"
                "\truntime:$upstream_http_x_runtime"
                "\tapptime:$upstream_response_time"
                "\tvhost:$host";

    #振り分け先のログは,upstream.logのファイル名で出力
    access_log  /var/log/nginx/access.log  ltsv;
    access_log /var/log/nginx/upstream.log upstreamlog;
    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*.conf;
}

# 以下のコマンドでconfファイルの文法チェック
$ nginx -t
```

# 10. Appendix

- Go Build
  - https://qiita.com/Utr/items/9469c1611abe8a0a3486
- スロークエリログ
  - https://qiita.com/bohebohechan/items/30103a0b79a520e991fa
- alp
  - https://zenn.dev/tkuchiki/articles/how-to-use-alp
  - https://github.com/tkuchiki/alp/blob/main/README.md
  - https://nishinatoshiharu.com/install-alp-to-nginx/
- MakeFile
  - https://qiita.com/yoskeoka/items/317a3afab370155b3ae8
- Git
  - https://github.com/Nagarei/isucon11-qualify-test/commit/b7e8f2667677831490d8e5966251633c14944015
- isucon11 設定
  - https://gist.github.com/south37/d4a5a8158f49e067237c17d13ecab12a
- そのほか
  - https://to-hutohu.com/2019/09/09/isucon9-qual/

# 11. 当日作業手順

1. SSH の設定
2. 計測準備
   1. Makefile の設定
   2. slow query の設定
   3. alp の設定
3. ビルド環境の準備
   1. Makefile の修正
4. ベンチの実行
   1. 初期スコア確認
   2. 計測ツールの結果確認
      1. alp, slow query の結果確認）
      2. 計測結果をメモする
   3. マニュアルの読み込み
5. チューニング作業
   1. SQL
      1. Index
      2. Slow Query
      3. N +1
      4. Bulk Insert
   2. API
      1. SQL の Limit
      2. キャンペーン系の変数
      3. 無駄な呼び出し
      4. キャッシュ
   3. アプリ全般
      1. ログの制限
   4. 基盤
      1. 負荷分散
         1. DB 固定化
         2. Nginx のプロキシ設定
      2. プロキシ
         1. キャッシュ
