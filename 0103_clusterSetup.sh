#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: 0103_clusterSetup.sh
# Purpose: Cluster bootstrap wrapper for mslcm (enable-cluster + add-node loop)
#
# Main functions/commands used:
#   - pvecm status: Detect cluster membership and enumerate nodes
#   - mslcm enable-cluster: Enable HA cluster backend on initial node
#   - mslcm add-node: Register additional cluster members
#
# Dependencies:
#   - bash 4.0+
#   - pvecm
#   - ./mslcm
#
# Usage:
#   ./0103_clusterSetup.sh [--restore]
#
# Notes:
#   - This script is intended to run on the initial cluster node.
#   - If this node is not in a cluster, script exits successfully.
################################################################################

set -euo pipefail

RESTORE_MODE=false
MSL_LANG="en"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MSLCM_PATH="${SCRIPT_DIR}/mslcm"
STATE_DIR="/etc/pve/mslsetup"
CLUSTER_ENV_PATH="${STATE_DIR}/cluster.env"
SHARED_ENV_PATH="${STATE_DIR}/.env"
LOCAL_ENV_PATH="${SCRIPT_DIR}/.env"
MSLCM_INSTALL_PATH="/usr/local/bin/mslcm"

NOT_CLUSTER_MSG="Error: Corosync config '/etc/pve/corosync.conf' does not exist - is this node part of a cluster?"

################################################################################
# Function: log_info
# Description: Print informational message to stdout.
#
# Main commands/functions used:
#   - printf: Print formatted log line
################################################################################
log_info() {
    printf '[INFO] %s\n' "$*"
}

################################################################################
# Function: log_error
# Description: Print error message to stderr.
#
# Main commands/functions used:
#   - printf: Print formatted log line
################################################################################
log_error() {
    printf '[ERROR] %s\n' "$*" >&2
}

################################################################################
# Function: print_usage
# Description: Print command usage.
#
# Main commands/functions used:
#   - cat: Print usage text
################################################################################
print_usage() {
    if [[ "${MSL_LANG}" == "jp" ]]; then
        cat <<'USAGE'
Usage: ./0103_clusterSetup.sh [en|jp] [--restore]
  en|jp     : コンソール言語 (既定: en)
  --restore : クラスタ復元フローを実行
              (cluster.env の BACKUP を全て del-node 後、MASTER で disable-cluster)
USAGE
    else
        cat <<'USAGE'
Usage: ./0103_clusterSetup.sh [en|jp] [--restore]
  en|jp     : Console language (default: en)
  --restore : Run cluster teardown flow (del-node for all BACKUP entries,
              then disable-cluster on MASTER node)
USAGE
    fi
}

