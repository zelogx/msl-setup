#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: sdn_backup_restore.sh
# Purpose: Encapsulate SDN backup and restore (live state dump, backup file dump,
#          deletion to backup state, and post-restore state logging)
#
# Main functions/commands used:
#   - pvesh: Query and mutate Proxmox SDN & firewall config
#   - jq: Parse JSON (for data extraction only, not formatting)
#   - ip route: Show kernel routing tables
#
# Dependencies:
#   - pvesh, jq, iproute2, bash
#
# Usage:
#   source lib/sdn_backup_restore.sh
#   msl_handle_backup_restore "${RESTORE_ONLY}"  # Performs backup or restore flows
#
# Notes:
#   - Relies on global variables: backup_dir, backup_complete_flag, VPN_POOL,
#     MSG_* localization strings, log_info/log_warn/log_error functions.
################################################################################

################################################################################
# Function: _dump_sdn_state
# Description: Generic helper to dump SDN/firewall/route state (live or backup)
# Main commands/functions used:
#   - pvesh get ... : Retrieve live config
#   - cat: Read backup files
#   - ip route show : Kernel routes
################################################################################
_dump_sdn_state() {
    local source="$1"  # "live" or "backup"
    local label_prefix="$2"  # e.g., "Current" or "Backup"
    
    if [[ "$source" == "live" ]]; then
        log_info "${label_prefix} SDN Zones:"
        pvesh get /cluster/sdn/zones --output-format json 2>/dev/null | while IFS= read -r l; do log_info "  $l"; done || true
        log_info "${label_prefix} SDN VNets:"
        pvesh get /cluster/sdn/vnets --output-format json 2>/dev/null | while IFS= read -r l; do log_info "  $l"; done || true
        local vnets
        vnets=$(pvesh get /cluster/sdn/vnets --output-format json 2>/dev/null | jq -r '.[].vnet' || echo "")
        if [[ -n "$vnets" ]]; then
            for v in $vnets; do
                log_info "${label_prefix} SDN Subnets for VNet $v:"
                pvesh get /cluster/sdn/vnets/$v/subnets --output-format json 2>/dev/null | while IFS= read -r l; do log_info "  $l"; done || true
            done
        fi
        log_info "${label_prefix} Firewall IPSets:"
        pvesh get /cluster/firewall/ipset --output-format json 2>/dev/null | while IFS= read -r l; do log_info "  $l"; done || true
        local ipsets
        ipsets=$(pvesh get /cluster/firewall/ipset --output-format json 2>/dev/null | jq -r '.[].name' || echo "")
        if [[ -n "$ipsets" ]]; then
            for n in $ipsets; do
                log_info "${label_prefix} entries for IPSet $n:"
                pvesh get /cluster/firewall/ipset/$n --output-format json 2>/dev/null | while IFS= read -r l; do log_info "  $l"; done || true
            done
        fi
        # Security Groups removed in v2.0 (no dump)
        # Datacenter firewall options (enable state, policies)
        log_info "${label_prefix} Firewall Options:"
        pvesh get /cluster/firewall/options --output-format json 2>/dev/null | while IFS= read -r l; do log_info "  $l"; done || true
        # Host-level firewall rules (v2.0)
        local node_name
        node_name=$(hostname)
        log_info "${label_prefix} Host Firewall Rules (node: $node_name):"
        pvesh get "/nodes/${node_name}/firewall/rules" --output-format json 2>/dev/null | while IFS= read -r l; do log_info "  $l"; done || true
        log_info "${label_prefix} kernel routes:"
        ip route show 2>/dev/null | while IFS= read -r l; do log_info "  $l"; done || true
        log_info "${label_prefix} VPN pool specific route:"
        ip route show to "$VPN_POOL" 2>/dev/null | while IFS= read -r l; do log_info "  $l"; done || true
    elif [[ "$source" == "backup" ]]; then
        if [[ -f "$backup_dir/sdn_zones_initial.json" ]]; then
            log_info "${label_prefix} SDN Zones JSON:"; cat "$backup_dir/sdn_zones_initial.json" | while IFS= read -r l; do log_info "  $l"; done || true
        fi
        if [[ -f "$backup_dir/sdn_vnets_initial.json" ]]; then
            log_info "${label_prefix} SDN VNets JSON:"; cat "$backup_dir/sdn_vnets_initial.json" | while IFS= read -r l; do log_info "  $l"; done || true
        fi
        for bf in "$backup_dir"/sdn_subnets_*_initial.json; do
            [[ -f "$bf" ]] || continue
            local vn
            vn=$(echo "$bf" | sed -E 's/.*sdn_subnets_(.+)_initial.json/\1/')
            log_info "${label_prefix} SDN Subnets for VNet $vn JSON:"; cat "$bf" | while IFS= read -r l; do log_info "  $l"; done || true
        done
        if [[ -f "$backup_dir/firewall_ipset_initial.json" ]]; then
            log_info "${label_prefix} Firewall IPSets JSON:"; cat "$backup_dir/firewall_ipset_initial.json" | while IFS= read -r l; do log_info "  $l"; done || true
            local b_ipsets
            b_ipsets=$(cat "$backup_dir/firewall_ipset_initial.json" | jq -r '.[].name' || echo "")
            if [[ -n "$b_ipsets" ]]; then
                for n in $b_ipsets; do
                    log_info "${label_prefix} entries for IPSet $n JSON:"; pvesh get /cluster/firewall/ipset/$n --output-format json 2>/dev/null | while IFS= read -r l; do log_info "  $l"; done || true
                done
            fi
        fi
        # Security Group backup removed in v2.0 (no file expected)
        if [[ -f "$backup_dir/firewall_options_initial.json" ]]; then
            log_info "${label_prefix} Firewall Options JSON:"; cat "$backup_dir/firewall_options_initial.json" | while IFS= read -r l; do log_info "  $l"; done || true
        fi
        if [[ -f "$backup_dir/host_firewall_rules_initial.json" ]]; then
            log_info "${label_prefix} Host Firewall Rules JSON:"; cat "$backup_dir/host_firewall_rules_initial.json" | while IFS= read -r l; do log_info "  $l"; done || true
        fi
        if [[ -f "$backup_dir/route_all_initial.txt" ]]; then
            log_info "${label_prefix} all routes snapshot:"; while IFS= read -r l; do log_info "  $l"; done < "$backup_dir/route_all_initial.txt" || true
        fi
        if [[ -f "$backup_dir/route_vpn_pool_initial.txt" ]]; then
            log_info "${label_prefix} VPN pool route snapshot:"; while IFS= read -r l; do log_info "  $l"; done < "$backup_dir/route_vpn_pool_initial.txt" || true
        fi
    fi
}

