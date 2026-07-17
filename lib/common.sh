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

# Log file (base). Use MSL_TIMESTAMP from environment if available (for session-wide unified logging),
# otherwise fall back to script-local timestamp.
if [[ -n "${MSL_TIMESTAMP:-}" ]]; then
    readonly LOG_FILE="${LOG_DIR}/msl-setup_${MSL_TIMESTAMP}.log"
else
    readonly LOG_FILE="${LOG_DIR}/msl-setup_${TIMESTAMP}.log"
fi

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
# Function: ipv4_to_int
# Description: Convert dotted IPv4 string to unsigned integer
# Main commands/functions used:
#   - bash arithmetic: Convert octets to 32-bit integer
################################################################################
ipv4_to_int() {
    local ip="$1"
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    printf '%u\n' "$(( (a << 24) + (b << 16) + (c << 8) + d ))"
}

################################################################################
# Function: int_to_ipv4
# Description: Convert unsigned integer to dotted IPv4 string
# Main commands/functions used:
#   - bash arithmetic: Extract octets from 32-bit integer
################################################################################
int_to_ipv4() {
    local int_ip="$1"
    local o1 o2 o3 o4
    o1=$(( (int_ip >> 24) & 255 ))
    o2=$(( (int_ip >> 16) & 255 ))
    o3=$(( (int_ip >> 8) & 255 ))
    o4=$(( int_ip & 255 ))
    printf '%d.%d.%d.%d\n' "$o1" "$o2" "$o3" "$o4"
}

################################################################################
# Function: calculate_project_dhcp_range
# Description: Calculate DHCP range as host-min to (host-max - 2) for CIDR
# Main commands/functions used:
#   - ipcalc: Get host range from CIDR
#   - ipv4_to_int/int_to_ipv4: Adjust end address by 2
################################################################################
calculate_project_dhcp_range() {
    local cidr="$1"
    local calc_out host_min host_max
    local start_int end_int

    calc_out=$(ipcalc "$cidr" 2>/dev/null || true)
    host_min=$(printf '%s\n' "$calc_out" | awk '/^HostMin:/ {print $2; exit}')
    host_max=$(printf '%s\n' "$calc_out" | awk '/^HostMax:/ {print $2; exit}')

    if [[ -z "$host_min" || -z "$host_max" ]]; then
        log_error "Unable to calculate host range from CIDR: $cidr"
        return 1
    fi

    start_int=$(ipv4_to_int "$host_min")
    end_int=$(( $(ipv4_to_int "$host_max") - 2 ))

    if (( end_int < start_int )); then
        log_error "Calculated DHCP range is invalid for CIDR: $cidr"
        return 1
    fi

    printf '%s-%s\n' "$host_min" "$(int_to_ipv4 "$end_int")"
}

################################################################################
# Function: set_vnet_subnet_dhcp_range
# Description: Set DHCP range for a specific VNet subnet
# Main commands/functions used:
#   - pvesh set: Update SDN subnet dhcp-range property
################################################################################
set_vnet_subnet_dhcp_range() {
    local vnet="$1"
    local subnet_cidr="$2"
    local subnet_id dhcp_range err_out
    local range_start range_end dhcp_range_param

    dhcp_range=$(calculate_project_dhcp_range "$subnet_cidr") || return 1
    range_start="${dhcp_range%-*}"
    range_end="${dhcp_range#*-}"
    dhcp_range_param="start-address=${range_start},end-address=${range_end}"
    subnet_id=$(pvesh get "/cluster/sdn/vnets/${vnet}/subnets" --output-format json 2>/dev/null \
        | jq -r --arg cidr "$subnet_cidr" '.[] | select(.cidr == $cidr) | .subnet' \
        | head -n1)
    if [[ -z "$subnet_id" ]]; then
        subnet_id="${vnet}-${subnet_cidr%/*}-${subnet_cidr#*/}"
    fi

    log_info "Setting DHCP range on ${vnet}/${subnet_cidr} (subnet-id: ${subnet_id}): ${dhcp_range} (${dhcp_range_param})"
    if ! err_out=$(pvesh set "/cluster/sdn/vnets/${vnet}/subnets/${subnet_id}" -dhcp-range "$dhcp_range_param" 2>&1); then
        log_error "Failed to set dhcp-range on ${vnet}/${subnet_cidr}"
        if [[ -n "$err_out" ]]; then
            log_error "pvesh error: ${err_out}"
        fi
        return 1
    fi

    return 0
}