################################################################################
# Function: msg
# Description: Return localized message by key.
#
# Main commands/functions used:
#   - case: Select message per language and key
################################################################################
msg() {
    local key="$1"
    case "${MSL_LANG}:${key}" in
        jp:UNKNOWN_ARG) printf '%s' '不明な引数: %s' ;;
        en:UNKNOWN_ARG) printf '%s' 'Unknown argument: %s' ;;
        jp:PVECM_NOT_FOUND) printf '%s' 'pvecm コマンドが見つかりません' ;;
        en:PVECM_NOT_FOUND) printf '%s' 'pvecm command not found' ;;
        jp:MSLCM_NOT_FOUND) printf '%s' 'mslcm が見つかりません: %s' ;;
        en:MSLCM_NOT_FOUND) printf '%s' 'mslcm not found: %s' ;;
        jp:PVE_IP_NOT_SET) printf '%s' 'PVE_IP が未設定です (%s と %s を確認)' ;;
        en:PVE_IP_NOT_SET) printf '%s' 'PVE_IP is not set (checked %s and %s)' ;;
        jp:PJALL_NOT_SET) printf '%s' 'PJALL_CIDR が未設定です (%s と %s を確認)' ;;
        en:PJALL_NOT_SET) printf '%s' 'PJALL_CIDR is not set (checked %s and %s)' ;;
        jp:CLUSTER_ENV_NOT_FOUND) printf '%s' 'cluster.env が見つかりません: %s' ;;
        en:CLUSTER_ENV_NOT_FOUND) printf '%s' 'cluster.env not found: %s' ;;
        jp:MAIN_VIP_NOT_SET) printf '%s' '%s に MAIN_VIP が設定されていません' ;;
        en:MAIN_VIP_NOT_SET) printf '%s' 'MAIN_VIP is not set in %s' ;;
        jp:CLUSTER_ENV_ALREADY_HAS) printf '%s' 'cluster.env に既に記録があります: %s' ;;
        en:CLUSTER_ENV_ALREADY_HAS) printf '%s' 'cluster.env already has record: %s' ;;
        jp:APPENDED_CLUSTER_ENV) printf '%s' 'cluster.env に追記しました: %s' ;;
        en:APPENDED_CLUSTER_ENV) printf '%s' 'Appended to cluster.env: %s' ;;
        jp:NOT_CLUSTER_EXIT) printf '%s' 'このノードはクラスタに参加していないため、0103_clusterSetup.sh を正常終了します。' ;;
        en:NOT_CLUSTER_EXIT) printf '%s' 'This node is not part of a cluster. Exiting 0103_clusterSetup.sh successfully.' ;;
        jp:PVECM_STATUS_FAILED) printf '%s' 'pvecm status の実行に失敗しました' ;;
        en:PVECM_STATUS_FAILED) printf '%s' 'pvecm status failed' ;;
        jp:RESTORE_MODE_DETECTED) printf '%s' 'restore モードです。%s から BACKUP エントリを読み込みます...' ;;
        en:RESTORE_MODE_DETECTED) printf '%s' 'Restore mode detected. Reading BACKUP entries from %s...' ;;
        jp:RESTORE_SKIPPED_SHARED_ENV_MISSING) printf '%s' 'restore をスキップします: 共有 .env が見つかりません (%s)' ;;
        en:RESTORE_SKIPPED_SHARED_ENV_MISSING) printf '%s' 'Skipping restore: shared .env not found (%s)' ;;
        jp:NO_BACKUP_ENTRIES) printf '%s' 'cluster.env に BACKUP エントリがありません。' ;;
        en:NO_BACKUP_ENTRIES) printf '%s' 'No BACKUP entries found in cluster.env.' ;;
        jp:RUNNING_CMD) printf '%s' 'ノードをMSL Setupクラスタ制御下に移行中: %s' ;;
        en:RUNNING_CMD) printf '%s' 'Attaching node to MSL Setup cluster control: %s' ;;
        jp:RUNNING_CMD2) printf '%s' 'ノードをMSL Setup制御下から切り離し中: %s' ;;
        en:RUNNING_CMD2) printf '%s' 'Detaching node from MSL Setup control: %s' ;;
        jp:LINE_SEP) printf '%s' '================================' ;;
        en:LINE_SEP) printf '%s' '================================' ;;
        jp:RESTORE_COMPLETED) printf '%s' 'クラスタのリストアが完了しました' ;;
        en:RESTORE_COMPLETED) printf '%s' 'Cluster restore completed successfully' ;;
        jp:ROUTER_REMINDER) printf '%s' 'ルーターの設定を変更してください:' ;;
        en:ROUTER_REMINDER) printf '%s' 'Router configuration reminder:' ;;
        jp:CHANGE_ROUTE_RESTORE) printf '%s' 'Static routeの設定を変更してください: destination %s -> gateway %s' ;;
        en:CHANGE_ROUTE_RESTORE) printf '%s' 'Change Static route: destination %s -> gateway %s' ;;
        jp:SCRIPT_RESTORE_DONE) printf '%s' 'リストア処理が正常終了しました' ;;
        en:SCRIPT_RESTORE_DONE) printf '%s' 'Restore completed successfully' ;;
        jp:MSLCM_INSTALLED) printf '%s' 'mslcm を配置しました: %s -> %s' ;;
        en:MSLCM_INSTALLED) printf '%s' 'Installed mslcm: %s -> %s' ;;
        jp:SHARED_ENV_INSTALLED) printf '%s' '.env を共有領域へ配置しました: %s -> %s' ;;
        en:SHARED_ENV_INSTALLED) printf '%s' 'Installed shared .env: %s -> %s' ;;
        jp:MSLCM_INSTALL_FAILED) printf '%s' 'mslcm の配置に失敗しました: %s -> %s' ;;
        en:MSLCM_INSTALL_FAILED) printf '%s' 'Failed to install mslcm: %s -> %s' ;;
        jp:SHARED_ENV_SOURCE_NOT_FOUND) printf '%s' '.env が見つかりません: %s' ;;
        en:SHARED_ENV_SOURCE_NOT_FOUND) printf '%s' '.env not found: %s' ;;
        jp:SHARED_ENV_INSTALL_FAILED) printf '%s' '共有 .env の配置に失敗しました: %s -> %s' ;;
        en:SHARED_ENV_INSTALL_FAILED) printf '%s' 'Failed to install shared .env: %s -> %s' ;;
        jp:MSLCM_REMOVED) printf '%s' '/usr/local/bin から mslcm を削除しました: %s' ;;
        en:MSLCM_REMOVED) printf '%s' 'Removed mslcm from /usr/local/bin: %s' ;;
        jp:MSLCM_REMOVE_FAILED) printf '%s' 'mslcm の削除に失敗しました: %s' ;;
        en:MSLCM_REMOVE_FAILED) printf '%s' 'Failed to remove mslcm: %s' ;;
        jp:STATE_DIR_REMOVED) printf '%s' '状態ディレクトリを削除しました: %s' ;;
        en:STATE_DIR_REMOVED) printf '%s' 'Removed state directory: %s' ;;
        jp:STATE_DIR_REMOVE_FAILED) printf '%s' '状態ディレクトリの削除に失敗しました: %s' ;;
        en:STATE_DIR_REMOVE_FAILED) printf '%s' 'Failed to remove state directory: %s' ;;
        jp:DETECTING_CLUSTER) printf '%s' 'Proxmox クラスタ状態を検出中...' ;;
        en:DETECTING_CLUSTER) printf '%s' 'Detecting Proxmox cluster state...' ;;
        jp:CLUSTER_NOT_READY_SKIP) printf '%s' 'クラスタメンバーが未検出のため、クラスタセットアップをスキップして正常終了します。' ;;
        en:CLUSTER_NOT_READY_SKIP) printf '%s' 'No cluster members detected. Skipping cluster setup and exiting successfully.' ;;
        jp:CLUSTER_DETECTED_ENABLE) printf '%s' 'Proxmoxはクラスタ状態です。クラスタ設定に移行: ./mslcm enable-cluster' ;;
        en:CLUSTER_DETECTED_ENABLE) printf '%s' 'Cluster detected. Moving to cluster setup: ./mslcm enable-cluster' ;;
        jp:NO_ADDNODE_TARGETS) printf '%s' 'add-node 対象がありません (0x00000002 以降)。' ;;
        en:NO_ADDNODE_TARGETS) printf '%s' 'No add-node targets found (0x00000002 or later).' ;;
        jp:SETUP_COMPLETED) printf '%s' 'クラスタセットアップが完了しました' ;;
        en:SETUP_COMPLETED) printf '%s' 'Cluster setup completed successfully' ;;
        jp:CHANGE_ROUTE_SETUP) printf '%s' 'Static routeの設定を変更してください: destination %s -> gateway %s (VIP)' ;;
        en:CHANGE_ROUTE_SETUP) printf '%s' 'Change Static route: destination %s -> gateway %s (VIP)' ;;
        *) printf '%s' "$key" ;;
    esac
}

