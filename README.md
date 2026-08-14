# e54c-istoreos-imagebuilder

Radxa E54C 用の iStoreOS SD カードイメージを GitHub Actions でビルドするリポジトリ。

iStoreOS 公式配布の ImageBuilder ([fw.koolcenter.com](https://fw.koolcenter.com/iStoreOS/ib/rk3xxx/)) に、USB テザリング上流 (Android / iOS) 用のパッケージと初期設定を焼き込んだイメージを生成する。

## イメージのビルド

1. Actions タブ → `build-e54c-image` → **Run workflow** を実行する
2. 完了後、workflow run の Artifacts から `istoreos-e54c-image` をダウンロードする (retention 7 日)
3. 展開すると `istoreos-*-radxa_e54c-squashfs-*.img.gz` が得られる

## SD カードへの焼き込み

`.img.gz` を展開して microSD (8GB 以上推奨) に書き込む。

### Balena Etcher (GUI)

1. [Balena Etcher](https://etcher.balena.io/) を起動
2. 展開した `.img` を選択 → microSD を選択 → **Flash**

### macOS の dd

```sh
gunzip istoreos-*-radxa_e54c-squashfs-*.img.gz
diskutil list                      # microSD のデバイス番号 (diskN) を確認
diskutil unmountDisk /dev/diskN
sudo dd if=istoreos-*-radxa_e54c-squashfs-*.img of=/dev/rdiskN bs=4m
diskutil eject /dev/diskN
```

`of=` の指定を誤ると他のディスクを破壊するため、`diskutil list` の結果を必ず確認すること。

## 初回起動

1. microSD を挿して 12V/3A 以上の電源 (5525 DC) で起動する
2. LAN ポート (WAN 表記以外のポート) に PC を接続し、`http://192.168.50.1` にアクセスする
   (LAN は 192.168.50.1/24 で焼き込み済み。DHCP 配布レンジも自動で同サブネットになる)
3. 初期アカウントは `root` (パスワード未設定)。ログイン後すぐパスワードを設定する

### eMMC 搭載個体の注意

Rockchip の BootROM は SPI → eMMC → SD の順にブートするため、eMMC に iStoreOS がプリインストールされた個体では SD が無視されることがある。起動したシステムのバージョンが焼いたものと一致するか確認し、eMMC 側が起動する場合は [Radxa 公式手順](https://docs.radxa.com/en/e/e54c/getting-started/install-os/maskrom/erase) で eMMC を消去する (eMMC の内容は失われる)。

## 上流の使い方

いずれか 1 つを接続して使う (複数同時は想定しない)。

### 有線 WAN (モバイルルーター等の RJ45)

WAN ポートに LAN ケーブルを挿すだけ。iStoreOS 既定の DHCP クライアントで動作する。

### Android USB テザリング

1. スマートフォンを USB Type-A ポートに接続する
2. スマートフォン側で「USB テザリング」を有効にする
3. `usb0` (焼き込み済みの `wan_usb` インターフェース) が DHCP で上流を取得する

### iOS USB テザリング

1. iPhone 側で「インターネット共有」を有効にして USB 接続する
2. iPhone のロックを解除し「このコンピュータを信頼」を承認する
3. `eth1` (焼き込み済みの `wan_ios` インターフェース) が DHCP で上流を取得する

繋がらないときは SSH で `ip link` を実行し、ipheth のインターフェース名が `eth1` 以外になっていないか確認する。テザリングは繋がるのに LAN 側から通信できない場合は `uci show firewall | grep -E 'wan_usb|wan_ios'` で wan ゾーンに入っているか確認する。ロック 1 時間後の切断を避けるには iOS の設定 → Face ID とパスコード →「USB アクセサリ」を許可する。

## カスタマイズ

- 同梱パッケージ: `packages.txt` (1 行 1 パッケージ、`#` でコメント)
- 焼き込みファイル: `files/` 配下がそのまま rootfs に重なる。初期設定は `files/etc/uci-defaults/` のスクリプトで行う (初回ブート時に 1 回実行され、成功すると削除される)

変更を push して workflow を再実行すればイメージに反映される。秘匿値 (パスワード・鍵) はこのリポジトリに焼き込まないこと。
