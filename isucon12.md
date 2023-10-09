# ISUCON12 CheetSheet

### 準備

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
- [ ] makefileの持ち込み
  - [ ] `scp Makefile isucon@18.179.167.248:~/`
  - [ ] `scp isucon_env isucon@18.179.167.248:~/`
- [ ] SetUP 用の Make コマンドを実行
  - [ ] `make init-setup`
- [ ] Git のセットアップ用のコマンドを実行する
  - [ ] `make init-git`
- [ ] サーバの設定情報を取得する
  - [ ] `make check-server`

### Go アプリケーションの設定確認

- [ ] Go のサービス名を確認(`server-setting.txt`)
- [ ] サービスの設定を確認

  - [ ] `sudo systemctl status アプリ名.go.service`

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

  - [ ] `less /etc/systemd/system/アプリ名.go.service`

    ```
    # 出力例
    [Unit]
    Description=isucholar.go
    After=cloud-config.service
    Wants=cloud-config.service
    [Unit]
    Description=isucholar.go
    After=cloud-config.service
    Wants=cloud-config.service
    [Unit]
    Description=isucholar.go
    After=cloud-config.service
    Wants=cloud-config.service

    [Service]
    WorkingDirectory=/home/isucon/webapp/go # アプリの参照先
    EnvironmentFile=/home/isucon/env.sh # 環境変数の参照先
    PIDFile=/home/isucon/webapp/go/server.pid

    User=isucon
    Group=isucon
    ExecStart=/home/isucon/webapp/go/isucholar
    ExecStop=/bin/kill -s QUIT $MAINPID

    Restart   = always
    Type      = simple

    [Install]
    WantedBy=multi-user.target
    ```

### nginx の設定変更

- [x] Nginx のセットアップ用のコマンドを実行する

  - [x] `make init-nginx`

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

#### slow-query の準備

- [x] Mysql のセットアップ用コマンドを実行する
  - [x] `make init-mysql`
- [x] MYSQL の設定ファイルを変更する
  - [x] `vim ~/mysql/mysql.conf.d/mysqld.cnf`

```
[mysqld]
slow_query_log = ON
slow_query_log_file = /home/iscuon/logs/mysql/mysql-slow.sql
long_query_time = 0
```

- [x] MySQL を再起動する
  - [x] `make setup-mysql`

### env ファイルの修正

- [x] `ALP_API_GROUP` : alp のログ集計のパラメータを変更
  ```
  ALP_API_GROUP="/api/announcements/[-a-z0-9]+, \
  /api/courses/[a-zA-Z0-9]+/classes, \
  /api/courses/[-A-Z0-9]/classes/[-A-Z0-9]+/assignments, \
  /api/courses/[-A-Z0-9]+/assignments, \
  /api/courses/[-A-Z0-9]+"
  ```
  - [ ] 参考情報
    - [ ] https://github.com/tkuchiki/alp/blob/main/README.ja.md
    - [ ] https://github.com/tkuchiki/alp/blob/main/docs/usage_samples.ja.md
- [ ] `APP_NAME` : アプリケーション名, `~/webapp/go`配下に記載

### アプリログを出力

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

### 計測コマンド

- [ ] slowlog の収集
  - [ ] `make exec-slowlog`
- [ ] alp による API の集計
  - [ ] `make alp`

---

## 後始末 CheckSheet

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

---

## Tips

### アプリの必須改善

- [ ] Debug ログを消す
  ```go
  /////////////////////////////////////
  // Goのデバッグログ設定をoffにする(ログレベルをErrorに)
  /////////////////////////////////////
  e.Debug = false
  e.Logger.SetLevel(log.ERROR)
  ```

### MySQL の必須改善

#### my.cnf

- [ ] `max_connections`を変更する
  ```
  [mysqld]
  ...中略
  # max_connectionsを追加
  max_connections=10000
  # InnoDBログの出力方法を変更する
  ## Disk I/Oを減らすことが目的。0と2の違いはトランザクションコミット時にログが出力されるかどうか。
  innodb_flush_log_at_trx_commit = 2
  ```

