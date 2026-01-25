#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: lib/network.sh
# Purpose: Network calculation and validation functions
#
# Main functions/commands used:
#   - calculate_subnet(): Calculate subnet division
#   - extract_last_octet(): Extract last octet from IP
#   - split_pool(): Split IP pool into subnets
#   - detect_existing_networks(): Discover all existing networks
#   - parse_cidr(): Parse CIDR into network/prefix
#   - cidr_overlaps(): Check if two CIDRs overlap
#   - find_available_network(): Find unused network range
#
# Dependencies:
#   - bash 4.0+
#   - iproute2 (ip command)
#   - ipcalc (CIDR calculations)
#   - jq (for JSON parsing)
#
# Usage:
#   source lib/network.sh
#
# Notes:
#   - Uses ipcalc for reliable CIDR calculations
#   - All functions use English comments per coding standards
################################################################################

set -euo pipefail

# Source common library if not already loaded
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi

################################################################################
# Function: ip_to_int
# Description: Convert IP address to 32-bit integer
#
# Main commands/functions used:
#   - IFS/read: Parse IP octets
#   - Arithmetic: Convert to integer
################################################################################
ip_to_int() {
    local ip="$1"
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
}

################################################################################
# Function: int_to_ip
# Description: Convert 32-bit integer to IP address
#
# Main commands/functions used:
#   - Arithmetic: Convert integer to octets
################################################################################
int_to_ip() {
    local int="$1"
    local a=$((int / 256 ** 3))
    local b=$(((int / 256 ** 2) % 256))
    local c=$(((int / 256) % 256))
    local d=$((int % 256))
    echo "${a}.${b}.${c}.${d}"
}

################################################################################
# Function: parse_cidr
# Description: Parse CIDR notation into network address and prefix length
#
# Main commands/functions used:
#   - String manipulation: Extract IP and prefix
#   - validate_cidr: Validate CIDR format
################################################################################
parse_cidr() {
    local cidr="$1"
    
    if ! validate_cidr "${cidr}"; then
        return 1
    fi
    
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"
    
    echo "${ip} ${prefix}"
    return 0
}

################################################################################
# Function: cidr_to_netmask
# Description: Convert CIDR prefix length to netmask
#
# Main commands/functions used:
#   - ipcalc: CIDR calculation
################################################################################
cidr_to_netmask() {
    local prefix="$1"
    ipcalc "0.0.0.0/${prefix}" | grep -oP 'Netmask:\s+\K[\d.]+'
}

################################################################################
# Function: network_address
# Description: Calculate network address from IP and prefix
#
# Main commands/functions used:
#   - ipcalc: Network calculation
################################################################################
network_address() {
    local ip="$1"
    local prefix="$2"
    
    # Special case for /32 (host route)
    if [[ "$prefix" == "32" ]]; then
        echo "$ip"
        return 0
    fi
    
    ipcalc "${ip}/${prefix}" | grep -oP 'Network:\s+\K[\d.]+(?=/)'
}

################################################################################
# Function: broadcast_address
# Description: Calculate broadcast address from network and prefix
#
# Main commands/functions used:
#   - ipcalc: Broadcast calculation
################################################################################
broadcast_address() {
    local network="$1"
    local prefix="$2"
    
    # Special case for /32 (host route)
    if [[ "$prefix" == "32" ]]; then
        echo "$network"
        return 0
    fi
    
    ipcalc "${network}/${prefix}" | grep -oP 'Broadcast:\s+\K[\d.]+'
}

################################################################################
# Function: cidr_overlaps
# Description: Check if two CIDR ranges overlap
#
# Main commands/functions used:
#   - parse_cidr: Extract network and prefix
#   - ip_to_int: Convert to integers
#   - Arithmetic: Range comparison
################################################################################
cidr_overlaps() {
    local cidr1="$1"
    local cidr2="$2"
    
    local net1 prefix1 net2 prefix2
    read net1 prefix1 < <(parse_cidr "$cidr1")
    read net2 prefix2 < <(parse_cidr "$cidr2")
    
    local net1_addr=$(network_address "$net1" "$prefix1")
    local net2_addr=$(network_address "$net2" "$prefix2")
    
    local bcast1=$(broadcast_address "$net1_addr" "$prefix1")
    local bcast2=$(broadcast_address "$net2_addr" "$prefix2")
    
    local net1_int=$(ip_to_int "$net1_addr")
    local bcast1_int=$(ip_to_int "$bcast1")
    local net2_int=$(ip_to_int "$net2_addr")
    local bcast2_int=$(ip_to_int "$bcast2")
    
    # Check if ranges overlap
    if [[ $net1_int -le $bcast2_int && $bcast1_int -ge $net2_int ]]; then
        return 0  # Overlap
    else
        return 1  # No overlap
    fi
}

