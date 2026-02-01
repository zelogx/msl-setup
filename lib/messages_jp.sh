#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: lib/messages_jp.sh
# Purpose: Japanese message definitions for interactive user input
#
# Main functions/commands used:
#   - Message variable definitions for JP locale
#
# Dependencies:
#   - None (pure variable definitions)
#
# Usage:
#   source lib/messages_jp.sh
#
# Notes:
#   - All user-facing messages in Japanese
#   - Loaded when LANG does not start with 'en'
################################################################################

# Welcome messages
MSG_WELCOME="Zelogx™ Multi-Project Secure Lab セットアップへようこそ"
MSG_STARTING="セットアップを開始します..."
MSG_PHASE="フェーズ"

# Uninstall messages
MSG_UNINSTALL_TITLE="Zelogx™ MSL セットアップ - アンインストール"
MSG_UNINSTALL_PREREQ_TITLE="重要: アンインストール前の準備事項"
MSG_UNINSTALL_PREREQ_WARN="vnetpjXXインターフェースを使用しているVMやCTが存在する場合、"
MSG_UNINSTALL_PREREQ_WARN2="アンインストール処理が正常に動作しない可能性があります。実行前に以下を確認してください:"
MSG_UNINSTALL_PREREQ_ITEM1="  - vnetpjXXネットワークを使用している全てのVM/CTを削除する、または"
MSG_UNINSTALL_PREREQ_ITEM2="  - それらのNICを別のブリッジ（例: vmbr0）に付け替える"
MSG_UNINSTALL_WARNING="警告: 以下のMSLセットアップ設定がすべて削除されます:"
MSG_UNINSTALL_ITEM1="  - セルフケアポータルおよびPool、ユーザーが削除されます"
MSG_UNINSTALL_ITEM2="  - Pritunl VMが破棄されます"
MSG_UNINSTALL_ITEM3="  - SDN設定が初期状態に復元されます"
MSG_UNINSTALL_ITEM4="  - すべてのネットワーク設定が元に戻されます"
MSG_UNINSTALL_CONFIRM="アンインストールを実行してもよろしいですか？ [y/N]"
MSG_UNINSTALL_CANCELLED="アンインストールがキャンセルされました。"
MSG_UNINSTALL_STARTING="アンインストール処理を開始します..."
MSG_UNINSTALL_STEP1="ステップ1: RBAC設定を削除しています..."
MSG_UNINSTALL_STEP2="ステップ2: Pritunl VMを破棄しています..."
MSG_UNINSTALL_STEP3="ステップ3: ネットワーク設定を復元しています..."
MSG_ASSUMING_NO_RBAC_OR_NO_CORPORATE_EDITION="RBAC設定の削除をスキップします（Corporate Editionではないか、関連スクリプトが見つかりません）。"
MSG_UNINSTALL_COMPLETE="アンインストールが正常に完了しました。"
MSG_UNINSTALL_FAILED="アンインストールに失敗しました。ログを確認してください。"

# Network discovery messages
MSG_DISCOVERING_NETWORK="既設ネットワークを探索しています..."
MSG_DETECTING_MAINLAN="MainLAN設定を検出しています..."
MSG_DETECTING_PVE_IP="Proxmox VE IPアドレスを検出しています..."
MSG_DETECTING_EXISTING="既設ネットワーク構成を検出しています..."
MSG_CHECKING_CONFLICTS="ネットワーク競合をチェックしています..."
MSG_NO_CONFLICTS="競合は検出されませんでした"
MSG_CONFLICTS_FOUND="警告: ネットワーク競合が検出されました"

# Interactive input prompts (a)-(i)
MSG_INPUT_MAINLAN_CIDR="MainLAN CIDR を入力してください"
MSG_INPUT_MAINLAN_GW="MainLAN ゲートウェイIPを入力してください"
MSG_DETECTED_MAINLAN="検出されたMainLAN設定"
MSG_CONFIRM_MAINLAN="この設定でよろしいですか？ [Y/n]"

MSG_INPUT_PVE_IP="Proxmox VE IPアドレスを入力してください"
MSG_DETECTED_PVE_IP="検出されたPVE IP"
MSG_CONFIRM_PVE_IP="この設定でよろしいですか？ [Y/n]"