#### slowlog

- [ ] ADMIN PREPARE

  ```
  # Profile
  # Rank Query ID                      Response time  Calls R/Call V/M   Ite
  # ==== ============================= ============== ===== ====== ===== ===
  # ....中略
  #    2 0xDA556F9115773A1A99AA0165...  18.1114  7.4% 84209 0.0002  0.00 ADMIN PREPARE
  ```

  ```go
  func GetDB(batch bool) (*sqlx.DB, error) {
    mysqlConfig := mysql.NewConfig()
    mysqlConfig.Net = "tcp"
    mysqlConfig.Addr = GetEnv("MYSQL_HOSTNAME", "127.0.0.1") + ":" + GetEnv("MYSQL_PORT", "3306")
    mysqlConfig.User = GetEnv("MYSQL_USER", "isucon")
    mysqlConfig.Passwd = GetEnv("MYSQL_PASS", "isucon")
    mysqlConfig.DBName = GetEnv("MYSQL_DATABASE", "isucholar")
    mysqlConfig.Params = map[string]string{
      "time_zone": "'+00:00'",
    }
    mysqlConfig.ParseTime = true
    mysqlConfig.MultiStatements = batch
    /////////////////////////////////////
    // プリペアードステートメント対策
    /////////////////////////////////////
    mysqlConfig.InterpolateParams = true

    return sqlx.Open("mysql", mysqlConfig.FormatDSN())
  }
  ```

