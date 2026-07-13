#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: 01_networkSetup.sh
# Purpose: Phase 1 orchestrator - Network configuration and SDN setup
#
# Main functions/commands used:
#   - 0101_checkConfigNetwork.sh: Environment configuration check and .env generation
#   - 0102_setupNetwork.sh: Proxmox SDN and firewall configuration
#
# Dependencies:
#   - 0101_checkConfigNetwork.sh
#   - 0102_setupNetwork.sh
#
# Usage:
#   ./01_networkSetup.sh [en|jp] [--restore]
#
# Notes:
#   - Executes sub-scripts sequentially
#   - Stops on first failure (die propagation)
#   - Language parameter (en/jp) is passed to all sub-scripts
################################################################################

set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/lib/common.sh"

UUID_FILE_PATH="$SCRIPT_DIR/.uuid"
MSL_SYSTEM_UUID=""
MSL_PROBE_TOKEN_RESPONSE=""

load_phase_uuid_or_exit() {
    local lang="$1"
    local uuid_value=""

    if [[ ! -f "$UUID_FILE_PATH" ]]; then
        if [[ "$lang" == "jp" ]]; then
            log_error ".uuid ファイルが見つかりません。先に ./00_configNetwork.sh jp を実行してください。" -c
        else
            log_error ".uuid file not found. Please run ./00_configNetwork.sh en first." -c
        fi
        exit 1
    fi

    uuid_value="$(tr -d '[:space:]' < "$UUID_FILE_PATH" || true)"
    if [[ -z "$uuid_value" ]]; then
        if [[ "$lang" == "jp" ]]; then
            log_error ".uuid ファイルが空です。先に ./00_configNetwork.sh jp を実行してください。" -c
        else
            log_error ".uuid file is empty. Please run ./00_configNetwork.sh en first." -c
        fi
        exit 1
    fi

    MSL_SYSTEM_UUID="$uuid_value"
    export MSL_UUID="$MSL_SYSTEM_UUID"
}

post_phase_probe_token() {
    local lang="$1"
    local phase_suffix="$2"
    local probe_url="https://msl-setup-probe.zelogx.com/api/v1/get_token?src=${MSL_SYSTEM_UUID}_${phase_suffix}"
    local body_file err_file http_code err_text

    body_file="$(mktemp)"
    err_file="$(mktemp)"

    http_code="$(curl -k -sS -o "$body_file" -w '%{http_code}' \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"magic":"ZELOGX"}' \
        "$probe_url" 2>"$err_file" || true)"

    err_text="$(tr '\n' ' ' < "$err_file" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"

    if [[ "$http_code" == 2* ]]; then
        MSL_PROBE_TOKEN_RESPONSE="$(tr -d '\r' < "$body_file")"
        export MSL_PROBE_TOKEN_RESPONSE
        log_info "Probe token request succeeded for ${phase_suffix} (HTTP ${http_code})"
    else
        if [[ -z "$err_text" ]]; then
            err_text="HTTP ${http_code:-000}"
        fi
        if [[ "$lang" == "jp" ]]; then
            log_error "Probe token request failed for ${phase_suffix} (${err_text})" -c
        else
            log_error "Probe token request failed for ${phase_suffix} (${err_text})" -c
        fi
    fi

    rm -f "$body_file" "$err_file"
}

print_usage() {
    cat <<'USAGE'
Usage: ./01_networkSetup.sh [en|jp] [--restore]
  en|jp      Console language (default: en)
  --restore  Restore SDN/firewall to backup state and exit
USAGE
}

LANG_ARG="en"
RESTORE_ONLY=false
LANG_SET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        en|jp)
            if [[ "$LANG_SET" == true ]]; then
                echo "ERROR: Multiple language codes specified"
                print_usage
                exit 1
            fi
            LANG_ARG="$1"
            LANG_SET=true
            shift
            ;;
        --restore)
            RESTORE_ONLY=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown argument: $1"
            print_usage
            exit 1
            ;;
    esac
done

load_phase_uuid_or_exit "$LANG_ARG"
post_phase_probe_token "$LANG_ARG" "01_start"

setup_cmd=(./0102_setupNetwork.sh "$LANG_ARG")
if [[ "$RESTORE_ONLY" == true ]]; then
    setup_cmd+=(--restore)
fi

cluster_cmd=(./0103_clusterSetup.sh "$LANG_ARG")
if [[ "$RESTORE_ONLY" == true ]]; then
    cluster_cmd+=(--restore)
fi

cluster_restore_cmd=(./0103_clusterSetup.sh "$LANG_ARG" --restore)