MSG_INPUT_NUM_PJ="プロジェクト数 (NUM_PJ) を入力してください"
MSG_NUM_PJ_NOTE="注意: 2の累乗 (2, 4, 8, 16) で指定してください"
MSG_DEFAULT_NUM_PJ="デフォルト"
MSG_INVALID_NUM_PJ="エラー: プロジェクト数は 2, 4, 8, 16 のいずれかである必要があります"

MSG_INPUT_VPNDMZ_CIDR="VPN DMZ ネットワーク (VPNDMZ_CIDR) を入力してください"
MSG_VPNDMZ_NOTE="注意: 最低 /30 のネットワークが必要です"
MSG_SUGGEST_VPNDMZ="提案"

MSG_INPUT_VPN_POOL="VPN クライアントプール (VPN_POOL) を入力してください"
MSG_VPN_POOL_NOTE="注意: OpenVPN/WireGuard用に分割され、さらにプロジェクト数で分割されます"
MSG_SUGGEST_VPN_POOL="提案"
MSG_VPN_POOL_SPLIT="VPN Pool分割結果"

MSG_INPUT_PJALL_CIDR="プロジェクトネットワーク全体 (PJALL_CIDR) を入力してください"
MSG_PJALL_NOTE="注意: プロジェクト数に応じて各 /24 に分割されます"
MSG_SUGGEST_PJALL="提案"
MSG_PJALL_SPLIT="プロジェクトネットワーク分割結果"

MSG_INPUT_PT_IG_IP="Pritunl MainLAN側IP (PT_IG_IP) を入力してください"
MSG_PT_IG_NOTE="注意: ポートフォワードの転送先IPになります"
MSG_SUGGEST_PT_IG="提案"
MSG_CHECKING_ARP="ARPテーブルで使用状況を確認しています..."
MSG_IP_IN_USE="警告: このIPアドレスは使用中の可能性があります"
MSG_IP_AVAILABLE="このIPアドレスは使用可能です"

MSG_INPUT_PT_EG_IP="Pritunl VPN DMZ側IP (PT_EG_IP) を入力してください"
MSG_PT_EG_NOTE="注意: VPNクライアントから開発セグメントへの出口IPになります"
MSG_SUGGEST_PT_EG="提案"

MSG_INPUT_PORT_OVPN="(i-1) OpenVPN ポート範囲を入力してください"
MSG_INPUT_PORT_WG="(i-2) WireGuard ポート範囲を入力してください"
MSG_PORT_NOTE="注意: プロジェクト数分のポートが必要です"
MSG_SUGGEST_PORT_OVPN="提案 (OpenVPN)"
MSG_SUGGEST_PORT_WG="提案 (WireGuard)"
MSG_PORT_FORMAT="形式: 開始ポート-終了ポート (例: 11856-11863)"

MSG_INPUT_DNS1="DNS サーバー 1 を入力してください"
MSG_INPUT_DNS2="DNS サーバー 2 を入力してください"
MSG_SUGGEST_DNS="提案"

# Validation messages
MSG_INVALID_IP="エラー: 無効なIPアドレスです"
MSG_INVALID_CIDR="エラー: 無効なCIDR表記です"
MSG_NOT_NETWORK_ADDR="エラー: CIDRはネットワークアドレスを指定してください (例: %s)"
MSG_INVALID_PRIVATE_IP="エラー: プライベートIPアドレス範囲ではありません"
MSG_INVALID_PORT_RANGE="エラー: 無効なポート範囲です"
MSG_INSUFFICIENT_PORTS="エラー: ポート数が不足しています"
MSG_NETWORK_CONFLICT="エラー: ネットワークアドレスが競合しています"

# .env generation messages
MSG_GENERATING_ENV=".env ファイルを生成しています..."
MSG_ENV_GENERATED=".env ファイルが生成されました"
MSG_ENV_LOCATION="場所"

# SVG diagram generation messages
MSG_GENERATING_SVG="ネットワーク図 (SVG) を生成しています..."
MSG_SVG_GENERATED="ネットワーク図が生成されました"
MSG_SVG_LOCATION="場所"
MSG_VIEW_SVG="ネットワーク図を確認してください"

# Confirmation messages
MSG_REVIEW_SETTINGS="設定内容を確認してください"
MSG_CONFIRM_CONTINUE="この設定で続行しますか？ [Y/n]"
MSG_USER_CANCELLED="ユーザーによりキャンセルされました"
MSG_CONTINUING="続行します..."