################################################################################
# Function: clear_vnet_subnet_dhcp_ranges
# Description: Clear all dhcp-range settings for all subnets in a VNet
# Main commands/functions used:
#   - pvesh get/set: Enumerate subnets and remove dhcp-range property
#   - jq: Parse subnet list
################################################################################
clear_vnet_subnet_dhcp_ranges() {
    local vnet="$1"
    local subnet subnet_id
    local subnets

    subnets=$(pvesh get "/cluster/sdn/vnets/${vnet}/subnets" --output-format json 2>/dev/null | jq -r '.[].subnet' 2>/dev/null || true)
    [[ -n "$subnets" ]] || return 0

    while IFS= read -r subnet; do
        [[ -n "$subnet" ]] || continue
        subnet_id="${subnet//\//%2F}"

        if pvesh set "/cluster/sdn/vnets/${vnet}/subnets/${subnet_id}" -delete dhcp-range >/dev/null 2>&1; then
            log_info "Cleared dhcp-range on ${vnet}/${subnet}"
        elif pvesh set "/cluster/sdn/vnets/${vnet}/subnets/${subnet_id}" -dhcp-range "" >/dev/null 2>&1; then
            log_info "Cleared dhcp-range on ${vnet}/${subnet} (fallback)"
        else
            log_warn "Failed to clear dhcp-range on ${vnet}/${subnet}; continuing"
        fi
    done <<< "$subnets"
}

################################################################################
# Function: clear_project_vnet_dhcp_ranges
# Description: Clear dhcp-range settings from all vnetpjXX subnets
# Main commands/functions used:
#   - pvesh get: Enumerate VNets
#   - jq/grep: Filter vnetpjXX entries
################################################################################
clear_project_vnet_dhcp_ranges() {
    local vnets
    local vnet

    vnets=$(pvesh get /cluster/sdn/vnets --output-format json 2>/dev/null | jq -r '.[].vnet' 2>/dev/null || true)
    [[ -n "$vnets" ]] || return 0

    while IFS= read -r vnet; do
        [[ "$vnet" =~ ^vnetpj[0-9]{2}$ ]] || continue
        clear_vnet_subnet_dhcp_ranges "$vnet"
    done <<< "$vnets"
}

################################################################################
# Function: persist_vpn_pool_route
# Description: Legacy cleanup helper for deprecated mslsetup-route hooks
# Main commands/functions used:
#   - rm: Remove legacy hook scripts if present
################################################################################
persist_vpn_pool_route() {
    remove_vpn_pool_route_hooks
    log_info "Legacy vpndmzvn route hooks removed; route handling moved to mslsetup-vxlan-gw"
}

################################################################################
# Function: remove_vpn_pool_route_hooks
# Description: Remove vpndmzvn route hook scripts created by persist_vpn_pool_route
# Main commands/functions used:
#   - rm: Delete hook scripts if present
################################################################################
remove_vpn_pool_route_hooks() {
    local if_up_hook="/etc/network/if-up.d/mslsetup-route"
    local if_down_hook="/etc/network/if-down.d/mslsetup-route"

    rm -f "$if_up_hook" "$if_down_hook"
    log_info "vpndmzvn route hooks removed (if existed)"
}

