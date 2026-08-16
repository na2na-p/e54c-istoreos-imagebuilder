# e54c-istoreos-imagebuilder

Radxa E54C 用の iStoreOS SD カードイメージを GitHub Actions でビルドするリポジトリ。

iStoreOS 公式配布の ImageBuilder ([fw.koolcenter.com](https://fw.koolcenter.com/iStoreOS/ib/rk3xxx/)) に、USB テザリング上流 (Android / iOS) 用のパッケージと初期設定、および USB WiFi ドングルで AP を立てるためのパッケージを焼き込んだイメージを生成する。

## イメージの入手

main への push をトリガーに自動でビルドされ、[Releases](../../releases) に CalVer タグ (`vYYYY.MM.DD-HHMM`、JST) で公開される。最新リリースの Assets から `istoreos-*-radxa_e54c-squashfs-*.img.gz` をダウンロードする。

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
3. `eth1` (焼き込み済みの `wan_usbeth` インターフェース) が DHCP で上流を取得する

繋がらないときは SSH で `ip link` を実行し、ipheth のインターフェース名が `eth1` 以外になっていないか確認する。テザリングは繋がるのに LAN 側から通信できない場合は `uci show firewall | grep -E 'wan_usb|wan_usbeth'` で wan ゾーンに入っているか確認する。ロック 1 時間後の切断を避けるには iOS の設定 → Face ID とパスコード →「USB アクセサリ」を許可する。

### ZTE Speed USB STICK U03 (LTE スティック)

1. U03 に APN を設定しておく (povo2.0 なら APN `povo.jp` / 認証なし / IPv4v6)。
   APN 設定は U03 本体側の設定で、パソコンに直挿しして管理画面 `http://192.168.100.1`
   から行う (ルーター経由の設定 API は改ざん防止トークンで弾かれるため非推奨)
2. U03 を E54C の USB Type-A ポートに挿す
3. hotplug が CD-ROM モードを検知して自動で RNDIS へ切り替え、`eth1` (`wan_usbeth`) が
   DHCP で上流を取得する

U03 は iOS と同じ `eth1` に来るため `wan_usbeth` を共用する (排他利用のみ想定)。
切り替わらない場合は `usbmode -s -c /etc/u03-mode.json` を手動実行し、`dmesg` で
`rndis_host ... eth1` が出るか確認する。`network_type` が `LIMITED_SERVICE` のままなら
APN 未設定 (手順 1) を疑う。

## 無線 AP (USB WiFi ドングル)

ELECOM WDC-433SU2M2BK (Realtek RTL8821AU、USB ID `056e:400e`) を USB Type-A ポートに挿すと、mainline の rtw88 ドライバ (`kmod-rtw88-8821au`) がバインドして無線 PHY (`phy0`) が現れ、hotplug が `/etc/config/wireless` に `radio0` を自動生成する (初期状態は無効・暗号化なし)。この時点ではネットワークインターフェースはまだ無く、有効化後に `phy0-ap0` として生成される。SSID とパスフレーズはイメージに焼き込まないため、初回は LuCI で設定する。

1. LuCI → Network → Wireless で `radio0` の Edit を開く
2. Advanced Settings で Country Code を `JP` にする (既定の world regdomain のままだと 5GHz は AP を開始できないチャンネル扱いになる)
3. Interface Configuration で Mode=Access Point、Network=`lan`、ESSID を入力し、Wireless Security で Encryption (WPA2-PSK/WPA3-SAE Mixed Mode) と Key を設定して保存
4. 一覧の Enable を押す

確認は SSH で `iw list | grep -A8 'Supported interface modes'` (AP が含まれること)、`iw dev` (`phy0-ap0` が `type AP` であること)、`dmesg | grep -i rtw_8821au` (firmware ロード成否)、`logread -e hostapd` (`AP-ENABLED`)。rtw88 の USB デバイスは AP モードで長時間運転すると応答しなくなる報告 (kernel 6.6 系、[lwfinger/rtw88#322](https://github.com/lwfinger/rtw88/issues/322)) があり、症状が出た場合は `wifi down; wifi up` で復帰する。安定運用が最優先なら OpenWrt で実績の多い MediaTek mt76 系 (`kmod-mt76x2u` など) のドングルへの置き換えも選択肢に入る。

## カスタマイズ

- 同梱パッケージ: `packages.txt` (1 行 1 パッケージ、`#` でコメント)
- 焼き込みファイル: `files/` 配下がそのまま rootfs に重なる。初期設定は `files/etc/uci-defaults/` のスクリプトで行う (初回ブート時に 1 回実行され、成功すると削除される)

変更を main に push すると自動でビルドされ、新しいリリースとして公開される。秘匿値 (パスワード・鍵) はこのリポジトリに焼き込まないこと。