# Phase completion messages
MSG_PHASE_COMPLETE="フェーズ完了"
MSG_NEXT_PHASE="次のフェーズ"
MSG_MANUAL_STEPS="手動設定が必要です"

# Router configuration messages
MSG_ROUTER_CONFIG_TITLE="ルーター設定 (手動操作が必要)"
MSG_ROUTER_PORT_FORWARD="ポートフォワード設定"
MSG_ROUTER_STATIC_ROUTE="スタティックルート設定"
MSG_ROUTER_CONFIG_COMPLETE="ルーター設定が完了したら次のスクリプトを実行してください"

# Router prompt (Phase0 last)
MSG_ROUTER_TITLE="ルーター設定のお願い"
MSG_ROUTER_INTRO="以下の設定をルーターに適用してください(値は自動展開済み):"
MSG_ROUTER_NEXT_STEP="設定完了後、次のフェーズに進んでください"

# VM cleanup messages
MSG_PREV_VM_FOUND="前回の実行で作成されたVM (VMID: %s) が見つかりました。"
MSG_PREV_VM_AUTOREMOVE="自動的に削除します..."
MSG_VM_STOPPING="  VMを停止中..."
MSG_VM_DESTROYING="  VMを完全削除中..."
MSG_VM_REMOVED="  削除完了。"

# Router prompt line formats
MSG_ROUTER_STATIC_ROUTE_LINE=" - スタティックルート: 宛先 %s → ゲートウェイ %s"
MSG_ROUTER_PF_OV_LINE=" - ポートフォワード (OpenVPN): %s-%s/UDP → %s"
MSG_ROUTER_PF_WG_LINE=" - ポートフォワード (WireGuard): %s-%s/UDP → %s"

# SVG generator messages
MSG_SVG_NOTICE="今からこの環境を生成します。ご確認お願いします。"
MSG_SVG_URL_LABEL="ネットワーク図URL:"
MSG_SVG_GUI_LABEL="または Proxmox GUI:"

# Port range input
MSG_PORT_RANGE_TITLE="(i) ポート範囲の入力"
MSG_PORT_RANGE_HINT_OV="OpenVPNのポート範囲を入力（例: 11856-11863）。デフォルトは開始+NUM_PJ-1で計算。"
MSG_PORT_RANGE_HINT_WG="WireGuardのポート範囲を入力（例: 15952-15959）。デフォルトは開始+NUM_PJ-1で計算。"
MSG_PORT_RANGE_COUNT_ERR="ポート数がNUM_PJと一致しません（現在: %d, 期待: %d）。再入力してください。"
MSG_PORT_RANGE_FORMAT_ERR="範囲の形式が不正です。例: 11856-11863"
MSG_PORT_RANGE_PROMPT_OV="OpenVPNポート範囲"
MSG_PORT_RANGE_PROMPT_WG="WireGuardポート範囲"

# SVG diagram note messages
MSG_SVG_NOTE_TITLE="Proxmox ノートへのネットワーク図追加"
MSG_SVG_NOTE_QUESTION="生成されたネットワーク図をProxmoxのノートに表示しますか？"
MSG_SVG_NOTE_DETAILS="追加内容:"
MSG_SVG_NOTE_COPY="  - SVGファイルを %s にコピー"
MSG_SVG_NOTE_APPEND="  - ノートに <img src=\"/pve2/images/%s\"> を追記"
MSG_SVG_NOTE_PRESERVE="  - 既存のノート内容は保持されます"
MSG_SVG_NOTE_LOCATION="表示場所: Datacenter > %s > Summary > Notes"
MSG_SVG_NOTE_CONFIRM="追加しますか?"

