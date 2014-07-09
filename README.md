# 絶賛開発中です

## 開発メモ

- cloudforecastのおきかえ
- 少し良いハードの上で、1000台~3000台ぐらいのホストに対して1分更新を実現する
- インストールが面倒なのでSNMP.pmに依存しない
- agentからのpushと、monitoringサーバからのpullの両方をつかうハイブリッド構成
- rrdtoolを使うところは変わらない。大量にグラフを表示したいのでjsだとたぶんきつい
- SQLiteで頑張らない。MySQLを使って付属情報を保存

## しくみ

### workerは4種類

1. agentからのmetricsを受け取って、rrdとmysqlをアップデートするjob worker
2. metricsをpullして、rrdとmysqlをアップデートするjob worker
3. 1分毎に起動して2にキューを投げるwoker
4. web画面

### push


### pull

## MQTT Broker

RabbitMQとMosquittoが使える

http://mosquitto.org/

http://www.rabbitmq.com/mqtt.html

RabbitMQを使う予定

### RabbitMQ + MQTTのインストール

http://www.rabbitmq.com/install-rpm.html

CenOS6 だと

1.  EPELを有効にして、`yum install erlang`
2.  http://www.rabbitmq.com/install-rpm.html から最新版のURLをみて、`rpm -ivh` or `yum install`

```
$ rabbitmq-plugins enable rabbitmq_mqtt
$ service rabbitmq-server start
$ chkconfig rabbitmq-server on
```

# Agent

perlで書いてある。依存関係が含まれた1つのファイルとなっているのでコピーすれば動く

```
$ wget https://raw.githubusercontent.com/kazeburo/Kurado/master/agent_fatpack/kurado_agent
$ chmod +x kurado_agent
$ ./kurado_agent --help
```

metricsを表示して終了する

```
$ kurado_agent --dump
```

1分毎にサーバにmetricsを送る

```
$ kurado_agent --interval 1 --self ip.address.of.myself --mqtt 127.0.0.1:1887 --conf-d /etc/kurado_agent/conf.d
```


### オプション

- --self

    サーバのIPアドレス

- --conf-d

    拡張metricsの設定があるディレクトリ。設定ファイルは *.toml となる
 
 - --dump

    現在のmetricsを表示して終了

- --mqtt

    MQTT brokerサーバの IPアドレス:ポート
 
- --pidfile

    pidファイルのパス

- --interval

    metricsを送信する間隔(分)。デフォルトは1(分)

### 標準のmetrics

サンプル。標準で

- cpu
- disk io
- disk usage
- load average
- memory
- tcp established

などを取っている

tab切りで、`key[TAB]value[TAB]timestamp` 形式

```
base.metrics.cpu-guest-nice.derive      0       1404871027
base.metrics.cpu-guest.derive   0       1404871027
base.metrics.cpu-idle.derive    5458133 1404871027
base.metrics.cpu-iowait.derive  993     1404871027
base.metrics.cpu-irq.derive     864     1404871027
base.metrics.cpu-nice.derive    1       1404871027
base.metrics.cpu-softirq.derive 887     1404871027
base.metrics.cpu-steal.derive   0       1404871027
base.metrics.cpu-system.derive  13294   1404871027
base.metrics.cpu-user.derive    44508   1404871027
base.metrics.disk-io-mapper_VolGroup-lv_root-read-ios.derive    38120   1404871027
base.metrics.disk-io-mapper_VolGroup-lv_root-read-sectors.derive        1013354 1404871027
base.metrics.disk-io-mapper_VolGroup-lv_root-write-ios.derive   311479  1404871027
base.metrics.disk-io-mapper_VolGroup-lv_root-write-sectors.device       2459520 1404871027
base.metrics.disk-io-mapper_VolGroup-lv_swap-read-ios.derive    409     1404871027
base.metrics.disk-io-mapper_VolGroup-lv_swap-read-sectors.derive        3272    1404871027
base.metrics.disk-io-mapper_VolGroup-lv_swap-write-ios.derive   630     1404871027
base.metrics.disk-io-mapper_VolGroup-lv_swap-write-sectors.device       5040    1404871027
base.metrics.disk-io-sda-read-ios.derive        24672   1404871027
base.metrics.disk-io-sda-read-sectors.derive    1023620 1404871027
base.metrics.disk-io-sda-write-ios.derive       43411   1404871027
base.metrics.disk-io-sda-write-sectors.device   2464636 1404871027
base.metrics.disk-usage-mapper_VolGroup-lv_root-available.gauge 36329956        1404871027
base.metrics.disk-usage-mapper_VolGroup-lv_root-used.gauge      1487388 1404871027
base.metrics.loadavg-1.gauge    0.00    1404871027
base.metrics.loadavg-15.gauge   0.00    1404871027
base.metrics.loadavg-5.gauge    0.00    1404871027
base.metrics.memory-buffers.gauge       41160704        1404871027
base.metrics.memory-cached.gauge        218746880       1404871027
base.metrics.memory-free.gauge  68255744        1404871027
base.metrics.memory-inactive.gauge      143384576       1404871027
base.metrics.memory-swap-free.gauge     970604544       1404871027
base.metrics.memory-swap-total.gauge    973070336       1404871027
base.metrics.memory-swap-used.gauge     2465792 1404871027
base.metrics.memory-total.gauge 480718848       1404871027
base.metrics.memory-used.gauge  269078528       1404871027
base.metrics.processors.gauge   1       1404871027
base.metrics.tcp-established.gauge      3       1404871027
base.meta.disk-usage-mapper_VolGroup-lv_root-mount      /       1404871027
base.meta.uptime        55326   1404871027
base.meta.version       Linux version 2.6.32-431.el6.x86_64 (mockbuild@c6b8.bsys.dev.centos.org) (gcc version 4.4.7 20120313 (Red Hat 4.4.7-4) (GCC) ) #1 SMP Fri Nov 22 03:15:09 UTC 2013  1404871027
```

### 拡張metrics(plugin)

`--conf-d` で指定するディレクトリに TOML でplugin設定を書く
 
 sample.toml
 
 ```
[plugin.metrics.process]command = "echo -e \"fork.derive\t\"$(cat /proc/stat |grep processes | awk '{print $2}')\"\t\"$(date +%s)"```

pluginは```[plugin.metrics.${plugin_name}```として設定する。ドットの数は2つである必要がある
pluginから以下の形式で出力する- metrics   ```metrics.${name1}[.${name2}[.{gauge,counter,derive,absolute}]]\t${value}\t${timestamp}```- meta
   ```meta.${name1}[.${name2}\t${text}```keyの最初がmetricsやmetaではない場合、"metrics"が追加される。<br />keyの最後が .{gauge,..} 等でなかった場合は、gaugeが使われる。<br />metaはmetricsの付属情報としてDBに保存される。サーバ情報などに使われる。履歴は残らない

上のprocess pluginの出力は

```
process.metrics.fork.derive     39234   1404871619
```

となる

# サーバリスト設定

これから

# グラフ設定

これから

# pull設定

これから

