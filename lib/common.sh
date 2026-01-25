#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: lib/common.sh
# Purpose: Common utility library for MSL setup scripts
#
# Main functions/commands used:
#   - log_info(): Information logging with timestamps
#   - log_error(): Error logging with timestamps
#   - log_warn(): Warning logging with timestamps
#   - die(): Error exit with cleanup
#   - backup_file(): File backup with timestamp
#   - restore_file(): File restoration from backup
#   - validate_ip(): IP address validation
#   - validate_cidr(): CIDR notation validation
#   - setup_logging(): Initialize logging with optional context name
#
# Dependencies:
#   - bash 4.0+
#   - coreutils (date, mkdir, cp, mv)
#
# Usage:
#   source lib/common.sh
#   setup_logging "script-name"
#
# Notes:
#   - All functions use English comments per coding standards
#   - User-facing messages must source messages_jp.sh or messages_en.sh
################################################################################

set -euo pipefail

# Global variables
# Renamed SCRIPT_DIR to COMMON_LIB_DIR to avoid collision with caller scripts
readonly COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${COMMON_LIB_DIR}/.." && pwd)"
readonly BACKUP_DIR="${PROJECT_ROOT}/backup"
readonly LOG_DIR="${PROJECT_ROOT}/logs"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Create required directories
mkdir -p "${BACKUP_DIR}" "${LOG_DIR}"

# Log file (base). Individual scripts may log context name.
readonly LOG_FILE="${LOG_DIR}/msl-setup_${TIMESTAMP}.log"

# Verbose mode flag (set by script arguments, default: false)
MSL_VERBOSE="${MSL_VERBOSE:-false}"

# -----------------------------------------------------------------------------
# Function: setup_logging
# Description: Provide an initialization entry and optional context name.
# -----------------------------------------------------------------------------
setup_logging() {
    local context_name="${1:-generic}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[INFO] [${timestamp}] Logging initialized for context: ${context_name}" >> "${LOG_FILE}"
    if [[ "${MSL_VERBOSE}" == "true" ]]; then
        echo "[INFO] [${timestamp}] Logging initialized for context: ${context_name} (log: ${LOG_FILE})"
    fi
}

#=============================================================================
# Function: get_msg
# Description: Retrieve a message string defined in message files by key.
# Usage: get_msg "VM_FOUND_PREVIOUS"
# Returns the value of variable MSG_<key> or empty string if not defined.
#=============================================================================
get_msg() {
    local key="$1"
    local varname="MSG_${key}"
    # Use indirect expansion to return the variable value if set
    printf "%s" "${!varname:-}"
}