# Additional UI messages
MSG_AUTO_DETECTED_MAINLAN="自動検出されたMainLAN (vmbr0ネットワーク):"
MSG_NETWORK="ネットワーク"
MSG_GATEWAY="ゲートウェイ"
MSG_ENTER_MAINLAN_CIDR="MainLAN CIDRを入力"
MSG_ENTER_MAINLAN_GW="MainLAN ゲートウェイを入力"
MSG_AUTO_DETECTED_PVE="自動検出されたProxmox VE IP (vmbr0):"
MSG_IP_ADDRESS="IPアドレス"
MSG_ENTER_PVE_IP="Proxmox VE IPを入力"
MSG_PROPOSED_NUM_PJ="提案されたプロジェクト数"
MSG_PROPOSED_VPNDMZ="提案されたVPN DMZネットワーク（最小 /30）:"
MSG_VPN_POOL_SPLIT_DESC="VPNクライアントプールは以下のように分割されます："
MSG_VPN_POOL_FIRST_HALF="  - 前半(/25): OpenVPNクライアント用"
MSG_VPN_POOL_SECOND_HALF="  - 後半(/25): WireGuardクライアント用"
MSG_VPN_POOL_FURTHER_SPLIT="  - 各プロトコルプールはさらに%d個のサブネット(/%d)に分割"
MSG_VPN_POOL_MAX_CLIENTS="  - 各プロジェクトは最大%d人のVPNクライアントを持てます（プロトコル毎）"
MSG_PROPOSED_VPN_POOL="提案されたVPNクライアントプール:"
MSG_OVPN_POOL_PER_PJ="プロジェクト毎のOpenVPNプール："
MSG_WG_POOL_PER_PJ="プロジェクト毎のWireGuardプール："
MSG_ENTER_VPN_POOL="VPNクライアントプールのCIDRを入力"
MSG_PJ_NETWORK_SPLIT_DESC="プロジェクトネットワークは以下のように分割されます："
MSG_PJ_NETWORK_TOTAL="  - 全体ネットワーク: %s"
MSG_PJ_NETWORK_COUNT="  - %d個のプロジェクトネットワークに分割（各/%d）"
MSG_PJ_NETWORK_DEDICATED="  - 各プロジェクトは専用の/%dネットワークを持ちます"
MSG_PROPOSED_PJ_NETWORK="提案されたプロジェクトネットワーク:"
MSG_ENTER_PJ_NETWORK="プロジェクトネットワークのCIDRを入力"
MSG_NETWORK_CONFIG_FOR="このネットワークでの設定:"
MSG_TOTAL_NETWORK="全体ネットワーク"
MSG_PJ_NETWORK_SPLIT="プロジェクトネットワーク分割:"
MSG_PROPOSED_PT_IG="提案されたPritunl MainLAN側IP:"
MSG_ENTER_PT_IG="Pritunl MainLAN側IPを入力"
MSG_PROPOSED_PT_EG="提案されたPritunl VPN DMZ側IP:"
MSG_ENTER_PT_EG="Pritunl VPN DMZ側IPを入力"
MSG_PROPOSED_DNS1="提案されたDNSサーバー1:"
MSG_ENTER_DNS1="DNSサーバー1を入力"
MSG_PROPOSED_DNS2="提案されたDNSサーバー2（オプション）:"
MSG_ENTER_DNS2="DNSサーバー2を入力（Enterでデフォルト、'skip'で省略）"
MSG_SPLIT_RESULT_PREVIEW="分割結果のプレビュー:"
MSG_ERROR_PREFIX_TOO_SMALL="エラー: /%dは%d個のサブネットに分割できません（結果が/%dになります）。より大きなネットワークが必要です。"

# Error messages
MSG_ERROR_OCCURRED="エラーが発生しました"
MSG_ABORTING="中断しています..."
MSG_CHECK_LOG="詳細はログファイルを確認してください"


# Success messages
MSG_SUCCESS="成功"
MSG_COMPLETED="完了しました"

# Backup/Restore messages
MSG_BACKING_UP="バックアップを作成しています"
MSG_BACKUP_CREATED="バックアップが作成されました"
MSG_RESTORING="バックアップから復元しています"
MSG_RESTORED="復元が完了しました"

# Progress messages
MSG_PLEASE_WAIT="お待ちください..."
MSG_PROCESSING="処理中..."
MSG_CALCULATING="計算中..."