################################################################################
# Function: cidr_contains
# Description: Check if an IP address is within a CIDR range
#
# Main commands/functions used:
#   - ip_to_int: Convert IP to integer
#   - network_address: Calculate network address
#   - broadcast_address: Calculate broadcast address
################################################################################
cidr_contains() {
    local cidr="$1"
    local ip="$2"
    
    [[ -z "$cidr" || -z "$ip" ]] && return 1
    
    local net prefix
    read net prefix < <(parse_cidr "$cidr")
    
    local net_addr=$(network_address "$net" "$prefix")
    local bcast=$(broadcast_address "$net_addr" "$prefix")
    
    local net_int=$(ip_to_int "$net_addr")
    local bcast_int=$(ip_to_int "$bcast")
    local ip_int=$(ip_to_int "$ip")
    
    # Check if IP is within range
    if [[ $ip_int -ge $net_int && $ip_int -le $bcast_int ]]; then
        return 0  # IP is in range
    else
        return 1  # IP is not in range
    fi
}

################################################################################
# Function: extract_last_octet
# Description: Extract last octet from IP address with leading dot
#
# Main commands/functions used:
#   - String manipulation: Extract last octet
################################################################################
extract_last_octet() {
    local ip="$1"
    local last_octet="${ip##*.}"
    echo ".${last_octet}"
}

################################################################################
# Function: calculate_subnet
# Description: Calculate subnet division based on number of subnets needed
#
# Main commands/functions used:
#   - parse_cidr: Extract network and prefix
#   - Arithmetic: Calculate new prefix and subnet addresses
################################################################################
calculate_subnet() {
    local parent_cidr="$1"
    local num_subnets="$2"
    
    local network prefix
    read network prefix < <(parse_cidr "$parent_cidr")
    
    # Calculate bits needed for subnets
    local subnet_bits=0
    local temp=$num_subnets
    while [[ $temp -gt 1 ]]; do
        subnet_bits=$((subnet_bits + 1))
        temp=$((temp / 2))
    done
    
    local new_prefix=$((prefix + subnet_bits))
    
    if [[ $new_prefix -gt 32 ]]; then
        log_error "Cannot divide $parent_cidr into $num_subnets subnets"
        return 1
    fi
    
    local net_int=$(ip_to_int "$network")
    local subnet_size=$((1 << (32 - new_prefix)))
    
    for ((i = 0; i < num_subnets; i++)); do
        local subnet_net=$((net_int + i * subnet_size))
        local subnet_ip=$(int_to_ip $subnet_net)
        echo "${subnet_ip}/${new_prefix}"
    done
}

################################################################################
# Function: split_pool
# Description: Split IP pool into OpenVPN and WireGuard portions, then by project
#
# Main commands/functions used:
#   - calculate_subnet: Divide networks
#   - jq: JSON formatting (if available)
################################################################################
split_pool() {
    local pool_cidr="$1"
    local num_projects="$2"
    
    # First split into /25 for OpenVPN and WireGuard
    local ovpn_pool wg_pool
    read ovpn_pool < <(calculate_subnet "$pool_cidr" 2 | head -n 1)
    read wg_pool < <(calculate_subnet "$pool_cidr" 2 | tail -n 1)
    
    echo "OVPN_POOL=${ovpn_pool}"
    echo "WG_POOL=${wg_pool}"
    
    # Split OpenVPN pool by project count (each gets /28)
    local i=1
    while IFS= read -r subnet; do
        printf "OVPN_POOL%d=%s\n" "$i" "$subnet"
        i=$((i + 1))
    done < <(calculate_subnet "$ovpn_pool" "$num_projects")
    
    # Split WireGuard pool by project count (each gets /28)
    i=1
    while IFS= read -r subnet; do
        printf "WG_POOL%d=%s\n" "$i" "$subnet"
        i=$((i + 1))
    done < <(calculate_subnet "$wg_pool" "$num_projects")
}