################################################################################
# Function: parse_args
# Description: Parse script arguments.
#
# Main commands/functions used:
#   - case: Argument branching
################################################################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            en|jp)
                MSL_LANG="$1"
                shift
                ;;
            --restore)
                RESTORE_MODE=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                log_error "$(printf "$(msg UNKNOWN_ARG)" "$1")"
                print_usage
                exit 1
                ;;
        esac
    done
}

################################################################################
# Function: require_prerequisites
# Description: Ensure required commands/files are present.
#
# Main commands/functions used:
#   - command -v: Check command availability
#   - test: Validate file presence
################################################################################
require_prerequisites() {
    if ! command -v pvecm >/dev/null 2>&1; then
        log_error "$(msg PVECM_NOT_FOUND)"
        exit 1
    fi

    if [[ ! -f "${MSLCM_PATH}" ]]; then
        log_error "$(printf "$(msg MSLCM_NOT_FOUND)" "${MSLCM_PATH}")"
        exit 1
    fi
}

################################################################################
# Function: resolve_master_ip
# Description: Resolve PVE_IP from shared env (preferred) or local .env.
#
# Main commands/functions used:
#   - source: Load key-value variables from env files
################################################################################
resolve_master_ip() {
    if [[ -f "${SHARED_ENV_PATH}" ]]; then
        # shellcheck disable=SC1090
        source "${SHARED_ENV_PATH}"
    elif [[ -f "${SCRIPT_DIR}/.env" ]]; then
        # shellcheck disable=SC1090
        source "${SCRIPT_DIR}/.env"
    fi

    if [[ -z "${PVE_IP:-}" ]]; then
        log_error "$(printf "$(msg PVE_IP_NOT_SET)" "${SHARED_ENV_PATH}" "${SCRIPT_DIR}/.env")"
        exit 1
    fi

    printf '%s\n' "$PVE_IP"
}