# Input prompt messages
MSG_INPUT_VPN_POOL="VPNクライアントプールの設定"
MSG_OVERLAPS_WITH="と重複しています"
MSG_NOT_PRIVATE_IP="プライベートIPではありません"
MSG_NUM_PJ_DESC="プロジェクト数を入力してください（2, 4, 8, または 16）"
MSG_NUM_PJ_PROMPT="プロジェクト数を入力"
MSG_NUM_PJ_ERROR="無効な値です。2, 4, 8, または 16 を入力してください。"
MSG_VPNDMZ_DESC="VPN DMZ ネットワークを入力してください（最小 /30）"
MSG_VPNDMZ_PROMPT="VPN DMZ CIDR を入力"
MSG_PREFIX_TOO_SMALL="プレフィックスが小さすぎます（最小 /30 が必要）"
MSG_INPUT_VPNDMZ="VPN DMZ ネットワークの設定"
MSG_INPUT_MAINLAN="MainLANの設定"
MSG_INPUT_PVE_IP="Proxmox VE IPの設定"
MSG_INPUT_NUM_PJ="プロジェクト数の設定"
MSG_FINDING_ALTERNATIVE="競合が検出されました。代替ネットワークを検索しています..."
MSG_SEARCHING="検索中"
MSG_ALTERNATIVE_FOUND="代替ネットワークが見つかりました"

# SDN (01_setup_sdn.sh) console messages
MSG_SDN_BACKUP_START="SDN・Firewall設定の初回バックアップを取得します..."
MSG_SDN_RESTORE_EXISTING="既存のバックアップが見つかりました。SDN・Firewall設定をバックアップ状態にリストアします..."
MSG_SDN_RESTORE_DONE="バックアップ状態へのリストアが完了しました"
MSG_SDN_RESTORE_ONLY_DONE="SDN設定をバックアップ状態にリストアしました。"
MSG_SDN_RESTORE_ONLY_NO_BACKUP="--restore が指定されましたがバックアップが存在しません。リストアをスキップします。"

MSG_SDN_APPLY_START="SDN設定を適用します..."
MSG_SDN_IPSET_START="IPSet作成を開始します..."
MSG_SDN_FW_OPTIONS="Datacenter Firewall Optionsを設定します..."
MSG_SDN_FW_OPTIONS_ERROR="Firewall Optionsの設定に失敗しました"
MSG_SDN_FW_RESTORE="Firewall設定をバックアップ状態にリストアします..."

MSG_SDN_CREATING_ZONES="SDNゾーンを作成中..."
MSG_SDN_CREATING_VNETS="SDN VNetを作成中..."
MSG_SDN_CREATING_SUBNETS="SDNサブネットを作成中..."
MSG_SDN_CREATING_IPSET="IPSetを作成中: "
MSG_SDN_DELETING_IN_PROGRESS="バックアップ状態に復元中（追加されたリソースを削除中）..."

MSG_SDN_ROUTE_PERSIST="VPN Pool経路を永続化します..."
MSG_SDN_ROUTE_CONFLICT="VPN Poolネットワークが直接接続されています。カスタム経路追加をスキップします。"
MSG_SDN_ROUTE_SKIP_NO_IFACE="vpndmzvnインターフェースが存在しません。戻り経路設定をスキップします。"

MSG_SDN_DONE="SDN設定が完了しました。"
MSG_SDN_ENV_MISSING=".envファイルが見つかりません。先に00_check_env.shを実行してください。"

# Usage / argument validation (v2.0)
## (Usage messages are English-only; no JP equivalents by project specification v2.0)

# ============================================================================
# VM Deployment Messages (Phase 2)
# ============================================================================

# VM インベントリ
MSG_VM_INVENTORY_COLLECT="既存VMインベントリを収集中..."
MSG_VM_INVENTORY_NONE="既存VMは見つかりませんでした。"
MSG_VM_INVENTORY_FOUND="%s個の既存VMが見つかりました。"

# VMID 割当
MSG_VM_VMID_SEARCH="%sから利用可能なVMIDを検索中..."
MSG_VM_VMID_ALLOCATED="割り当てられたVMID: %s"

# SSH鍵管理
MSG_VM_SSH_KEY_CHECK="SSHキーを確認中..."
MSG_VM_SSH_KEY_FOUND="既存のSSHキーを使用: %s"
MSG_VM_SSH_KEY_GENERATE="SSHキーが見つかりません。新しいキーを生成中..."
MSG_VM_SSH_KEY_GENERATED="新しいSSHキーを生成しました: %s"

