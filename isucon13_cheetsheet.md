<!-- omit in toc -->

# ISUCON13 CheetSheet

## 1. 必須改善

### 1.1. アプリ

- [ ] Debug ログを消す
  ```go
  /////////////////////////////////////
  // Goのデバッグログ設定をoffにする(ログレベルをErrorに)
  /////////////////////////////////////
  e.Debug = false
  e.Logger.SetLevel(log.ERROR)
  ```

### 1.2. MySQL

#### 1.2.1. my.cnf

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

### 1.3. Nginx

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

### 1.4. カーネルパラメータ

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

## 2. 定番チューニング

### 2.1. データベース関連

#### 2.1.1. ADMIN PREPARE

- [ ] SowLog

  ```
  # Profile
  # Rank Query ID                      Response time  Calls R/Call V/M   Ite
  # ==== ============================= ============== ===== ====== ===== ===
  # ....中略
  #    2 0xDA556F9115773A1A99AA0165...  18.1114  7.4% 84209 0.0002  0.00 ADMIN PREPARE
  ```

- [ ] GO アプリ改善

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

#### 2.1.2. COMMIT

- [ ] SowLog

  ```
  # Profile
  # Rank Query ID                      Response time  Calls R/Call V/M   Ite
  # ==== ============================= ============== ===== ====== ===== ===
  #    1 0xFFFCA4D67EA0A788813031B8... 213.7360 75.7% 15578 0.0137  0.02 COMMIT
  ```

- [ ] DDL を変更し、MyISAM に移行する(スコア落ちたり、Faile することもあるので注意)

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

#### 2.1.3. INSERT

- [ ] GO アプリを改修し、BULK INSERT する

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

#### 2.1.4. Select

- [ ] Limit をつけて、検索行数を減らす

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

### 2.2. Index の貼り方

- [ ] mysql へのログイン

```
mysql -u isucon -p
```

- [ ] mysql の DB 選択

```
use DB名
```

- [ ] index の確認

```
show index from テーブル名;
```

- [ ] explain での確認項目
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

  - 「Where 句と Order by で指定されているカラムに index 貼る。絞りがあるところも複合インデックスに含める」
  - 複合 index を作ることになるので評価順序を気にする。Where で使われている句 →ORDER BY で使われている句の順番で index を作るなど。先頭で絞り込みできるほどいいので、等価条件で利用されたりカーディナリティが高かったりするカラムを複合インデックスの先頭にする。（カーディナリティが高いとは、テーブルのレコードに対してデータの種類が多いことを表します。）
  - https://qiita.com/ichi_zamurai/items/a8e5e4a37faecf9cd77a
    https://nishinatoshiharu.com/overview-multicolumn-indexes/

- [ ] OrderBy のソート(昇順/降順注意)
  ```sql
  # 以下のようにWhereとOrderで検索している場合、複合Indexを貼る
  SELECT * FROM `isu_condition` WHERE `jia_isu_uuid` = '4c86e8eb-0820-4216-a4b3-2e55b182b73e' ORDER BY `timestamp` DESC LIMIT 1\G
  ```
  ```
  # 昇順(ASC)/降順(DESC)に注意
  ALTER TABLE `isu_condition` ADD INDEX time_idx(`jia_isu_uuid` DESC, `timestamp` DESC);
  ```

### 2.3. DB 振り分け

#### 2.3.1. DB の接続許可

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

#### 2.3.2. NGINX の設定変更

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

---

## 3. その他作業 Tips

### 3.1. Memcache の利用

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

### 3.2. go 言語の構文

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

### 3.3. 静的ファイルをリバースプロキシから直接配信

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

## 4. 参考情報

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
