#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: lib/input_functions.sh
# Purpose: Interactive input functions for network configuration
#
# Dependencies:
#   - lib/common.sh
#   - lib/network.sh
#   - lib/messages_*.sh
#
# Usage:
#   source "${PROJECT_ROOT}/lib/input_functions.sh"
#
# Notes:
#   - All functions store results in CONFIG associative array
#   - Provides preview, validation, and conflict detection
################################################################################

# Global cache for detected existing networks (populated on first detection)
declare -a DETECTED_EXISTING_NETWORKS=()

# Helper: Check whether an IP is reachable (lightweight probe)
# Uses ping (one packet, short timeout) when available. Returns 0 if reachable.
is_ip_reachable() {
    local ip="$1"
    if [[ -z "$ip" ]]; then
        return 1
    fi
    if command -v ping &>/dev/null; then
        # Use a single ICMP echo with 1s timeout
        if ping -c 1 -W 1 "$ip" &>/dev/null; then
            return 0
        else
            return 1
        fi
    fi
    return 1
}

# Helper: Ensure CIDR is aligned to its network address
ensure_network_alignment() {
    local cidr="$1"
    local calc_network
    calc_network=$(ipcalc "$cidr" 2>/dev/null | grep -oP 'Network:\s+\K[\d.]+/\d+' || true)
    if [[ -z "$calc_network" ]]; then
        log_error "${MSG_INVALID_CIDR}: $cidr" -c
        return 1
    fi
    if [[ "$calc_network" != "$cidr" ]]; then
        printf -v _msg "${MSG_NOT_NETWORK_ADDR:-Error: CIDR must use valid network address (e.g., %s)}" "$calc_network"
        log_error "${_msg}" -c
        return 1
    fi
    return 0
}

# Helper: Return already-configured CIDR networks from CONFIG[*_CIDR]
get_configured_networks() {
    local nets=()
    local key
    for key in "${!CONFIG[@]}"; do
        if [[ "$key" =~ _CIDR$ ]] && [[ -n "${CONFIG[$key]}" ]]; then
            nets+=("${CONFIG[$key]}")
        fi
    done
    printf "%s\n" "${nets[@]}"
}

################################################################################
# Function: input_mainlan
# Description: Interactive input for MainLAN network (a: ML_CIDR, ML_GW)
#
# Returns:
#   0: Success (sets CONFIG[ML_CIDR], CONFIG[ML_GW], CONFIG[ML_GW_LO])
################################################################################
input_mainlan() {
    printf "\n%s\n%s\n" "(a) ${MSG_INPUT_MAINLAN}" "----------------------------------------"
    
    # Auto-detect from vmbr0
    local vmbr0_info
    vmbr0_info=$(ip -4 addr show vmbr0 2>/dev/null | grep -oP 'inet \K[\d.]+/\d+') || \
        die "Failed to detect vmbr0 address"
    
    local default_cidr
    default_cidr=$(ipcalc "$vmbr0_info" | grep -oP 'Network:\s+\K[\d.]+/\d+')
    
    local default_gw
    default_gw=$(ip route show default | grep -oP 'via \K[\d.]+' | head -n 1) || \
        die "Failed to detect default gateway"
    
    log_info "Auto-detected MainLAN: ${default_cidr}, GW: ${default_gw}"
    
    # Confirm with user
    local ml_cidr ml_gw
    while true; do
        printf "\n%s\n  %s: %s\n  %s: %s\n\n" "${MSG_AUTO_DETECTED_MAINLAN}" "${MSG_NETWORK}" "${default_cidr}" "${MSG_GATEWAY}" "${default_gw}"
        read -p "${MSG_ENTER_MAINLAN_CIDR} [${default_cidr}]: " ml_cidr
        
        [[ -z "$ml_cidr" ]] && ml_cidr="$default_cidr"
        
        if ! validate_cidr "$ml_cidr"; then
            log_error "${MSG_INVALID_CIDR}: $ml_cidr" -c
            continue
        fi

        if ! ensure_network_alignment "$ml_cidr"; then
            continue
        fi
        
        read -p "${MSG_ENTER_MAINLAN_GW} [${default_gw}]: " ml_gw
        
        [[ -z "$ml_gw" ]] && ml_gw="$default_gw"
        
        if ! validate_ip "$ml_gw"; then
            log_error "${MSG_INVALID_IP}: $ml_gw" -c
            continue
        fi
        
        CONFIG[ML_CIDR]="$ml_cidr"
        CONFIG[ML_GW]="$ml_gw"
        CONFIG[ML_GW_LO]=$(extract_last_octet "$ml_gw")
        
        log_info "MainLAN: ${CONFIG[ML_CIDR]}, GW: ${CONFIG[ML_GW]}"
        break
    done
}

