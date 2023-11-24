<!-- omit in toc -->

# ISUCON13 作業手順書

## 1. セットアップ作業

- [ ] Config にサーバ定義(/Users/user_name/.ssh/config 参照)
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
- [ ] SSH ログイン

  ```bash
    ssh isucon
  ```

- [ ] isucon ユーザーに変更
  - [ ] `su isucon`(pass: isucon)
- [ ] ISUCON ユーザーでログインできるように変更
  - [ ] `mkdir ~/.ssh`
  - [ ] `sudo cp /home/ubuntu/.ssh/authorized_keys /home/isucon/.ssh`
  - [ ] `sudo chown isucon:isucon /home/isucon/.ssh/authorized_keys`
- [ ] ローカルの`~/.ssh/config`を isucon ユーザーに変更する
  ```txt
    Host isucon
    HostName 35.72.65.191
    User isucon # ubuntuから変更
    IdentityFile ~/.ssh/isucon_key.pem
    port 22
  ```
- [ ] makefile の持ち込み
  - [ ] `scp Makefile isucon@18.179.167.248:~/`
  - [ ] `scp isucon_env isucon@18.179.167.248:~/`
- [ ] SetUP 用の Make コマンドを実行
  - [ ] `make init-setup`
- [ ] Git のセットアップ用のコマンドを実行する
  - [ ] `make init-git`
- [ ] サーバの設定情報を取得する
  - [ ] `make check-server`

## 2. ミドル系設定変更

### 2.1. Go アプリケーションの設定確認

- [ ] Go のサービス名を確認(`server-setting.txt`)
- [ ] サービスの設定を確認

  - [ ] `sudo systemctl status isuconquest.go.service`

    ```txt
    # 出力例
    isucon@ip-172-31-2-16:~$ sudo systemctl status isucholar.go.service
    ● isucholar.go.service - isucholar.go
        Loaded: loaded (/etc/systemd/system/isucholar.go.service; enabled; vendor preset: enabled) #Serviceの設定ファイルの場所
        Active: active (running) since Sat 2022-07-16 20:18:50 JST; 1h 31min ago
      Main PID: 7429 (isucholar)
          Tasks: 6 (limit: 4691)
        Memory: 1.5M
        CGroup: /system.slice/isucholar.go.service
                └─7429 /home/isucon/webapp/go/isucholar #Goアプリケーションの配置場所

    Jul 16 20:18:50 ip-172-31-2-16 systemd[1]: Started isucholar.go.
    Jul 16 20:18:50 ip-172-31-2-16 isucholar[7429]: ⇨ http server started on [::]:7000
    ```

- [ ] サービスファイルを確認

  - [ ] `less /etc/systemd/system/isuconquest.go.service`

    ```
    # 出力例
    [Unit]
    Description=isuconquest.go

    [Service]
    WorkingDirectory=/home/isucon/webapp/go
    EnvironmentFile=/home/isucon/env
    PIDFile=/home/isucon/webapp/go/server.pid

    User=isucon
    Group=isucon
    ExecStart=/home/isucon/.x /home/isucon/webapp/go/isuconquest
    ExecStop=/bin/kill -s QUIT $MAINPID

    Restart   = always
    Type      = simple

    [Install]
    WantedBy=multi-user.target
    ```

### 2.2. nginx の設定変更

- [ ] Nginx のセットアップ用のコマンドを実行する

  - [ ] `make init-nginx`

- [ ] nginx のログ出力を変更

  - [ ] `vim ~/nginx/nginx.conf`

  ```nginx.confの記載内容
    # access_log  /var/log/nginx/access.log  main;
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

    access_log  /var/log/nginx/access.log  ltsv;
  ```

- [ ] Nginx を再起動する
  - [ ] `make setup-nginx`

### 2.3. MySQL の設定変更

- [ ] Mysql のセットアップ用コマンドを実行する
  - [ ] `make init-mysql`
- [ ] MYSQL の設定ファイルを変更する
  - [ ] `vim ~/mysql/mysql.conf.d/mysqld.cnf`

```
[mysqld]
slow_query_log = ON
slow_query_log_file = /home/iscuon/logs/mysql/mysql-slow.sql
long_query_time = 0
```

- [ ] MySQL を再起動する
  - [ ] `make setup-mysql`

