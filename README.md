# 絶賛開発中です

## 開発メモ

- cloudforecastのおきかえ
- 少し良いハードの上で、1000台~3000台ぐらいのホストに対して1分更新を実現する
- インストールが面倒なのでSNMP.pmに依存しない
- agentからのpushと、monitoringサーバからのpullの両方をつかうハイブリッド構成
- rrdtoolを使うところは変わらない。大量にグラフを表示したいのでjsだとたぶんきつい
- SQLiteで頑張らない。Redisを使って付属情報を保存

## しくみ

### workerは4種類

1. agentからのmetricsを受け取って、rrdとRedisをアップデートするjob worker
2. metricsをpullして、rrdとmysqlをアップデートするjob worker
3. 1分毎に起動して2にキューを投げるwoker
4. web画面

## Redis

Redisをキュー/付属情報DBとして使う

### Redisのインストール

CenOS6 だとEPEL/Remiを有効にして `yum install redis` 

```
$ sudo yum install http://ftp.jaist.ac.jp/pub/Linux/Fedora/epel/6/i386/epel-release-6-8.noarch.rpm
$ sudo yum install http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
$ sudo yum --enablerepo=remi,epel install redis
$ service redis start
$ chkconfig redis on
```

# Agent

perlで書いてある。依存関係が含まれた1つのファイルとなっているのでコピーすれば動く

```
$ wget https://raw.githubusercontent.com/kazeburo/Kurado/master/agent_fatpack/kurado_agent
$ chmod +x kurado_agent
$ ./kurado_agent --help
```

rpmもある

```
$ sudo yum install https://s3-ap-northeast-1.amazonaws.com/kurado-agent/RPMS/noarch/kurado_agent-latest.noarch.rpm
$ sudo service kurado_agent start
```

metricsを表示して終了する

```
$ kurado_agent --dump
```

1分毎にサーバにmetricsを送る

```
$ kurado_agent --interval 1 --self-ip ip.address.of.myself --mq 127.0.0.1:1887 --conf-d /etc/kurado_agent/conf.d
```


### オプション

- --conf-d

    拡張metricsの設定があるディレクトリ。設定ファイルは *.toml となる

- --interval

    metricsを送信する間隔(分)。デフォルトは1(分)

- --mq

    Redisの IPアドレス:ポート

- --self-ip

    サーバのIPアドレス(なければredisへの接続元のIPアドレスを使う)

- --pidfile

    pidファイルのパス

- --max-delay

    metricsを遅延する最大秒数(秒)。"0"秒に負荷が集中するのを低減する。デフォルトは0(なし)

 - --dump

    現在のmetricsを表示して終了

### 標準のmetrics

サンプル。標準で

- cpu
- disk io
- disk usage
- load average
- memory
- tcp established

などを取っている

tab切りで、`ip[TAB]key[TAB]value[TAB]timestamp` 形式。

サンプルはIPを省略している

```
base.metrics.cpu-guest-nice.derive	0	1404873350
base.metrics.cpu-guest.derive	0	1404873350
base.metrics.cpu-idle.derive	5689557	1404873350
base.metrics.cpu-iowait.derive	998	1404873350
base.metrics.cpu-irq.derive	894	1404873350
base.metrics.cpu-nice.derive	1	1404873350
base.metrics.cpu-softirq.derive	899	1404873350
base.metrics.cpu-steal.derive	0	1404873350
base.metrics.cpu-system.derive	13462	1404873350
base.metrics.cpu-user.derive	44682	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_root-read-ios.derive	38124	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_root-read-sectors.derive	1013426	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_root-write-ios.derive	311834	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_root-write-sectors.device	2462360	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_swap-read-ios.derive	409	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_swap-read-sectors.derive	3272	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_swap-write-ios.derive	630	1404873350
base.metrics.disk-io-mapper_VolGroup-lv_swap-write-sectors.device	5040	1404873350
base.metrics.disk-io-sda-read-ios.derive	24676	1404873350
base.metrics.disk-io-sda-read-sectors.derive	1023692	1404873350
base.metrics.disk-io-sda-write-ios.derive	43704	1404873350
base.metrics.disk-io-sda-write-sectors.device	2467476	1404873350
base.metrics.disk-usage-mapper_VolGroup-lv_root-available.gauge	36329940	1404873350
base.metrics.disk-usage-mapper_VolGroup-lv_root-used.gauge	1487404	1404873350
base.metrics.loadavg-1.gauge	0.00	1404873350
base.metrics.loadavg-15.gauge	0.00	1404873350
base.metrics.loadavg-5.gauge	0.00	1404873350
base.metrics.memory-buffers.gauge	41582592	1404873350
base.metrics.memory-cached.gauge	218800128	1404873350
base.metrics.memory-free.gauge	68136960	1404873350
base.metrics.memory-inactive.gauge	143220736	1404873350
base.metrics.memory-swap-free.gauge	970604544	1404873350
base.metrics.memory-swap-total.gauge	973070336	1404873350
base.metrics.memory-swap-used.gauge	2465792	1404873350
base.metrics.memory-total.gauge	480718848	1404873350
base.metrics.memory-used.gauge	269361152	1404873350
base.metrics.processors.gauge	1	1404873350
base.metrics.tcp-established.gauge	3	1404873350
base.metrics.traffic-eth0-rxbytes.derive	146026292	1404873350
base.metrics.traffic-eth0-txbytes.derive	4955348	1404873350
base.meta.disk-io-devices	mapper_VolGroup-lv_root,mapper_VolGroup-lv_swap,sda	1404873350
base.meta.disk-usage-devices	mapper_VolGroup-lv_root	1404873350
base.meta.disk-usage-mapper_VolGroup-lv_root-mount	/	1404873350
base.meta.traffic-interfaces	eth0	1404873350
base.meta.uptime	57649	1404873350
base.meta.version	Linux version 2.6.32-431.el6.x86_64 (mockbuild@c6b8.bsys.dev.centos.org) (gcc version 4.4.7 20120313 (Red Hat 4.4.7-4) (GCC) ) #1 SMP Fri Nov 22 03:15:09 UTC 2013	1404873350
```