################################################################################
# Function: msl_dump_live_state
# Description: Dump current live SDN/firewall/route state to logs (JSON + raw)
################################################################################
msl_dump_live_state() {
    log_info "==== PRE-RESTORE CURRENT STATE ===="
    _dump_sdn_state "live" "Current (live)"
}

################################################################################
# Function: msl_dump_backup_files
# Description: Dump existing backup JSON/text snapshots to logs
################################################################################
msl_dump_backup_files() {
    log_info "==== BACKUP FILE CONTENTS ===="
    _dump_sdn_state "backup" "Backup"
}

################################################################################
# Function: _report_missing
# Description: Log and print missing resources expected from backup (non-fatal)
# Main commands/functions used:
#   - log_error: Log missing resource
#   - echo: Emit concise console error (English only)
################################################################################
_report_missing() {
    local kind="$1"
    local name="$2"
    log_error "Missing ${kind} from backup: ${name}"
    echo "[ERROR] Missing ${kind} from backup: ${name}" >&2
}

################################################################################
# Function: _list_contains
# Description: Check if a newline-delimited list contains an exact item
################################################################################
_list_contains() {
    local needle="$1"
    local haystack="$2"
    echo "$haystack" | grep -Fxq "$needle"
}

################################################################################
# Function: _pvesh_delete_logged
# Description: Delete a pvesh resource and log stderr/rc on failure
################################################################################
_pvesh_delete_logged() {
    local desc="$1"
    local path="$2"
    local output
    output=$(pvesh delete "$path" 2>&1)
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        log_error "Failed to delete ${desc} (path=${path}, rc=${rc}): ${output}"
        echo "[ERROR] Failed to delete ${desc} (path=${path}, rc=${rc}): ${output}" >&2
    fi
    return $rc
}

################################################################################
# Function: _route_del_logged
# Description: Delete a route and log stderr/rc on failure
################################################################################
_route_del_logged() {
    local desc="$1"
    local target="$2"
    local output
    output=$(ip route del "$target" 2>&1)
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        log_error "Failed to delete ${desc} (${target}, rc=${rc}): ${output}"
        echo "[ERROR] Failed to delete ${desc} (${target}, rc=${rc}): ${output}" >&2
    fi
    return $rc
}