# Cloud-Initイメージ
MSG_VM_IMAGE_DOWNLOAD="AlmaLinux 9.7 cloud-initイメージをダウンロード中..."
MSG_VM_IMAGE_CACHED="キャッシュされたcloud-initイメージを使用します。"
MSG_VM_IMAGE_VERIFY="イメージハッシュを検証中..."
MSG_VM_IMAGE_HASH_OK="イメージハッシュ検証成功。"
MSG_VM_IMAGE_HASH_FAIL="イメージハッシュ検証失敗。再ダウンロードします..."
MSG_VM_IMAGE_STORAGE_MULTIPLE="複数のイメージ格納先が見つかりました。どれを使用しますか?"
MSG_VM_IMAGE_STORAGE_SELECT="選択 (1-%s): "
MSG_VM_IMAGE_STORAGE_INVALID="無効な選択です。もう一度入力してください。"

# VM作成
MSG_VM_CREATE_START="Pritunl VMを作成中 (VMID: %s)..."
MSG_VM_CREATE_SUCCESS="VM作成成功。"
MSG_VM_START="VMを起動中..."

# Cloud-Init
MSG_VM_CLOUDINIT_WAIT="cloud-init完了を待機中 (タイムアウト: %s秒)..."
MSG_VM_CLOUDINIT_DONE="cloud-init完了。"
MSG_VM_CLOUDINIT_TIMEOUT="cloud-initタイムアウト。VMコンソールを確認: qm terminal %s"

# SSHアクセス
MSG_VM_SSH_VERIFY="SSHアクセスを検証中..."
MSG_VM_SSH_OK="SSHアクセス検証成功。"
MSG_VM_SSH_FAIL="%s回のリトライ後、SSHアクセス失敗。"

# ファイルコピーと検証
MSG_VM_COPY_ENV=".envをVMにコピー中..."
MSG_VM_COPY_SCRIPT="検証バイナリをVMにコピー中..."
MSG_VM_RUN_VALIDATION="VM上でリモート検証を実行中..."
MSG_VM_VALIDATION_OK="VM検証が正常に完了しました。"
MSG_VM_VALIDATION_FAIL="VM検証が失敗しました。詳細はログを確認してください。"
MSG_ICMP_ENABLE_START="検証用に一時的なICMP許可ルールを有効化します..."
MSG_ICMP_ENABLE_OK="ICMPルールを有効化しました (ID: %s)"
MSG_ICMP_ENABLE_SKIP="ICMPルールIDが不足/不正のためスキップ (%s)"
MSG_ICMP_ENABLE_FAIL="ICMPルールの有効化に失敗しました (ID: %s)"
MSG_ICMP_DISABLE_START="一時的なICMP許可ルールを無効化します..."
MSG_ICMP_DISABLE_OK="ICMPルールを無効化しました (ID: %s)"
MSG_ICMP_DISABLE_SKIP="ICMPルールIDが不足/不正のためスキップ (%s)"
MSG_ICMP_DISABLE_FAIL="ICMPルールの無効化に失敗しました (ID: %s)"

# 完了
MSG_VM_DEPLOY_COMPLETE="Pritunl VM展開が正常に完了しました！"
MSG_VM_ACCESS_INFO="VMアクセス情報:\n  VMID: %s\n  SSH: ssh root@%s"

# ============================================================================
# RBAC Self-Care Portal メッセージ (Phase 3.5)
# ============================================================================

# フェーズヘッダー
MSG_SELFCARE_PHASE_TITLE="フェーズ 3.5: RBAC セルフケアポータル セットアップ"
MSG_SELFCARE_PHASE_DESC="VPNユーザーがVM管理を行えるようProxmox RBACを設定します"

# バックアップ/リストア
MSG_SELFCARE_BACKUP_CHECK="既存のRBACバックアップを確認中..."
MSG_SELFCARE_BACKUP_FOUND="バックアップが見つかりました。処理を開始する前にバックアップ状態に復元します..."
MSG_SELFCARE_BACKUP_NOT_FOUND="バックアップが見つかりません。初期バックアップを作成します..."
MSG_SELFCARE_BACKUP_CREATED="初期RBAC状態を ./rbac_backup/ にバックアップしました"
MSG_SELFCARE_RESTORE_START="RBAC設定をバックアップ状態に復元中..."
MSG_SELFCARE_RESTORE_COMPLETE="復元が正常に完了しました。"
MSG_SELFCARE_RESTORE_ONLY="リストアのみモード: 復元後に終了します。"
MSG_SELFCARE_RESTORE_NO_BACKUP="エラー: バックアップが見つかりません。復元できません。"

# ACL競合チェック
MSG_SELFCARE_ACL_CHECK="ACL競合を確認中..."
MSG_SELFCARE_ACL_CONFLICT="エラー: ACL競合が検出されました。以下のパスが既に存在します:"
MSG_SELFCARE_ACL_OK="ACL競合は検出されませんでした。"