################################################################################
# Function: input_pve_ip
# Description: Interactive input for Proxmox VE IP (b: PVE_IP)
#
# Returns:
#   0: Success (sets CONFIG[PVE_IP], CONFIG[PVE_IP_LO])
################################################################################
input_pve_ip() {
    printf "\n%s\n%s\n" "(b) ${MSG_INPUT_PVE_IP}" "----------------------------------------"
    
    # Auto-detect from vmbr0
    local default_ip
    default_ip=$(ip -4 addr show vmbr0 | grep -oP 'inet \K[\d.]+(?=/)') || \
        die "Failed to detect PVE IP"
    
    log_info "Auto-detected PVE IP: ${default_ip}"
    
    # Confirm with user
    local pve_ip
    while true; do
        printf "\n%s\n  %s: %s\n\n" "${MSG_AUTO_DETECTED_PVE}" "${MSG_IP_ADDRESS}" "${default_ip}"
        read -p "${MSG_ENTER_PVE_IP} [${default_ip}]: " pve_ip
        
        [[ -z "$pve_ip" ]] && pve_ip="$default_ip"
        
        if ! validate_ip "$pve_ip"; then
            log_error "${MSG_INVALID_IP}: $pve_ip" -c
            continue
        fi
        
        CONFIG[PVE_IP]="$pve_ip"
        CONFIG[PVE_IP_LO]=$(extract_last_octet "$pve_ip")
        
        log_info "PVE IP: ${CONFIG[PVE_IP]}"
        break
    done
}

################################################################################
# Function: input_num_pj
# Description: Get number of projects from user (e: NUM_PJ)
#
# Returns:
#   0: Success (sets CONFIG[NUM_PJ])
################################################################################
input_num_pj() {
    printf "\n%s\n%s\n%s\n" "(e) ${MSG_INPUT_NUM_PJ}" "----------------------------------------" "${MSG_NUM_PJ_DESC}"
    
    local default=8
    local input
    
    log_info "Proposed number of projects: ${default}"
    
    while true; do
        printf "\n"
        read -p "${MSG_NUM_PJ_PROMPT} [${default}]: " input
        
        input="${input:-$default}"
        
        # Validate: must be power of 2 and between 2-16
        if [[ "$input" =~ ^(2|4|8|16)$ ]]; then
            CONFIG[NUM_PJ]="$input"
            log_info "NUM_PJ set to: ${CONFIG[NUM_PJ]}"
            break
        else
            log_error "${MSG_NUM_PJ_ERROR}" -c
        fi
    done
}