################################################################################
# Function: detect_existing_networks
# Description: Discover all existing network ranges from multiple sources
#
# Main commands/functions used:
#   - ip: Get addresses and routes
#   - grep/awk/sed: Parse configuration files
#   - pvesh: Proxmox API queries
#
# Detection Scope and Limitations:
#   ✓ Detects: Proxmox-managed IPs (cloud-init ipconfig, LXC net config)
#   ✓ Detects: Bridge/vnet definitions, routing table, interface addresses
#   ✓ Detects: Active IPs from ARP table (currently reachable devices only)
#   ✗ Cannot detect: IPs configured inside guest OS when VM is stopped
#   ✗ Cannot detect: IPs of devices not in ARP cache (inactive or expired)
#   
#   Rationale: QEMU Guest Agent requires running VM. Scanning guest filesystems
#   from host is not secure. ARP table only shows currently active devices.
#   
#   Recommendation: Users should manually verify no guest-internal static IPs
#   conflict with proposed network ranges.
################################################################################
detect_existing_networks() {
    local networks=()
    
    # 1. Direct Configuration: /etc/network/interfaces
    if [[ -f /etc/network/interfaces ]]; then
        while IFS= read -r line; do
            if [[ $line =~ address[[:space:]]+([0-9.]+/[0-9]+) ]]; then
                networks+=("${BASH_REMATCH[1]}")
            fi
        done < /etc/network/interfaces
    fi
    
    # 2. Direct Configuration: /etc/pve/sdn/* (SDN zones/vnets/subnets)
    if [[ -d /etc/pve/sdn ]]; then
        for file in /etc/pve/sdn/vnets.cfg /etc/pve/sdn/subnets.cfg; do
            if [[ -f $file ]]; then
                while IFS= read -r line; do
                    if [[ $line =~ ([0-9.]+/[0-9]+) ]]; then
                        networks+=("${BASH_REMATCH[1]}")
                    fi
                done < "$file"
            fi
        done
    fi
    
    # 3. Kernel routing table
    while IFS= read -r line; do
        if [[ $line =~ ^([0-9.]+/[0-9]+) ]]; then
            networks+=("${BASH_REMATCH[1]}")
        fi
    done < <(ip route show 2>/dev/null | grep -v default)
    
    # 4. Interface addresses
    while IFS= read -r line; do
        if [[ $line =~ inet[[:space:]]+([0-9.]+/[0-9]+) ]]; then
            networks+=("${BASH_REMATCH[1]}")
        fi
    done < <(ip addr show 2>/dev/null)
    
    # 5. ARP table (only shows currently active/reachable devices)
    if command -v ip &>/dev/null; then
        local arp_output
        arp_output=$(ip neighbor show 2>/dev/null || true)
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            # Extract IP from ARP entries (skip INCOMPLETE/FAILED entries)
            if [[ $line =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
                local arp_ip="${BASH_REMATCH[1]}"
                # Skip incomplete or failed entries
                if [[ $line =~ INCOMPLETE ]] || [[ $line =~ FAILED ]]; then
                    continue
                fi
                # Validate and add as /32
                if validate_ip "$arp_ip" && validate_private_ip "$arp_ip"; then
                    networks+=("${arp_ip}/32")
                fi
            fi
        done <<< "$arp_output"
    fi
    
    # 6. Proxmox API: VM/CT configurations (if pvesh is available)
    # Detection scope: Only cloud-init ipconfig and LXC net config entries
    # Known limitation: Guest-internal static IPs are not detectable when VM stopped
    if command -v pvesh &>/dev/null; then
        # Get all VMs and CTs
        local resources
        resources=$(pvesh get /cluster/resources --type vm --output-format json 2>/dev/null || echo "[]")
        
        # Parse VM/CT IDs and query their configs
        local ids
        ids=$(echo "$resources" | jq -r '.[] | .vmid' 2>/dev/null || true)
        
        for vmid in $ids; do
            local node
            node=$(echo "$resources" | jq -r ".[] | select(.vmid==$vmid) | .node" 2>/dev/null || true)
            
            if [[ -n "$node" ]]; then
                local vm_type
                vm_type=$(echo "$resources" | jq -r ".[] | select(.vmid==$vmid) | .type" 2>/dev/null || true)
                
                local config
                if [[ "$vm_type" == "qemu" ]]; then
                    config=$(pvesh get "/nodes/${node}/qemu/${vmid}/config" --output-format json 2>/dev/null || echo "{}")
                elif [[ "$vm_type" == "lxc" ]]; then
                    config=$(pvesh get "/nodes/${node}/lxc/${vmid}/config" --output-format json 2>/dev/null || echo "{}")
                fi
                
                # Extract IP configs from VM/CT config JSON
                # Only detects: cloud-init ipconfig entries (ip=x.x.x.x/xx format)
                # Does NOT detect: IPs configured inside guest OS (netplan, /etc/network/interfaces)

                # Search for ip= pattern in config values
                local ip_configs
                ip_configs=$(echo "$config" | jq -r '.[] | select(. | type == "string")' 2>/dev/null || true)
                while IFS= read -r ipconfig; do
                    if [[ $ipconfig =~ ip=([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?) ]]; then
                        local found="${BASH_REMATCH[1]}"
                        # If no prefix provided, normalize to /32
                        if [[ "$found" =~ / ]]; then
                            networks+=("$found")
                        else
                            networks+=("${found}/32")
                        fi
                    fi
                done <<< "$ip_configs"
            fi
        done
    fi
    
    # Normalize all networks to network addresses and remove duplicates
    local normalized_networks=()
    local seen_networks=()
    
    if [[ ${#networks[@]} -gt 0 ]]; then
        # First pass: normalize each CIDR to its network address
        for cidr in "${networks[@]}"; do
            local normalized
            # Use ipcalc to get the actual network address
            normalized=$(ipcalc "$cidr" 2>/dev/null | grep -oP 'Network:\s+\K[\d.]+/\d+' || echo "$cidr")
            normalized_networks+=("$normalized")
        done
        
        # Second pass: remove duplicates and sort
        local unique_networks
        unique_networks=$(printf '%s\n' "${normalized_networks[@]}" | sort -u -t. -k1,1n -k2,2n -k3,3n -k4,4n)
        
        # Third pass: remove networks that are subsets of larger networks
        local final_networks=()
        while IFS= read -r net1; do
            [[ -z "$net1" ]] && continue
            local is_subset=false
            
            # Check if net1 is contained in any other network
            while IFS= read -r net2; do
                [[ -z "$net2" ]] && continue
                [[ "$net1" == "$net2" ]] && continue
                
                # If net1 is contained within net2, skip net1
                if cidr_contains "$net2" "${net1%/*}" 2>/dev/null; then
                    # Also check that net2 is actually larger (not equal)
                    local prefix1="${net1#*/}"
                    local prefix2="${net2#*/}"
                    if [[ "$prefix2" -lt "$prefix1" ]]; then
                        is_subset=true
                        break
                    fi
                fi
            done <<< "$unique_networks"
            
            if [[ "$is_subset" == "false" ]]; then
                final_networks+=("$net1")
            fi
        done <<< "$unique_networks"
        
        # Print final deduplicated and normalized networks
        printf '%s\n' "${final_networks[@]}" | sort -u -t. -k1,1n -k2,2n -k3,3n -k4,4n
    fi
}

################################################################################
# Function: find_available_network
# Description: Find an unused network range of specified size
#
# Main commands/functions used:
#   - detect_existing_networks: Get existing networks
#   - cidr_overlaps: Check for conflicts
################################################################################
find_available_network() {
    local desired_prefix="$1"
    local ip_class="${2:-192}"
    
    local existing_networks=()
    while IFS= read -r cidr; do
        existing_networks+=("$cidr")
    done < <(detect_existing_networks)
    
    # Search for available network based on IP class
    local base_network
    case "$ip_class" in
        10)
            base_network="10.0.0.0"
            ;;
        172)
            base_network="172.16.0.0"
            ;;
        192)
            base_network="192.168.0.0"
            ;;
        *)
            log_error "Invalid IP class: $ip_class"
            return 1
            ;;
    esac
    
    # Try to find available network
    local base_int=$(ip_to_int "$base_network")
    local subnet_size=$((1 << (32 - desired_prefix)))
    
    for ((i = 0; i < 256; i++)); do
        local candidate_int=$((base_int + i * subnet_size))
        local candidate_ip=$(int_to_ip $candidate_int)
        local candidate_cidr="${candidate_ip}/${desired_prefix}"
        
        # Show progress every 10 iterations
        if ((i % 10 == 0)); then
            printf "." >&2
        fi
        
        # Check if this network overlaps with any existing network
        local has_overlap=0
        for existing_cidr in "${existing_networks[@]}"; do
            if cidr_overlaps "$candidate_cidr" "$existing_cidr"; then
                has_overlap=1
                break
            fi
        done
        
        if [[ $has_overlap -eq 0 ]]; then
            printf "\n" >&2  # Newline after progress dots
            echo "$candidate_cidr"
            return 0
        fi
    done
    
    printf "\n" >&2  # Newline after progress dots
    
    log_error "No available /${desired_prefix} network found in class $ip_class"
    return 1
}

log_info "Network library loaded successfully"