################################################################################
# Function: resolve_pjall_cidr
# Description: Resolve PJALL_CIDR from shared env (preferred) or local .env.
#
# Main commands/functions used:
#   - source: Load key-value variables from env files
################################################################################
resolve_pjall_cidr() {
    if [[ -f "${SHARED_ENV_PATH}" ]]; then
        # shellcheck disable=SC1090
        source "${SHARED_ENV_PATH}"
    elif [[ -f "${LOCAL_ENV_PATH}" ]]; then
        # shellcheck disable=SC1090
        source "${LOCAL_ENV_PATH}"
    fi

    if [[ -z "${PJALL_CIDR:-}" ]]; then
        log_error "$(printf "$(msg PJALL_NOT_SET)" "${SHARED_ENV_PATH}" "${LOCAL_ENV_PATH}")"
        exit 1
    fi

    printf '%s\n' "$PJALL_CIDR"
}

################################################################################
# Function: resolve_vip_ip
# Description: Resolve VIP IP from MAIN_VIP in cluster.env (CIDR -> IP only).
#
# Main commands/functions used:
#   - awk: Parse MAIN_VIP entry from cluster.env
################################################################################
resolve_vip_ip() {
    local main_vip

    if [[ ! -f "${CLUSTER_ENV_PATH}" ]]; then
        log_error "$(printf "$(msg CLUSTER_ENV_NOT_FOUND)" "${CLUSTER_ENV_PATH}")"
        exit 1
    fi

    main_vip="$(awk -F'=' '/^MAIN_VIP=/{print $2; exit}' "${CLUSTER_ENV_PATH}")"
    if [[ -z "$main_vip" ]]; then
        log_error "$(printf "$(msg MAIN_VIP_NOT_SET)" "${CLUSTER_ENV_PATH}")"
        exit 1
    fi

    printf '%s\n' "${main_vip%%/*}"
}

################################################################################
# Function: append_cluster_env_record
# Description: Append a single marker line to cluster.env if not already present.
#
# Main commands/functions used:
#   - grep: Deduplicate marker lines
#   - printf: Append record to file
################################################################################
append_cluster_env_record() {
    local record="$1"

    mkdir -p "${STATE_DIR}"
    touch "${CLUSTER_ENV_PATH}"

    if grep -Fxq "$record" "${CLUSTER_ENV_PATH}"; then
        log_info "$(printf "$(msg CLUSTER_ENV_ALREADY_HAS)" "${record}")"
        return 0
    fi

    printf '%s\n' "$record" >> "${CLUSTER_ENV_PATH}"
    log_info "$(printf "$(msg APPENDED_CLUSTER_ENV)" "${record}")"
}

################################################################################
# Function: get_cluster_status
# Description: Run pvecm status and return output through stdout.
#              If host is not part of a cluster, prints message and exits 0.
#
# Main commands/functions used:
#   - pvecm status: Cluster membership inspection
#   - grep: Detect non-cluster specific error text
################################################################################
get_cluster_status() {
    local status_output

    if ! status_output="$(pvecm status 2>&1)"; then
        if printf '%s\n' "$status_output" | grep -Fq "$NOT_CLUSTER_MSG"; then
            log_info "$(msg NOT_CLUSTER_EXIT)"
            exit 0
        fi

        log_error "$(msg PVECM_STATUS_FAILED)"
        printf '%s\n' "$status_output" >&2
        exit 1
    fi

    printf '%s\n' "$status_output"
}

