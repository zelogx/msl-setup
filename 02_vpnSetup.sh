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

load_phase_uuid_or_exit "$LANG_ARG"
post_phase_probe_token "$LANG_ARG" "02_start"

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

post_phase_probe_token "$LANG_ARG" "02_done"

exit 0