################################################################################
# Function: _backup_and_log_sdn_state
# Description: Backup SDN/firewall/route state to files and log contents
################################################################################
_backup_and_log_sdn_state() {
    pvesh get /cluster/sdn/zones --output-format json > "$backup_dir/sdn_zones_initial.json" 2>/dev/null || echo '[]' > "$backup_dir/sdn_zones_initial.json"
    log_info "SDN Zones JSON:"; cat "$backup_dir/sdn_zones_initial.json" | while IFS= read -r l; do log_info "  $l"; done
    
    pvesh get /cluster/sdn/vnets --output-format json > "$backup_dir/sdn_vnets_initial.json" 2>/dev/null || echo '[]' > "$backup_dir/sdn_vnets_initial.json"
    log_info "SDN VNets JSON:"; cat "$backup_dir/sdn_vnets_initial.json" | while IFS= read -r l; do log_info "  $l"; done
    
    local vnets
    vnets=$(pvesh get /cluster/sdn/vnets --output-format json 2>/dev/null | jq -r '.[].vnet' || echo "")
    if [[ -n "$vnets" ]]; then
        for v in $vnets; do
            pvesh get /cluster/sdn/vnets/$v/subnets --output-format json > "$backup_dir/sdn_subnets_${v}_initial.json" 2>/dev/null || echo '[]' > "$backup_dir/sdn_subnets_${v}_initial.json"
            log_info "SDN Subnets for VNet $v JSON:"; cat "$backup_dir/sdn_subnets_${v}_initial.json" | while IFS= read -r l; do log_info "  $l"; done
        done
    else
        log_info "No VNets found, no subnets to backup"
    fi
    
    pvesh get /cluster/firewall/ipset --output-format json > "$backup_dir/firewall_ipset_initial.json" 2>/dev/null || echo '[]' > "$backup_dir/firewall_ipset_initial.json"
    log_info "Firewall IPSets JSON:"; cat "$backup_dir/firewall_ipset_initial.json" | while IFS= read -r l; do log_info "  $l"; done
    local ipsets
    ipsets=$(cat "$backup_dir/firewall_ipset_initial.json" | jq -r '.[].name' || echo "")
    if [[ -n "$ipsets" ]]; then
        for n in $ipsets; do
            log_info "IPSet '$n' entries JSON:"; pvesh get /cluster/firewall/ipset/$n --output-format json 2>/dev/null | while IFS= read -r l; do log_info "  $l"; done
        done
    fi
    
    # Security Groups deprecated (no backup)

    # Datacenter firewall options (enable state & policies)
    pvesh get /cluster/firewall/options --output-format json > "$backup_dir/firewall_options_initial.json" 2>/dev/null || echo '{}' > "$backup_dir/firewall_options_initial.json"
    log_info "Firewall Options JSON:"; cat "$backup_dir/firewall_options_initial.json" | while IFS= read -r l; do log_info "  $l"; done

    # Host-level firewall rules (v2.0)
    local node_name
    node_name=$(hostname)
    # Host firewall options (enable, nftables)
    pvesh get "/nodes/${node_name}/firewall/options" --output-format json > "$backup_dir/host_firewall_options_initial.json" 2>/dev/null || echo '{}' > "$backup_dir/host_firewall_options_initial.json"
    log_info "Host Firewall Options JSON (node: $node_name):"; cat "$backup_dir/host_firewall_options_initial.json" | while IFS= read -r l; do log_info "  $l"; done
    pvesh get "/nodes/${node_name}/firewall/rules" --output-format json > "$backup_dir/host_firewall_rules_initial.json" 2>/dev/null || echo '[]' > "$backup_dir/host_firewall_rules_initial.json"
    log_info "Host Firewall Rules JSON (node: $node_name):"; cat "$backup_dir/host_firewall_rules_initial.json" | while IFS= read -r l; do log_info "  $l"; done
    
    ip route show > "$backup_dir/route_all_initial.txt" 2>/dev/null || echo "" > "$backup_dir/route_all_initial.txt"
    log_info "All routes:"; while IFS= read -r l; do log_info "  $l"; done < "$backup_dir/route_all_initial.txt" || true
    
    ip route show to "$VPN_POOL" > "$backup_dir/route_vpn_pool_initial.txt" 2>/dev/null || echo "" > "$backup_dir/route_vpn_pool_initial.txt"
    if [[ -s "$backup_dir/route_vpn_pool_initial.txt" ]]; then
        local rc
        rc=$(cat "$backup_dir/route_vpn_pool_initial.txt")
        log_info "VPN pool route: $rc"
    else
        log_info "No VPN pool route found"
    fi
}

