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

setup_cmd=(./0102_setupNetwork.sh "$LANG_ARG")
if [[ "$RESTORE_ONLY" == true ]]; then
    setup_cmd+=(--restore)
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