### 拡張metrics(plugin)

`--conf-d` で指定するディレクトリに TOML でplugin設定を書く
 
 sample.toml
 
 ```
[plugin.metrics.process]
command = "echo -e \"fork.derive\t\"$(cat /proc/stat |grep processes | awk '{print $2}')\"\t\"$(date +%s)"
```

pluginは

```
[plugin.metrics.${plugin_name}
```

として設定する。ドットの数は2つである必要がある

pluginから以下の形式で出力する

- metrics

   `metrics.${name1}[.${name2}[.{gauge,counter,derive,absolute}]]\t${value}\t${timestamp}`

- meta
   `meta.${name1}[.${name2}\t${text}`

keyの最初がmetricsやmetaではない場合、"metrics"が追加される。<br />
keyの最後が .{gauge,..} 等でなかった場合は、gaugeが使われる。<br />
metaはmetricsの付属情報としてDBに保存される。サーバ情報などに使われる。

上のprocess pluginの出力は

```
process.metrics.fork.derive     39234   1404871619
```

となる

# サーバ側セットアップ

このrepositoryをcloneして、`cpanm --installdeps .` して

```
$ perl bin/kurado_worker -c config.yml
```


# サーバ設定

sample_kurado.ymlを参照

cloudforecastとだいたい同じ


# 設定のテスト

```
$ perl bin/kurado_config -c config.yml
```

で設定のテストができる

#Kurado plugin protocol

## API

metricsを取得する系 metrics fetcher

- fetcher本体

metricsを表示する系

- グラフのリスト + meta情報の表示
- graph definition

## pluginに渡されるデータ

- metrics_config
- address hostname comments
- plugin arguments
- metrics meta (サーバ情報)

これらはコマンドの引数として渡される

## pluginのディレクトリ

`metrics_plugins/view` ディレクトリと `metrics_plugin/fetch`の2つにわけて格納されている。設定ファイルでディレクトリを追加できる

## Protocol

- $Kurado::Plugin::BRIDGE{'kurodo.metrics_config'}
- $ENV{'kurodo.metrics_config_json'} 今のところやらない。perlじゃない場合に使う。execするとps eで漏れるのでbase64ぐらいするかな
- $Kurado::Plugin::BRIDGE{'kurodo.metrics_meta'}
- $ENV{'kurodo.metrics_meta_json'} 今のところやらない。perlじゃない場合に使う。execするとps eで漏れるのでbase64ぐらいするかな
- コマンド引数に
  - --address => $address
  - --hostsname => $hostname
  - --comments => $comment あれば
  - --plugin-arguments => roll_configのmetricsの:以降のやつ。あれば複数個。なければない
  - --graph => graph, metrics-graph apiの時だけ

実行例

```
./view/nginx.pl --address 127.0.0.1 --hostname example.com --plugin-argument 80 -plugin-argument /nginx_status
```

## API

### metrics-fetcher

metricsを取得して、kurodo_agentのpluginが返すとの同じフォーマットで返す。

### metrics-list

metricsのリストとグラフ付随情報

```
#Nginx (80)[TAB]server[TAB]nginx[TAB]key[TAB]value
processes
reqs
```

「#」の行がグラフグループのタイトル。1つのプラグインで複数のグループをもてる。タイトルのところには、TAB区切りで情報が追加できます。<br />
情報のvalue部分の最初を「>||」にすると、HTMLが書けます
「#」が付かない行がグラフのキー

### metrics-graph

RRDtoolのグラフ定義を返す<br />
1行目はグラフの縦軸のラベル(必須)

```
TCP Established
DEF:n=<%RRD_FOR tcp-established.gauge %>:n:AVERAGE
AREA:n#00C000:Established
GPRINT:n:LAST:Cur\:%6.0lf
GPRINT:n:AVERAGE:Ave\:%6.0lf
GPRINT:n:MAX:Max\:%6.0lf
GPRINT:n:MIN:Min\:%6.0lf\l
```

テンプレート的に以下が使える