#=============================================================================
# Function: msg_printf
# Description: Print formatted message from message variables to stdout/stderr
# Usage: msg_printf "VM_FOUND_PREVIOUS" "$PREVIOUS_VMID"
#=============================================================================
msg_printf() {
    local key="$1"
    shift || true
    local fmt
    fmt=$(get_msg "$key")
    if [[ -z "$fmt" ]]; then
        # Fallback: print key and args
        printf "%s\n" "$key" "$@"
        return 0
    fi
    # If there are arguments, pass them to printf
    if [[ $# -gt 0 ]]; then
        printf "$fmt\n" "$@"
    else
        printf "%s\n" "$fmt"
    fi
}

log_info() {
    local message="$1"
    local flag="${2:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[INFO] [${timestamp}] ${message}"
    echo "${log_line}" >> "${LOG_FILE}"
    # Console output if verbose mode or -c passed
    if [[ "${MSL_VERBOSE}" == "true" || "${flag}" == "-c" ]]; then
        echo "${log_line}"
    fi
}

log_error() {
    local message="$1"
    local flag="${2:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[ERROR] [${timestamp}] ${message}"
    echo "${log_line}" >> "${LOG_FILE}"
    # Only print to stderr if -c passed (or verbose mode forces console output)
    if [[ "${MSL_VERBOSE}" == "true" || "${flag}" == "-c" ]]; then
        echo "${log_line}" >&2
    fi
}

log_warn() {
    local message="$1"
    local flag="${2:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[WARN] [${timestamp}] ${message}"
    echo "${log_line}" >> "${LOG_FILE}"
    # Console output only if verbose mode or -c explicitly requested
    if [[ "${MSL_VERBOSE}" == "true" || "${flag}" == "-c" ]]; then
        echo "${log_line}"
    fi
}

die() {
    local message="$1"
    local exit_code="${2:-1}"
    # Ensure die still prints error to console by default
    log_error "${message}" -c
    exit "${exit_code}"
}

backup_file() {
    local file_path="$1"
    if [[ ! -f "${file_path}" ]]; then
        log_warn "File does not exist, skipping backup: ${file_path}"
        return 0
    fi
    local filename=$(basename "${file_path}")
    local backup_path="${BACKUP_DIR}/${filename}.${TIMESTAMP}.bak"
    if cp -p "${file_path}" "${backup_path}"; then
        log_info "Backed up: ${file_path} -> ${backup_path}"
        return 0
    else
        log_error "Failed to backup: ${file_path}"
        return 1
    fi
}

restore_file() {
    local file_path="$1"
    local filename=$(basename "${file_path}")
    local latest_backup=$(ls -1 "${BACKUP_DIR}/${filename}".*.bak 2>/dev/null | sort -r | head -n 1)
    if [[ -z "${latest_backup}" ]]; then
        log_error "No backup found for: ${file_path}"
        return 1
    fi
    if cp -p "${latest_backup}" "${file_path}"; then
        log_info "Restored: ${latest_backup} -> ${file_path}"
        return 0
    else
        log_error "Failed to restore: ${file_path}"
        return 1
    fi
}

validate_ip() {
    local ip="$1"
    local stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra OCTETS <<< "$ip"
        [[ ${OCTETS[0]} -le 255 && ${OCTETS[1]} -le 255 && \
           ${OCTETS[2]} -le 255 && ${OCTETS[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

validate_cidr() {
    local cidr="$1"
    if [[ ! $cidr =~ ^([0-9\.]+)/([0-9]+)$ ]]; then
        return 1
    fi
    local ip="${BASH_REMATCH[1]}"
    local prefix="${BASH_REMATCH[2]}"
    if ! validate_ip "${ip}"; then
        return 1
    fi
    if [[ ${prefix} -lt 0 || ${prefix} -gt 32 ]]; then
        return 1
    fi
    return 0
}

validate_private_ip() {
    local ip="$1"
    if ! validate_ip "${ip}"; then
        return 1
    fi
    IFS='.' read -ra OCTETS <<< "$ip"
    local first="${OCTETS[0]}"
    local second="${OCTETS[1]}"
    if [[ ${first} -eq 10 ]]; then
        return 0
    fi
    if [[ ${first} -eq 172 && ${second} -ge 16 && ${second} -le 31 ]]; then
        return 0
    fi
    if [[ ${first} -eq 192 && ${second} -eq 168 ]]; then
        return 0
    fi
    return 1
}


#===========================================================
# IPSet を新規作成する
#  - 既に存在している場合 or pvesh エラー時は exit 1
#  - 事前の存在チェックはしない（作れない＝異常）
#-----------------------------------------------------------
create_ipset() {
    local name="$1"
    local comment="$2"
    if [[ -z "$name" ]]; then
        log_error "create_ipset(): IPSet name is empty"
        exit 1
    fi
    echo -n "$MSG_SDN_CREATING_IPSET" "$name"
    log_info "Creating IPSet ${name}..."
    if ! pvesh create /cluster/firewall/ipset \
            -name "$name" \
            -comment "$comment"; then
        log_error "Failed to create IPSet ${name} (already exists or pvesh error)"
        exit 1
    fi
    log_info "  IPSet ${name} created"
    echo -n "."
}

#===========================================================
# IPSet にエントリ(CIDR)を追加する
#  - 追加に失敗したら exit 1
#-----------------------------------------------------------
create_ipset_entry() {
    local name="$1"
    local cidr="$2"
    local comment="$3"
    if [[ -z "$name" || -z "$cidr" ]]; then
        log_error "create_ipset_entry(): name or cidr is empty (name='${name}', cidr='${cidr}')"
        exit 1
    fi
    log_info "  Adding entry to ${name}: ${cidr} (${comment})"
    if ! pvesh create "/cluster/firewall/ipset/${name}" \
            -cidr "$cidr" \
            -comment "$comment"; then
        log_error "Failed to add CIDR=${cidr} to IPSet ${name}"
        exit 1
    fi
    echo -n "."
}

################################################################################
# Function: create_sdn_zone
# Description: SDN Zoneを作成（冪等性あり）
# Main commands/functions used:
#   - pvesh: Proxmox API操作
################################################################################
create_sdn_zone() {
    local zone_name="$1"
    local zone_type="$2"
    local params="$3"
    # 既存Zone一覧取得
    local exists=$(pvesh get /cluster/sdn/zones --output-format json | jq -r ".[] | select(.zone == \"$zone_name\") | .zone")
    if [[ "$exists" == "$zone_name" ]]; then
        log_info "SDN zone $zone_name already exists. Skipping."
        return 0
    fi
    log_info "Creating SDN zone $zone_name, Type: $zone_type, Params: $params"
    pvesh create /cluster/sdn/zones -zone "$zone_name" -type "$zone_type" $params
    log_info "  Zone $zone_name created successfully"
    echo -n "."
}

################################################################################
# Function: create_sdn_vnet
# Description: SDN VNetを作成（冪等性あり）
# Main commands/functions used:
#   - pvesh: Proxmox API操作
################################################################################
create_sdn_vnet() {
    local vnet_name="$1"
    local zone="$2"
    local params="$3"
    local exists=$(pvesh get /cluster/sdn/vnets --output-format json | jq -r ".[] | select(.vnet == \"$vnet_name\") | .vnet")
    if [[ "$exists" == "$vnet_name" ]]; then
        log_info "SDN VNet $vnet_name already exists. Skipping."
        return 0
    fi
    log_info "Creating SDN VNet $vnet_name, Zone: $zone, Params: $params"
    pvesh create /cluster/sdn/vnets -vnet "$vnet_name" -zone "$zone" $params
    log_info "  VNet $vnet_name created successfully"
    echo -n "."
}

################################################################################
# Function: create_sdn_subnet
# Description: SDN Subnetを作成（冪等性あり）
# Main commands/functions used:
#   - pvesh: Proxmox API操作
################################################################################
create_sdn_subnet() {
    local subnet_cidr="$1"
    local vnet="$2"
    local params="$3"
    # SubnetはVNet配下で管理されるため、VNet経由でチェック
    # subnet IDは zone-network-mask形式なので、CIDRフィールドで比較
    log_info "Creating SDN subnet $subnet_cidr, VNet: $vnet, Params: $params"
    if ! pvesh create /cluster/sdn/vnets/$vnet/subnets -subnet "$subnet_cidr" -type subnet $params; then
        log_info "Create SDN $vnet Subnet $subnet_cidr Param $params failed."
        return 1
    fi
    log_info "  Subnet $subnet_cidr created successfully"
    echo -n "."
}

################################################################################
# Function: persist_vpn_pool_route
# Description: Ensure VPN pool route persistence block exists in vpndmzvn iface block
# Main commands/functions used:
#   - awk: Insert route commands into vpndmzvn interface block
################################################################################
persist_vpn_pool_route() {
    local sdn_file="/etc/network/interfaces.d/sdn"
    
    if grep -q "up ip route add $VPN_POOL via $PT_EG_IP" "$sdn_file" 2>/dev/null; then
        log_info "Route persistence already configured in $sdn_file"
        return 0
    fi

    log_info "Adding route persistence to vpndmzvn interface block in $sdn_file"
    log_info "  Route: $VPN_POOL via $PT_EG_IP dev vpndmzvn"
    # Insert post-up/pre-down lines into vpndmzvn block (after last indented line)
    awk -v pool="$VPN_POOL" -v egip="$PT_EG_IP" '
    /^iface vpndmzvn/ { in_vpndmzvn=1; print; next }
    in_vpndmzvn && /^[[:space:]]/ { 
        buf = buf $0 "\n"
        next 
    }
    in_vpndmzvn && !/^[[:space:]]/ {
        # End of vpndmzvn block - insert routes before next section
        printf "%s", buf
        print "        post-up ip route add " pool " via " egip " dev vpndmzvn || true"
        print "        pre-down ip route del " pool " via " egip " dev vpndmzvn || true"
        in_vpndmzvn=0
        buf=""
        print
        next
    }
    { print }
    END {
        # If file ended while in vpndmzvn block
        if (in_vpndmzvn && buf != "") {
            printf "%s", buf
            print "        post-up ip route add " pool " via " egip " dev vpndmzvn || true"
            print "        pre-down ip route del " pool " via " egip " dev vpndmzvn || true"
        }
    }
    ' "$sdn_file" > "${sdn_file}.tmp"
    
    # Replace original with modified version
    mv "${sdn_file}.tmp" "$sdn_file"
    
    ifreload -a
    log_info "Route persistence configuration added successfully"
}

# Helper: private IP detection (RFC1918 only)
################################################################################
# Function: is_private_ip
# Description: Return 0 if IP is in RFC1918 ranges (10/8, 172.16-31/12, 192.168/16)
# Main commands/functions used:
#   - bash regex matching
################################################################################
is_private_ip() {
    local ip="$1"
    [[ -z "$ip" ]] && return 1
    [[ "$ip" =~ ^10\. ]] && return 0
    [[ "$ip" =~ ^192\.168\. ]] && return 0
    if [[ "$ip" =~ ^172\.([1-2][0-9]|3[0-1])\. ]]; then
        return 0
    fi
    return 1
}

################################################################################
# Function: check_vm_snapshot_exists
# Description: Check if VM snapshot exists using pvesh (Proxmox API)
#
# Parameters:
#   $1 - VM ID
#   $2 - Optional snapshot name (if not provided, looks for any snapshot)
#
# Returns: Outputs snapshot name if found (non-empty), exits with 0 if found, 1 if not
################################################################################
check_vm_snapshot_exists() {
    local vmid="$1"
    local snap_name="${2:-}"
    local node="$(hostname -s)"
    
    # Get snapshots list via pvesh
    local snapshots
    if ! snapshots=$(pvesh get /nodes/"${node}"/qemu/"$vmid"/snapshot --output=json 2>/dev/null); then
        return 1
    fi
    
    if [ -z "$snap_name" ]; then
        # Check if any snapshots exist (excluding "current")
        local latest_snap=$(echo "$snapshots" | jq -r '.[] | select(.name != "current") | .name' | tail -1 2>/dev/null)
        
        if [ -n "$latest_snap" ]; then
            echo "$latest_snap"
            return 0
        else
            return 1
        fi
    else
        # Check for specific snapshot
        if echo "$snapshots" | jq -e ".[] | select(.name == \"$snap_name\")" &>/dev/null; then
            echo "$snap_name"
            return 0
        else
            return 1
        fi
    fi
}

################################################################################
# Function: take_vm_snapshot
# Description: Create VM snapshot for retry capability
#
# Parameters:
#   $1 - VM ID
#   $2 - Snapshot name (default: msl-setup-<timestamp>)
#
# Main commands/functions used:
#   - qm: Proxmox VM snapshot management
################################################################################
take_vm_snapshot() {
    local vmid="$1"
    local snap_name="${2:-msl-setup-$(date +%s)}"
    
    log_info "Creating VM snapshot for retry capability..." -c
    log_info "  VM ID: ${vmid}" -c
    log_info "  Snapshot name: ${snap_name}" -c
    
    if qm snapshot "$vmid" "$snap_name" --description "MSL Setup checkpoint" 2>&1; then
        log_info "Snapshot created successfully: ${snap_name}" -c
        return 0
    else
        log_error "Failed to create VM snapshot"
        return 1
    fi
}

################################################################################
# Function: restore_from_vm_snapshot
# Description: Restores a VM from the specified snapshot checkpoint
#
# Parameters:
#   $1 - VM ID
#   $2 - Snapshot name
#
# Main commands/functions used:
#   - qm: Proxmox VM snapshot management
################################################################################
restore_from_vm_snapshot() {
    local vmid="$1"
    local snap_name="${2:-}"
    
    # Determine snapshot name - check via pvesh if not provided
    if [ -z "$snap_name" ]; then
        snap_name=$(check_vm_snapshot_exists "$vmid")
        if [ -z "$snap_name" ]; then
            log_error "No snapshot found for VM ${vmid}"
            return 1
        fi
    fi
    
    log_info "Restoring VM from snapshot..." -c
    log_info "  VM ID: ${vmid}" -c
    log_info "  Snapshot name: ${snap_name}" -c
    
    # Verify snapshot exists via pvesh API
    local node="$(hostname -s)"
    local snapshots_json
    snapshots_json=$(pvesh get /nodes/"${node}"/qemu/"$vmid"/snapshot --output=json 2>&1)
    local pvesh_rc=$?
    
    if [ $pvesh_rc -ne 0 ]; then
        log_error "Failed to list snapshots via pvesh (exit code: $pvesh_rc)"
        log_error "pvesh output: $snapshots_json"
        return 1
    fi
    
    # Check if snapshot exists in list
    if ! echo "$snapshots_json" | jq -e ".[] | select(.name == \"$snap_name\")" &>/dev/null; then
        log_error "Snapshot '${snap_name}' not found for VM ${vmid}"
        log_error "Available snapshots:"
        echo "$snapshots_json" | jq -r '.[] | "\(.name) (created: \(.snaptime))"' | while read -r snap_info; do
            log_error "  - $snap_info"
        done
        return 1
    fi
    
    # VM must be stopped before restore
    log_info "Stopping VM ${vmid}..."
    local vm_status
    vm_status=$(qm status "$vmid" 2>&1)
    log_info "Current VM status: $vm_status"
    
    if echo "$vm_status" | grep -q "running"; then
        log_info "VM is running, stopping it..."
        local stop_output
        stop_output=$(qm stop "$vmid" 2>&1)
        local stop_rc=$?
        if [ $stop_rc -ne 0 ]; then
            log_warn "qm stop returned exit code: $stop_rc"
            log_warn "qm stop output: $stop_output"
        fi
        sleep 3
    fi
    
    log_info "Performing rollback from snapshot: ${snap_name}" -c
    local rollback_output
    rollback_output=$(qm rollback "$vmid" "$snap_name" 2>&1)
    local rollback_rc=$?
    
    if [ $rollback_rc -eq 0 ]; then
        log_info "Snapshot rollback completed successfully" -c
        log_info "Rollback output: $rollback_output"
        
        # Start VM after rollback
        log_info "Starting VM ${vmid}..."
        local start_output
        start_output=$(qm start "$vmid" 2>&1)
        local start_rc=$?
        if [ $start_rc -eq 0 ]; then
            log_info "VM started successfully"
            sleep 3
        else
            log_error "Failed to start VM after rollback (exit code: $start_rc)"
            log_error "Start output: $start_output"
            return 1
        fi
        return 0
    else
        log_error "Rollback failed with exit code: $rollback_rc"
        log_error "Rollback output: $rollback_output"
        return 1
    fi
}

log_info "Common library loaded successfully"