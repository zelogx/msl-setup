# REVIEW NOTES — コード整理前の気づき一覧

- 作成日: 2026-09-24
- 対象: リポジトリ直下の現行コード（`msl-setup-*/` のリリーススナップショットは対象外）
- 方法: **静的な読解のみ**。スクリプトの実行や Proxmox 上での再現はしていない。参照系コマンドで確かめたのは、このホストに `ifreload2` が無いこと、`ipcalc` が Debian 版（`Network:` / `Broadcast:` 形式で出力）であることの 2 点だけ。
- この文書は判断材料の一覧です。**削除・修正するかどうかはユーザーが判断してください。** ここに挙げた項目は、承認なしに変更しません。

確度の表記:

| 表記 | 意味 |
|---|---|
| **高** | コード上で直接確認できる（呼び出し元の有無、上書き、到達不能など） |
| **中** | 前提（現在の実行フロー、PVE 9 環境など）が成り立てば正しい |
| **低（推測）** | 外部の挙動（Proxmox / AlmaLinux / Pritunl の仕様）に依存しており、実機では未確認 |

---

## 目次（サマリ）

| ID | 区分 | 概要 | 確度 |
|---|---|---|---|
| A-1 | 冪等性 | SDN zone / vnet 作成前の存在チェック | 中 |
| A-2 | 冪等性 | 0102 の DC アクセスルール削除が restore と二重 | 高 |
| A-3 | 冪等性 | `interfaces.d/sdn` の旧 post-up 行の除去 | 中 |
| A-4 | 冪等性 | 0202 のスナップショットロールバック（通常フローでは到達しない） | 中 |
| A-5 | 冪等性 | Pritunl の事前 stop/disable | 低（推測） |
| A-6 | 冪等性 | `mslcm remove_master_entry_from_cluster_env`（常に空振り） | 高 |
| B-1 | フォールバック | `ifreload2` の分岐 | 高 |
| B-2 | フォールバック | mslcm の `ipcalc -n/-b`（RedHat 系 ipcalc 形式） | 高 |
| B-3 | フォールバック | keepalived `auth_pass` の固定値 | 高 |
| B-4 | フォールバック | wget が無いときの curl 分岐 | 高 |
| B-5 | フォールバック | VMID 採番のローカルチェック | 中 |
| B-6 | フォールバック | `pvesh` の存在チェック | 高 |
| B-7 | フォールバック | pritunl.conf 編集の jq → python3 → エラー | 低（推測） |
| B-8 | フォールバック | 旧 `mslsetup-route` フックの削除 | 中 |
| B-9 | フォールバック | DHCP range 設定時の subnet ID 組み立て | 中 |
| B-10 | フォールバック | `dhcp-range` 削除の `""` 代替 | 低（推測） |
| B-11 | フォールバック | ホスト FW 有効化失敗時の「すでに有効かも」 | 中 |
| C-1 | 重複 | Pritunl VM の root ユーザー・パスワード設定 | 高（一部推測） |
| C-2 | 重複 | SSH 公開鍵の二重読込と未使用の一時ファイル | 高 |
| C-3 | 重複 | snippets ディレクトリ作成・user-data の書き出し | 高 |
| C-4 | 重複 | sshd の `ListenAddress` 設定が 2 箇所 | 高 |
| C-5 | 重複 | Pritunl デフォルトパスワードの取得が 3 箇所 | 高 |
| C-6 | 重複 | `.env` とヘルパーバイナリの VM への二重転送 | 中 |
| C-7 | 重複 | known_hosts の登録・削除 | 高 |
| C-8 | 重複 | MongoDB の疎通確認が 4 回 | 高 |
| C-9 | 重複 | keepalived.conf テンプレートが 2 箇所 | 高 |
| C-10 | 重複 | zone peers 更新・削除で vpndmz だけ別コピー | 高 |
| C-11 | 重複 | IP 変換・プライベート IP 判定関数が複数 | 高 |
| C-12 | 重複 | サブネット分割計算が 3 実装（1 つは結果が必ず上書きされる） | 高 |
| C-13 | 重複 | 既設ネットワーク探索が bash と Python の 2 実装 | 中 |
| C-14 | 重複 | SVG 生成が bash と Python の 2 実装 | 高 |
| C-15 | 重複 | TUI の保存処理が 3 コピー | 高 |
| C-16 | 重複 | probe / UUID 処理が 01 と 02 で同一コピー | 高 |
| C-17 | 重複 | SDN 状態ダンプ処理の重複 | 高 |
| C-18 | 重複 | if/else の中身が同一 | 高 |
| D-1〜D-11 | 未使用・到達不能 | 未使用関数、到達不能分岐、旧スクリプト | 高 |
| E-1〜E-10 | 文書と実装の食い違い | | — |
| F-1〜F-10 | 不具合の可能性 | 単一ノードでの再実行・アンインストール失敗など | 中〜低 |
| G-1〜G-8 | その他 | セキュリティ上の観察、リポジトリ管理、メッセージ | — |

---

## A. 冪等性チェックのうち、実際には不要と思われるもの