- `<%RRD_FOR ${metrics_key}.{gauge,counter,derive,absolute} %>` plugin,ipは自動補完。rrdファイルへのpath
- `<%RRD_EX ${plugin} ${ip} ${metrics_key}.{gauge,counter,derive,absolute} %>` 他のplugin,ipのrrdファイルへのpath


## pluginサンプル

Kurado::Pluginモジュールをつかうとテンプレートや引数の処理を自動でやってくれて、便利です　

### fetcherサンプル

mysqlの任意のテーブルをcountするやつ

```
#!/usr/bin/perluse strict;use warnings;use FindBin;use lib "$FindBin::Bin/../../lib";use Kurado::Plugin;use DBI;our $VERSION = '0.01';my $plugin = Kurado::Plugin->new(@ARGV);my $host = $plugin->address;my ($port,$db, $table) = @{$plugin->plugin_arguments};$port ||= 3306;die "db or table are not defined, simplecountsql:port:db:table" if  !$db || !$table;my $user = $plugin->metrics_config->{MySQL}->{user} || 'root';my $password = $plugin->metrics_config->{MySQL}->{password} || '';my $dsn = "DBI:mysql:$db;hostname=$host;port=$port";my $dbh = eval {    DBI->connect(        $dsn,        $user,        $password,        {            RaiseError => 1,        }    );};die "connection failed to " . $dsn .": $@" if $@;my $row = $dbh->selectrow_arrayref('SELECT COUNT(*) FROM '.$table);die "failed to fetch count of jobs" unless $row;my $time = time;print "metrics.count.gauge\t$row->[0]\t$time\n";```

### viewer サンプル

```
#!/usr/bin/perluse strict;use warnings;use FindBin;use lib "$FindBin::Bin/../../lib";use Kurado::Plugin;our $VERSION = '0.01';my $plugin = Kurado::Plugin->new(@ARGV);sub metrics_list {    my $plugin = shift;    my ($port,$db,$table) = @{$plugin->plugin_arguments};    $port ||= 3306;    die "db or table are not defined, simplecountsql:port:db:table" if !$db || !$table;    my $list = sprintf '#Count by SQL (table=%s,db=%s,port=%s)'."\n", $table, $db, $port;    $list .= "count\n";    print $list;}sub metrics_graph {    my $plugin = shift;    my $graph = $plugin->graph;    my $def = '';    $def = $plugin->render($graph);    print "$def\n";}if ($plugin->graph ) {    metrics_graph($plugin);}else {    metrics_list($plugin);}__DATA__@@ countCOUNT(*)DEF:my1=<%RRD count.gauge %>:queue:AVERAGELINE:my1#00C000:CountGPRINT:my1:LAST:Cur\: %6.0lfGPRINT:my1:AVERAGE:Ave\: %6.0lfGPRINT:my1:MAX:Max\: %6.0lf\l```


## rrdファイルのディレクトリ構成

~/data/${ip}/$plugin/${metrics_key}.{gauge,counter,derive,absolute}.rrd

## rrdファイルの定義


    #RRA:CFタイプ:xff:steps:rows
    # xff Unknownの率
    # steps 集約するステップ数
    # rows保存する数
    my @param = (
        '--start', $timestamp - 10,
        '--step', '60',
        "DS:n:${dst}:120:U:U",
        'RRA:AVERAGE:0.5:1:2880',    #1分   1分    2日 2*24*60/(1*1) daily用
        'RRA:AVERAGE:0.5:5:2880',   #5分   5分    10日 10*24*60/(5*1) weekly用
        'RRA:AVERAGE:0.5:60:960',   #1時間  60分  40日 40*24*60/(60*1) monthly用
        'RRA:AVERAGE:0.5:1440:1100', #24時間 1440分 1100日
        'RRA:MIN:0.5:1:2880', 
        'RRA:MIN:0.5:5:2880',
        'RRA:MIN:0.5:60:960',
        'RRA:MIN:0.5:1440:1100',
        'RRA:MAX:0.5:1:2880', 
        'RRA:MAX:0.5:5:2880',
        'RRA:MAX:0.5:60:960',
        'RRA:MAX:0.5:1440:1100',
    );

だいたいこれで 190KB ぐらい

## 設計メモ

- pluginは起動時に読み込まれる
- __DATA__は使いたい
- sub {apiname} { .. } をいくつか書くでいいかな
-- 単体でのテストしにくい => test用のscriptをつくる
- CGIなプロトコルにするのはどうか？
-- perl以外の言語でpluginが書ける。でも必要ないよねぇ

- 必要なapiは
-- is_passive
-- fetcher本体
-- グラフのリスト + meta情報の表示
-- graph definition

- テストツールの機能
-- fetcherの有無を返す(is_passive)
-- metricsをfetchして結果を表示
-- webサーバを起動して、グラフのサンプル表示

- pluginを2つに分けるのはどうか
-- is_passiveのかわりにfetchを消す
-- 先にfetchだけつくって、あとからdisplayのpluginを作るとかできる
-- 既存のデータをつかって、表示だけするpluginとかもできる
-- pluginが存在してないことのエラーは？
--- fetchだけ、displayだけ両方ともあるので、両方存在しなければエラー

- plugin 2つに分けるならCGI::Compie方式でもいいのかな