################################################################################
# Function: msl_perform_backup
# Description: Perform initial backup and dump initial state + backup content
################################################################################
msl_perform_backup() {
    log_info "$MSG_SDN_BACKUP_START"
    log_info "==== INITIAL STATE (BEFORE BACKUP) ===="
    _backup_and_log_sdn_state
    touch "$backup_complete_flag"
    log_info "Backup complete: $backup_dir"
    log_info "==== END INITIAL STATE ===="
}

################################################################################
# Function: msl_restore_to_backup
# Description: Delete resources not present in backup and dump post-restore state
################################################################################
msl_restore_to_backup() {
    log_info "$MSG_SDN_RESTORE_EXISTING"
    echo "$MSG_SDN_DELETING_IN_PROGRESS"
    msl_dump_live_state
    msl_dump_backup_files
    log_info "==== RESTORE OPERATION: Analyzing backup and current state ===="
    local backup_zones backup_vnets
    backup_zones=$(cat "$backup_dir/sdn_zones_initial.json" | jq -r '.[].zone' || echo "")
    backup_vnets=$(cat "$backup_dir/sdn_vnets_initial.json" | jq -r '.[].vnet' || echo "")
    local zone_count vnet_count ipset_count
    zone_count=$(cat "$backup_dir/sdn_zones_initial.json" | jq '. | length')
    vnet_count=$(cat "$backup_dir/sdn_vnets_initial.json" | jq '. | length')
    ipset_count=$(cat "$backup_dir/firewall_ipset_initial.json" | jq '. | length')
    log_info "Backup state summary:"; log_info "  Zones: $zone_count, VNets: $vnet_count, IPSets: $ipset_count"
    local node_name
    node_name=$(hostname)

    echo -n "Deleting VPN pool route........"
    
    # Delete VPN pool route FIRST (before VNet deletion which would auto-delete it)
    local backup_route
    backup_route=$(cat "$backup_dir/route_vpn_pool_initial.txt" 2>/dev/null || echo "")
    log_info "Checking VPN pool route restore status..."
    if [[ -z "$backup_route" ]]; then
        log_info "Backup had no VPN pool route"
        if ip route show to "$VPN_POOL" 2>/dev/null | grep -q .; then
            local current_route
            current_route=$(ip route show to "$VPN_POOL")
            log_info "Current VPN pool route exists: $current_route"
            log_info "Deleting VPN pool route not present in backup..."
            _route_del_logged "VPN pool route" "$VPN_POOL"
        else
            log_info "No VPN pool route currently exists"
        fi
    else
        if ip route show to "$VPN_POOL" 2>/dev/null | grep -q .; then
            log_info "VPN pool route exists and is retained"
        else
            _report_missing "VPN pool route" "$VPN_POOL"
        fi
    fi
    echo " [OK]"
    
    # Delete Subnets not in backup and warn on missing
    local current_vnets
    current_vnets=$(pvesh get /cluster/sdn/vnets --output-format json 2>/dev/null | jq -r '.[].vnet' || echo "")
    echo -n "Deleting subnets not in backup.."
    if [[ -n "$current_vnets" ]]; then
        for v in $current_vnets; do
            local backup_subnet_file backup_subnets current_subnets
            backup_subnet_file="$backup_dir/sdn_subnets_${v}_initial.json"
            if [[ -f "$backup_subnet_file" ]]; then
                backup_subnets=$(cat "$backup_subnet_file" | jq -r '.[].subnet' || echo "")
            else
                backup_subnets=""
            fi
            current_subnets=$(pvesh get /cluster/sdn/vnets/$v/subnets --output-format json 2>/dev/null | jq -r '.[].subnet' || echo "")
            if [[ -n "$current_subnets" ]]; then
                for s in $current_subnets; do
                    if ! _list_contains "$s" "$backup_subnets"; then
                        log_info "Deleting subnet not present in backup: $s (vnet: $v)"
                        _pvesh_delete_logged "SDN subnet $s (vnet: $v)" "/cluster/sdn/vnets/$v/subnets/$s"
                        echo -n "."
                    fi
                done
            fi
            if [[ -n "$backup_subnets" ]]; then
                while IFS= read -r s; do
                    [[ -z "$s" ]] && continue
                    if ! _list_contains "$s" "$current_subnets"; then
                        _report_missing "SDN subnet ($v)" "$s"
                    fi
                done <<< "$backup_subnets"
            fi
        done
    fi
    echo " [OK]"

    echo -n "Deleting VNets not in backup...."
    if [[ -n "$current_vnets" ]]; then
        for v in $current_vnets; do
            if ! _list_contains "$v" "$backup_vnets"; then
                log_info "Deleting VNet not present in backup: $v"
                _pvesh_delete_logged "SDN VNet $v" "/cluster/sdn/vnets/$v"
                echo -n "."
            fi
        done
    fi
    echo " [OK]"
    if [[ -n "$backup_vnets" ]]; then
        while IFS= read -r v; do
            [[ -z "$v" ]] && continue
            if ! _list_contains "$v" "$current_vnets"; then
                _report_missing "SDN VNet" "$v"
            fi
        done <<< "$backup_vnets"
    fi
    echo -n "Deleting zones not in backup...."
    local current_zones
    current_zones=$(pvesh get /cluster/sdn/zones --output-format json 2>/dev/null | jq -r '.[].zone' || echo "")
    if [[ -n "$current_zones" ]]; then
        for z in $current_zones; do
            if ! _list_contains "$z" "$backup_zones"; then
                log_info "Deleting zone not present in backup: $z"
                _pvesh_delete_logged "SDN zone $z" "/cluster/sdn/zones/$z"
                echo -n "."
            fi
        done
    fi
    echo " [OK]"
    if [[ -n "$backup_zones" ]]; then
        while IFS= read -r z; do
            [[ -z "$z" ]] && continue
            if ! _list_contains "$z" "$current_zones"; then
                _report_missing "SDN zone" "$z"
            fi
        done <<< "$backup_zones"
    fi
    log_info "Applying SDN delete configuration..."; pvesh set /cluster/sdn >/dev/null 2>&1
    log_info "$MSG_SDN_FW_RESTORE"

    # Restore datacenter firewall options (enable state)
    echo -n "Aligning DC firewall options...."
    if [[ -f "$backup_dir/firewall_options_initial.json" ]]; then
        local backup_enable
        backup_enable=$(jq -r '.enable // 0' "$backup_dir/firewall_options_initial.json" 2>/dev/null || echo 0)
        log_info "Aligning datacenter firewall enable to backup (enable=$backup_enable)"
        pvesh set /cluster/firewall/options -enable "$backup_enable" >/dev/null 2>&1 || log_error "Failed to align datacenter firewall enable=$backup_enable"
    else
        log_warn "No firewall_options_initial.json found; leaving current datacenter firewall options unchanged"
    fi
    echo " [OK]"

    # Restore host firewall options (enable, nftables)
    echo -n "Aligning host firewall options.."
    if [[ -f "$backup_dir/host_firewall_options_initial.json" ]]; then
        local host_enable host_nft
        host_enable=$(jq -r '.enable // 0' "$backup_dir/host_firewall_options_initial.json" 2>/dev/null || echo 0)
        host_nft=$(jq -r '.nftables // 0' "$backup_dir/host_firewall_options_initial.json" 2>/dev/null || echo 0)
        log_info "Aligning host firewall options: enable=$host_enable nftables=$host_nft"
        pvesh set "/nodes/${node_name}/firewall/options" -enable "$host_enable" -nftables "$host_nft" >/dev/null 2>&1 || log_error "Failed to align host firewall options"
    else
        log_warn "No host_firewall_options_initial.json found; leaving current host firewall options unchanged"
    fi
    echo " [OK]"

    # Reconcile host-level firewall rules (v2.0): delete extras, warn on missing, do not recreate
    log_info "Reconciling host-level firewall rules (delete extras, warn on missing)"
    echo -n "Deleting extra host FW rules....."
    if [[ -f "$backup_dir/host_firewall_rules_initial.json" ]]; then
        local backup_rules_norm current_rules_json backup_rules_norm_list
        backup_rules_norm=$(jq -r '.[] | del(.pos) | @json' "$backup_dir/host_firewall_rules_initial.json" 2>/dev/null || echo "")
        current_rules_json=$(pvesh get "/nodes/${node_name}/firewall/rules" --output-format json 2>/dev/null || echo '[]')
        # Delete rules not present in backup (process in reverse order to avoid position shifts)
        echo "$current_rules_json" | jq -c '[.[] | {pos, norm:(del(.pos))}] | sort_by(.pos) | reverse | .[]' | while IFS= read -r rule_obj; do
            local pos norm_rule
            pos=$(echo "$rule_obj" | jq -r '.pos')
            norm_rule=$(echo "$rule_obj" | jq -c '.norm')
            if ! _list_contains "$norm_rule" "$backup_rules_norm"; then
                log_info "Deleting host firewall rule at position $pos (not in backup)"
                _pvesh_delete_logged "host firewall rule at position $pos" "/nodes/${node_name}/firewall/rules/$pos"
                echo -n "."
            fi
        done
        # Warn on missing rules that were in backup
        backup_rules_norm_list="$backup_rules_norm"
        if [[ -n "$backup_rules_norm_list" ]]; then
            local current_rules_norm_after
            current_rules_norm_after=$(pvesh get "/nodes/${node_name}/firewall/rules" --output-format json 2>/dev/null | jq -r '.[] | del(.pos) | @json' || echo "")
            while IFS= read -r bnorm; do
                [[ -z "$bnorm" ]] && continue
                if ! _list_contains "$bnorm" "$current_rules_norm_after"; then
                    _report_missing "Host firewall rule" "$bnorm"
                fi
            done <<< "$backup_rules_norm_list"
        fi
    else
        log_warn "No host_firewall_rules_initial.json found in backup; leaving current host firewall rules unchanged"
    fi
    echo " [OK]"

    local backup_ipsets
    backup_ipsets=$(cat "$backup_dir/firewall_ipset_initial.json" | jq -r '.[].name' || echo "")
    local current_ipsets
    current_ipsets=$(pvesh get /cluster/firewall/ipset --output-format json 2>/dev/null | jq -r '.[].name' || echo "")
    echo -n "Deleting IPSets not in backup...."
    if [[ -n "$current_ipsets" ]]; then
        for ipset in $current_ipsets; do
            if ! _list_contains "$ipset" "$backup_ipsets"; then
                log_info "Deleting IPSet not present in backup: $ipset"
                local entries
                entries=$(pvesh get /cluster/firewall/ipset/$ipset --output-format json 2>/dev/null | jq -r '.[].cidr' || echo "")
                if [[ -n "$entries" ]]; then
                    for cidr in $entries; do
                        log_info "Deleting IPSet entry: $ipset/$cidr"
                        _pvesh_delete_logged "IPSet entry $ipset/$cidr" "/cluster/firewall/ipset/$ipset/$cidr"
                        echo -n "."
                    done
                fi
                _pvesh_delete_logged "IPSet $ipset" "/cluster/firewall/ipset/$ipset"
                echo -n "."
            fi
        done
    fi
    echo " [OK]"
    if [[ -n "$backup_ipsets" ]]; then
        while IFS= read -r ipset; do
            [[ -z "$ipset" ]] && continue
            if ! _list_contains "$ipset" "$current_ipsets"; then
                _report_missing "Firewall IPSet" "$ipset"
            fi
        done <<< "$backup_ipsets"
    fi

    # (Datacenter firewall options already restored earlier)
    log_info "$MSG_SDN_RESTORE_DONE"
    log_info "==== POST-RESTORE STATE ===="
    _dump_sdn_state "live" "Post-restore (live)"
    log_info "==== END POST-RESTORE STATE ===="
}

################################################################################
# Function: msl_handle_backup_restore
# Description: Decide whether to backup (first run) or restore (subsequent run)
################################################################################
msl_handle_backup_restore() {
    local restore_only_flag="$1"
    local had_backup_at_start=false
    if [[ -f "$backup_complete_flag" ]]; then
        had_backup_at_start=true
    fi

    # --restore: do not create backup; only restore if a backup already exists
    if [[ "$restore_only_flag" == true ]]; then
        if [[ "$had_backup_at_start" == true ]]; then
            msl_restore_to_backup
            echo "[SUCCESS] $MSG_SDN_RESTORE_ONLY_DONE"
        else
            log_warn "Restore-only requested but no backup existed at start; skipping restore"
            echo "[WARN] $MSG_SDN_RESTORE_ONLY_NO_BACKUP"
        fi
        exit 0
    fi

    # Normal run: create backup only when none existed, but skip restore on very first run
    if [[ "$had_backup_at_start" == false ]]; then
        msl_perform_backup
    fi

    if [[ "$had_backup_at_start" == true ]]; then
        msl_restore_to_backup
    else
        log_info "First run detected; skipping restore because no backup existed at start"
    fi
}
