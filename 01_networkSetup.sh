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
#   ./01_networkSetup.sh [en|jp]
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

# Parse language argument (default: en)
LANG_ARG="${1:-en}"

if [[ "$LANG_ARG" != "en" && "$LANG_ARG" != "jp" ]]; then
    echo "Usage: $0 [en|jp]"
    echo "  en: English (default)"
    echo "  jp: Japanese"
    exit 1
fi

################################################################################
# Phase 1.1: Check and Configure Network Environment
################################################################################
echo ""
echo "=========================================="
if [[ "$LANG_ARG" == "jp" ]]; then
    echo "フェーズ 1.1: ネットワーク環境チェック"
else
    echo "Phase 1.1: Network Environment Check"
fi
echo "=========================================="
echo ""

if ! ./0101_checkConfigNetwork.sh "$LANG_ARG"; then
    if [[ "$LANG_ARG" == "jp" ]]; then
        echo ""
        echo "エラー: ネットワーク設定チェックが失敗しました"
        echo "詳細はログを確認してください: logs/"
    else
        echo ""
        echo "ERROR: Network configuration check failed"
        echo "Check logs for details: logs/"
    fi
    exit 1
fi

################################################################################
# Phase 1.2: Setup Proxmox SDN and Firewall
################################################################################
echo ""
echo "=========================================="
if [[ "$LANG_ARG" == "jp" ]]; then
    echo "フェーズ 1.2: Proxmox SDN セットアップ"
else
    echo "Phase 1.2: Proxmox SDN Setup"
fi
echo "=========================================="
echo ""

if ! ./0102_setupNetwork.sh "$LANG_ARG"; then
    if [[ "$LANG_ARG" == "jp" ]]; then
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
if [[ "$LANG_ARG" == "jp" ]]; then
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
