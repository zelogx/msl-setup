#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: lib/probe.sh
# Purpose: Installation UUID loading and probe API notification shared by
#          01_networkSetup.sh and 02_vpnSetup.sh
#
# Main functions/commands used:
#   - load_phase_uuid_or_exit(): Load .uuid into MSL_SYSTEM_UUID / MSL_UUID
#   - post_phase_probe_token(): POST phase marker, set MSL_PROBE_TOKEN_RESPONSE
#
# Dependencies:
#   - lib/common.sh (PROJECT_ROOT, log_info, log_error)
#   - curl
#
# Usage:
#   source lib/common.sh
#   source lib/probe.sh
#   load_phase_uuid_or_exit "$LANG_ARG"
#   post_phase_probe_token "$LANG_ARG" "01_start"
#
# Notes:
#   - The data sent is documented in GITHUB_WIKI_DATA_SENT_*.md
################################################################################

UUID_FILE_PATH="${PROJECT_ROOT}/.uuid"
MSL_SYSTEM_UUID=""
MSL_PROBE_TOKEN_RESPONSE=""

################################################################################
# Function: load_phase_uuid_or_exit
# Description: Read the installation UUID from .uuid (created by 00) or exit
#
# Main commands/functions used:
#   - tr: Strip whitespace from .uuid
################################################################################
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

################################################################################
# Function: post_phase_probe_token
# Description: POST a phase marker to the probe API and keep the token response
#              (failure is reported but does not stop the caller)
#
# Main commands/functions used:
#   - curl: POST to msl-setup-probe.zelogx.com
################################################################################
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
        log_error "Probe token request failed for ${phase_suffix} (${err_text})" -c
    fi

    rm -f "$body_file" "$err_file"
}
