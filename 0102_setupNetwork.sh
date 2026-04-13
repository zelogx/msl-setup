#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: 01_setup_sdn.sh
# Purpose: Proxmox SDN構成（Zones, VNets, Subnets）を自動作成・適用する
#
# Main functions/commands used:
#   - pvesh: Proxmox API操作
#   - jq: JSON処理
#   - bash: 制御・冪等性
#
# Dependencies:
#   - pvesh, jq, bash
#
# Usage:
#   bash 01_setup_sdn.sh [en|jp]            # 通常実行（バックアップ→削除→再作成）
#   bash 01_setup_sdn.sh [en|jp] --restore  # リストアのみ（削除して終了）
#
# Notes:
#   - .envファイルを事前に生成しておくこと
#   - 冪等性を担保（既存設定は差分のみ適用）
################################################################################


set -euo pipefail

print_usage() {
        # Always show English usage (spec v2.0)
        cat <<'USAGE'
Usage: 01_setup_sdn.sh [en|jp] [--restore]
    en|jp       : Console language (default: en)
    --restore   : Restore SDN/firewall to backup state and exit
Notes:
    - Requires .env file with network variables
    - First run creates backup; subsequent runs are idempotent
USAGE
}

MSL_LANG=""
RESTORE_ONLY=false
LANG_SET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        en|jp)
            if [[ "$LANG_SET" == true ]]; then
                echo "[ERROR] Multiple language codes specified"
                print_usage
                exit 1
            fi
            MSL_LANG="$1"
            LANG_SET=true
            shift ;;
        --restore)
            RESTORE_ONLY=true ; shift ;;
        -h|--help)
            print_usage; exit 0 ;;
        *)
            echo "[ERROR] Unknown argument: $1"
            print_usage
            exit 1 ;;
    esac
done

# Default to English if no language specified
if [[ -z "$MSL_LANG" ]]; then
    MSL_LANG="en"
fi
export MSL_LANG

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Common library (logging, etc.)
# shellcheck source=/dev/null
source "$SCRIPT_ROOT/lib/common.sh"

 # RESTORE_ONLY already set in arg loop

# Multi-language messages (console output)
if [[ "${MSL_LANG}" == "en" ]]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_ROOT/lib/messages_en.sh"
else
    # shellcheck source=/dev/null
    source "$SCRIPT_ROOT/lib/messages_jp.sh"
fi

# Router prompt functions
# shellcheck source=/dev/null
source "$SCRIPT_ROOT/lib/router_prompt.sh"

# .env読込
env_file=".env"
if [[ ! -f "$env_file" ]]; then
    echo "[ERROR] $MSG_SDN_ENV_MISSING"
    exit 1
fi
source "$env_file"

################################################################################
# Function: update_env_var
# Description: Upsert key/value into the .env file (idempotent per key)
#
# Main commands/functions used:
#   - sed: Inline replacement for existing keys
#   - echo: Append when key is missing
################################################################################
update_env_var() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$env_file"; then
        sed -i "s/^${key}=.*/${key}=${value}/" "$env_file"
    else
        echo "${key}=${value}" >> "$env_file"
    fi
}

################################################################################
# Function: get_rule_pos_by_comment
# Description: Fetch datacenter firewall rule position by exact comment match
#
# Main commands/functions used:
#   - pvesh get: Retrieve firewall rules JSON
#   - jq: Filter by comment and extract pos
################################################################################
get_rule_pos_by_comment() {
    local node_name="$1"
    local comment="$2"
    pvesh get "/cluster/firewall/rules" --output-format json 2>/dev/null \
        | jq -r --arg c "$comment" '.[] | select(.comment==$c) | .pos' | head -n1
}

################################################################################
# Function: remove_msl_dc_access_rules
# Description: Remove MSL datacenter access rules by comment in reverse order
#
# Main commands/functions used:
#   - get_rule_pos_by_comment: Resolve firewall rule position by comment
#   - pvesh delete: Delete datacenter firewall rule
################################################################################
remove_msl_dc_access_rules() {
    local node_name="$1"
    local comments=(
        "MSLSetup Allow Spice from external network to DC"
        "MSLSetup Allow ssh from external network to DC"
        "MSLSetup Allow https from external network to DC"
    )
    local comment pos
    for comment in "${comments[@]}"; do
        pos=$(get_rule_pos_by_comment "$node_name" "$comment")
        if [[ -n "$pos" && "$pos" != "null" ]]; then
            log_info "Deleting datacenter firewall rule at position $pos (comment: $comment)"
            pvesh delete "/cluster/firewall/rules/$pos" >/dev/null 2>&1 || log_warn "Failed to delete datacenter firewall rule: $comment"
        fi
    done
}

