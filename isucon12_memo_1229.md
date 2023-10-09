# 2022-12-29

## ハマりどころメモ

### SLOW ログの設定

- my.cnf で設定しても有効化されない
  - DB に接続し、以下のコマンドで確認できる

```
mysql> show variables like 'slow%';
+---------------------+----------------------------------------+
| Variable_name       | Value                                  |
+---------------------+----------------------------------------+
| slow_launch_time    | 2                                      |
| slow_query_log      | OFF                                    |
| slow_query_log_file | /home/iscuon/logs/mysql/mysql-slow.sql |
+---------------------+----------------------------------------+
3 rows in set (0.01 sec)

```

- slow_query_log_file が/var/lib/mysql 以下でないと、有効化できない

```
slow_query_log = 1
slow_query_log_file	= /var/lib/mysql/hoge-slow.log ※要注意
long_query_time = 0
```

### root ユーザーによる mysql 接続

- query-digester は root ユーザーで接続するので、root ユーザーのパスワードを my.cnf で無効化する

```
[mysqld]
skip-grant-tables ※追加
```

- 上記の設定だと、ベンチマークがこける事象が発生した。。mysql は root/root が設定されていた。query-digester だと以下のように設定
  ```
  sudo query-digester -duration 90 -- -uroot -proot &
  ```