if [[ "$RESTORE_ONLY" == true ]]; then
    ################################################################################
    # Phase 1.1: Cluster Setup Restore (Restore first - reverse order)
    ################################################################################
    echo ""
    echo "=========================================="
    if [[ "$LANG_ARG" == "jp" ]]; then
        echo "フェーズ 1.1: クラスタ設定リストア"
    else
        echo "Phase 1.1: Cluster Setup Restore"
    fi
    echo "=========================================="
    echo ""

    if ! "${cluster_cmd[@]}"; then
        if [[ "$LANG_ARG" == "jp" ]]; then
            echo ""
            echo "エラー: クラスタ設定リストアが失敗しました"
            echo "詳細はログを確認してください: logs/"
        else
            echo ""
            echo "ERROR: Cluster setup restore failed"
            echo "Check logs for details: logs/"
        fi
        exit 1
    fi

    ################################################################################
    # Phase 1.2: Setup Proxmox SDN and Firewall Restore (run after cluster restore)
    ################################################################################
    echo ""
    echo "=========================================="
    if [[ "$LANG_ARG" == "jp" ]]; then
        echo "フェーズ 1.2: Proxmox SDN リストア"
    else
        echo "Phase 1.2: Proxmox SDN Restore"
    fi
    echo "=========================================="
    echo ""

    if ! "${setup_cmd[@]}"; then
        if [[ "$LANG_ARG" == "jp" ]]; then
            echo ""
            echo "エラー: SDN リストアが失敗しました"
            echo "詳細はログを確認してください: logs/"
        else
            echo ""
            echo "ERROR: SDN restore failed"
            echo "Check logs for details: logs/"
        fi
        exit 1
    fi

    ################################################################################
    # Phase 1 Restore Complete
    ################################################################################
    echo ""
    echo "=========================================="
    if [[ "$LANG_ARG" == "jp" ]]; then
        echo "フェーズ 1 完了: ネットワーク設定をバックアップ状態に復元しました"
    else
        echo "Phase 1 Complete: Network Configuration Restored to Backup State"
    fi
    echo "=========================================="
    echo ""

    exit 0
fi

################################################################################
# Phase 1.1: Cluster Setup Restore (pre-restore before normal setup)
################################################################################
echo ""
echo "=========================================="
if [[ "$LANG_ARG" == "jp" ]]; then
    echo "フェーズ 1.1: クラスタ設定リストア"
else
    echo "Phase 1.1: Cluster Setup Restore"
fi
echo "=========================================="
echo ""

if ! "${cluster_restore_cmd[@]}"; then
    if [[ "$LANG_ARG" == "jp" ]]; then
        echo ""
        echo "エラー: クラスタ設定リストアが失敗しました"
        echo "詳細はログを確認してください: logs/"
    else
        echo ""
        echo "ERROR: Cluster setup restore failed"
        echo "Check logs for details: logs/"
    fi
    exit 1
fi

################################################################################
# Phase 1.2: Setup Proxmox SDN and Firewall
################################################################################
echo ""
echo "=========================================="
if [[ "$RESTORE_ONLY" == true && "$LANG_ARG" == "jp" ]]; then
    echo "フェーズ 1.2: Proxmox SDN リストア"
elif [[ "$RESTORE_ONLY" == true ]]; then
    echo "Phase 1.2: Proxmox SDN Restore"
elif [[ "$LANG_ARG" == "jp" ]]; then
    echo "フェーズ 1.2: Proxmox SDN セットアップ"
else
    echo "Phase 1.2: Proxmox SDN Setup"
fi
echo "=========================================="
echo ""

if ! "${setup_cmd[@]}"; then
    if [[ "$RESTORE_ONLY" == true && "$LANG_ARG" == "jp" ]]; then
        echo ""
        echo "エラー: SDN リストアが失敗しました"
        echo "詳細はログを確認してください: logs/"
    elif [[ "$RESTORE_ONLY" == true ]]; then
        echo ""
        echo "ERROR: SDN restore failed"
        echo "Check logs for details: logs/"
    elif [[ "$LANG_ARG" == "jp" ]]; then
        echo ""
        echo "エラー: SDN セットアップが失敗しました"
        echo "詳細はログを確認してください: logs/"
    else
        echo ""
        echo "ERROR: SDN setup failed"
        echo "Check logs for details: logs/"
    fi
    exit 1
fi

if [[ "$RESTORE_ONLY" != true ]]; then
    echo ""
    if [[ "$LANG_ARG" == "jp" ]]; then
        echo "続行するには何かキーを押してください..."
    else
        echo "Press any key to continue..."
    fi
    read -n 1 -s -r
    echo ""

    ################################################################################
    # Phase 1.3: Cluster Setup
    ################################################################################
    echo ""
    echo "=========================================="
    if [[ "$LANG_ARG" == "jp" ]]; then
        echo "フェーズ 1.3: クラスタセットアップ"
    else
        echo "Phase 1.3: Cluster Setup"
    fi
    echo "=========================================="
    echo ""

    if ! "${cluster_cmd[@]}"; then
        if [[ "$LANG_ARG" == "jp" ]]; then
            echo ""
            echo "エラー: クラスタセットアップが失敗しました"
            echo "詳細はログを確認してください: logs/"
        else
            echo ""
            echo "ERROR: Cluster setup failed"
            echo "Check logs for details: logs/"
        fi
        exit 1
    fi
fi

################################################################################
# Phase 1 Complete
################################################################################
echo ""
echo "=========================================="
if [[ "$RESTORE_ONLY" == true && "$LANG_ARG" == "jp" ]]; then
    echo "フェーズ 1 完了: ネットワーク設定をバックアップ状態に復元しました"
elif [[ "$RESTORE_ONLY" == true ]]; then
    echo "Phase 1 Complete: Network Configuration Restored to Backup State"
elif [[ "$LANG_ARG" == "jp" ]]; then
    echo "フェーズ 1 完了: ネットワークセットアップ成功"
    echo ""
    echo "次のステップ:"
    echo "  1. ルーター設定を実施してください（前のステップで表示された指示に従う）"
    echo "  2. ルーター設定完了後、以下を実行:"
    echo "     ./02_vpnSetup.sh jp"
else
    echo "Phase 1 Complete: Network Setup Successful"
    echo ""
    echo "Next Steps:"
    echo "  1. Configure your router (follow instructions from previous step)"
    echo "  2. After router configuration, run:"
    echo "     ./02_vpnSetup.sh en"
fi
echo "=========================================="
echo ""

exit 0