################################################################################
# SDN設定バックアップ・リストア (moved to lib/sdn_backup_restore.sh)
################################################################################
backup_dir="sdn_backup"
mkdir -p "$backup_dir"
backup_complete_flag="$backup_dir/.backup_complete"
had_backup=false
if [[ -f "$backup_complete_flag" ]]; then
    had_backup=true
fi

# shellcheck source=/dev/null
source "$SCRIPT_ROOT/lib/sdn_backup_restore.sh"

# Backup/restore flow (v2.0):
# 1. If backup doesn't exist: create backup of initial (empty) state FIRST
# 2. If --restore specified: restore to backup state and exit
# 3. Else (normal run): if backup exists, restore first, then provision
if [[ "$had_backup" == false ]]; then
    log_info "No backup found. Creating initial state backup before provisioning..."
    msl_perform_backup
fi

if [[ "$RESTORE_ONLY" == true ]]; then
    if [[ "$had_backup" == true ]]; then
        log_info "Restore flag detected; performing restore and exiting"
        msl_restore_to_backup
        remove_msl_dc_access_rules "$(hostname)"
        remove_vpn_pool_route_hooks
        remove_project_gateway_hooks
        echo "[SUCCESS] $MSG_SDN_RESTORE_ONLY_DONE"
    else
        log_warn "Restore flag detected, but no backup existed at start; skipping restore"
        remove_msl_dc_access_rules "$(hostname)"
        remove_vpn_pool_route_hooks
        remove_project_gateway_hooks
        echo "[SUCCESS] $MSG_SDN_BACKUP_START"
    fi
    exit 0
fi

# Normal run: only restore if backup existed at start
if [[ "$had_backup" == true ]]; then
    log_info "Backup existed at start. Restoring to initial state before provisioning..."
    msl_restore_to_backup
    remove_msl_dc_access_rules "$(hostname)"
else
    log_info "First run (no prior backup). Skipping restore before provisioning."
fi

################################################################################
# SDN Zone作成
################################################################################
echo -n "$MSG_SDN_CREATING_ZONES"
zone_peer_ip="$PVE_IP"
log_info "Creating vpndmz as VXLAN with self peer: ${zone_peer_ip}"
log_info "Creating devpj zones as VXLAN with self peer: ${zone_peer_ip}"
log_info "MTU policy: use Proxmox default (AUTO) when available"
create_sdn_zone "vpndmz" "vxlan" "--ipam pve --peers ${zone_peer_ip}"
for i in $(seq 1 "$NUM_PJ"); do
    idx=$(printf '%02d' "$i")
    create_sdn_zone "devpj${idx}" "vxlan" "--ipam pve --peers ${zone_peer_ip}"
done
echo " [OK]"

################################################################################
# SDN VNet作成
################################################################################
echo -n "$MSG_SDN_CREATING_VNETS"
create_sdn_vnet "vpndmzvn" "vpndmz" "-tag 10000"
for i in $(seq 1 "$NUM_PJ"); do
    idx=$(printf '%02d' "$i")
    vnet_tag="100${idx}"
    create_sdn_vnet "vnetpj${idx}" "devpj${idx}" "-tag ${vnet_tag}"
done
echo " [OK]"

################################################################################
# SDN Subnet作成
################################################################################
echo -n "$MSG_SDN_CREATING_SUBNETS"
create_sdn_subnet "$VPNDMZ_CIDR" "vpndmzvn" "-gateway $VPNDMZ_GW"
for i in $(seq 1 "$NUM_PJ"); do
    idx=$(printf '%02d' "$i")
    cidr_var="PJ${idx}_CIDR"
    gw_var="PJ${idx}_GW"
    create_sdn_subnet "${!cidr_var}" "vnetpj${idx}" "-gateway ${!gw_var}"
done
echo " [OK]"

################################################################################
# SDN Apply
################################################################################
echo -n "$MSG_SDN_APPLY_START"
log_info "$MSG_SDN_APPLY_START"
pvesh set /cluster/sdn >/dev/null 2>&1
log_info "SDN configuration applied successfully"
echo " [OK]"