# ストレージ選択
MSG_SELFCARE_STORAGE_TITLE="プロジェクトプール用ストレージ選択"
MSG_SELFCARE_STORAGE_PROMPT="利用可能なストレージ:"
MSG_SELFCARE_STORAGE_INPUT="ストレージ番号を入力 (カンマ区切り, 例: 1,2) またはEnterで全選択: "
MSG_SELFCARE_STORAGE_CONFIRM_TITLE="ストレージ選択を確認:"
MSG_SELFCARE_STORAGE_SELECTED="  ✓ 選択済み"
MSG_SELFCARE_STORAGE_NOT_SELECTED="    未選択"
MSG_SELFCARE_STORAGE_CONFIRM="この設定を全てのプロジェクトに適用しますか？ [Y/n]: "
MSG_SELFCARE_STORAGE_CANCELLED="ストレージ選択がキャンセルされました。"
MSG_SELFCARE_STORAGE_INVALID="エラー: 無効なストレージ番号です。もう一度入力してください。"

# Pool/Group/User作成
MSG_SELFCARE_CREATE_POOLS="%s個のプロジェクトプールを作成中..."
MSG_SELFCARE_CREATE_POOL="プール作成中: %s"
MSG_SELFCARE_CREATE_GROUPS="%s個のプロジェクトグループを作成中..."
MSG_SELFCARE_CREATE_GROUP="グループ作成中: %s"
MSG_SELFCARE_CREATE_USERS="%s個のプロジェクトユーザーを作成中..."
MSG_SELFCARE_CREATE_USER="ユーザー作成中: %s"

# Permission割り当て
MSG_SELFCARE_ASSIGN_PERMS="プールとSDNゾーンにパーミッションを割り当て中..."
MSG_SELFCARE_ASSIGN_POOL_PERM="プールパーミッション割り当て: /pool/%s → %s (PVEAdmin)"
MSG_SELFCARE_ASSIGN_SDN_PERM="SDNパーミッション割り当て: %s → %s (PVEAdmin)"
MSG_SELFCARE_ASSIGN_STORAGE="プールにストレージを割り当て中: %s"

# Firewallルール
MSG_SELFCARE_FW_CREATE="Proxmoxダッシュボードアクセス用ノードファイアウォールルールを追加中..."
MSG_SELFCARE_FW_RULE="ルール追加: vpn_guest_pool → vnetpj%s-gateway:8006"
MSG_SELFCARE_FW_COMPLETE="%s個のファイアウォールルールを追加しました。"

# パスワード表示
MSG_SELFCARE_PASS_TITLE="╔════════════════════════════════════════════════════════════════╗"
MSG_SELFCARE_PASS_HEADER="║  重要: この認証情報を今すぐ安全な場所に保存してください！   ║"
MSG_SELFCARE_PASS_FOOTER="╚════════════════════════════════════════════════════════════════╝"
MSG_SELFCARE_PASS_TABLE_HEADER="プロジェクト | ユーザー名      | パスワード"
MSG_SELFCARE_PASS_TABLE_SEPARATOR="------------|-----------------|----------------------------------"
MSG_SELFCARE_PASS_INSTRUCTION="上記の認証情報を安全な場所にコピーしてください。"
MSG_SELFCARE_PASS_WARN="これらのパスワードは二度と表示されません。"

# 完了
MSG_SELFCARE_COMPLETE="RBACセルフケアポータルのセットアップが正常に完了しました！"
MSG_SELFCARE_SUMMARY="サマリー: %s個のプール、%s個のグループ、%s個のユーザー、%s個のファイアウォールルールを作成しました。"

# エラーメッセージ
MSG_SELFCARE_ERR_POOL_EXISTS="エラー: プール '%s' は既に存在します。"
MSG_SELFCARE_ERR_GROUP_EXISTS="エラー: グループ '%s' は既に存在します。"
MSG_SELFCARE_ERR_USER_EXISTS="エラー: ユーザー '%s' は既に存在します。"
MSG_SELFCARE_ERR_NO_STORAGE="エラー: プール割り当て用のストレージが利用できません。"
MSG_SELFCARE_ERR_CMD_FAILED="エラー: コマンド実行失敗: %s"