### 2.4. ALP の計測設定

- [ ] `ALP_API_GROUP` : alp のログ集計のパラメータを変更
  ```
  ALP_API_GROUP="/user/[-a-zA-Z0-9]+/home, \
  /user/[-a-zA-Z0-9]+/reward, \
  /user/[-a-zA-Z0-9]+/card, \
  /user/[-a-zA-Z0-9]+/item, \
  /user/[-a-zA-Z0-9]+/card/addexp/[-a-zA-Z0-9]+, \
  /user/[-a-zA-Z0-9]+/present/index/[-a-zA-Z0-9], \
  /user/[-a-zA-Z0-9]+/present/recieve, \
  /user/[-a-zA-Z0-9]+/gacha/index, \
  /user/[-a-zA-Z0-9]+/gacha/drawx/[-a-zA-Z0-9]/[-a-zA-Z0-9], \
  /login, \
  /admin/[-a-zA-Z0-9], \
  /admin/user/[-a-zA-Z0-9], \
  /api/courses/[-A-Z0-9]+"
  ```
  - [ ] 参考情報
    - [ ] https://github.com/tkuchiki/alp/blob/main/README.ja.md
    - [ ] https://github.com/tkuchiki/alp/blob/main/docs/usage_samples.ja.md
- [ ] `APP_NAME` : アプリケーション名, `~/webapp/go`配下に記載

### 2.5. アプリログの出力

main.go に以下の通り記載

```go
import (
	"database/sql"
...
	"log"//logパッケージを読み込む
)

....

// journalログの出力フォーマット
func logFormat() string {
        // Refer to https://github.com/tkuchiki/alp
        var format string
        format += "time:${time_rfc3339}\t"
        format += "host:${remote_ip}\t"
        format += "forwardedfor:${header:x-forwarded-for}\t"
        format += "req:-\t"
        format += "status:${status}\t"
        format += "method:${method}\t"
        format += "uri:${uri}\t"
        format += "size:${bytes_out}\t"
        format += "referer:${referer}\t"
        format += "reqtime_ns:${latency}\t"
        format += "cache:-\t"
        format += "runtime:-\t"
        format += "apptime:-\t"
        format += "host:${host}\n"

        return format
}

func main() {
	e := echo.New()
	// logの出力先を変更(以下を追記)
  /////////////////////////////////////
  // ここから
  /////////////////////////////////////
  // accessログ
	fp, err := os.OpenFile("/home/isucon/logs/app/app_access.log", os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
  	if err != nil {
    	panic(err)
  	}
	e.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
		Format: logFormat(),
    Output: fp,
	}))

  //appログ
  fpApp, err := os.OpenFile("/home/isucon/logs/app/app.log", os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
  	if err != nil {
    	panic(err)
  	}
	log.SetOutput(fpApp)
  /////////////////////////////////////
  // ここまで
  /////////////////////////////////////
```

- ログの出力方法
  - `app log`: `log.Printf("Values : %v", values)`
    - %v は任意の変数型に対して有効
  - `journal log`: `c.Logger().Error(err)`
    - c は、echo.Context であり、HTTP リクエスト状況を表す

### 2.6. ベンチマークの実行方法

```
./bin/benchmarker --stage=prod --request-timeout=10s --initialize-request-timeout=120s --target-host=localhost:80
```

---

## 3. 各種計測コマンド

- [ ] MySQL の再起動
  - [ ] `make setup-mysql`
- [ ] NGINX の再起動
  - [ ] `setup-nginx`
- [ ] Go のビルド
  - [ ] `make build-go`
- [ ] ベンチマークの計測
  - [ ] `make exec-bench`
- [ ] NetData の確認
  - [ ] 統計データは`http://IPアドレス:19999`から確認可能

---

## 4. 後始末

- [ ] アプリ
  - [ ] ログの停止
  - [ ] アプリ内の不要なログを消す
- [ ] DB
  - [ ] Slowlog の停止
  - [ ] MySQL の binlog
- [ ] nginx
  - [ ] access ログの停止
- [ ] 不要なサービスの停止
  - [ ] アプリサーバ
    - [ ] DB サービス
  - [ ] DB サーバ
    - [ ] アプリ
    - [ ] Nginx