################################################################################
# IPSet作成
################################################################################
log_info "$MSG_SDN_IPSET_START"
echo "$MSG_SDN_IPSET_START"

# IPSet: devpjs (All development project networks)
log_info "Creating IPSet devpjs..."
# Create IPSet for devpjs
create_ipset "devpjs" "All development project networks"
# Adding entries for each project network
for i in $(seq 1 "$NUM_PJ"); do
    idx=$(printf '%02d' "$i")
    cidr_var="PJ${idx}_CIDR"
    cidr="${!cidr_var}"
    create_ipset_entry "devpjs" "${cidr}" "Project ${idx} network"
done
log_info "  IPSet devpjs created with $NUM_PJ entries"
echo " [OK]"

# IPSet: mainlan (MainLAN)
# Create IPSet mainlan
create_ipset "mainlan" "Main LAN network"
# CIDR の追加
create_ipset_entry "mainlan" "$ML_CIDR" "MainLAN"
log_info "  IPSet mainlan completed"
echo " [OK]"

# IPSet: vpn_guest_pool (VPN Client Pool)
log_info "Creating IPSet vpn_guest_pool..."
create_ipset "vpn_guest_pool" "VPN client IP pool"
create_ipset_entry "vpn_guest_pool" "$VPN_POOL" "VPN client pool"
echo " [OK]"

# IPSet: all_private_ip (All private IP ranges) - v2.0 added
create_ipset "all_private_ip" "All private IP address ranges (RFC1918 + loopback)"
create_ipset_entry "all_private_ip" "10.0.0.0/8" "Class A private"
create_ipset_entry "all_private_ip" "172.16.0.0/12" "Class B private"
create_ipset_entry "all_private_ip" "192.168.0.0/16" "Class C private"
create_ipset_entry "all_private_ip" "127.0.0.0/8" "Loopback"
echo " [OK]"
log_info "  IPSet all_private_ip completed with 4 entries"

################################################################################
# Datacenter Firewall Options設定 (v2.0: enable host firewall + nftables)
################################################################################
dc_fw_enable_initial=$(pvesh get /cluster/firewall/options --output-format json 2>/dev/null | jq -r '.enable // 0' || echo "0")
dc_fw_was_off=false
if [[ "$dc_fw_enable_initial" != "1" ]]; then
    dc_fw_was_off=true
fi

log_info "$MSG_SDN_FW_OPTIONS"
log_info "Datacenter firewall initial enable state: ${dc_fw_enable_initial}"
echo -n "Setting datacenter firewall options..."
if ! pvesh set /cluster/firewall/options -enable 1; then
    echo "[ERROR] $MSG_SDN_FW_OPTIONS_ERROR"
else
    echo " [OK]"
fi

# Enable host firewall and nftables (v2.0 added)
node_name=$(hostname)
log_info "Enabling host firewall and nftables on node $node_name..." -c
if pvesh set "/nodes/${node_name}/firewall/options" -enable 1 -nftables 1; then
    log_info "  Host firewall and nftables enabled successfully" -c
    echo "Host firewall/nftables........... [OK]"
else
    log_warn "  Failed to enable host firewall/nftables (may already be enabled)" -c
    echo "Host firewall/nftables........... [WARN]"
fi

################################################################################
# Datacenter-level Firewall Rules (v2.0: replaces Security Group pj-dev)
################################################################################
log_info "Creating datacenter-level FW rules..."
echo -n "Creating datacenter-level FW rules"

if [[ "$dc_fw_was_off" == true ]]; then
    log_info "  Datacenter firewall was OFF at start; adding DC access rules"
    log_info "  Access rule: IN ACCEPT +dc/all_private_ip → tcp/3128"
    pvesh create "/cluster/firewall/rules" \
        -pos 0 -action ACCEPT -type in -source "+dc/all_private_ip" -proto tcp -dport 3128 -enable 1 \
        -comment "MSLSetup Allow Spice from external network to DC" >/dev/null 2>&1
    log_info "  Access rule: IN ACCEPT +dc/all_private_ip → tcp/22"
    pvesh create "/cluster/firewall/rules" \
        -pos 0 -action ACCEPT -type in -source "+dc/all_private_ip" -proto tcp -dport 22 -enable 1 \
        -comment "MSLSetup Allow ssh from external network to DC" >/dev/null 2>&1
    log_info "  Access rule: IN ACCEPT +dc/all_private_ip → tcp/8006"
    pvesh create "/cluster/firewall/rules" \
        -pos 0 -action ACCEPT -type in -source "+dc/all_private_ip" -proto tcp -dport 8006 -enable 1 \
        -comment "MSLSetup Allow https from external network to DC" >/dev/null 2>&1
    echo -n "."