################################################################################
# Function: run_mslcm
# Description: Execute mslcm subcommand with passthrough arguments.
#
# Main commands/functions used:
#   - bash: Execute mslcm script
################################################################################
run_mslcm() {
    local subcmd="$1"
    shift || true
    bash "$MSLCM_PATH" "$subcmd" "$@"
}

################################################################################
# Function: install_mslcm_to_usr_local_bin
# Description: Overwrite-copy mslcm into /usr/local/bin at script start.
#
# Main commands/functions used:
#   - install: Copy executable with mode and ownership
################################################################################
install_mslcm_to_usr_local_bin() {
    if install -m 0755 "${MSLCM_PATH}" "${MSLCM_INSTALL_PATH}"; then
        log_info "$(printf "$(msg MSLCM_INSTALLED)" "${MSLCM_PATH}" "${MSLCM_INSTALL_PATH}")"
    else
        log_error "$(printf "$(msg MSLCM_INSTALL_FAILED)" "${MSLCM_PATH}" "${MSLCM_INSTALL_PATH}")"
        exit 1
    fi

    if [[ ! -f "${LOCAL_ENV_PATH}" ]]; then
        log_error "$(printf "$(msg SHARED_ENV_SOURCE_NOT_FOUND)" "${LOCAL_ENV_PATH}")"
        exit 1
    fi

    mkdir -p "${STATE_DIR}"
    if [[ -e "${SHARED_ENV_PATH}" ]]; then
        rm -f "${SHARED_ENV_PATH}" || {
            log_error "$(printf "$(msg SHARED_ENV_INSTALL_FAILED)" "${LOCAL_ENV_PATH}" "${SHARED_ENV_PATH}")"
            exit 1
        }
    fi

    if cp "${LOCAL_ENV_PATH}" "${SHARED_ENV_PATH}"; then
        log_info "$(printf "$(msg SHARED_ENV_INSTALLED)" "${LOCAL_ENV_PATH}" "${SHARED_ENV_PATH}")"
        return 0
    fi

    log_error "$(printf "$(msg SHARED_ENV_INSTALL_FAILED)" "${LOCAL_ENV_PATH}" "${SHARED_ENV_PATH}")"
    exit 1
}

################################################################################
# Function: cleanup_restore_artifacts
# Description: Remove restore-only artifacts at the end of restore flow.
#
# Main commands/functions used:
#   - rm: Remove installed mslcm binary, local .env, and state directory
################################################################################
cleanup_restore_artifacts() {
    if [[ -e "${MSLCM_INSTALL_PATH}" ]]; then
        if rm -f "${MSLCM_INSTALL_PATH}"; then
            log_info "$(printf "$(msg MSLCM_REMOVED)" "${MSLCM_INSTALL_PATH}")"
        else
            log_error "$(printf "$(msg MSLCM_REMOVE_FAILED)" "${MSLCM_INSTALL_PATH}")"
            exit 1
        fi
    fi

    if [[ -e "${STATE_DIR}" ]]; then
        if rm -rf "${STATE_DIR}"; then
            log_info "$(printf "$(msg STATE_DIR_REMOVED)" "${STATE_DIR}")"
        else
            log_error "$(printf "$(msg STATE_DIR_REMOVE_FAILED)" "${STATE_DIR}")"
            exit 1
        fi
    fi
}

################################################################################
# Function: collect_add_node_targets
# Description: Collect target IPs from pvecm membership lines where nodeid is
#              0x00000002 or later, excluding local entry.
#
# Main commands/functions used:
#   - awk: Parse membership lines from pvecm status output
################################################################################
collect_add_node_targets() {
    local status_output="$1"

    printf '%s\n' "$status_output" \
        | awk '/^0x/ && $1 != "0x00000001" && $0 !~ /\(local\)/ {print $3}'
}

################################################################################
# Function: collect_backup_targets_from_cluster_env
# Description: Collect BACKUP node IPs from cluster.env.
#
# Main commands/functions used:
#   - awk: Parse BACKUP entries from cluster.env
################################################################################
collect_backup_targets_from_cluster_env() {
    if [[ ! -f "${CLUSTER_ENV_PATH}" ]]; then
        return 0
    fi

    awk -F'=' '/^BACKUP=/{print $2}' "${CLUSTER_ENV_PATH}" | awk '!seen[$0]++'
}

