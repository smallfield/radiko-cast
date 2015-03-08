# radiko-cast
Radikoにて指定した番組を録音し、Podcast化して配信するWebアプリ。

# 動作要件

下記が必要です。
- Ruby(v2.0.0以上)
  - Bundler
- crontab
- 何らかのWebサーバ(Apache, Nginxなど)
- rtmpdump(v2.4以上)
- swfextract
- ffmpeg
- wget


# 導入方法
まずファイルの配置と必須Gemのインストールを行います。
```
$ git clone https://github.com/smallfield/radiko-cast.git ~/radiko-cast
$ cd ~/radiko-cast
$ bundle install
```
しかるのちに、 conf.yml.sample を conf.yml にリネームした上で、設定を記述して下さい。（設定の内容については、サンプルのコメントを参照して下さい。）

設定後、下記コマンドを実行することで、録音cronの設定及び、配信用の静的ファイル生成を行います。
```
$ cd ~/radiko-cast
$ ruby RadikoCast.rb     # cron設定ファイルの置き場によっては、root権限が必要
```
設置したパスの public をWebから参照できるように、Webサーバを設定して下さい。
Apacheの例
```
# httpd.conf 
<VirtualHost *:80>
    DocumentRoot /home/hoge/www/nicoanime/public
    ServerName radicast.example.jp
</VirtualHost>
```
公開したWebサイトにアクセスすることで、Podcastの購読設定が出来ます。

# 謝辞
録音処理については、matchy2 様のシェルスクリプトを拝借しました。
https://gist.github.com/matchy2/3956266