else
    log_info "  Datacenter firewall was already ON at start; skipping DC access rules"
fi

# Base DROP rule (always)
log_info "  DROP rule: FORWARD DROP +dc/devpjs → +dc/all_private_ip"
pvesh create "/cluster/firewall/rules" \
    -action DROP -type forward -source "+dc/devpjs" -dest "+dc/all_private_ip" -enable 1 \
    -comment "MSLSetup Drop devpjs to all private networks" >/dev/null 2>&1
echo -n "."
# DNS_IP1 (only if private)
if is_private_ip "${DNS_IP1:-}"; then
    log_info "  DNS rule: FORWARD ACCEPT +dc/devpjs → $DNS_IP1:53/udp"
    pvesh create "/cluster/firewall/rules" \
        -action ACCEPT -type forward -source "+dc/devpjs" -dest "$DNS_IP1" -dport 53 -proto udp -enable 1 \
        -comment "MSLSetup Allow DNS UDP to $DNS_IP1" >/dev/null 2>&1
    log_info "  DNS rule: FORWARD ACCEPT +dc/devpjs → $DNS_IP1:53/tcp"
    pvesh create "/cluster/firewall/rules" \
        -action ACCEPT -type forward -source "+dc/devpjs" -dest "$DNS_IP1" -dport 53 -proto tcp -enable 1 \
        -comment "MSLSetup Allow DNS TCP to $DNS_IP1" >/dev/null 2>&1
else
    log_info "  Skipping DNS_IP1 ($DNS_IP1) - not private"
fi
echo -n "."
# DNS_IP2 (only if defined and private)
if [[ -n "${DNS_IP2:-}" ]]; then
    if is_private_ip "$DNS_IP2"; then
        log_info "  DNS rule: FORWARD ACCEPT +dc/devpjs → $DNS_IP2:53/udp"
        pvesh create "/cluster/firewall/rules" \
            -action ACCEPT -type forward -source "+dc/devpjs" -dest "$DNS_IP2" -dport 53 -proto udp -enable 1 \
            -comment "MSLSetup Allow DNS UDP to $DNS_IP2" >/dev/null 2>&1 || log_warn "Failed to add DNS_IP2 UDP rule"
        log_info "  DNS rule: FORWARD ACCEPT +dc/devpjs → $DNS_IP2:53/tcp"
        pvesh create "/cluster/firewall/rules" \
            -action ACCEPT -type forward -source "+dc/devpjs" -dest "$DNS_IP2" -dport 53 -proto tcp -enable 1 \
            -comment "MSLSetup Allow DNS TCP to $DNS_IP2" >/dev/null 2>&1 || log_warn "Failed to add DNS_IP2 TCP rule"
    else
        log_info "  Skipping DNS_IP2 ($DNS_IP2) - not private"
    fi
fi
echo -n "."
# Intra-VNet communication rules (one per project)
for i in $(seq "$NUM_PJ" -1 1); do
    idx=$(printf '%02d' "$i")
    log_info "  Intra-VNet rule: FORWARD ACCEPT +sdn/vnetpj${idx}-all → +sdn/vnetpj${idx}-all"
    pvesh create "/cluster/firewall/rules" \
        -action ACCEPT -type forward -source "+sdn/vnetpj${idx}-all" -dest "+sdn/vnetpj${idx}-all" -enable 1 \
        -comment "MSLSetup Allow intra-vnet PJ${idx}" >/dev/null 2>&1 || log_warn "Failed to add vnetpj${idx} east-west rule"
    echo -n "."
done

# Allow icmp to gateways (created disabled; Phase 2 will enable just for validation)
icmp_rule1_comment="MSLSetup ICMP Prtn VPNDMZ GW"
icmp_rule2_comment="MSLSetup ICMP Prtn DEVPJS"
icmp_rule3_comment="MSLSetup ICMP Prtn MAINLAN ANY"

log_info "  ICMP rule1: in ACCEPT +sdn/vpndmzvn-no-gateway → +sdn/vpndmzvn-gateway"
pvesh create "/cluster/firewall/rules" \
    -action ACCEPT -type in -source "+sdn/vpndmzvn-no-gateway" -dest "+sdn/vpndmzvn-gateway" -proto icmp -enable 0 \
    -comment "$icmp_rule1_comment" >/dev/null 2>&1 || log_warn "Failed to add icmp rule1"