################################################################################
# Function: input_vpndmz_network
# Description: Get VPN DMZ network configuration from user (c: VPNDMZ_CIDR)
#
# Returns:
#   0: Success (sets CONFIG[VPNDMZ_CIDR], CONFIG[VPNDMZ_GW])
################################################################################
input_vpndmz_network() {
    printf "\n%s\n%s\n" "(c) ${MSG_INPUT_VPNDMZ}" "----------------------------------------"
    
    # Use cached networks if available, otherwise detect once
    local existing_networks=()
    if [[ ${#DETECTED_EXISTING_NETWORKS[@]} -eq 0 ]]; then
        log_info "Detecting existing networks for conflict check..."
        while IFS= read -r cidr; do
            DETECTED_EXISTING_NETWORKS+=("$cidr")
        done < <(detect_existing_networks)
        log_info "Found ${#DETECTED_EXISTING_NETWORKS[@]} existing networks"
        for net in "${DETECTED_EXISTING_NETWORKS[@]}"; do
            log_info "  - $net"
        done
    fi
    existing_networks=("${DETECTED_EXISTING_NETWORKS[@]}")
    
    # Propose default or find available network
    local default_proposal="192.168.80.0/24"
    local has_conflict=false
    
    for existing_cidr in "${existing_networks[@]}"; do
        if cidr_overlaps "$default_proposal" "$existing_cidr"; then
            has_conflict=true
            break
        fi
    done
    
    if [[ "$has_conflict" == "true" ]]; then
        printf "\n%s\n" "${MSG_FINDING_ALTERNATIVE}" >&2
        printf "%s" "${MSG_SEARCHING}" >&2
        default_proposal=$(find_available_network 24 192) || default_proposal="192.168.80.0/24"
        log_info "${MSG_ALTERNATIVE_FOUND}: ${default_proposal}"
        printf "\n%s %s\n\n" "${MSG_ALTERNATIVE_FOUND}:" "${default_proposal}"
    fi
    
    log_info "Proposed VPN DMZ network: ${default_proposal}"
    
    local input
    local current_proposal="$default_proposal"
    
    while true; do
        # Calculate Gateway for current proposal
        local preview_gw
        preview_gw=$(ipcalc "$current_proposal" | grep -oP 'HostMin:\s+\K[\d.]+' || echo "")
        
        printf "\n%s\n\n%s\n  %s: %s\n  %s: %s\n\n" \
            "${MSG_VPNDMZ_DESC}" "${MSG_PROPOSED_VPNDMZ}" \
            "${MSG_NETWORK}" "${current_proposal}" "${MSG_GATEWAY}" "${preview_gw}"
        read -p "${MSG_VPNDMZ_PROMPT} [${current_proposal}]: " input
        
        input="${input:-$current_proposal}"
        
        # Validate CIDR
        if ! validate_cidr "$input"; then
            log_error "${MSG_INVALID_CIDR}: $input" -c
            continue
        fi

        if ! ensure_network_alignment "$input"; then
            continue
        fi
        
        # Validate private IP
        local network_ip="${input%/*}"
        if ! validate_private_ip "$network_ip"; then
            log_error "${MSG_NOT_PRIVATE_IP}: $network_ip" -c
            continue
        fi
        
        # Check minimum /30
        local prefix="${input#*/}"
        if [[ $prefix -gt 30 ]]; then
            log_error "${MSG_PREFIX_TOO_SMALL}" -c
            continue
        fi
        
        # Check for conflicts with existing networks
        has_conflict=false
        for existing_cidr in "${existing_networks[@]}"; do
            if cidr_overlaps "$input" "$existing_cidr"; then
                log_error "${MSG_NETWORK_CONFLICT}: $input ${MSG_OVERLAPS_WITH} $existing_cidr" -c
                has_conflict=true
                break
            fi
        done
        
        if [[ "$has_conflict" == "true" ]]; then
            continue
        fi
        
        # If user entered a different value, show preview and confirm
        if [[ "$input" != "$current_proposal" ]]; then
            local new_gw
            new_gw=$(ipcalc "$input" | grep -oP 'HostMin:\s+\K[\d.]+' || echo "")
            
            printf "\n%s\n  %s: %s\n  %s: %s\n\n" \
                "${MSG_NETWORK_CONFIG_FOR}" "${MSG_NETWORK}" "${input}" "${MSG_GATEWAY}" "${new_gw}"
            read -p "${MSG_CONFIRM_CONTINUE/\[Y\/n\]/(y/n) [y]}" confirm
            
            [[ -z "$confirm" ]] && confirm="y"
            
            if [[ ! "$confirm" =~ ^[Yy] ]]; then
                # User rejected this value, update proposal for next iteration
                current_proposal="$input"
                continue
            fi
        fi
        
        # Set values
        CONFIG[VPNDMZ_CIDR]="$input"
        local gw_ip=$(ipcalc "$input" | grep -oP 'HostMin:\s+\K[\d.]+')
        CONFIG[VPNDMZ_GW]="$gw_ip"
        CONFIG[VPNDMZ_GW_LO]=$(extract_last_octet "$gw_ip")
        
        log_info "VPNDMZ set to: ${CONFIG[VPNDMZ_CIDR]} GW: ${CONFIG[VPNDMZ_GW]}"
        break
    done
}

# Additional input functions will be added here
# (input_vpn_pool, input_pjall_network, input_pritunl_mainlan_ip, 
#  input_pritunl_vpndmz_ip, input_port_ranges, input_dns_servers)

################################################################################
# Function: input_vpn_pool
# Description: Interactive input for VPN Client Pool network (d: VPN_POOL)
#
# Returns:
#   0: Success (sets VPN_POOL, OVPN_POOL, WG_POOL, OVPN_POOLx, WG_POOLx)
################################################################################
input_vpn_pool() {
    printf "\n%s\n%s\n" "(d) ${MSG_INPUT_VPN_POOL}" "----------------------------------------"
    
    # Detect existing networks for conflict checking
    local existing_networks=()
    while IFS= read -r cidr; do
        existing_networks+=("$cidr")
    done < <(detect_existing_networks)

    # Include already chosen networks (any *_CIDR in CONFIG) to avoid overlaps
    local conflict_networks=()
    conflict_networks+=("${existing_networks[@]}")
    while IFS= read -r cidr; do
        conflict_networks+=("$cidr")
    done < <(get_configured_networks)
    
    # Propose default or find available network
    local default_pool="192.168.81.0/24"
    local has_conflict=false
    
    for existing_cidr in "${conflict_networks[@]}"; do
        if cidr_overlaps "$default_pool" "$existing_cidr"; then
            has_conflict=true
            break
        fi
    done
    
    if [[ "$has_conflict" == "true" ]]; then
        printf "\n%s\n" "${MSG_FINDING_ALTERNATIVE}" >&2
        printf "%s" "${MSG_SEARCHING}" >&2
        default_pool=$(find_available_network 24 192) || default_pool="192.168.81.0/24"
        log_info "${MSG_ALTERNATIVE_FOUND}: ${default_pool}"
        printf "\n%s %s\n\n" "${MSG_ALTERNATIVE_FOUND}:" "${default_pool}"
    fi
    
    # Calculate split results for the default proposal
    log_info "Calculating VPN pool split for preview..."
    local preview_split
    preview_split=$(split_pool "$default_pool" "${CONFIG[NUM_PJ]}")
    
    local vpn_pool=""
    local current_proposal="$default_pool"
    
    while true; do
        # Recalculate preview if proposal changed
        if [[ "$current_proposal" != "$default_pool" ]]; then
            preview_split=$(split_pool "$current_proposal" "${CONFIG[NUM_PJ]}")
        fi
        
        # Calculate usable hosts per project subnet
        # Subtract 3 reserved addresses:
        #   -1 Network address (first IP, e.g., 192.168.81.0)
        #   -1 Broadcast address (last IP, e.g., 192.168.81.15 for /28)
        #   -1 Gateway address (typically .1, e.g., 192.168.81.1)
        local first_pj_subnet=$(echo "$preview_split" | grep "^OVPN_POOL1=" | cut -d= -f2)
        local pj_prefix="${first_pj_subnet#*/}"
        local pj_subnet_size=$((2 ** (32 - pj_prefix)))
        local usable_hosts=$((pj_subnet_size - 3))
        
        printf "\n%s\n" "${MSG_VPN_POOL_SPLIT_DESC}"
        printf "%s\n" "${MSG_VPN_POOL_FIRST_HALF}"
        printf "%s\n" "${MSG_VPN_POOL_SECOND_HALF}"
        printf "%s\n" "$(printf "${MSG_VPN_POOL_FURTHER_SPLIT}" "${CONFIG[NUM_PJ]}" "${pj_prefix}")"
        printf "%s\n" "$(printf "%s" "${MSG_VPN_POOL_MAX_CLIENTS}" | sed "s/%s/${usable_hosts}/")"
        printf "\n%s\n  %s: %s\n\n" "${MSG_PROPOSED_VPN_POOL}" "${MSG_NETWORK}" "${current_proposal}"
        printf "%s\n" "${MSG_SPLIT_RESULT_PREVIEW}"
        echo "----------------------------------------"
        
        local preview_ovpn=$(echo "$preview_split" | grep "^OVPN_POOL=" | cut -d= -f2)
        local preview_wg=$(echo "$preview_split" | grep "^WG_POOL=" | cut -d= -f2)
        echo "OpenVPN Pool:    ${preview_ovpn}"
        echo "WireGuard Pool:  ${preview_wg}"
        printf "\n%s\n" "${MSG_OVPN_POOL_PER_PJ}"
        echo "$preview_split" | grep "^OVPN_POOL[0-9]"
        printf "\n%s\n" "${MSG_WG_POOL_PER_PJ}"
        echo "$preview_split" | grep "^WG_POOL[0-9]"
        printf "%s\n\n" "----------------------------------------"
        read -p "${MSG_ENTER_VPN_POOL} [${current_proposal}]: " vpn_pool
        
        # Use current proposal if empty
        [[ -z "$vpn_pool" ]] && vpn_pool="$current_proposal"
        
        # Validate CIDR format
        if ! validate_cidr "$vpn_pool"; then
            log_error "${MSG_INVALID_CIDR}: $vpn_pool" -c
            continue
        fi

        if ! ensure_network_alignment "$vpn_pool"; then
            continue
        fi
        
        # Validate private IP
        local pool_ip="${vpn_pool%/*}"
        if ! validate_private_ip "$pool_ip"; then
            log_error "${MSG_NOT_PRIVATE_IP}: $pool_ip" -c
            continue
        fi
        
        # Check for conflicts with existing networks
        local has_conflict=0
        for existing_cidr in "${conflict_networks[@]}"; do
            if cidr_overlaps "$vpn_pool" "$existing_cidr"; then
                log_error "${MSG_NETWORK_CONFLICT}: $vpn_pool ${MSG_OVERLAPS_WITH} $existing_cidr" -c
                has_conflict=1
                break
            fi
        done
        
        if [[ $has_conflict -eq 1 ]]; then
            continue
        fi
        
        # If user entered a different value, recalculate and show results
        if [[ "$vpn_pool" != "$default_pool" ]]; then
            local split_output
            split_output=$(split_pool "$vpn_pool" "${CONFIG[NUM_PJ]}")
            
            printf "\n%s\n%s\n" "${MSG_VPN_POOL_SPLIT}" "----------------------------------------"
            
            local final_ovpn=$(echo "$split_output" | grep "^OVPN_POOL=" | cut -d= -f2)
            local final_wg=$(echo "$split_output" | grep "^WG_POOL=" | cut -d= -f2)
            echo "OpenVPN Pool:    ${final_ovpn}"
            echo "WireGuard Pool:  ${final_wg}"
            printf "\n%s\n" "${MSG_OVPN_POOL_PER_PJ}"
            echo "$split_output" | grep "^OVPN_POOL[0-9]"
            printf "\n%s\n" "${MSG_WG_POOL_PER_PJ}"
            echo "$split_output" | grep "^WG_POOL[0-9]"
            
            read -p "${MSG_CONFIRM_CONTINUE/\[Y\/n\]/(y/n) [y]}" confirm
            
            [[ -z "$confirm" ]] && confirm="y"
            
            if [[ ! "$confirm" =~ ^[Yy] ]]; then
                # User rejected this value, update proposal for next iteration
                current_proposal="$vpn_pool"
                continue
            fi
        else
            # User accepted default, use preview_split
            split_output="$preview_split"
        fi
        
        # Store configuration
        CONFIG[VPN_POOL]="$vpn_pool"
        eval "$split_output"
        break
    done
}

input_pjall_network() {
    printf "\n%s\n%s\n" "(f) ${MSG_INPUT_PJALL_CIDR}" "----------------------------------------"
    
    # Use cached networks (already detected in input_vpndmz_network)
    local existing_networks=("${DETECTED_EXISTING_NETWORKS[@]}")

    # Include already selected networks (any *_CIDR in CONFIG) to avoid overlaps
    local conflict_networks=()
    conflict_networks+=("${existing_networks[@]}")
    while IFS= read -r cidr; do
        conflict_networks+=("$cidr")
    done < <(get_configured_networks)
    
    # Propose default or find available network
    local default_proposal="172.16.16.0/21"
    local has_conflict=false
    
    for existing_cidr in "${conflict_networks[@]}"; do
        if cidr_overlaps "$default_proposal" "$existing_cidr"; then
            has_conflict=true
            break
        fi
    done
    
    if [[ "$has_conflict" == "true" ]]; then
        printf "\n%s\n" "${MSG_FINDING_ALTERNATIVE}" >&2
        printf "%s" "${MSG_SEARCHING}" >&2
        default_proposal=$(find_available_network 21 172) || default_proposal="172.16.16.0/21"
        log_info "${MSG_ALTERNATIVE_FOUND}: ${default_proposal}"
        printf "\n%s %s\n\n" "${MSG_ALTERNATIVE_FOUND}:" "${default_proposal}"
    fi
    
    log_info "Proposed project networks: ${default_proposal}"
    
    # Calculate initial preview split
    local preview_split
    preview_split=$(calculate_subnet "$default_proposal" "${CONFIG[NUM_PJ]}")
    
    local input
    local current_proposal="$default_proposal"
    
    while true; do
        # Recalculate preview if proposal changed
        if [[ "$current_proposal" != "$default_proposal" ]]; then
            preview_split=$(calculate_subnet "$current_proposal" "${CONFIG[NUM_PJ]}")
        fi
        
        # Calculate subnet size for each project
        local first_pj_subnet=$(echo "$preview_split" | head -n 1)
        local pj_prefix="${first_pj_subnet#*/}"
        
        printf "\n%s\n" "${MSG_PJ_NETWORK_SPLIT_DESC}"
        printf "%s\n" "$(printf "${MSG_PJ_NETWORK_TOTAL}" "${current_proposal}")"
        printf "%s\n" "$(printf "${MSG_PJ_NETWORK_COUNT}" "${CONFIG[NUM_PJ]}" "${pj_prefix}")"
        printf "%s\n" "$(printf "${MSG_PJ_NETWORK_DEDICATED}" "${pj_prefix}")"
        printf "\n%s\n" "${MSG_PROPOSED_PJ_NETWORK}"
        echo "  ${MSG_NETWORK}: ${current_proposal}"
        printf "\n%s\n" "${MSG_SPLIT_RESULT_PREVIEW}"
        echo "----------------------------------------"
        local i=1
        while IFS= read -r subnet; do
            local gw_ip=$(ipcalc "$subnet" | grep -oP 'HostMax:\s+\K[\d.]+' || echo "")
            printf "PJ%02d: %-18s (GW: %s)\n" "$i" "$subnet" "$gw_ip"
            i=$((i + 1))
        done <<< "$preview_split"
        echo -e "----------------------------------------\n"
        read -p "${MSG_ENTER_PJ_NETWORK} [${current_proposal}]: " input
        
        # Use current proposal if empty
        [[ -z "$input" ]] && input="$current_proposal"
        
        # Validate CIDR format
        if ! validate_cidr "$input"; then
            log_error "${MSG_INVALID_CIDR}: $input" -c
            continue
        fi

        # Validate private IP
        local network_ip="${input%/*}"
        if ! validate_private_ip "$network_ip"; then
            log_error "${MSG_NOT_PRIVATE_IP}: $network_ip" -c
            continue
        fi

        # Validate that the provided IP is the actual network address
        if ! ensure_network_alignment "$input"; then
            continue
        fi
        
        # Check if network can be divided into NUM_PJ subnets
        local prefix="${input#*/}"
        # Calculate bits needed: log2(NUM_PJ)
        local subnet_bits=0
        local temp="${CONFIG[NUM_PJ]}"
        while [[ $temp -gt 1 ]]; do
            subnet_bits=$((subnet_bits + 1))
            temp=$((temp / 2))
        done
        local new_prefix=$((prefix + subnet_bits))
        
        if [[ $new_prefix -gt 30 ]]; then
            # Use localized prefix-too-small message
            msg_printf PREFIX_TOO_SMALL "$prefix" "${CONFIG[NUM_PJ]}" "$new_prefix"
            continue
        fi
        
        # Check for conflicts with existing networks
        has_conflict=false
        for existing_cidr in "${conflict_networks[@]}"; do
            if cidr_overlaps "$input" "$existing_cidr"; then
                log_error "${MSG_NETWORK_CONFLICT}: $input ${MSG_OVERLAPS_WITH} $existing_cidr" -c
                has_conflict=true
                break
            fi
        done
        
        if [[ "$has_conflict" == "true" ]]; then
            continue
        fi
        
        # If user entered a different value, show preview and confirm
        if [[ "$input" != "$current_proposal" ]]; then
            local new_split
            new_split=$(calculate_subnet "$input" "${CONFIG[NUM_PJ]}")
            
            printf "\n%s\n" "${MSG_NETWORK_CONFIG_FOR}"
            printf "%s\n" "$(printf "${MSG_TOTAL_NETWORK}: %s" "${input}")"
            printf "\n%s\n" "${MSG_PJ_NETWORK_SPLIT}"
            echo "----------------------------------------"
            local i=1
            while IFS= read -r subnet; do
                local gw_ip=$(ipcalc "$subnet" | grep -oP 'HostMax:\s+\K[\d.]+' || echo "")
                printf "PJ%02d: %-18s (GW: %s)\n" "$i" "$subnet" "$gw_ip"
                i=$((i + 1))
            done <<< "$new_split"
            printf "%s\n\n" "----------------------------------------"
            read -p "${MSG_CONFIRM_CONTINUE/\[Y\/n\]/(y/n) [y]}" confirm
            
            [[ -z "$confirm" ]] && confirm="y"
            
            if [[ ! "$confirm" =~ ^[Yy] ]]; then
                # User rejected this value, update proposal for next iteration
                current_proposal="$input"
                continue
            fi
            
            preview_split="$new_split"
        fi
        
        # Store configuration
        CONFIG[PJALL_CIDR]="$input"
        
        # Store each project's CIDR and GW
        local i=1
        while IFS= read -r subnet; do
            local pj_num=$(printf "%02d" "$i")
            CONFIG["PJ${pj_num}_CIDR"]="$subnet"
            local gw_ip=$(ipcalc "$subnet" | grep -oP 'HostMax:\s+\K[\d.]+' || echo "")
            CONFIG["PJ${pj_num}_GW"]="$gw_ip"
            i=$((i + 1))
        done <<< "$preview_split"
        
        break
    done
}

input_pritunl_mainlan_ip() {
    printf "\n%s\n%s\n" "(g) ${MSG_INPUT_PT_IG_IP}" "----------------------------------------"
    
    # Propose default IP
    local ml_network="${CONFIG[ML_CIDR]%/*}"
    local ml_prefix="${CONFIG[ML_CIDR]#*/}"
    local base_ip="${ml_network%.*}"
    local default_proposal="${base_ip}.9"
    
    # Check ARP table for this IP
    log_info "${MSG_CHECKING_ARP}"
    local arp_entry
    arp_entry=$(ip neighbor show "$default_proposal" 2>/dev/null || true)

    if [[ -n "$arp_entry" ]] && [[ ! "$arp_entry" =~ INCOMPLETE|FAILED ]]; then
        # ARP entry exists. Verify reachability to avoid stale ARP false-positives.
        if is_ip_reachable "$default_proposal"; then
            log_warn "${MSG_IP_IN_USE}: $default_proposal"
            # Find next available IP (skip ips that respond)
            for octet in {10..253}; do
                local candidate="${base_ip}.${octet}"
                arp_entry=$(ip neighbor show "$candidate" 2>/dev/null || true)
                # Accept first candidate that does not respond to ping (ARP state is advisory)
                if ! is_ip_reachable "$candidate"; then
                    default_proposal="$candidate"
                    log_info "${MSG_IP_AVAILABLE}: $default_proposal"
                    break
                fi
            done
        else
            # ARP entry present but host not reachable -> likely stale
            log_info "${MSG_IP_AVAILABLE}: $default_proposal (stale ARP)"
        fi
    else
        log_info "${MSG_IP_AVAILABLE}: $default_proposal"
    fi
    
    local input
    while true; do
        printf "\n%s\n\n%s\n  IP: %s\n\n" "${MSG_PT_IG_NOTE}" "${MSG_PROPOSED_PT_IG}" "${default_proposal}"
        read -p "${MSG_ENTER_PT_IG} [${default_proposal}]: " input
        
        input="${input:-$default_proposal}"
        
        # Validate IP format
        if ! validate_ip "$input"; then
            log_error "${MSG_INVALID_IP}: $input" -c
            continue
        fi
        
        # Check if IP is within ML_CIDR range
        if ! cidr_contains "${CONFIG[ML_CIDR]}" "$input"; then
            log_error "${MSG_NETWORK_CONFLICT}: ${input} ${MSG_OVERLAPS_WITH} ${CONFIG[ML_CIDR]}" -c
            continue
        fi
        
        # Check ARP table and log details for user-entered IP
        arp_entry=$(ip neighbor show "$input" 2>/dev/null || true)
        log_info "ARP entry for ${input}: '${arp_entry}'"
        if [[ -n "$arp_entry" ]] && [[ ! "$arp_entry" =~ INCOMPLETE|FAILED ]]; then
            # Verify reachability before warning
            if is_ip_reachable "$input"; then
                log_warn "${MSG_IP_IN_USE}: $input"
                read -p "${MSG_CONFIRM_CONTINUE/\[Y\/n\]/(y/n) [n]}" confirm
                [[ -z "$confirm" ]] && confirm="n"
                if [[ ! "$confirm" =~ ^[Yy] ]]; then
                    continue
                fi
            else
                # Stale ARP, treat as available
                log_info "Ping probe for ${input}: unreachable (stale ARP). Marking available"
                log_info "${MSG_IP_AVAILABLE}: $input (stale ARP)"
            fi
        else
            # No ARP entry present; perform ping probe and log result
            if is_ip_reachable "$input"; then
                log_warn "Ping probe: ${input} is reachable (no ARP entry but host responded)"
                read -p "${MSG_CONFIRM_CONTINUE/\[Y\/n\]/(y/n) [n]}" confirm
                [[ -z "$confirm" ]] && confirm="n"
                if [[ ! "$confirm" =~ ^[Yy] ]]; then
                    continue
                fi
            else
                log_info "Ping probe for ${input}: unreachable; accepting as available"
            fi
        fi
        
        # Store configuration
        CONFIG[PT_IG_IP]="$input"
        break
    done
}

input_pritunl_vpndmz_ip() {
    printf "\n%s\n%s\n" "(h) ${MSG_INPUT_PT_EG_IP}" "----------------------------------------"
    
    # Propose default IP (.2 in VPNDMZ network)
    local vpndmz_network="${CONFIG[VPNDMZ_CIDR]%/*}"
    local base_ip="${vpndmz_network%.*}"
    local default_proposal="${base_ip}.2"
    
    log_info "Proposed Pritunl VPN DMZ IP: ${default_proposal}"
    
    local input
    while true; do
        printf "\n%s\n\n%s\n  IP: %s\n\n" "${MSG_PT_EG_NOTE}" "${MSG_PROPOSED_PT_EG}" "${default_proposal}"
        read -p "${MSG_ENTER_PT_EG} [${default_proposal}]: " input
        
        input="${input:-$default_proposal}"
        
        # Validate IP format
        if ! validate_ip "$input"; then
            log_error "${MSG_INVALID_IP}: $input" -c
            continue
        fi
        
        # Check if IP is within VPNDMZ_CIDR range
        if ! cidr_contains "${CONFIG[VPNDMZ_CIDR]}" "$input"; then
            log_error "${MSG_NETWORK_CONFLICT}: ${input} ${MSG_OVERLAPS_WITH} ${CONFIG[VPNDMZ_CIDR]}" -c
            continue
        fi
        
        # Check if IP conflicts with gateway
        if [[ "$input" == "${CONFIG[VPNDMZ_GW]}" ]]; then
            log_error "${MSG_NETWORK_CONFLICT}: ${input} ${MSG_OVERLAPS_WITH} ${CONFIG[VPNDMZ_GW]}" -c
            continue
        fi
        
        # Store configuration
        CONFIG[PT_EG_IP]="$input"
        break
    done
}

################################################################################
# Function: input_port_ranges
# Description: Read OpenVPN/WG port ranges and validate count == NUM_PJ.
################################################################################
input_port_ranges() {
    printf "\n%s\n%s\n" "${MSG_PORT_RANGE_TITLE}" "----------------------------------------"

    # Defaults
    local default_ovpn_start="${PF_ST_OV:-11856}"
    local default_wg_start="${PF_ST_WG:-15952}"
    # Use configured NUM_PJ from CONFIG (set by input_num_pj)
    local np="${CONFIG[NUM_PJ]:-8}"

    # Derive default end = start + NUM_PJ - 1 (inclusive range)
    local default_ovpn_end="$(( default_ovpn_start + np - 1 ))"
    local default_wg_end="$(( default_wg_start + np - 1 ))"

    # OpenVPN
    while true; do
        echo "${MSG_PORT_RANGE_HINT_OV}"
        read -r -p "${MSG_PORT_RANGE_PROMPT_OV} [${default_ovpn_start}-${default_ovpn_end}]: " input
        input="${input:-${default_ovpn_start}-${default_ovpn_end}}"

        if [[ ! "${input}" =~ ^([0-9]{2,5})-([0-9]{2,5})$ ]]; then
            log_error "${MSG_PORT_RANGE_FORMAT_ERR}" -c
            continue
        fi
        local s="${BASH_REMATCH[1]}" e="${BASH_REMATCH[2]}"
        if (( e < s )); then
            log_error "${MSG_PORT_RANGE_FORMAT_ERR}" -c
            continue
        fi
        local count="$(( e - s + 1 ))"
        if (( count != np )); then
            printf -v _msg "${MSG_PORT_RANGE_COUNT_ERR}" "${count}" "${np}"
            log_error "${_msg}" -c
            continue
        fi
        CONFIG[PF_ST_OV]="${s}"
        CONFIG[PF_ED_OV]="${e}"
        break
    done

    # WireGuard
    while true; do
        echo "${MSG_PORT_RANGE_HINT_WG}"
        read -r -p "${MSG_PORT_RANGE_PROMPT_WG} [${default_wg_start}-${default_wg_end}]: " input
        input="${input:-${default_wg_start}-${default_wg_end}}"

        if [[ ! "${input}" =~ ^([0-9]{2,5})-([0-9]{2,5})$ ]]; then
            log_error "${MSG_PORT_RANGE_FORMAT_ERR}" -c
            continue
        fi
        local s="${BASH_REMATCH[1]}" e="${BASH_REMATCH[2]}"
        if (( e < s )); then
            log_error "${MSG_PORT_RANGE_FORMAT_ERR}" -c
            continue
        fi
        local count="$(( e - s + 1 ))"
        if (( count != np )); then
            printf -v _msg "${MSG_PORT_RANGE_COUNT_ERR}" "${count}" "${np}"
            log_error "${_msg}" -c
            continue
        fi
        CONFIG[PF_ST_WG]="${s}"
        CONFIG[PF_ED_WG]="${e}"
        break
    done
}

input_dns_servers() {
    printf "\n%s\n%s\n" "${MSG_INPUT_DNS1}" "----------------------------------------"
    
    # DNS1 (default: ML_GW)
    local default_dns1="${CONFIG[ML_GW]}"
    local input
    
    while true; do
        printf "\n%s\n  IP: %s\n\n" "${MSG_PROPOSED_DNS1}" "${default_dns1}"
        read -p "${MSG_ENTER_DNS1} [${default_dns1}]: " input
        
        input="${input:-$default_dns1}"
        
        if ! validate_ip "$input"; then
            log_error "${MSG_INVALID_IP}: $input" -c
            continue
        fi
        
        CONFIG[DNS_IP1]="$input"
        break
    done
    
    # DNS2 (default: 1.1.1.1)
    printf "\n%s\n%s\n" "${MSG_INPUT_DNS2}" "----------------------------------------"
    
    local default_dns2="1.1.1.1"
    
    while true; do
        printf "\n%s\n  IP: %s\n\n" "${MSG_PROPOSED_DNS2}" "${default_dns2}"
        read -p "${MSG_ENTER_DNS2} [${default_dns2}]: " input
        
        # Check if user wants to skip
        if [[ "$input" =~ ^[Ss][Kk][Ii][Pp]$ ]]; then
            CONFIG[DNS_IP2]=""
            log_info "DNS Server 2 skipped"
            break
        fi
        
        # Use default if empty
        [[ -z "$input" ]] && input="$default_dns2"
        
        if ! validate_ip "$input"; then
            log_error "${MSG_INVALID_IP}: $input" -c
            continue
        fi
        
        CONFIG[DNS_IP2]="$input"
        break
    done
}