################################################################################
# Function: run_restore_flow
# Description: Restore flow: del-node for all BACKUP entries, then disable-cluster.
#
# Main commands/functions used:
#   - run_mslcm: Invoke del-node and disable-cluster
#   - mapfile: Build BACKUP IP list from cluster.env
################################################################################
run_restore_flow() {
    local backup_ips
    local ip
    local pjall_cidr
    local pve_ip

    if [[ ! -f "${SHARED_ENV_PATH}" ]]; then
        log_info "$(printf "$(msg RESTORE_SKIPPED_SHARED_ENV_MISSING)" "${SHARED_ENV_PATH}")"
        return 0
    fi

    log_info "$(printf "$(msg RESTORE_MODE_DETECTED)" "${CLUSTER_ENV_PATH}")"
    mapfile -t backup_ips < <(collect_backup_targets_from_cluster_env)

    if [[ "${#backup_ips[@]}" -eq 0 ]]; then
        log_info "$(msg NO_BACKUP_ENTRIES)"
    else
        for ip in "${backup_ips[@]}"; do
            log_info "$(msg LINE_SEP)"
            log_info "$(printf "$(msg RUNNING_CMD2)" "./mslcm del-node ${ip}")"
            run_mslcm del-node "$ip"
        done
    fi

    log_info "$(msg LINE_SEP)"
    log_info "$(printf "$(msg RUNNING_CMD2)" "./mslcm disable-cluster")"
    run_mslcm disable-cluster

    pjall_cidr="$(resolve_pjall_cidr)"
    pve_ip="$(resolve_master_ip)"

    log_info "$(msg LINE_SEP)"
    log_info "$(msg RESTORE_COMPLETED)"
    log_info "$(msg ROUTER_REMINDER)"
    log_info "$(printf "$(msg CHANGE_ROUTE_RESTORE)" "${pjall_cidr}" "${pve_ip}")"
    log_info "$(msg LINE_SEP)"
    log_info "$(msg SCRIPT_RESTORE_DONE)"

    cleanup_restore_artifacts
}

################################################################################
# Function: main
# Description: Orchestrate cluster setup: detect cluster, enable-cluster,
#              then add-node for 0x00000002 and later members.
#
# Main commands/functions used:
#   - get_cluster_status: Retrieve and validate cluster status
#   - run_mslcm: Invoke mslcm subcommands
#   - mapfile: Build target IP list for add-node loop
################################################################################
main() {
    local status_output
    local target_ips
    local ip
    local master_ip
    local pjall_cidr
    local vip_ip

    parse_args "$@"
    require_prerequisites

    # Skip mslcm/env installation during restore (will be cleaned up at end)
    if [[ "$RESTORE_MODE" != "true" ]]; then
        install_mslcm_to_usr_local_bin
    fi

    log_info "$(msg DETECTING_CLUSTER)"
    status_output="$(get_cluster_status)"

    if [[ "$RESTORE_MODE" == "true" ]]; then
        run_restore_flow
        exit 0
    fi

    # When no member lines exist yet, skip cluster setup as a successful no-op.
    if ! printf '%s\n' "$status_output" | grep -q '^0x'; then
        log_info "$(msg CLUSTER_NOT_READY_SKIP)"
        exit 0
    fi

    log_info "$(msg CLUSTER_DETECTED_ENABLE)"
    run_mslcm enable-cluster

    status_output="$(get_cluster_status)"
    mapfile -t target_ips < <(collect_add_node_targets "$status_output")

    if [[ "${#target_ips[@]}" -eq 0 ]]; then
        log_info "$(msg NO_ADDNODE_TARGETS)"
        exit 0
    fi

    for ip in "${target_ips[@]}"; do
        log_info "$(msg LINE_SEP)"
        log_info "$(printf "$(msg RUNNING_CMD)" "./mslcm add-node ${ip}")"
        run_mslcm add-node "$ip"
    done

    pjall_cidr="$(resolve_pjall_cidr)"
    vip_ip="$(resolve_vip_ip)"

    log_info "$(msg LINE_SEP)"
    log_info "$(msg SETUP_COMPLETED)"
    log_info "$(msg ROUTER_REMINDER)"
    log_info "$(printf "$(msg CHANGE_ROUTE_SETUP)" "${pjall_cidr}" "${vip_ip}")"
    log_info "$(msg LINE_SEP)"

}

main "$@"