echo -n "."
log_info "  ICMP rule2: in ACCEPT +sdn/vpndmzvn-no-gateway → +dc/devpjs"
pvesh create "/cluster/firewall/rules" \
    -action ACCEPT -type in -source "+sdn/vpndmzvn-no-gateway" -dest "+dc/devpjs" -proto icmp -enable 0 \
    -comment "$icmp_rule2_comment" >/dev/null 2>&1 || log_warn "Failed to add icmp rule2"
echo -n "."
log_info "  ICMP rule3: in ACCEPT +dc/mainlan → any"
pvesh create "/cluster/firewall/rules" \
    -action ACCEPT -type in -source "+dc/mainlan" -proto icmp -enable 0 \
    -comment "$icmp_rule3_comment" >/dev/null 2>&1 || log_warn "Failed to add icmp rule3"
echo -n "."

# Keep ICMP rule comments as fixed identifiers in scripts (not persisted to .env)
echo " [OK]"
log_info "  Datacenter-level FORWARD/IN rules completed."

################################################################################
# 戻り経路設定 (VPN_POOL via PT_EG_IP)
# Note: vpndmzvnインターフェースが存在する場合のみ設定
################################################################################
persist_project_gateway_hooks
echo "Adding PJ gateway hooks.......... [OK]"
log_info "$MSG_SDN_DONE"

################################################################################
# FINAL STATE DUMP (complete details)
################################################################################
log_info "==== FINAL CONFIGURATION STATE ===="

# SDN Configuration - full JSON dumps
log_info "SDN Zones JSON (final):"
pvesh get /cluster/sdn/zones --output-format json 2>/dev/null | while IFS= read -r line; do
    log_info "  $line"
done

log_info "SDN VNets JSON (final):"
pvesh get /cluster/sdn/vnets --output-format json 2>/dev/null | while IFS= read -r line; do
    log_info "  $line"
done

final_vnets=$(pvesh get /cluster/sdn/vnets --output-format json 2>/dev/null | jq -r '.[].vnet' || echo "")
if [[ -n "$final_vnets" ]]; then
    for vnet in $final_vnets; do
        log_info "SDN Subnets for VNet $vnet JSON (final):"
        pvesh get /cluster/sdn/vnets/$vnet/subnets --output-format json 2>/dev/null | while IFS= read -r line; do
            log_info "  $line"
        done
    done
fi

# Firewall Configuration - full JSON dumps with all entries
log_info "Firewall IPSets JSON (final):"
pvesh get /cluster/firewall/ipset --output-format json 2>/dev/null | while IFS= read -r line; do
    log_info "  $line"
done

final_ipset_names=$(pvesh get /cluster/firewall/ipset --output-format json 2>/dev/null | jq -r '.[].name' || echo "")
if [[ -n "$final_ipset_names" ]]; then
    for ipset_name in $final_ipset_names; do
        log_info "IPSet '$ipset_name' entries JSON (final):"
        pvesh get /cluster/firewall/ipset/$ipset_name --output-format json 2>/dev/null | while IFS= read -r line; do
            log_info "  $line"
        done
    done
fi

log_info "Firewall Security Groups JSON (final):"
pvesh get /cluster/firewall/groups --output-format json 2>/dev/null | while IFS= read -r line; do
    log_info "  $line"
done

final_group_names=$(pvesh get /cluster/firewall/groups --output-format json 2>/dev/null | jq -r '.[].group' || echo "")
if [[ -n "$final_group_names" ]]; then
    for group_name in $final_group_names; do
        log_info "Security Group '$group_name' rules JSON (final):"
        pvesh get /cluster/firewall/groups/$group_name --output-format json 2>/dev/null | while IFS= read -r line; do
            log_info "  $line"
        done
    done
fi

# Route Configuration - all routes
log_info "All routes (final):"
ip route show 2>/dev/null | while IFS= read -r line; do
    log_info "  $line"
done

# Prompt user for router configuration (manual steps)
echo ""
echo "${MSG_MANUAL_STEPS}: ${MSG_ROUTER_CONFIG_TITLE}"
prompt_router_setup

log_info "==== SETUP COMPLETED SUCCESSFULLY ===="