- [ ] COMMIT

  ```
  # Profile
  # Rank Query ID                      Response time  Calls R/Call V/M   Ite
  # ==== ============================= ============== ===== ====== ===== ===
  #    1 0xFFFCA4D67EA0A788813031B8... 213.7360 75.7% 15578 0.0137  0.02 COMMIT
  ```

  - [ ] MyISAM に移行する(スコア落ちたり、Faile することもあるので注意)

  ```sql
  # MyISAMに移行する
  CREATE TABLE `registrations`
  (
      `course_id` CHAR(26),
      `user_id`   CHAR(26),
      PRIMARY KEY (`course_id`, `user_id`),
      CONSTRAINT FK_registrations_course_id FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`),
      CONSTRAINT FK_registrations_user_id FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
  )ENGINE=MyISAM;
  ...

  CREATE TABLE `submissions`
  (
      `user_id`   CHAR(26)     NOT NULL,
      `class_id`  CHAR(26)     NOT NULL,
      `file_name` VARCHAR(255) NOT NULL,
      `score`     TINYINT UNSIGNED,
      PRIMARY KEY (`user_id`, `class_id`),
      CONSTRAINT FK_submissions_user_id FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
      CONSTRAINT FK_submissions_class_id FOREIGN KEY (`class_id`) REFERENCES `classes` (`id`)
  )ENGINE=MyISAM;

  ...

  CREATE TABLE `unread_announcements`
  (
      `announcement_id` CHAR(26)   NOT NULL,
      `user_id`         CHAR(26)   NOT NULL,
      `is_deleted`      TINYINT(1) NOT NULL DEFAULT false,
      PRIMARY KEY (`announcement_id`, `user_id`),
      CONSTRAINT FK_unread_announcements_announcement_id FOREIGN KEY (`announcement_id`) REFERENCES `announcements` (`id`),
      CONSTRAINT FK_unread_announcements_user_id FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
  )ENGINE=MyISAM;
  ```

- [ ] INSERT

  - [ ] BULK INSERT

  ```go
  log.Printf("Target : %v", targets)

  //BULK INSERT
  query2 := "INSERT INTO `unread_announcements` (`announcement_id`, `user_id`) VALUES "

  var values []string
  if (len(targets) > 0) {
  	for _, user := range targets {
  		value := fmt.Sprintf(
  			"('%s','%s')", // 文字列は '' で囲む必要あり！
  			req.ID,
  			user.ID,
  		)
  		values = append(values, value)
  		log.Printf("Values : %v", values)
  	}
  	query2 += strings.Join(values, ", ")
  	log.Printf("Query2: %s", query2)

  	if _, err := tx.Exec(query2); err != nil {
  		log.Printf("Error: %s", err)
  		c.Logger().Error(err)
  		return c.NoContent(http.StatusInternalServerError)
  	}
  }
  ```

  ```go
  var rows []IsuCondition
  for _, cond := range req {
  	timestamp := time.Unix(cond.Timestamp, 0)
  	// key := fmt.Sprintf("jia_isu_uuid.%v.condition", jiaIsuUUID)
  	// _ = mc.Delete(key)

  	if !isValidConditionFormat(cond.Condition) {
  		return c.String(http.StatusBadRequest, "bad request body")
  	}

  	cLevel, err := calculateConditionLevel(cond.Condition)
  	if err != nil {
  		return c.String(http.StatusBadRequest, "bad request body")
  	}
  	// value := fmt.Sprintf(
  	// 	"('%v','%v', '%v', '%v', '%v')", // 文字列は '' で囲む必要あり！
  	// 	jiaIsuUUID,
  	// 	timestamp,
  	// 	cond.IsSitting,
  	// 	cond.Condition,
  	// 	cond.Message,
  	// )
  	//alues = append(values, value)
  	rows = append(rows, IsuCondition{
  		JIAIsuUUID: jiaIsuUUID,
  		Timestamp:  timestamp,
  		IsSitting:  cond.IsSitting,
  		Condition:  cond.Condition,
  		Level:      cLevel,
  		Message:    cond.Message,
  	})

  	// _, err = tx.Exec(
  	// 	"INSERT INTO `isu_condition`"+
  	// 		"	(`jia_isu_uuid`, `timestamp`, `is_sitting`, `condition`, `message`)"+
  	// 		"	VALUES (?, ?, ?, ?, ?)",
  	// 	jiaIsuUUID, timestamp, cond.IsSitting, cond.Condition, cond.Message)
  	// if err != nil {
  	// 	c.Logger().Errorf("db error: %v", err)
  	// 	return c.NoContent(http.StatusInternalServerError)
  	// }

  }
  // query := "INSERT INTO `isu_condition` (`jia_isu_uuid`, `timestamp`, `is_sitting`, `condition`, `message`) VALUES "
  // query += strings.Join(values, ", ")
  // log.Printf("Query: %s", query)
  //_, err = tx.Exec(query)
  _, err = tx.NamedExec( //ここでBULK INSERT
  	"INSERT INTO `isu_condition`"+
  		"	(`jia_isu_uuid`, `timestamp`, `is_sitting`, `condition`, `message`, `level`)"+
  		"	VALUES (:jia_isu_uuid, :timestamp, :is_sitting, :condition, :message, :level)",
  	rows)
  if err != nil {
  	c.Logger().Errorf("db error: %v", err)
  	return c.NoContent(http.StatusInternalServerError)
  }
  if err != nil {
  	c.Logger().Errorf("db error: %v", err)
  	return c.NoContent(http.StatusInternalServerError)
  }
  ```

- [ ] Select

  - [ ] Limit をつけて、検索行数を減らす

  ```sql
  # Query 1: 182.30 QPS, 0.80x concurrency, ID 0x931A992E852C61FC6D46141A39DEF4FE at byte 113530944
  # Scores: V/M = 0.01
  # Time range: 2022-07-17 12:09:00 to 12:10:01
  # Attribute    pct   total     min     max     avg     95%  stddev  median
  # ============ === ======= ======= ======= ======= ======= ======= =======
  # Count          2   11120
  # Exec time     33     49s     9us    90ms     4ms    16ms     6ms     2ms
  # Lock time     15   522ms       0    17ms    46us    35us   438us    10us
  # Rows sent     62   3.19M       0   1.56k  300.75   1.09k  369.54   97.36　★検索行数が多い！！！
  # Rows examine  62   3.18M       0   1.56k  300.28   1.09k  369.84   97.36
  # Rows affecte   0       0       0       0       0       0       0       0
  # Bytes sent    37 496.80M     589 255.29k  45.75k 174.27k  56.05k  15.20k
  # Query size     3   1.22M     115     115     115     115       0     115
  # Boolean:
  # QC hit         1% yes,  98% no
  # String:
  # Databases    isucondition
  # Hosts        localhost
  # Users        isucon
  # Query_time distribution
  #   1us  #
  #  10us  ###
  # 100us  ###################################################
  #   1ms  ################################################################
  #  10ms  ###################
  # 100ms
  #    1s
  #  10s+
  # Tables
  #    SHOW TABLE STATUS FROM `isucondition` LIKE 'isu_condition'\G
  #    SHOW CREATE TABLE `isucondition`.`isu_condition`\G
  # EXPLAIN /*!50100 PARTITIONS*/
  SELECT * FROM `isu_condition` WHERE `jia_isu_uuid` = 'ac0b1b54-ce84-4901-b11f-3e1a24271ac9' ORDER BY timestamp DESC\G
  ```

  ```go
  // Limitにより検索行数を減らす
  err = tx.Get(&lastCondition, "SELECT * FROM `isu_condition` WHERE `jia_isu_uuid` = ? ORDER BY `timestamp` DESC LIMIT 1",
    isu.JIAIsuUUID)
  if err != nil {
    if errors.Is(err, sql.ErrNoRows) {
      foundLastCondition = false
    } else {
      c.Logger().Errorf("db error: %v", err)
      return c.NoContent(http.StatusInternalServerError)
    }
  }

  ```

#### INDEX

- [ ] OrderBy のソート(昇順/降順注意)
  ```sql
  # 以下のようにWhereとOrderで検索している場合、複合Indexを貼る
  SELECT * FROM `isu_condition` WHERE `jia_isu_uuid` = '4c86e8eb-0820-4216-a4b3-2e55b182b73e' ORDER BY `timestamp` DESC LIMIT 1\G
  ```
  ```
  # 昇順(ASC)/降順(DESC)に注意
  ALTER TABLE `isu_condition` ADD INDEX time_idx(`jia_isu_uuid` DESC, `timestamp` DESC);
  ```

## Memcache

```go
import (
	"encoding/json"
  ...
	"github.com/bradfitz/gomemcache/memcache"
)

