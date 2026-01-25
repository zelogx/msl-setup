#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: 02_vpnSetup.sh
# Purpose: Phase 2 orchestrator - VPN infrastructure deployment and configuration
#
# Main functions/commands used:
#   - 0201_createPritunlVM.sh: Deploy Pritunl VM with cloud-init
#   - 0202_configurePritunl.sh: Configure Pritunl servers, organizations, and users
#
# Dependencies:
#   - 0201_createPritunlVM.sh
#   - 0202_configurePritunl.sh
#
# Usage:
#   ./02_vpnSetup.sh [en|jp]
#
# Notes:
#   - Executes sub-scripts sequentially
#   - Stops on first failure (die propagation)
#   - Language parameter (en/jp) is passed to all sub-scripts
#   - Requires Phase 1 (01_networkSetup.sh) to be completed first
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

# Check if .env exists (Phase 1 prerequisite)
if [[ ! -f .env ]]; then
    if [[ "$LANG_ARG" == "jp" ]]; then
        echo ""
        echo "エラー: .env ファイルが見つかりません"
        echo "先にフェーズ 1 を実行してください: ./01_networkSetup.sh jp"
        echo ""
    else
        echo ""
        echo "ERROR: .env file not found"
        echo "Please run Phase 1 first: ./01_networkSetup.sh en"
        echo ""
    fi
    exit 1
fi

################################################################################
# Phase 2.1: Deploy Pritunl VM
################################################################################
echo ""
echo "=========================================="
if [[ "$LANG_ARG" == "jp" ]]; then
    echo "フェーズ 2.1: Pritunl VM デプロイ"
else
    echo "Phase 2.1: Pritunl VM Deployment"
fi
echo "=========================================="
echo ""

if ! ./0201_createPritunlVM.sh "$LANG_ARG"; then
    if [[ "$LANG_ARG" == "jp" ]]; then
        echo ""
        echo "エラー: Pritunl VM デプロイが失敗しました"
        echo "詳細はログを確認してください: logs/"
    else
        echo ""
        echo "ERROR: Pritunl VM deployment failed"
        echo "Check logs for details: logs/"
    fi
    exit 1
fi

################################################################################
# Phase 2.2: Configure Pritunl
################################################################################
echo ""
echo "=========================================="
if [[ "$LANG_ARG" == "jp" ]]; then
    echo "フェーズ 2.2: Pritunl 設定"
else
    echo "Phase 2.2: Pritunl Configuration"
fi
echo "=========================================="
echo ""

if ! ./0202_configurePritunl.sh "$LANG_ARG"; then
    if [[ "$LANG_ARG" == "jp" ]]; then
        echo ""
        echo "エラー: Pritunl 設定が失敗しました"
        echo "詳細はログを確認してください: logs/"
    else
        echo ""
        echo "ERROR: Pritunl configuration failed"
        echo "Check logs for details: logs/"
    fi
    exit 1
fi

################################################################################
# Phase 2 Complete
################################################################################
echo ""
echo "=========================================="
if [[ "$LANG_ARG" == "jp" ]]; then
    echo "フェーズ 2 完了: VPN セットアップ成功"
    echo ""
    echo "セットアップ完了！"
else
    echo "Phase 2 Complete: VPN Setup Successful"
    echo ""
    echo "Setup Complete!"
fi
echo "=========================================="
echo ""

exit 0