### A-1. SDN zone / vnet 作成前の存在チェック
- **場所**: [lib/common.sh:291-296](../lib/common.sh#L291-L296)（`create_sdn_zone`）、[lib/common.sh:313-317](../lib/common.sh#L313-L317)（`create_sdn_vnet`）。呼び出し元は [0102_setupNetwork.sh:246-262](../0102_setupNetwork.sh#L246-L262)
- **守っているもの**: 同名の zone / vnet がすでにあるときに `pvesh create` が失敗するのを避け、スキップする。
- **不要と判断した根拠**: 0102 は、初回はプロビジョニング前の状態をバックアップし（[0102:201-204](../0102_setupNetwork.sh#L201-L204)）、再実行時は必ず `msl_restore_to_backup` でバックアップに無い zone / vnet を消してから作り直す（[0102:229-233](../0102_setupNetwork.sh#L229-L233)）。そのため、MSL が作った zone / vnet が作成時点で残っていることは通常ない。削除に失敗した場合は `set -e` で処理が止まる（F-5）ので、そのまま作成処理に進むこともない。
- **消した場合のリスク**: 初回実行前から同名の zone / vnet（`vpndmz`, `devpj01`, `vnetpj01` など）が存在した環境では、今は**既存のものを黙って流用**しているが、消すと `pvesh create` が失敗して止まるようになる（こちらの方が安全とも言える）。IPSet は「作れない＝異常」という方針で存在チェックをしていない（[lib/common.sh:236-239](../lib/common.sh#L236-L239)）ので、方針をそろえるかどうかの判断材料にもなる。
- **確度**: 中（「作成前に必ず restore が走る」という現在のフローが前提）
- **補足（2026-09-24、ユーザー）**: `vpndmz` / `devpjXX` / `vpndmzvn` / `vnetpjXX` は、Wiki の [Environmental Integrity & System Impact Report](https://github.com/zelogx/msl-setup/wiki/Environmental-Integrity-&-System-Impact-Report) に MSL Setup が使う名前として記載されている。ただし「予約名であり、利用者は使わないこと」とは明記されていないので、後で Wiki に追記する予定。追記したら、同じ名前が既にある場合の扱い（流用するのか停止するのか）もあわせて決める。

### A-2. 0102 の DC アクセスルール削除が restore と二重
- **場所**: [0102_setupNetwork.sh:211](../0102_setupNetwork.sh#L211)、[0102_setupNetwork.sh:233](../0102_setupNetwork.sh#L233)（`remove_msl_dc_access_rules`、定義は [0102:145-160](../0102_setupNetwork.sh#L145-L160)）
- **守っているもの**: コメントが `MSLSetup Allow Spice/ssh/https from external network to DC` の 3 ルールを、再作成前に削除する。
- **不要と判断した根拠**: 直前の `msl_restore_to_backup` が、同じ 3 つのコメントを `managed_rule_comments` に含めて削除している（[lib/sdn_backup_restore.sh:412-414](../lib/sdn_backup_restore.sh#L412-L414)、[:439-448](../lib/sdn_backup_restore.sh#L439-L448)）。211 行目と 233 行目の呼び出しは、毎回「対象なし」で終わる。
- **消した場合のリスク**: [0102:219](../0102_setupNetwork.sh#L219)（`--restore` 指定かつバックアップ無しの分岐）では restore が走らないので、ここだけは残す必要がある。211・233 行目だけなら、`managed_rule_comments` と同期している限りリスクは無い。
- **確度**: 高（211・233 行目について）
- **状態: 後回し（致命的ではない、ユーザー判断 2026-09-24）**
- **補足（2026-09-24）**: F-4 の修正で、`remove_msl_dc_access_rules` は `msl_delete_dc_rules_matching` を呼ぶだけの関数になった。restore のパターンにも同じルールが含まれるので、restore の後に呼ぶ箇所（現在の 0102:176・198 付近）が冗長である点は変わらない。行番号は変わっている。

### A-3. `/etc/network/interfaces.d/sdn` から旧 post-up/pre-down 行を除去する処理
- **場所**: [lib/common.sh:627-635](../lib/common.sh#L627-L635)（`persist_project_gateway_hooks` の中）
- **守っているもの**: 旧方式で `interfaces.d/sdn` に追記した `post-up ip addr add ... vnetpjXX` の行が残って、GW IP が二重に付くこと。
- **不要と判断した根拠**: v2.0-a の実装計画に「`SDN Apply` 実行時に `/etc/network/interfaces.d/sdn` の `post-up/pre-down` 追記が消えるため、同方式は廃止する」とある（[docs/specs/v2.0-a_vxlan_backend_implementation_plan.md:91](specs/v2.0-a_vxlan_backend_implementation_plan.md)）。0102 はこの関数の直前に SDN Apply（[0102:284](../0102_setupNetwork.sh#L284)）を実行するので、ファイルはその時点で作り直されている。また README は v1.x からの直接アップグレードをサポートしていない。
- **消した場合のリスク**: SDN Apply で消えない形の旧行が残っている環境（想定外の手編集など）では、行が残る。さらに、Proxmox が管理するファイルを MSL が書き換える処理がなくなるので、リスクはむしろ下がる。
- **確度**: 中（「SDN Apply でファイルが作り直される」という仕様書の記述を前提にしている）
- **状態: 対応済み（コミット `823b48d`）**。後始末の awk と、使われなくなったローカル変数を削除した。pve20（単一ノード）で、01 の実行後に vpndmzvn と vnetpj01〜04 に GW の IP が付くことを確認した（2026-09-24）。
- **補足（2026-09-24）**: 現在の `interfaces.d/sdn` に `post-up` / `pre-down` が無いのは、v2.0-a からの仕様どおり。GW の IP は、単一ノードでは `if-up.d/mslsetup-vxlan-gw`、クラスタでは keepalived の notify（`msl-vip-hook.sh master`）が付ける。pve13（クラスタの MASTER）で、vpndmzvn と vnetpj01〜04 に GW の IP が付いていること、`VPN_POOL via PT_EG_IP` の経路があること、if-up フックが no-op 化されていることを確認した。この項目で指摘しているのは、旧方式の行を消す後始末が不要だという点だけで、GW の付与には影響しない。

### A-4. 0202 のスナップショットロールバック分岐
- **場所**: [0202_configurePritunl.sh:112-143](../0202_configurePritunl.sh#L112-L143)
- **守っているもの**: 0202 だけを再実行したとき、VM を「0202 実行前」の状態に戻してからやり直す。
- **不要と判断した根拠**: 通常フロー（`02_vpnSetup.sh`）では 0201 が毎回 VM を破棄して作り直す（[0201:263-317](../0201_createPritunlVM.sh#L263-L317)）ので、0202 の開始時点でスナップショットは存在しない。この分岐に入るのは、ユーザーが `0202_configurePritunl.sh` を単独で再実行した場合だけ。README のトラブルシューティングでは `02_vpnSetup.sh` の再実行を案内している。
- **消した場合のリスク**: 0202 の単独再実行をサポート範囲とするなら必要。残す場合でも、`check_vm_snapshot_exists` を名前なしで呼ぶと**ユーザーが手動で作ったスナップショットを含む任意の最新スナップショット**にロールバックする（[lib/common.sh:703-712](../lib/common.sh#L703-L712)）ので、`msl-phase3-*` に限定するかどうか検討の余地がある。
- **確度**: 中（「0202 の単独再実行はサポートしない」ならば不要）
- **状態: 対応しない（現状維持、ユーザー判断 2026-09-24）**。このスナップショットは、Pritunl VM を設定前の状態に戻したい利用者のためのもの。スナップショットが無くなっていても問題ない。

### A-5. Pritunl サービスの事前 stop/disable
- **場所**: [lib/pritunl_install.sh:228-240](../lib/pritunl_install.sh#L228-L240)（`configure_pritunl_initial`）
- **守っているもの**: 設定ファイルを書き換える前に Pritunl が起動していないこと。
- **不要と判断した根拠（推測）**: dnf でインストールした直後の RHEL 系パッケージは、通常サービスを自動起動・自動有効化しない（systemd preset 既定）。また、0202 は毎回まっさらな VM（またはロールバック後の VM）で動く。
- **消した場合のリスク**: Pritunl の RPM が postinstall でサービスを起動する仕様なら、起動中に `pritunl.conf` を書き換えることになる。仕様は未確認。
- **確度**: 低（推測）
- **状態: 対応しない（現状維持、2026-09-24）**。後続の `configure_global_pritunl_settings` は、設定を書き換えた後に `systemctl start`（`restart` ではない）で起動する。もし起動中のまま書き換えると、`start` は何もしないので設定が反映されない。事前の stop は「停止した状態で書き換え、start で反映する」流れを保証しているので、不要ではないと判断を改めた。今の環境で問題なく動いているのは、インストール直後で元々停止しているから。

### A-6. `mslcm remove_master_entry_from_cluster_env`（常に空振り）
- **場所**: [mslcm:579-596](../mslcm#L579-L596)、呼び出しは [mslcm:1471](../mslcm#L1471)
- **守っているもの**: disable-cluster 時に `cluster.env` から `MASTER=` 行を消す。
- **不要と判断した根拠**: 直前の [mslcm:1463](../mslcm#L1463) で `rm -f "$CLUSTER_ENV"` しているので、ファイルが存在せず毎回スキップされる。さらに [mslcm:587](../mslcm#L587) の `grep -Fxq "^MASTER="` は固定文字列・行全体一致なので、ファイルがあってもマッチしない。
- **消した場合のリスク**: なし（現状でも何もしていない）。
- **確度**: 高。F-1 の修正で `cluster.env` を最後に削除するようにしたため、現在はファイルがある状態で呼ばれる。それでも grep がマッチせず、クラスタ環境の実行ログに `cluster.env does not contain MASTER entry; skipping` と出ることを確認した（2026-09-24）。直後に `cluster.env` を丸ごと削除するので、実害は無い。
- **状態: 対応済み（コミット `ee9c07d`）**。pve13 で、restore の disable-cluster が完了し、「does not contain MASTER entry」の行が出なくなったことを確認した（2026-09-24）。関数と、disable-cluster からの呼び出しを削除した。`cluster.env` は disable-cluster の最後に丸ごと削除される。

---

## B. 現在は発生しない状況に対するフォールバック

### B-1. `ifreload2` の分岐
- **場所**: [lib/common.sh:637-641](../lib/common.sh#L637-L641)
- **守っているもの**: `ifreload2` というコマンドがある環境では、そちらを使う。
- **根拠**: PVE 9 の ifupdown2 が提供するのは `ifreload` / `ifup` / `ifdown` / `ifquery` で、このホストにも `ifreload2` は無い（確認済み）。`mslcm` 側は `ifreload` だけを使っている（[mslcm:732](../mslcm#L732)、[:1019](../mslcm#L1019)）。
- **消した場合のリスク**: なし（`ifreload2` を提供するディストリビューションは把握していない）。
- **確度**: 高（PVE 9 環境について）

### B-2. mslcm の `ipcalc -n` / `ipcalc -b` フォールバック
- **場所**: [mslcm:186-189](../mslcm#L186-L189)（`ip_in_cidr`）、[mslcm:1039-1041](../mslcm#L1039-L1041)（`get_valid_vip`）
- **守っているもの**: `NETWORK=` / `BROADCAST=` 形式で出力する RedHat 系 ipcalc（ipcalc-ng）がインストールされている環境。
- **根拠**: PVE（Debian）の `ipcalc` は `Network:` / `Broadcast:` 形式で出力する（このホストで確認済み）。`00_configNetwork.sh` が入れるのも Debian の `ipcalc` パッケージ（[00_configNetwork.sh:105](../00_configNetwork.sh#L105)）。`lib/network.sh` や `lib/common.sh` はこの形式を前提にしていてフォールバックを持たないので、ipcalc-ng の環境ではどのみち他の箇所が壊れる。
- **消した場合のリスク**: ipcalc-ng に入れ替えた環境で、mslcm の VIP 入力チェックが失敗するようになる（ただし前述のとおり、他の処理も同様に動かない）。
- **確度**: 高

### B-3. keepalived `auth_pass` の固定値フォールバック
- **場所**: [mslcm:1234-1237](../mslcm#L1234-L1237)
- **守っているもの**: 乱数から生成したパスワードが空になった場合に `Ze!0gx` を使う。
- **根拠**: `tr -dc 'A-Za-z0-9' </dev/urandom | head -c 8` が空を返すのは `/dev/urandom` が読めない場合くらいで、PVE では実質起きない。
- **消した場合のリスク**: なし。むしろ、固定値が Pritunl VM の root パスワード（C-1）と同じ文字列になっている点の方が気になる。
- **確度**: 高

### B-4. wget が無いときの curl 分岐
- **場所**: [lib/vm_utils.sh:280-288](../lib/vm_utils.sh#L280-L288)（`download_cloud_image`）、[lib/vm_utils.sh:327-336](../lib/vm_utils.sh#L327-L336)（`verify_image_hash`）
- **守っているもの**: wget が無い環境でも curl でダウンロードできるようにする。
- **根拠**: 0201 は事前チェックで `wget` を必須にしており、無ければ die する（[0201_createPritunlVM.sh:341-345](../0201_createPritunlVM.sh#L341-L345)）。そのため curl の分岐と「どちらも無い」分岐には到達しない。
- **消した場合のリスク**: なし（将来 wget を必須から外すなら、この分岐が必要になる）。
- **確度**: 高

### B-5. VMID 採番のローカルチェック
- **場所**: [lib/vm_utils.sh:190-196](../lib/vm_utils.sh#L190-L196)
- **守っているもの**: `pvesh get /cluster/resources` が使えないときに、`qm status` / `pct status` で空き VMID を探す。
- **根拠**: `pvesh` は PVE 標準、`jq` は 0201 の必須チェックに含まれている。この分岐に入るのは `pvesh get` が失敗したとき（pmxcfs の異常など）だけで、その状況では後続の `qm create` も失敗する可能性が高い。
- **消した場合のリスク**: クラスタ API が一時的に失敗したとき、フォールバックせずに止まるようになる（ローカルチェックでは他ノードの VMID を検出できないので、止まる方が安全とも言える）。
- **確度**: 中

### B-6. `pvesh` の存在チェック
- **場所**: [lib/vm_utils.sh:70-73](../lib/vm_utils.sh#L70-L73)、[lib/vm_utils.sh:176](../lib/vm_utils.sh#L176)
- **根拠**: Proxmox ホスト上でしか動かないスクリプトで、`pvesh` は必ず存在する。
- **消した場合のリスク**: なし。
- **確度**: 高

### B-7. pritunl.conf 編集の jq → python3 → エラー
- **場所**: [lib/pritunl_install.sh:421-452](../lib/pritunl_install.sh#L421-L452)
- **守っているもの**: VM 内に jq が無くても python3 で JSON を編集できるようにする。
- **根拠（推測）**: AlmaLinux 9 GenericCloud イメージには dnf の依存として python3 が必ず入っている。jq は既定では入っておらず、cloud-init の `packages` にも無い（[lib/vm_utils.sh:453-456](../lib/vm_utils.sh#L453-L456)）。つまり実際に使われているのは python3 の経路で、jq の経路と「どちらも無い」分岐は通っていない可能性が高い。
- **消した場合のリスク**: イメージの内容が変わった場合に影響する。どちらか一方の経路に統一する場合は、cloud-init の `packages` で明示的にインストールすると確実。
- **確度**: 低（推測。イメージの内容は未確認）

### B-8. 旧 `mslsetup-route` フックの削除
- **場所**: [lib/common.sh:496-513](../lib/common.sh#L496-L513)（`persist_vpn_pool_route` / `remove_vpn_pool_route_hooks`）、呼び出しは [0102:213](../0102_setupNetwork.sh#L213)、[0102:221](../0102_setupNetwork.sh#L221)
- **守っているもの**: 旧版が作った `/etc/network/if-{up,down}.d/mslsetup-route` を削除する。
- **根拠**: 現在の戻り経路（`VPN_POOL via PT_EG_IP`）は `mslsetup-vxlan-gw` フックで設定している（[lib/common.sh:598](../lib/common.sh#L598)）。v1.x からの直接アップグレードはサポートされていない。`persist_vpn_pool_route` はどこからも呼ばれていない。
- **消した場合のリスク**: 旧版のフックが残ったホストで `--restore` しても、そのフックが消えなくなる。どのバージョンまで `mslsetup-route` を作っていたかは未確認。
- **確度**: 中

### B-9. DHCP range 設定時の subnet ID 組み立て
- **場所**: [lib/common.sh:422-427](../lib/common.sh#L422-L427)（`set_vnet_subnet_dhcp_range`）
- **守っているもの**: `pvesh get .../subnets` で subnet ID が取れなかったとき、ID を組み立てて使う。
- **根拠**: 直前の [0102:274](../0102_setupNetwork.sh#L274) で subnet を作成したばかりなので、ID は取得できるはず。また、組み立てている形式 `${vnet}-<ip>-<mask>` は、同じファイルのコメント（[lib/common.sh:335](../lib/common.sh#L335) の「subnet ID は zone-network-mask 形式」）と食い違っている。実際の ID が zone 名始まりなら、このフォールバックは正しい ID にならない。
- **消した場合のリスク**: 取得に失敗した時点でエラーになる（現状でも、組み立てた ID が誤っていれば `pvesh set` が失敗するので、結果は大きく変わらない）。
- **確度**: 中（subnet ID の実際の形式は実機で確認していない）

### B-10. `dhcp-range` 削除の `""` 代替
- **場所**: [lib/common.sh:460-466](../lib/common.sh#L460-L466)
- **守っているもの**: `-delete dhcp-range` が使えないバージョンの PVE では、空文字列を設定して代用する。
- **根拠（推測）**: 対象は PVE 9.0+ で、`-delete` は PVE の API で一般的に使えるパラメータ。
- **消した場合のリスク**: 古い PVE で消せなくなる（対象外のバージョン）。
- **確度**: 低（推測）

### B-11. ホスト FW 有効化に失敗したときの「すでに有効かも」
- **場所**: [0102_setupNetwork.sh:352-358](../0102_setupNetwork.sh#L352-L358)
- **守っているもの**: `pvesh set /nodes/<node>/firewall/options -enable 1 -nftables 1` が失敗しても、WARN を出して続行する。
- **根拠**: `pvesh set` は同じ値の再設定では失敗しないので、メッセージにある「すでに有効かも」という理由では失敗しない。失敗するのは別の原因（ノード名の不一致など）で、その場合はホスト FW が無効のまま続行することになる。
- **消した場合のリスク**: die するように変えると、原因不明の失敗で止まるケースが出る。WARN で続行したまま隔離が効いていない状態の方が、リスクとしては大きいと考える（判断はユーザー）。
- **確度**: 中

---

## C. 重複している処理

### C-1. Pritunl VM の root ユーザー・パスワード設定（ご指摘の件）
- **場所**:
  1. [lib/vm_utils.sh:486](../lib/vm_utils.sh#L486): cloud-init user-data の `runcmd` で `echo 'root:Ze!0gx' | chpasswd`
  2. [lib/vm_utils.sh:450-451](../lib/vm_utils.sh#L450-L451): `disable_root: false` / `ssh_pwauth: true`
  3. [lib/vm_utils.sh:471-479](../lib/vm_utils.sh#L471-L479): `sshd_config.d` の cloud-init 用ファイルを削除し、`99-msl.conf` で `PermitRootLogin yes` / `PasswordAuthentication yes` を設定
  4. [lib/vm_utils.sh:561](../lib/vm_utils.sh#L561): `qm set --ciuser root`
  5. [lib/vm_utils.sh:548](../lib/vm_utils.sh#L548): コメントは「`--cipassword` で root パスワードを設定」だが、実際には `--cipassword` を渡していない
  6. 同じパスワード文字列が [lib/pritunl_install.sh:759](../lib/pritunl_install.sh#L759)（VM notes への記載）と [mslcm:1236](../mslcm#L1236)（B-3）にもハードコードされている
- **守っているもの**: root でのパスワード SSH ログインを可能にする（VM notes で案内している初期クレデンシャル）。
- **重複と判断した根拠**:
  - `--cicustom user=...` を指定すると、Proxmox が生成する user-data（`ciuser` / `cipassword` / `sshkeys` を反映する部分）はカスタム user-data に置き換わる。そのため 4 の `--ciuser root` は効いていないと考えられる（**推測**: Proxmox の cicustom の仕様に基づく判断で、実機では未確認）。
  - 2 の `ssh_pwauth: true` と 3 の `PasswordAuthentication yes` は、同じ設定を 2 つの方法で入れている。
  - パスワード文字列が 3 ファイルに分散しているので、変更時に漏れが起きやすい。
- **消した場合のリスク**: 4 を消したあと、もし `--ciuser` が実際には効いていた場合、既定ユーザー（AlmaLinux の `almalinux`）が作られるなど挙動が変わる可能性がある。2 と 3 はどちらか一方を消しても動く見込みだが、`60-cloudimg-settings.conf` や `50-cloud-init.conf` を削除する処理との順序に依存するので、片方に寄せる場合は実機で確認が必要。
- **確度**: 重複そのものは高。`--ciuser` が無効という点は低（推測）

### C-2. SSH 公開鍵の二重読込と、使われない一時ファイル
- **場所**: [lib/vm_utils.sh:421-426](../lib/vm_utils.sh#L421-L426)、[lib/vm_utils.sh:439-441](../lib/vm_utils.sh#L439-L441)、[lib/vm_utils.sh:572](../lib/vm_utils.sh#L572)
- **守っているもの**: VM に SSH 公開鍵を配置する。
- **重複と判断した根拠**: 公開鍵は user-data の `ssh_authorized_keys`（[:458-459](../lib/vm_utils.sh#L458-L459)）で渡している。`/var/lib/vz/snippets/pritunl-vm-<id>-sshkey.pub` は書き出すだけで `qm set --sshkeys` には渡しておらず、最後に削除される。`ssh_pubkey` は 422 行目と 440 行目で 2 回読み込まれ、`local` も 2 回宣言されている。
- **消した場合のリスク**: なし（一時ファイルは参照されていない）。
- **確度**: 高

### C-3. snippets ディレクトリの作成と user-data の書き出し
- **場所**: [lib/vm_utils.sh:424](../lib/vm_utils.sh#L424) と [:570](../lib/vm_utils.sh#L570)（`mkdir -p` が 2 回）、[:444](../lib/vm_utils.sh#L444) と [:571](../lib/vm_utils.sh#L571)（`/tmp` に書き出してから snippets にコピー）
- **重複と判断した根拠**: 同じディレクトリを 2 回作っている。user-data は snippets に直接書き出せば足りる。
- **消した場合のリスク**: 小さい。現状は `qm set --cicustom`（[:560](../lib/vm_utils.sh#L560)）の**後に** snippets へコピーしているが、qm set の時点ではファイルの存在を確認しないはずなので問題は起きていない（推測）。直接書き出す形に変えれば、この順序の問題もなくなる。
- **確度**: 高

### C-4. sshd の `ListenAddress` 設定が 2 箇所
- **場所**: [lib/vm_utils.sh:474-481](../lib/vm_utils.sh#L474-L481)（cloud-init で `sshd_config.d/99-msl.conf` に `ListenAddress $PT_IG_IP` を書き、sshd を再起動）、[lib/pritunl_install.sh:261-273](../lib/pritunl_install.sh#L261-L273)（`apply_security_hardening` で `sshd_config` 本体から `ListenAddress` 行を消して追記し、sshd を再起動）
- **守っているもの**: SSH を MainLAN 側の IP でだけ待ち受ける（設計原則 2.4）。
- **重複と判断した根拠**: 同じ設定を 2 つのファイルに書いている。後者は `sshd_config.d` 側の設定を消さないので、同じアドレスの `ListenAddress` が 2 行ある状態になる（sshd が 2 回目の bind 失敗をログに出す可能性があるが、**推測**で未確認）。`sshd_config.backup` も実行のたびに上書きされる。
- **消した場合のリスク**: cloud-init 側を消すと、0202 が終わるまでの間 sshd が全インターフェースで待ち受ける。0202 側を消すと、cloud-init が失敗した場合の保険がなくなる（ただし `wait_for_cloudinit` で完了を確認している）。
- **確度**: 高

### C-5. Pritunl デフォルトパスワードの取得が 3 箇所
- **場所**: [0202_configurePritunl.sh:190](../0202_configurePritunl.sh#L190)、[lib/pritunl_install.sh:533-543](../lib/pritunl_install.sh#L533-L543)（`setup_pritunl_orgs`）、[lib/pritunl_install.sh:738-746](../lib/pritunl_install.sh#L738-L746)（`save_config_to_vm_notes`）
- **守っているもの**: パスワードが空だった場合に、もう一度 `pritunl default-password` を実行して取得し直す。
- **重複と判断した根拠**: 0202 は取得したパスワードを必ず両方の関数に渡している。関数側の再取得は、0202 で空だった場合にだけ、同じコマンドをもう一度実行する。
- **消した場合のリスク**: 一時的な失敗からの回復手段がなくなる（`setup_pritunl_orgs` は空パスワードの場合に return 1 する）。関数側を消すなら、0202 側に空チェックとリトライを集約する必要がある。なお、[0202:191](../0202_configurePritunl.sh#L191) はパスワードを平文でログファイルに書いている（G-1）。
- **確度**: 高

### C-6. `.env` とヘルパーバイナリを VM に二重転送している
- **場所**: 0201 で `.env` と `lib/pritunl_build_helper` を VM の `/root` へ転送（[0201:420](../0201_createPritunlVM.sh#L420)、[lib/vm_utils.sh:661-685](../lib/vm_utils.sh#L661-L685)）。0202 でも `.env` を `/tmp/.env` へ（[0202:181](../0202_configurePritunl.sh#L181)）、ヘルパーを `/tmp/pritunl_build_helper` へ転送（[lib/pritunl_install.sh:577-593](../lib/pritunl_install.sh#L577-L593)）
- **重複と判断した根拠**: 0202 のスナップショットは 0201 の後に作られるので、ロールバックしても `/root` の 2 ファイルは残っている。0202 は `/root` のファイルをそのまま使える。
- **消した場合のリスク**: 0202 だけを別の VM に対して実行するケースを想定しているなら、転送が必要になる。現状は `/tmp` 側のヘルパーだけを削除していて、`/tmp/.env` と `/root/.env` は VM に残っている。
- **確度**: 中

### C-7. known_hosts の登録と削除
- **場所**: [0201:291](../0201_createPritunlVM.sh#L291)（破棄時に削除）、[0201:410](../0201_createPritunlVM.sh#L410)（`ssh-keyscan` で追記）、[0202:73](../0202_configurePritunl.sh#L73)・[:106](../0202_configurePritunl.sh#L106)（再び削除し、`StrictHostKeyChecking=accept-new` で登録し直す）
- **守っているもの**: VM を作り直してホスト鍵が変わっても、SSH が失敗しないようにする。
- **重複と判断した根拠**: 0201 の `ssh-keyscan` で登録した鍵は、0202 の冒頭で必ず削除される。0201 自身の SSH/SCP は `UserKnownHostsFile=/dev/null` を使っているので、この登録は使われていない。実質的には「SSH が準備できたかの確認」として働いているだけで、それは直前の `wait_for_cloudinit` がすでに確認している。
- **消した場合のリスク**: 0201 だけを実行して 0202 を実行しない場合に、known_hosts に行が残らなくなる（悪影響は無い）。keyscan の失敗で die する部分がなくなる。
- **確度**: 高

### C-8. MongoDB の疎通確認が 4 回
- **場所**: [lib/pritunl_install.sh:183-196](../lib/pritunl_install.sh#L183-L196)（ping の待機ループ）、[:199-203](../lib/pritunl_install.sh#L199-L203)（`is-active`）、[:205-210](../lib/pritunl_install.sh#L205-L210)（もう一度 ping）、[:805-811](../lib/pritunl_install.sh#L805-L811)（`perform_verification`）
- **重複と判断した根拠**: 待機ループが成功した直後に、同じ ping をもう一度実行している。
- **消した場合のリスク**: 小さい（205-210 行目の再 ping は WARN を出すだけ）。
- **確度**: 高

### C-9. keepalived.conf のテンプレートが 2 箇所
- **場所**: [mslcm:801-850](../mslcm#L801-L850)（`render_keepalived_conf`）と [mslcm:1324-1364](../mslcm#L1324-L1364)（`cmd_add_node` 内のヒアドキュメント）
- **重複と判断した根拠**: 内容はほぼ同じで、priority の値だけが違う。出力先をパラメータにすれば 1 つにできる。
- **消した場合のリスク**: 統合するときに、どちらか一方だけに入っている差分を落とさないよう注意が必要（現時点では差分は見当たらない）。片方だけ修正されて設定が食い違うリスクは今の方が大きい。
- **確度**: 高

### C-10. zone peers の更新・削除で vpndmz だけ別コピー
- **場所**: [mslcm:1146-1164](../mslcm#L1146-L1164) と [:1166-1190](../mslcm#L1166-L1190)（`update_zone_peers`）、[mslcm:653-666](../mslcm#L653-L666) と [:668-688](../mslcm#L668-L688)（`remove_zone_peers`）
- **重複と判断した根拠**: `vpndmz` と `devpjXX` で同じ処理を繰り返している（違いは「zone が見つからないときに warn を出すか」だけ）。ループの中で `local` を再宣言している（[mslcm:1167](../mslcm#L1167)）。
- **消した場合のリスク**: 統合するときに warn の挙動をそろえる必要がある。
- **確度**: 高

### C-11. IP 変換・プライベート IP 判定の関数が複数ある
- **場所**: `ipv4_to_int` / `int_to_ipv4`（[lib/common.sh:351-372](../lib/common.sh#L351-L372)）、`ip_to_int` / `int_to_ip`（[lib/network.sh:50-71](../lib/network.sh#L50-L71)）、`ipv4_to_int`（[mslcm:162-167](../mslcm#L162-L167)）。`validate_private_ip`（[lib/common.sh:214-232](../lib/common.sh#L214-L232)）と `is_private_ip`（[lib/common.sh:671-680](../lib/common.sh#L671-L680)）
- **重複と判断した根拠**: 同じ機能の関数が別名で存在する。
- **消した場合のリスク**: `mslcm` は lib を source しない単独動作の設計（`/usr/local/bin` に配置されるため）なので、mslcm 内のコピーは意図的なもの。統合するのは lib 内の重複にとどめるのが無難。
- **確度**: 高

### C-12. サブネット分割計算が 3 実装（1 つは結果が必ず上書きされる）
- **場所**:
  1. bash: `calculate_subnet` / `split_pool`（[lib/network.sh:237-302](../lib/network.sh#L237-L302)）。`input_functions.sh` から使われている
  2. Python: `_calculate_subnet_py` / `_split_pool_py`（[00_configNetwork.sh:425-472](../00_configNetwork.sh#L425-L472)）。`compute_config` から呼ばれる（[:818-819](../00_configNetwork.sh#L818-L819)）
  3. Python: `_calculate_project_cidrs` / `_calculate_vpn_pools`（[00_configNetwork.sh:1112-1196](../00_configNetwork.sh#L1112-L1196)）
- **重複と判断した根拠**: `compute_config` を呼んでいるのは `_recalculate_config` だけで（[:1062](../00_configNetwork.sh#L1062)）、その直後に `_apply_port_ranges`（[:1072](../00_configNetwork.sh#L1072)）が 3 の関数で PJ・プールの値を上書きする（[:1241-1258](../00_configNetwork.sh#L1241-L1258)）。そのため 2 の計算結果は最終的に使われない。なお 2 の GW 計算は if/else の両方が `broadcast_address` になっており（[:441-444](../00_configNetwork.sh#L441-L444)）、コメント（「最終の使用可能アドレス」）とも README（GW は .254）とも食い違っているが、上書きされるので実害は無い。
- **消した場合のリスク**: 2 を消しても出力は変わらない見込み。ただし、2 はプレフィックスが 30 を超える場合に例外を出す（握りつぶされる）が 3 は出さないなど、エッジケースの挙動が少し違う。
- **確度**: 高

### C-13. 既設ネットワーク探索が bash と Python の 2 実装
- **場所**: bash の `detect_existing_networks`（[lib/network.sh:326-469](../lib/network.sh#L326-L469)）、Python の `_collect_existing_networks_fallback`（[00_configNetwork.sh:621-725](../00_configNetwork.sh#L621-L725)）。両方の結果を `get_existing_networks`（[:562-619](../00_configNetwork.sh#L562-L619)）でマージしている。さらに `_run_base_config` でも bash 版を実行している（[:492](../00_configNetwork.sh#L492)）
- **重複と判断した根拠**: 名前は「fallback」だが、コメントのとおり Python 版が主系で、bash 版は補助になっている。両者の検出範囲は一部しか重ならない（ARP と VM/CT の設定は bash 版だけ、`ip -o route` / `addr scope global` は両方）。
- **消した場合のリスク**: どちらかを消すと検出範囲が変わる（設計原則 2.7 の検出対象を満たさなくなる可能性がある）。統合するなら、機能の和集合を 1 つの実装にまとめる必要がある。
- **確度**: 中

### C-14. SVG 生成が bash と Python の 2 実装
- **場所**: [lib/svg_generator.sh](../lib/svg_generator.sh)（bash）、[00_configNetwork.sh:874-986](../00_configNetwork.sh#L874-L986)（Python の `generate_svg`）
- **重複と判断した根拠**: bash 版を source しているのは旧 `0101_checkConfigNetwork.sh` だけ（[0101:75](../0101_checkConfigNetwork.sh#L75)）で、0101 は現行フローから呼ばれない（D-7）。
- **消した場合のリスク**: 0101 を残すなら bash 版も必要。
- **確度**: 高

### C-15. TUI の保存処理が 3 コピー
- **場所**: [00_configNetwork.sh:2457-2499](../00_configNetwork.sh#L2457-L2499)、[:2501-2547](../00_configNetwork.sh#L2501-L2547)、[:2564-2592](../00_configNetwork.sh#L2564-L2592)
- **重複と判断した根拠**: `.env` の生成、結果ダイアログ、SVG ダイアログ、`generate_svg` という流れが 3 回コピーされている。1 つ目は `if self.mode == "CUSTOM":` ブロックの中にある `mode == "AUTO"` の分岐なので、到達しない（D-8）。
- **消した場合のリスク**: 1 つ目は到達不能なので無し。2 つ目と 3 つ目は検証内容が少し違う（CUSTOM ではカスタムフィールドを検証する）。
- **確度**: 高

### C-16. probe / UUID 処理が 01 と 02 で同一コピー
- **場所**: [01_networkSetup.sh:40-100](../01_networkSetup.sh#L40-L100) と [02_vpnSetup.sh:41-101](../02_vpnSetup.sh#L41-L101)（`load_phase_uuid_or_exit` / `post_phase_probe_token`）。00 には Python 版がある
- **重複と判断した根拠**: 2 つの関数は完全に同じ内容。さらに `post_phase_probe_token` の jp/en の分岐は、両方が同じ英語メッセージを出している（[01:92-96](../01_networkSetup.sh#L92-L96)）。
- **消した場合のリスク**: lib に移す場合、外部送信の内容が変わらないことを確認する必要がある（`GITHUB_WIKI_DATA_SENT_*.md` との整合）。
- **確度**: 高

### C-17. SDN 状態のダンプ処理の重複
- **場所**: [lib/sdn_backup_restore.sh:37-109](../lib/sdn_backup_restore.sh#L37-L109)（`_dump_sdn_state`）、[:191-242](../lib/sdn_backup_restore.sh#L191-L242)（`_backup_and_log_sdn_state`）、[0102_setupNetwork.sh:477-535](../0102_setupNetwork.sh#L477-L535)（FINAL STATE DUMP）
- **重複と判断した根拠**: 0102 の最終ダンプは `_dump_sdn_state live` とほぼ同じ内容。しかも v2.0 で廃止した Security Group のダンプ（[0102:516-529](../0102_setupNetwork.sh#L516-L529)）が残っている。
- **消した場合のリスク**: ログの出力内容が少し変わるだけ。
- **確度**: 高

### C-18. if/else の中身が同一
- **場所**: [0201_createPritunlVM.sh:268-272](../0201_createPritunlVM.sh#L268-L272)（どちらの分岐も `msg_printf PREV_VM_AUTOREMOVE`）、[00_configNetwork.sh:441-444](../00_configNetwork.sh#L441-L444)（C-12）、[01_networkSetup.sh:92-96](../01_networkSetup.sh#L92-L96)（C-16）
- **確度**: 高

---

## D. 未使用・到達不能のコード（整理の候補）

| ID | 場所 | 内容 | 確度 |
|---|---|---|---|
| D-1 | [lib/sdn_backup_restore.sh:495-524](../lib/sdn_backup_restore.sh#L495-L524) | `msl_handle_backup_restore` はどこからも呼ばれていない（ファイルヘッダの Usage は、この関数を使う前提で書かれている）。0102 に書かれている処理と挙動も違う（こちらは `--restore` のときにバックアップを作らない） | 高 |
| D-2 | [lib/common.sh:496-499](../lib/common.sh#L496-L499) | `persist_vpn_pool_route` は未使用 | 高 |
| D-3 | [lib/common.sh:169-184](../lib/common.sh#L169-L184) | `restore_file` は未使用（`backup/` の `.env` バックアップは、書くだけで読まれない） | 高 |
| D-4 | [0102_setupNetwork.sh:112-120](../0102_setupNetwork.sh#L112-L120)、[:130-135](../0102_setupNetwork.sh#L130-L135) | `update_env_var` は未使用。`get_rule_pos_by_comment` の引数 `node_name` も使われていない | 高 |
| D-5 | [0103_clusterSetup.sh:308-321](../0103_clusterSetup.sh#L308-L321)、[:519](../0103_clusterSetup.sh#L519) | `append_cluster_env_record` は未使用（mslcm 側に同じ役割の関数がある）。`local master_ip` も未使用 | 高 |
| D-6 | [01_networkSetup.sh:257-288](../01_networkSetup.sh#L257-L288)、[:332-335](../01_networkSetup.sh#L332-L335) | `--restore` の処理は 223 行目で `exit 0` するので、それより後にある `RESTORE_ONLY == true` の分岐には到達しない | 高 |
| D-7 | [0101_checkConfigNetwork.sh](../0101_checkConfigNetwork.sh) | 呼び出し元は 00 の `_exec_custom`（[00:2919-2928](../00_configNetwork.sh#L2919-L2928)）だけで、`_exec_custom` 自体がどこからも呼ばれていない。さらに [0101:77](../0101_checkConfigNetwork.sh#L77) に全角の「２」が 1 文字だけの行があり、実行すると `set -e` の下で `command not found` になって即終了するはず。それでもリリースには同梱されている（[make_release_mslpro.sh:43](../make_release_mslpro.sh#L43)、[make_release_mslpro_corporate.sh:39](../make_release_mslpro_corporate.sh#L39)）。`0301:127` のエラーメッセージも 0101 を案内している | 高 |
| D-8 | [00_configNetwork.sh:2457-2499](../00_configNetwork.sh#L2457-L2499) | CUSTOM ブロックの中にある `mode == "AUTO"` の分岐は到達不能（その中の `if self.mode == "CUSTOM"` も同様） | 高 |
| D-9 | [mslcm:1483-1486](../mslcm#L1483-L1486) | `enable-vpn-ha` は v2.0-c 用のプレースホルダ（使い方の表示にも出る）。ロードマップ上の意図があるなら残す | 高 |
| D-10 | [lib/pritunl_install.sh:104-106](../lib/pritunl_install.sh#L104-L106)、[:840-846](../lib/pritunl_install.sh#L840-L846)、[99_uninstall.sh:225-242](../99_uninstall.sh#L225-L242) | コメントアウトされた旧コード（yum の版固定、戻り経路の検証、クォータの restore） | 高 |
| D-11 | [scripts/pritunl_build_helper.py:915](../scripts/pritunl_build_helper.py#L915)、[:933](../scripts/pritunl_build_helper.py#L933) | `create_server` の引数 `dns_ip1` は使われておらず、`dns_servers` は `1.1.1.1` 固定。v1.4.6 の修正（DNS_IP1 にプライベート IP を指定すると VPN 接続中にインターネットに出られない問題）による意図的なものかもしれない（**推測**） | 高（意図は推測） |

---

## E. 設計文書と実装の食い違い

どちらが正しいかの判断はユーザーに委ねます。

### E-1. Pritunl のプロビジョニング方法
- **文書**（[ARCHITECTURE_AND_DESIGN_PRINCIPLES.md:71-89](../ARCHITECTURE_AND_DESIGN_PRINCIPLES.md)）: 「Pritunl API（VM 内で設定した key/secret）を使って Organization / Server を作成し、紐付けて起動する」「すべてドキュメント化された REST API でプロビジョニングする」
- **実装**: **Server は MongoDB に直接 insert して作成している**（[lib/pritunl_install.sh:562-594](../lib/pritunl_install.sh#L562-L594)、[scripts/pritunl_build_helper.py:1007-1009](../scripts/pritunl_build_helper.py#L1007-L1009)。関数のコメントも「bypasses GUI」）。Organization の作成・紐付け・起動は API で行っているが、認証は key/secret ではなく、ユーザー名 `pritunl` とデフォルトパスワードによるログイン（[lib/pritunl_install.sh:552](../lib/pritunl_install.sh#L552)）。
- **状態: 対応済み（文書を実装に合わせた、ユーザー判断 2026-09-24）**。「Server は VM 内のヘルパーで MongoDB に直接登録し、Organization の作成・紐付け・起動は初期管理者アカウントでログインした HTTP API で行う」と EN / JP の両方に記載した。

### E-2. 「MSL 独自の常駐サービスを持たない」
- **文書**（JP [ARCHITECTURE_AND_DESIGN_PRINCIPLES_jp.md:67](../ARCHITECTURE_AND_DESIGN_PRINCIPLES_jp.md)、EN "No long-running daemons"）
- **実装**: `msldhcp` がホストに `/usr/local/sbin/msl-dhcp-export-all` と systemd の `msl-dhcp-export-all.path` / `.service` をインストールし、SDN 設定の変更を監視して DHCP 設定をエクスポートし続ける（[msldhcp:518-522](../msldhcp#L518-L522)、[:1472-1499](../msldhcp#L1472-L1499)）。CT 内にも `msl-dhcp-source.path` を置いている。path unit は常駐プロセスではないが、「MSL 独自の実行時コンポーネント」であることは確か。keepalived の notify フック（`msl-vip-hook.sh`）は、JP 版の「既存基盤（keepalived）の仕組みを活用」の範囲内と読める。延期中の `0302` は inotify による監視サービスを導入する（リリースには同梱されていない）。
- **状態: 対応済み（文書に例外を明記、ユーザー判断 2026-09-24）**。msldhcp の path unit は opt-in で、隔離には関与せず、停止しても DHCP 設定の変更が反映されなくなるだけ、と EN / JP の両方に記載した。

### E-3. 設計文書の EN 版と JP 版の差
- JP 版の「設計ポリシー」には 3 つ目の項目「既存基盤の仕組みを活用（Proxmox、Pritunl、keepalived など）」があるが、EN 版には無い。EN 版の "No long-running daemons" は keepalived の導入（v2.0-b 以降）を前提にしていない書き方になっている。
- **状態: 対応済み**。EN 版に「Rely on existing components」を追加し、「No long-running daemons」を「No MSL-specific long-running daemons」に修正して JP 版と揃えた。

### E-4. Security Group の記述が残っている
- **文書**: README の 3.3 f「Firewall settings for these VMs are controlled by Security Groups (SG).」、[README_jp.md:204](../README_jp.md#L204)「このVMへのFW設定はSecurity Group(SG)で制御される。」、`.github/copilot-instructions.md` のフェーズ 3「Security Group 作成（pj-dev）」
- **実装**: v2.0 で Security Group は廃止し、DC レベルの FW ルールに置き換えている（[0102:360-464](../0102_setupNetwork.sh#L360-L464)）。
- **状態: 対応済み**。README / README_jp を「Datacenter レベルのルールで制御（同一プロジェクト内は許可、他のプライベートネットワーク宛は遮断）」に修正した。copilot-instructions の記述は E-9 で扱う。

### E-5. アンインストールの手順
- **文書**: README の Quickstart には「This will: 1. Destroy Pritunl VM 2. Restore network configuration」とある。
- **実装**: 4 ステップ（0301 RBAC の restore → VM の破棄 → クラスタの restore → ネットワークの restore）（[99_uninstall.sh:143-222](../99_uninstall.sh#L143-L222)）。
- **状態: 対応済み**。README（EN）を実際の 4 ステップに修正した。README_jp にはステップの記載が無いので、変更していない。

### E-6. 「元の状態に戻せる」という記述と、アンインストール後に残るもの
- **文書**（[GITHUB_WIKI_IMPACT_EN.md](../GITHUB_WIKI_IMPACT_EN.md)）: 「`99_uninstall.sh` removes the configuration added by MSL Setup and is intended to return to the pre-run state.」。実行フローの説明は v1.x のまま（0103 / mslcm / keepalived / msldhcp / if-up フックの記載が無い）。
- **実装**: 静的に読んだ限り、アンインストール後に次のものが残る。`/usr/local/bin/msldhcp`、msldhcp が作った DHCP CT・ホストの systemd unit・`/usr/local/sbin/msl-dhcp-export-all`・`/var/lib/mslsetup/`、`/usr/share/pve-manager/images/msl-setup-network-diagram.svg` とノード notes の図のブロック、`/var/lib/vz/snippets/pritunl-vm-*-userdata.yml`、クラウドイメージのキャッシュ。
- **状態: 後回し（リファクタリングで対応、ユーザー判断 2026-09-24）**

### E-7. スクリプトのヘッダ・メッセージに残る古いファイル名と説明
- [01_networkSetup.sh:12-17](../01_networkSetup.sh#L12-L17): 「0101_checkConfigNetwork.sh を実行する」とあるが、実際に実行するのは 0103 --restore → 0102 → 0103。
- ヘッダの Filename が古い名前: 0101（`00_check_env.sh`）、0102（`01_setup_sdn.sh`）、00（`0101_configNetwork.sh`。使い方の表示も同じ、[00:3119](../00_configNetwork.sh#L3119)）、0201（`02_deploy_pritunl.sh`）、0202（`03_pritunl_setup.sh`）。
- [0202_configurePritunl.sh:26-30](../0202_configurePritunl.sh#L26-L30) の Notes: 「Pritunl free version does not support API token authentication」「Organization/Server creation requires GUI」→ 現在は自動化されている。
- エラーメッセージが古いファイル名を案内している: [0201:330](../0201_createPritunlVM.sh#L330)（`01_setup_sdn.sh`）、[0202:59](../0202_configurePritunl.sh#L59)・[:92](../0202_configurePritunl.sh#L92)、[lib/env_generator.sh:58](../lib/env_generator.sh#L58)（生成される `.env` に「Re-run 00_check_env.sh」と書かれる）。
- [lib/pritunl_install.sh:59-68](../lib/pritunl_install.sh#L59-L68): コメントとリポジトリ名は「MongoDB 8.0」だが、baseurl は `8.2`。
- **状態: 後回し（古い記述の修正、ユーザー判断 2026-09-24）**

### E-8. 0102 のコメント「vpndmzvn インターフェースが存在する場合のみ設定」
- **場所**: [0102_setupNetwork.sh:466-470](../0102_setupNetwork.sh#L466-L470)
- **実装**: 存在は確認していない（フックを生成するだけ）。「VLAN IF の存在監視は持たない」という方針（CLAUDE.md 第 3 章 #3）とは実装の方が合っているので、古いのはコメントの方だと思われる。
- **状態: 後回し（古い記述の修正、ユーザー判断 2026-09-24）**

### E-9. `.github/copilot-instructions.md` と現行実装
- Pritunl VM の OS: 文書は Ubuntu 24.04 + ufw 無効化、実装は AlmaLinux 9 + SELinux（[0201:111-114](../0201_createPritunlVM.sh#L111-L114)）。
- 「VLAN タグ不要の実装（Linux bridge + vnet 使用）」→ 現在は VXLAN zone。
- 「ドキュメントやユーザー向けメッセージは日本語で記述する」→ 実装の既定は英語（`en`）。
- `PJALL_CIDR` の既定値: 文書は `172.16.16.0/20`、実装は `172.16.16.0/21`（[00_configNetwork.sh:87](../00_configNetwork.sh#L87)）。
- `set -euo pipefail` を使う規約 → `0301` は `set -uo pipefail`。
- **状態: 後回し（古い記述の修正、ユーザー判断 2026-09-24）**

### E-10. `.editorconfig` とコード
- `.editorconfig` は `*.sh` を 2 スペースインデントと定義しているが、実際のコードはほぼ 4 スペース。
- **状態: 対応済み**。`.editorconfig` の `*.sh` を 4 スペースに変更した（`lib/router_prompt.sh` だけは 2 スペースのまま）。

---

## F. 不具合の可能性がある点（観点外だが、整理の前に知っておいた方がよいもの）

### F-1. 単一ノード環境で、2 回目以降の `01_networkSetup.sh` と `99_uninstall.sh` が失敗する可能性
- **状態: 対応済み（2026-09-24、ブランチ `fix/0103-single-node-restore` のコミット `1bdc2ad`）**。pve20（非クラスタ）で、`01_networkSetup.sh` の繰り返し実行、`99_uninstall.sh`（Step 3 が成功し、mslcm と `/etc/pve/mslsetup` が削除された）、アンインストール後の再実行、`01_networkSetup.sh --restore` がすべて成功することを確認した。クラスタ環境（pve13/14/15 の 3 ノード）でも、`99_uninstall.sh` で del-node ×2 → disable-cluster → 後始末が従来どおり実行されることを確認した。`0103 --restore` は `cluster.env` が無ければ del-node / disable-cluster をスキップし、後始末（`cleanup_restore_artifacts`）だけを行うように変更。`get_cluster_status` はサブシェル内で exit しないように変更。`mslcm disable-cluster` は `cluster.env` を最後に削除するように変更。以下は修正前の分析。
- **実機での再現（修正前）**: 非クラスタの PVE（pve20）で、公開版を clone して `01_networkSetup.sh` を 2 回実行したところ、2 回目の Phase 1.1 で次のように失敗した（下記の推論と一致）。1 回目の Phase 1.3 では、`get_cluster_status` の「This node is not part of a cluster」が表示されず、`No cluster members detected.` だけが出ていた（メッセージが変数に吸い込まれていることの裏付け）。
  ```
  [INFO] Restore mode detected. Reading BACKUP entries from /etc/pve/mslsetup/cluster.env...
  [INFO] No BACKUP entries found in cluster.env.
  [INFO] Detaching node from MSL Setup control: ./mslcm disable-cluster
  [INFO] Proxmox cluster has not been created on this node yet.
  ...
  ERROR: Cluster setup restore failed
  ```
- **場所**: [0103_clusterSetup.sh:332-347](../0103_clusterSetup.sh#L332-L347)、[:470-490](../0103_clusterSetup.sh#L470-L490)、[:531-536](../0103_clusterSetup.sh#L531-L536)、[mslcm:117-124](../mslcm#L117-L124)、[mslcm:1454](../mslcm#L1454)
- **推論**:
  1. `get_cluster_status` は、非クラスタのときに `exit 0` するつもりで書かれているが、`status_output="$(get_cluster_status)"` のコマンド置換（サブシェル）の中で呼ばれているので、サブシェルが終わるだけでメインの処理は続く。
  2. 通常の実行では、クラスタかどうかに関係なく `install_mslcm_to_usr_local_bin` が `/etc/pve/mslsetup/.env` を作る。
  3. 2 回目の `01_networkSetup.sh` は、まず `0103 --restore` を実行する → `run_restore_flow` は `/etc/pve/mslsetup/.env` があるので続行 → `mslcm disable-cluster` → `check_cluster_state` は非クラスタなので `exit 1` → 0103 が失敗 → 01 が「Cluster setup restore failed」で終わる。`99_uninstall.sh` の Step 3 も同じ経路を通る。
- **確度**: 中（静的な読解による推論で、実機では再現していない。実際に問題なく動いているなら、見落としている前提があるはず）

### F-2. Corporate 版で、0301 を実行していないと `99_uninstall.sh` が Step 1 で止まる
- **場所**: [0301_setupSelfCarePortal.sh:866-871](../0301_setupSelfCarePortal.sh#L866-L871)、[99_uninstall.sh:146-157](../99_uninstall.sh#L146-L157)
- **推論**: `0301 --restore` は `rbac_backup/` が無いと `exit 1` する。99 は 0301 のファイルがあれば（Corporate 版なら常にある）これを呼び、失敗すると die する。`rbac_backup/` はリリースに含まれないので、0301 を一度も実行していない Corporate ユーザーはアンインストールできない。
- **確度**: 中〜高
- **補足（2026-09-24）**: pve20 で 0301 を実行しないまま `99_uninstall.sh` を実行したところ、問題なく完了した。ただしこの環境は Personal 版（公開リポジトリの clone）で、`0301_setupSelfCarePortal.sh` が存在しないため、Step 1 は「not Corporate Edition」としてスキップされていた。F-2 が問題にしているのは 0301 が存在する Corporate 版なので、この結果では F-2 の検証になっていない。
- **状態: 対応済み（コミット `3a6a5a1`）**。pve20 に 0301 を持ち込んで Corporate 版の状況を再現し、`0301 --restore` 単独での exit 0 と、`99_uninstall.sh` の完走を確認した（2026-09-24）。`--restore` のときにバックアップが無ければ「復元対象なし」として exit 0 するように変更した。restore 時に「No backup found. Creating initial backup...」が表示される誤表示も修正した。

### F-3. 再実行のたびに「PJ のインターネット遮断ルール」が増えていく
- **場所**: [0102_setupNetwork.sh:387-394](../0102_setupNetwork.sh#L387-L394)（作成）、[:228-236](../0102_setupNetwork.sh#L228-L236)（通常の再実行時の restore）、[lib/sdn_backup_restore.sh:410-435](../lib/sdn_backup_restore.sh#L410-L435)（削除対象のコメント一覧）
- **推論**: `MSLSetup Disallow internet access for PJxx` のルール（無効状態で作成される）は `managed_rule_comments` に含まれておらず、削除されるのは `--restore` のとき（[0102:212](../0102_setupNetwork.sh#L212)・[:220](../0102_setupNetwork.sh#L220)）だけ。`--restore` を付けずに `01_networkSetup.sh` を再実行すると、NUM_PJ 個ずつ重複して増えていく。
- **確認方法**: `01_networkSetup.sh` を 2 回実行したあとに次の参照コマンドを実行する。結果が `NUM_PJ` より大きければ再現している（F-1 の修正後なら、2 回目の実行が最後まで進むので確認できる）。
  ```bash
  pvesh get /cluster/firewall/rules --output-format json | jq '[.[] | select(.comment // "" | startswith("MSLSetup Disallow internet access"))] | length'
  ```
- **確度**: 高。pve20（非クラスタ、NUM_PJ=4）で 0102 を 3 回完走させたあと、カウントが 12 になり再現を確認した（2026-09-24）。
- **状態: 対応済み（コミット `432948c`）**。pve20 で修正後に 1 回実行し、カウントが 12 から 4 に減ったことを確認した（2026-09-24）。その後の F-4 の修正で、`remove_msl_project_inet_drop_rules` もパターン一致による全件削除に変更し、`head -n1` の問題も解消した。`managed_rule_comments` に `MSLSetup Disallow internet access for PJxx` を追加した。`remove_msl_project_inet_drop_rules`（`head -n1` で 1 件ずつしか消せない）の整理は A-2 と一緒に扱う。

### F-4. 前回の実行から `.env` が変わると、restore が古いルールを消せない
- **場所**: [lib/sdn_backup_restore.sh:420-435](../lib/sdn_backup_restore.sh#L420-L435)
- **推論**: DNS ルールと intra-vnet ルールの削除対象は、**現在の** `.env` の `DNS_IP1/2` と `NUM_PJ` から組み立てている。00 で `.env` を作り直した後（例: NUM_PJ を 8 から 4 に変更）に 01 を再実行すると、`MSLSetup Allow intra-vnet PJ05..08` や、変更前の DNS IP のルールが残る。存在しない `+sdn/vnetpj05-all` を参照するルールが残った場合に、FW のコンパイルがどうなるかは未確認（**推測**）。
- **確度**: 中
- **状態: 修正済み（ブランチ `fix/rule-cleanup-by-pattern`）**。pve20（非クラスタ）で確認した（2026-09-24）。NUM_PJ=4 でセットアップしたあと、00 で NUM_PJ=2 に変更（VPNDMZ/VPN_POOL/PJALL も変更）してから `01 --restore` を実行し、MSLSetup のルールがすべて削除された。その後の再セットアップでは PJ01/02 のルールだけが作成された。0301 は pve13 で確認した。NUM_PJ=4 で作成したあと、`.env` を NUM_PJ=2 に書き換えて `--restore` し、Selfcare のルールが 4 件とも削除された。0102 の FW ルールの処理はクラスタかどうかで変わらないため、クラスタでの再テストは不要と判断した（ユーザー判断）。
- **補足**: 0301 の restore の Step 2（ACL の削除、[0301:297-331](../0301_setupSelfCarePortal.sh#L297-L331)）は、まだ `NUM_PJ` でループしている。ただし、Proxmox はグループやプールを削除するとその ACL も自動で削除する（`PVE::AccessControl::delete_group_acl` / `delete_pool_acl`）。0301 はグループとプールをバックアップとの差分で削除するので、実害は無い。一貫性のためにパターン一致へ揃えるのは、低優先の整理候補。いったん保留（運用での回避）としたあと、方針を変えて修正した。DC FW ルールの削除を、`.env` の値から組み立てた完全一致ではなく、コメントのパターン一致に変更した（0102: `MSL_0102_RULE_COMMENT_REGEX` など、0301: `^MSLSetup Selfcare PJ[0-9]{2} GUI Access$`）。mslcm の VXLAN / VRRP ルールはパターンに含めない。「`MSLSetup` で始まるコメントは変更・流用しない」という運用ルールを README と README_jp の Known Issues に記載した。restore の中で `.env` に依存する処理として残っているのは VPN pool route の削除だけだが、経路は vpndmzvn と一緒に消えるので実害は無い。

### F-5. `set -e` の下で、エラーをログに残す処理が動かない
- **場所**: [lib/sdn_backup_restore.sh:157-185](../lib/sdn_backup_restore.sh#L157-L185)（`_pvesh_delete_logged` / `_route_del_logged`）、[0102_setupNetwork.sh:369-379](../0102_setupNetwork.sh#L369-L379)、[:397-399](../0102_setupNetwork.sh#L397-L399)、[:404-410](../0102_setupNetwork.sh#L404-L410)、[:284](../0102_setupNetwork.sh#L284)
- **推論**: `output=$(pvesh delete ...)` が失敗すると、`set -e` によってその行でスクリプトが終了する。そのため直後の `rc=$?` と log_error には到達しない（restore は削除に 1 つでも失敗した時点で、ログを残さずに止まる）。0102 の `pvesh create ... >/dev/null 2>&1` のうち `||` が付いていないものも、失敗すると stderr を捨てたまま無言で終了する。
- **確度**: 高（bash の仕様による）
- **状態: 修正済み（ブランチ `fix/pvesh-error-logging`、実機では未検証）**。`lib/common.sh` に `pvesh_logged` を追加し、0102 の pvesh 作成・削除・SDN apply と restore の SDN apply をこれ経由にした。失敗すると、ログファイルにコマンド、終了コード、pvesh の stderr を記録する。中断するか続行するかの挙動は変えていない（中断するものは `die "... See log: <path>"` で理由を表示する）。`_pvesh_delete_logged` と `_route_del_logged` は、`|| rc=$?` で終了コードを受け取るように直した。

### F-6. `mslcm enable-cluster` を手動で再実行すると BACKUP 行が消える
- **場所**: [mslcm:780-792](../mslcm#L780-L792)（`write_cluster_env` が `cluster.env` を丸ごと上書きする）
- **推論**: 0103 経由なら事前に restore されるので問題ない。しかし、すでにクラスタ化済みの状態で手動で `enable-cluster` を実行すると `BACKUP=` 行が失われ、あとで `0103 --restore` を実行してもそのノードに対して del-node が走らなくなる。
- **確度**: 中（運用上ありうる操作かどうかによる）
- **追記（2026-09-24）**: 再実行すると、MASTER の `auth_pass`（と VIP）だけが作り直され、BACKUP ノードとの VRRP 認証が一致しなくなる（スプリットブレインの恐れ。推測）。BACKUP 行が消えるより、こちらの方が影響が大きい。
- **状態: 対応済み（コミット `8afcacf`）**。pve13 で確認した（2026-09-24）。ガードによって enable-cluster が exit 1 で終了し、`cluster.env` と `keepalived.conf` に変化が無いことを md5 で確かめた。`01_networkSetup.sh` の restore と再構築も正常に完了し、add-node では「Appended BACKUP entry」が FW の有効化より前に出ていた。`cluster.env` に `BACKUP=` 行があるときだけ `enable-cluster` を拒否するようにした。add-node の前であれば、途中で失敗した enable-cluster のやり直しを許可するため。あわせて、`cmd_add_node` の `BACKUP=` の記録を、リモートへの変更より前に移した。これで add-node が途中で失敗しても、`0103 --restore` で del-node の対象になり、ガードの判定にも含まれる。

### F-7. `set_vnet_subnet_dhcp_range` のフォールバック ID
- B-9 を参照。フォールバックが使われた場合、`pvesh set` が失敗して [0102:275](../0102_setupNetwork.sh#L275) で止まる（`set -e` の下、`||` なし）。

### F-8. `die "... (exit code: $?)"` が常に 0 を表示する
- **場所**: [lib/pritunl_install.sh:73](../lib/pritunl_install.sh#L73)、[:94](../lib/pritunl_install.sh#L94)、[:178](../lib/pritunl_install.sh#L178)、[:496](../lib/pritunl_install.sh#L496)
- **推論**: `if ! cmd; then` の中の `$?` は否定した後の値なので 0 になる。表示だけの問題。
- **確度**: 高

### F-9. 0102 は `.env` と `sdn_backup` を相対パスで参照している
- **場所**: [0102_setupNetwork.sh:97](../0102_setupNetwork.sh#L97)、[:186](../0102_setupNetwork.sh#L186)
- **推論**: 0102 自身は `cd` しない。01 と 99 は `cd` してから呼ぶので問題ないが、別のディレクトリから 0102 を直接実行すると、別の場所の `.env` や `sdn_backup` を見に行く。
- **確度**: 高（影響は直接実行した場合だけ）

### F-10. クラスタ化済みの MASTER ノードでは `00_configNetwork.sh` を実行できない（2026-09-24、実機で判明）
- **場所**: [00_configNetwork.sh:2955-2982](../00_configNetwork.sh#L2955-L2982)（`_check_vmbr0_single_ipv4`）
- **事象**: pve13（クラスタの MASTER）で 00 を実行すると、keepalived の VIP（192.168.77.63）が vmbr0 に付いているため「Detected multiple IPv4 addresses on vmbr0.」と表示されて終了する。
- **影響**: クラスタ環境で `.env` を作り直すには、先に `01_networkSetup.sh --restore`（disable-cluster で keepalived が止まり、VIP が外れる）を実行する必要がある。これは F-4 の運用ルール（restore してから 00）と同じ順番なので、結果として運用ルールを守らせる形になっている。ただし、エラーメッセージは「テスト用・移行用の IP を外してください」という案内なので、利用者には原因が分かりにくい。
- **対応案（未決定）**: (a) `/etc/pve/mslsetup/cluster.env` の `MAIN_VIP` を除外して判定する。(b) VIP を検出したら「先に `01_networkSetup.sh --restore` を実行してください」と案内する。(b) は運用ルールと一貫していて、分かりやすい。
- **状態: 対応済み（コミット `2449d57`）**。pve13（MASTER、VIP あり）で案内が表示されることを確認した（2026-09-24）。(b) を採用した。`cluster.env` の `MAIN_VIP` と vmbr0 の IP が一致したら、「先に `./01_networkSetup.sh --restore` を実行してください」と案内して終了する。VIP 以外の余分な IP については従来のメッセージのまま。メッセージは既存のチェックに合わせて英語のみ。(a)（VIP を除外して続行する）を採用しなかったのは、`input_mainlan` / `input_pve_ip` も vmbr0 のすべての inet 行を拾っていて、修正範囲が広がるため。

### F-11. クラスタ化済みの環境で 0102 を単独で `--restore` すると、`vxlan_peers` IPSet を削除してしまう
- **場所**: [lib/sdn_backup_restore.sh](../lib/sdn_backup_restore.sh) の「Deleting IPSets not in backup」
- **推論**: restore は、バックアップに無い IPSet をすべて削除する。mslcm が作る `vxlan_peers` もバックアップに無いので削除対象になり、それを参照する VXLAN / VRRP ルール（mslcm の所有）だけが残る。`01_networkSetup.sh` と `99_uninstall.sh` は `0103 --restore`（disable-cluster）を先に実行するので、通常の手順では起きない。0102 を直接実行した場合だけの問題。
- **確度**: 中（静的な読解による。F-4 の修正とは関係ない既存の挙動）
- **状態: 未対応（低優先）**

### F-12. keepalived の削除で `apt-get autoremove -y --purge` を実行している（2026-09-24 追記）
- **場所**: [mslcm:763-771](../mslcm#L763-L771)（`remove_packages_local`）、[mslcm](../mslcm) の `cmd_del_node` の中にあるリモートでの purge
- **内容**: disable-cluster / del-node のたびに、keepalived と arping を purge したうえで `apt-get autoremove -y --purge` を実行する。クラスタで `01_networkSetup.sh` を再実行したとき（最初に restore が走る）や `99_uninstall.sh` を実行したときに、全ノードで実行される。
- **影響**: keepalived とは無関係な孤立パッケージも Proxmox ホストから削除される。さらに、MSL より前から keepalived を使っていた環境では、enable-cluster で `/etc/keepalived/keepalived.conf` が上書きされ、restore でパッケージごと purge される。
- **対応案**: keepalived / arping を MSL がインストールしたかどうかを記録し、自分が入れた場合だけ削除する。autoremove はやめる。
- **状態: 対応済み（コミット `49d8281`）**。pve13/14/15 で確認した（2026-09-24）。restore の前後でインストール済みパッケージ数が一致した（1304）。コマンドが無い場合だけインストールし、各ノードのローカルの `/var/lib/mslsetup/msl-installed-packages` に記録する。削除するときは、記録にあるパッケージだけを purge し、autoremove は行わない。ローカル（enable-cluster / disable-cluster）とリモート（add-node / del-node）で同じスクリプトを使う。偽の apt-get を使って 5 ケースを確認した。
- **移行時の注意**: 修正前のバージョンで keepalived を入れたノードには記録ファイルが無いので、restore しても keepalived はアンインストールされない（停止・無効化と設定ファイルの削除は従来どおり行われる）。
- **残っている課題**: MSL より前から keepalived を使っていた環境では、enable-cluster / add-node が `keepalived.conf` を上書きし、restore でサービスを停止して設定を削除する。パッケージが削除されることはなくなったが、設定の上書きは残っている。

### F-13. DC / ホストの FW の有効化に失敗しても続行する（2026-09-24 追記、B-11 と同じ系統）
- **場所**: [0102_setupNetwork.sh](../0102_setupNetwork.sh) の `Setting datacenter firewall options`（失敗しても `echo "[ERROR]"` のみ）と `Host firewall/nftables`（失敗しても `[WARN]` のみ）
- **影響**: FW が無効のままセットアップが「完了」と表示され、テナント間の隔離が効かない。
- **対応案**: どちらも失敗したら die する（`pvesh_logged ... || die`）。
- **状態: 対応済み（コミット `fde9786`）**。失敗を実機で再現するのが難しいため、コードを読んだ範囲での確認で OK とした（ユーザー判断）。どちらも `pvesh_logged` 経由にし、失敗したら die するようにした（コンソールにエラーとログのパスを表示し、pvesh の詳細はログファイルに記録）。原因を取り除いてから `01_networkSetup.sh` を再実行すれば、restore からやり直せる。

### F-14. 0301 が前提条件（Phase 1 の完了）を確認しないまま RBAC を作り始める（2026-09-24、実機で判明）
- **事象**: `01_networkSetup.sh --restore` の後（IPSet が無い状態）に 0301 を実行すると、pool / group / user / ACL を作ったあと、FW ルールの作成で `no such ipset 'vpn_guest_pool'` のエラーになって停止した。restore で片付くので、環境が壊れることはない。
- **状態: 対応済み（コミット `c47268c`）**。pve13 で、01 を実行していない状態では何も作らずに exit 1 で停止し、01 を実行した後は正常に完了することを確認した（2026-09-24）。セットアップ時（`--restore` 以外）は最初に IPSet `vpn_guest_pool` の存在を確認し、無ければ「Run ./01_networkSetup.sh first.」で停止する。
- **関連（対応しない）**: `exec_cmd_with_log` は失敗の詳細を stdout に出していて、呼び出し側が `> /dev/null` しているため、コンソールには `Command execution failed` しか出ない。詳細はログファイルに残っていて原因を調べられるので、今回は修正しない（ユーザー判断）。エラー処理の方法は、後でまとめて統一する可能性がある。

---

## G. その他の気づき

- **G-1. 平文のクレデンシャルがログに残る**: Pritunl のデフォルトパスワード（[0202:191](../0202_configurePritunl.sh#L191)）。0301 のユーザーパスワードは `exec_cmd_with_log` の `Command:` 行に出力される（[0301:158](../0301_setupSelfCarePortal.sh#L158)、[:737](../0301_setupSelfCarePortal.sh#L737)）。`logs/` は `.gitignore` の対象だが、ホスト上には残る。
  - Pritunl のデフォルトパスワード: **対応しない（ユーザー判断、2026-09-24、G-2 と同じ理由）**。
  - 0301 の Selfcare ユーザーのパスワード: `logs/msl-setup_*.log` に平文で出力されていることを実機で確認した（2026-09-24、pve13 の `logs/msl-setup_20260924_182109.log` と `logs/msl-setup_20260716_152519.log`）。**状態: 対応済み（コミット `78076ec`）**。`exec_cmd_with_log` で `--password '...'` を `***` にマスクし、ログファイルと失敗時のコンソール表示の両方に適用した。pve13 のログで `--password '***'` になっていることを確認した（2026-09-24）。作成したユーザーの一覧表をコンソールに一度だけ表示する動作は、意図したものなので変更しない。
- **G-2. Pritunl VM の root パスワードが全インストールで共通の固定値**（C-1）。SSH は MainLAN 側 IP でだけ待ち受けており、VM notes で変更を促してはいる。**状態: 対応しない（ユーザー判断、2026-09-24）**。VM notes で初回ログイン時の変更を促すことで対処とする。パスワードを乱数で生成しても notes に記載する以上は同じ問題が残る、という判断。
- **G-3. `.gitignore` の対象なのに git 管理されているもの**: `msl-setup-2.0.3/`、`msl-setup-2.1.0/` などのリリーススナップショット（`msl-setup-*/`）、`rbac_backup/*.json`（開発環境の RBAC 状態。内容は確認していないが、ユーザー名などが含まれる可能性がある）。 **状態: 対応済み（2026-09-24）**。`git rm --cached` で git の管理対象から外した（`msl-setup-2.0.3/`、`msl-setup-2.1.0/`、`msl-setup-pro-2.0.3_corporate/`、`msl-setup-pro-2.1.0_corporate/`、`rbac_backup/`）。ディスク上のファイルは残っている。過去のコミットの履歴には残っているので、`rbac_backup` の内容を履歴からも消す必要があれば、別途履歴の書き換えが必要。
- **G-4. エラー処理・ログの流儀がスクリプトごとに違う**: `0301` は `set -e` なし、`0103` / `mslcm` / `msldhcp` は独自のロガー（コンソールのみ、`logs/` に残らない）、01 / 02 / 0103 はメッセージを直書き。整理するときに統一するか、単独動作するコマンド（`mslcm` / `msldhcp`）は例外として残すかを決めておくとよい。
- **G-5. `msldhcp` はヘッダ形式が違う**（Zelogx の標準ヘッダが無く、中身のファイル名は `deploy-vnet-dhcp-ct-v9-strict-api.sh`）。
- **G-6. `todo.md`**: クォータ機能（0302 と `scripts/zelogx-quota-*`）は無期限延期と書かれている。整理の対象にするか、参考資料として残すかは判断が必要。
- **G-7. クラスタ処理が失敗したときの「Check logs for details: logs/」は誤った案内**: 0103 と `mslcm` はコンソールにしか出力しないので、`logs/` には手がかりが残らない。該当箇所は [01_networkSetup.sh:179](../01_networkSetup.sh#L179)・[:247](../01_networkSetup.sh#L247)・[:321](../01_networkSetup.sh#L321) と [99_uninstall.sh:197](../99_uninstall.sh#L197)。SDN（0102）、VM（0201/0202）、RBAC（0301）の失敗時の同じ案内は、各スクリプトが `logs/` に書いているので正しい。**状態: 対応済み（コミット `f9096ce`）**。クラスタ処理に関する 4 か所から案内を削除した。
- **G-8. `mslcm` の `check_cluster_state` のメッセージをサブコマンド間で共用している**: 非クラスタで `disable-cluster` / `add-node` / `del-node` を実行しても、「'mslcm enable-cluster' can only be used after creating a cluster.」と表示される（[mslcm:117-124](../mslcm#L117-L124)）。F-1 の修正で 0103 経由では発生しなくなり、表示されるのは手動で実行した場合だけ。**状態: 対応しない（ユーザー判断、2026-09-24）**。