//memcacheのインスタンス
var mc *memcache.Client

func main() {
...
  //接続先の指定
	mc = memcache.New("127.0.0.1:11211")


// 	///////////////////////
// 	// ここからキャッシュコード
// 	////////////////////////
	key := fmt.Sprintf("jia_isu_uuid.%v.condition", jiaIsuUUID)
	log.Printf("Jia_isu_uuid: %v", key)
	val, err := mc.Get(key)

	if err == memcache.ErrCacheMiss {
		if startTime.IsZero() {
			err = db.Select(&conditions,
				"SELECT * FROM `isu_condition` WHERE `jia_isu_uuid` = ?"+
					"	AND `timestamp` < ?"+
					"	ORDER BY `timestamp` DESC",
				jiaIsuUUID, endTime,
			)
		} else {
			err = db.Select(&conditions,
				"SELECT * FROM `isu_condition` WHERE `jia_isu_uuid` = ?"+
					"	AND `timestamp` < ?"+
					"	AND ? <= `timestamp`"+
					"	ORDER BY `timestamp` DESC",
				jiaIsuUUID, endTime, startTime,
			)
		}
		if err != nil {
			return nil, fmt.Errorf("db error: %v", err)
		}
		byte, _ := json.Marshal(conditions)
		err = mc.Set(&memcache.Item{Key:key, Value: byte, Expiration: 3})
	} else {
		_ = json.Unmarshal(val.Value, &conditions)
		log.Printf("Cache ConditionValue: %v", conditions)
	}

// 	///////////////////////
// 	// ここまで
// 	////////////////////////
```

```go
	var announcement AnnouncementDetail
	var unread bool

	// Cache利用
	key := fmt.Sprintf("announcements.%v.detail", announcementID)
	log.Printf("AnnuncementDetailKey: %v", key)
	val, err := mc.Get(key)
	//val = []byte(val.Value)
	if err != nil && err != memcache.ErrCacheMiss {
		return c.NoContent(http.StatusInternalServerError)
	}

	query := "SELECT `announcements`.`id`, `courses`.`id` AS `course_id`, `courses`.`name` AS `course_name`, `announcements`.`title`, `announcements`.`message`, NOT `unread_announcements`.`is_deleted` AS `unread`" +
		" FROM `announcements`" +
		" JOIN `courses` ON `courses`.`id` = `announcements`.`course_id`" +
		" JOIN `unread_announcements` ON `unread_announcements`.`announcement_id` = `announcements`.`id`" +
		" WHERE `announcements`.`id` = ?" +
		" AND `unread_announcements`.`user_id` = ?"

	if err == memcache.ErrCacheMiss {
		if err := tx.Get(&announcement, query, announcementID, userID); err != nil && err != sql.ErrNoRows {
			c.Logger().Error(err)
			return c.NoContent(http.StatusInternalServerError)
		} else if err == sql.ErrNoRows {
			return c.String(http.StatusNotFound, "No such announcement.")
		}
		byte, _ := json.Marshal(announcement)
		err = mc.Set(&memcache.Item{Key:key, Value: byte})
	} else {
		query = "SELECT NOT `unread_announcements`.`is_deleted` AS `unread`" +
			" FROM `unread_announcements`" +
			" WHERE `unread_announcements`.`announcement_id` = ?" +
			" AND `unread_announcements`.`user_id` = ?"
		if err := tx.Get(&unread, query, announcementID, userID); err != nil && err != sql.ErrNoRows {
			log.Printf("ERROR: %v", err)
			c.Logger().Error(err)
			return c.NoContent(http.StatusInternalServerError)
		}
		_ = json.Unmarshal(val.Value, &announcement)
		announcement.Unread = unread
		log.Printf("Cache AnnuncementDetailValue: %v", announcement)
	}
	var registrationCount int
	if err := tx.Get(&registrationCount, "SELECT COUNT(*) FROM `registrations` WHERE `course_id` = ? AND `user_id` = ?", announcement.CourseID, userID); err != nil {
		c.Logger().Error(err)
		return c.NoContent(http.StatusInternalServerError)
	}
	if registrationCount == 0 {
		return c.String(http.StatusNotFound, "No such announcement.")
	}

	if _, err := tx.Exec("UPDATE `unread_announcements` SET `is_deleted` = true WHERE `announcement_id` = ? AND `user_id` = ?", announcementID, userID); err != nil {
		c.Logger().Error(err)
		return c.NoContent(http.StatusInternalServerError)
	}
```

- https://qiita.com/y13i/items/37e1ae7aa84fb946646a
- https://ema-hiro.hatenablog.com/entry/20170818/1502988493
- https://qiita.com/masahikoofjoyto/items/a62a1c2b6c4affca772f

## go 言語

- 文字列を Map に詰める

```go
var values []string
for _, user := range targets {
  value := fmt.Sprintf(
    "('%s','%s')", // 文字列は '' で囲む必要あり！
    req.ID,
    user.ID,
  )
  values = append(values, value)
  log.Printf("Values : %v", values)
}
```

- go のパッケージを追加したが、パッケージが見つからずにエラー

```
goのコードが入ったディレクトリで実行
$ go mod tidy
go: downloading github.com/mattn/go-sqlite3 v1.14.6
go: downloading github.com/lib/pq v1.2.0
go: downloading github.com/stretchr/testify v1.4.0
go: downloading github.com/davecgh/go-spew v1.1.0
go: downloading github.com/pmezard/go-difflib v1.0.0
go: downloading gopkg.in/yaml.v2 v2.2.2
go: finding module for package github.com/bradfitz/gomemcache/memcache
```

### DB 振り分け

- DB 用サーバの設定変更（ローカルホスト以外の接続を受け付ける）
  - /etc/mysql/mysql.conf.d の設定を変更する
  ```txt
  bind-address            = 0.0.0.0
  ```
  - mysql にログイン
  ```SQL
  su mysql -u root;
  CREATE USER `isucon`@`192.168.%` IDENTIFIED BY ‘isucon’;
  GRANT ALL PRIVILEGES ON `isucholar`.* TO `isucon`@`192.168.%`;
  ```
- APP 用サーバの設定変更
  - env.sh の書き換え
  ```shell
  MYSQL_HOST=“192.168.7.243”
  ```
  - APP サーバから DB サーバへの疎通確認。ログインできれば成功
  ```txt
  make coonect-mysql
  ```
  - db.go の書き換え
  ```go
  mysqlConfig.Addr = GetEnv(“MYSQL_HOSTNAME”, “192.168.7.243”) + “:” + GetEnv(“MYSQL_PORT”, “3306")
  ```
- AWS インスタンスの設定変更
  - インバウンドルールを編集
  ```txt
  IPv4 MYSQL/Aurora TCP 3306 {AWSのAPPサーバのIPアドレス}
  ```

### サーバ複数台活用

- sites-available/isucondition.conf に以下の設定を追加
  ```txt
  location / {
        proxy_cache proxy1;
        proxy_set_header Host $http_host;
        proxy_pass http://webapps;
    }
    location @app {
        proxy_pass http://webapps;
    }
  ```
-

### 静的ファイルをリバースプロキシから直接配信

- sites-available/isucondition.conf に以下の設定を追加
  ```txt
  location ~ .*\.(htm|html|css|js|jpg|png|gif|ico) {
      expires 24h;
      add_header Cache-Control public;
      gzip on;  # cpu 使うのでメリット・デメリット見極める必要あり。gzip_static 使えるなら事前にgzip圧縮した上でそちらを使う。
      gzip_types text/css application/javascript application/json application/font-woff application/font-tff image/gif image/png image/jpeg image/svg+xml image/x-icon application/octet-stream;
      gzip_disable “msie6”;
      gzip_static on;  # nginx configure時に --with-http_gzip_static_module 必要
      gzip_vary on;
  }
  ```
- nginx/nginx.conf に以下の設定を追加
  ```txt
  upstream webapps {
        least_conn;
        server 192.168.0.11:3000;
        server 192.168.0.12:3000;
  }
  ```

### Nginx の基本設定

- sites-available/isucondition.conf に以下の設定を追加
  ```txt
  open_file_cache max=1000 inactive=60s;
  open_file_cache_valid 60s;
  open_file_cache_errors on;
  sendfile on;
  ```
- nginx/nginx.conf に以下の設定を追加
  ```txt
    ルート
    worker_rlimit_nofile 200000; #cat /proc/sys/fs/file-max % worker_processesよりも小さい数字を設定
  ```
  ```txt
    events配下
    worker_connections  4096;
    multi_accept on;
  ```
  ```txt
    httpディレクティブ配下
    # 基本設定
    sendfile        on;
    tcp_nopush     on;
    tcp_nodelay on;
    types_hash_max_size 2048;
    server_tokens    off;
    # keep-aliveの設定
    keepalive_requests 500;
    keepalive_timeout  65;
    # Gzipの設定
    gzip on;
    gzip_types text/css text/javascript application/javascript application/x-javascript application/json;
    gzip_min_length 1k;
    gzip_static on;
    gzip_comp_level 1;
  ```

### カーネルパラメータ

- /etc/sysctl.conf に以下を追加
  ```txt
  net.core.somaxconn = 10000  # <- 追加。32768 (2^15) くらいまで大きくしても良いかも。
  net.ipv4.ip_local_port_range = 10000    60999  # port の範囲を広げる
  net.ipv4.tcp_tw_reuse = 1
  ```
  ```txt
  上記の設定を反映
  sudo sysctl -p
  その他の設定は以下を参照
  https://gist.github.com/south37/d4a5a8158f49e067237c17d13ecab12a
  ```


### Indexの貼り方
- [ ] mysqlへのログイン
```
mysql -u isucon -p
```
- [ ] mysqlのDB選択
```
use DB名
```
- [ ] indexの確認
```
show index from テーブル名;
```
- [ ] explainでの確認項目
  - key: 実際に使用されているインデックス
  - rows: そのテーブルから参照される行数の大まかな見積もり。
  - type: レコードへのアクセス方法
  - https://free-engineer.life/mysql-explain/
- [ ] テーブル定義変更(インデックス追加)
```
ALTER TABLE visit_history ADD INDEX idx_all_cover
  (tenant_id, competition_id, player_id, created_at);
```
- [ ] テーブル定義変更(インデックス削除)
```
ALTER TABLE db_01.USER_DATA DROP INDEX index01;
```
- [ ] テーブル作成時に作成(複合)
```
create table staff(joiny int, id int, name varchar(10), index joiny_id_index (joiny, id));
```
- [ ] 方針確認
  - 「Where句とOrder byで指定されているカラムにindex貼る。絞りがあるところも複合インデックスに含める」
  - 複合indexを作ることになるので評価順序を気にする。Whereで使われている句→ORDER BYで使われている句の順番でindexを作るなど。先頭で絞り込みできるほどいいので、等価条件で利用されたりカーディナリティが高かったりするカラムを複合インデックスの先頭にする。（カーディナリティが高いとは、テーブルのレコードに対してデータの種類が多いことを表します。）
  -   https://qiita.com/ichi_zamurai/items/a8e5e4a37faecf9cd77a
  https://nishinatoshiharu.com/overview-multicolumn-indexes/

## 参考情報

- [ ] ISUCON 過去問
  - [ ] [ISUCON7 予選でやったインフラのお仕事](https://qiita.com/ihsiek/items/11106ce7a13e09b61547)
  - [ ] [ISUCON11 実践解説](https://isucon.net/archives/56082639.html)
- [ ] Nginx
  - [ ] [NGINX の設定](https://gist.github.com/south37/d4a5a8158f49e067237c17d13ecab12a)
  - [ ] [ALP の見方](https://muttan1203.hatenablog.com/entry/how_to_setup_alp)
- [ ] MySQL
  - [ ] [MySQL クエリキャッシュ値設定と確認方法](https://qiita.com/tukiyo3/items/797f9916e6494ec33991)
  - [ ] [MySQL スロークエリ改善 初心者向け](https://zenn.dev/ohkisuguru/articles/48dff6cf195244)
  - [ ] [DB 分割](https://github.com/Nagarei/isucon11-qualify-test/commit/207ace7d999b0216b5626c248ac87efb22cbd47e)
- [ ] sql
  - [ ] [go における IN 句](https://igatea.hatenablog.com/entry/2020/12/22/200000)
  - [ ] [go における IN 句](https://github.com/Nagarei/isucon11-qualify-test/commit/a553313dea8d43abb241bf5c570ea96c723ba9c9)
  - [ ] [BULK INSERT](https://github.com/Nagarei/isucon11-qualify-test/commit/324ad3eeac56d545cca192c6e18567cf2b5e231a)
- [ ] app
  - [ ] [Debug ログを止める](https://github.com/Nagarei/isucon11-qualify-test/commit/d5b1378dbe1d5be4dd349e5a312b803307928a5c)
- [ ] os
  - [ ] [カーネルパラメータのパフォーマンスチューニング](https://ac-as.net/kernel-parameter-performance-tuning/)