################################################################################
# Function: persist_project_gateway_hooks
# Description: Ensure per-project gateway hooks exist via if-up/if-down scripts
# Main commands/functions used:
#   - cat/printf: Generate hook scripts for vnetpjXX interfaces
#   - awk: Remove legacy post-up/pre-down lines from interfaces.d/sdn
################################################################################
persist_project_gateway_hooks() {
    local if_up_hook="/etc/network/if-up.d/mslsetup-vxlan-gw"
    local if_down_hook="/etc/network/if-down.d/mslsetup-vxlan-gw"
    local sdn_file="/etc/network/interfaces.d/sdn"
    local tmp_file="${sdn_file}.tmp"
    local up_tmp
    local down_tmp
    local i idx iface cidr_var gw_var cidr gw prefix
    local valid_count=0

    up_tmp="$(mktemp)"
    down_tmp="$(mktemp)"

    cat > "$up_tmp" <<'EOF'
#!/bin/bash
################################################################################
# Zelogx Multi-Project Secure Lab Setup
#
# Filename: mslsetup-vxlan-gw
# Purpose: Add project gateway IP when a vnetpjXX interface is brought up
################################################################################

set -euo pipefail

apply_arp_isolation() {
    local ifname="$1"

    [ -d "/proc/sys/net/ipv4/conf/${ifname}" ] || return 0

    sysctl -w "net.ipv4.conf.${ifname}.arp_ignore=1" >/dev/null || true
    sysctl -w "net.ipv4.conf.${ifname}.arp_announce=2" >/dev/null || true
}

case "${IFACE:-}" in
EOF

    cat > "$down_tmp" <<'EOF'
#!/bin/bash
################################################################################
# Zelogx Multi-Project Secure Lab Setup
#
# Filename: mslsetup-vxlan-gw
# Purpose: Remove project gateway IP when a vnetpjXX interface is brought down
################################################################################

set -euo pipefail

case "${IFACE:-}" in
EOF

    for i in $(seq 1 "$NUM_PJ"); do
        idx=$(printf '%02d' "$i")
        iface="vnetpj${idx}"
        cidr_var="PJ${idx}_CIDR"
        gw_var="PJ${idx}_GW"
        cidr="${!cidr_var:-}"
        gw="${!gw_var:-}"

        if [[ -z "$cidr" || -z "$gw" ]]; then
            log_warn "Skipping $iface hook generation due to missing ${cidr_var} or ${gw_var}"
            continue
        fi

        if [[ "$cidr" != */* ]]; then
            log_warn "Skipping $iface hook generation due to invalid CIDR: $cidr"
            continue
        fi
        prefix="${cidr#*/}"

        printf '    %s) apply_arp_isolation %s; ip addr replace %s/%s dev %s || true ;;\n' "$iface" "$iface" "$gw" "$prefix" "$iface" >> "$up_tmp"
        printf '    %s) ip addr del %s/%s dev %s || true ;;\n' "$iface" "$gw" "$prefix" "$iface" >> "$down_tmp"
        valid_count=$((valid_count + 1))
    done

    if [[ -n "${VPNDMZ_CIDR:-}" && -n "${VPNDMZ_GW:-}" && "${VPNDMZ_CIDR}" == */* ]]; then
        prefix="${VPNDMZ_CIDR#*/}"
        printf '    vpndmzvn) apply_arp_isolation vpndmzvn; ip addr replace %s/%s dev vpndmzvn || true; ip route replace %s via %s dev vpndmzvn ;;\n' "$VPNDMZ_GW" "$prefix" "$VPN_POOL" "$PT_EG_IP" >> "$up_tmp"
        printf '    vpndmzvn) ip route del %s via %s dev vpndmzvn 2>/dev/null || true; ip addr del %s/%s dev vpndmzvn || true ;;\n' "$VPN_POOL" "$PT_EG_IP" "$VPNDMZ_GW" "$prefix" >> "$down_tmp"
        valid_count=$((valid_count + 1))
    else
        log_warn "Skipping vpndmzvn hook generation due to missing/invalid VPNDMZ_CIDR or VPNDMZ_GW"
    fi

    cat >> "$up_tmp" <<'EOF'
    *)
        exit 0
        ;;
esac

exit 0
EOF

    cat >> "$down_tmp" <<'EOF'
    *)
        exit 0
        ;;
esac

exit 0
EOF

    mv "$up_tmp" "$if_up_hook"
    mv "$down_tmp" "$if_down_hook"
    chmod 0755 "$if_up_hook" "$if_down_hook"

    # Remove legacy in-interface hooks from /etc/network/interfaces.d/sdn.
    if [[ -f "$sdn_file" ]]; then
        awk '
            /post-up[[:space:]]+ip[[:space:]]+addr[[:space:]]+(add|replace)/ && /vnetpj[0-9][0-9]/ { next }
            /pre-down[[:space:]]+ip[[:space:]]+addr[[:space:]]+del/ && /vnetpj[0-9][0-9]/ { next }
            { print }
        ' "$sdn_file" > "$tmp_file"
        mv "$tmp_file" "$sdn_file"
    fi

    if command -v ifreload2 >/dev/null 2>&1; then
        ifreload2 -a
    else
        ifreload -a
    fi

    if [[ "$valid_count" -gt 0 ]]; then
        log_info "Project gateway hooks configured successfully for $valid_count interfaces"
    else
        log_warn "Project gateway hooks created with no valid vnetpj entries"
    fi
}

################################################################################
# Function: remove_project_gateway_hooks
# Description: Remove vnetpj gateway hook scripts created by persist_project_gateway_hooks
# Main commands/functions used:
#   - rm: Delete hook scripts if present
################################################################################
remove_project_gateway_hooks() {
    local if_up_hook="/etc/network/if-up.d/mslsetup-vxlan-gw"
    local if_down_hook="/etc/network/if-down.d/mslsetup-vxlan-gw"

    rm -f "$if_up_hook" "$if_down_hook"
    log_info "vnetpj gateway hooks removed (if existed)"
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