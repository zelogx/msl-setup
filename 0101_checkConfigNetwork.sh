#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: 00_check_env.sh
# Purpose: Discover existing network configuration and generate .env file
#
# Dependencies:
#   - lib/common.sh
#   - lib/network.sh
#   - lib/input_functions.sh
#   - lib/messages_*.sh
#   - ipcalc, jq
#
# Usage:
#   ./00_check_env.sh [en|jp] [--verbose]
#
# Notes:
#   - Must be run as root on Proxmox VE host
#   - Interactive mode with multi-language support (pass en|jp as first argument; default en)
#   - Use --verbose to show log messages on console (always written to log file)
################################################################################

set -euo pipefail

print_usage_check_env() {
    cat <<'USAGE'
Usage: 00_check_env.sh [en|jp] [--verbose]
    en|jp        : Console language (default: en)
    --verbose|-v : Echo log messages to console (always logged to file)
Notes:
    - Must be run on Proxmox host as root
    - Generates .env interactively (Phase 0 legacy script)
USAGE
}

MSL_LANG=""
MSL_VERBOSE="false"
LANG_SET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        en|jp)
            if [[ "$LANG_SET" == true ]]; then
                echo "[ERROR] Multiple language codes specified"; print_usage_check_env; exit 1
            fi
            MSL_LANG="$1"
            LANG_SET=true
            shift ;;
        --verbose|-v)
            MSL_VERBOSE="true"; shift ;;
        -h|--help)
            print_usage_check_env; exit 0 ;;
        *)
            echo "[ERROR] Unknown argument: $1"; print_usage_check_env; exit 1 ;;
    esac
done

# Default to English if no language specified
if [[ -z "$MSL_LANG" ]]; then
    MSL_LANG="en"
fi
export MSL_LANG MSL_VERBOSE

# Get script directory and load libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
source "${PROJECT_ROOT}/lib/common.sh"
source "${PROJECT_ROOT}/lib/network.sh"
source "${PROJECT_ROOT}/lib/input_functions.sh"
source "${PROJECT_ROOT}/lib/env_generator.sh"
source "${PROJECT_ROOT}/lib/svg_generator.sh"
source "${PROJECT_ROOT}/lib/router_prompt.sh"

# Load language-specific messages
if [[ "${MSL_LANG}" == "en" ]]; then
    source "${PROJECT_ROOT}/lib/messages_en.sh"
else
    source "${PROJECT_ROOT}/lib/messages_jp.sh"
fi

# Global variables for discovered/configured values
declare -A CONFIG

################################################################################
# Function: main
# Description: Main script execution flow
#
# Returns:
#   0: Success
#   1: Error
################################################################################
main() {
    echo "========================================"
    echo "${MSG_WELCOME}"
    echo "========================================"
    echo ""
    
    # Phase 1: Interactive Input (order: a→b→e→c→d→f→g→h→i)
    echo "${MSG_PHASE} 1: ${MSG_DISCOVERING_NETWORK}"
    echo "----------------------------------------"
    
    # (a) MainLAN configuration
    input_mainlan
    
    # (b) PVE IP
    input_pve_ip
    
    # (e) Number of projects
    input_num_pj
    
    # (c) VPN DMZ network
    input_vpndmz_network
    
    # (d) VPN Client Pool
    input_vpn_pool
    
    # (f) Project Networks
    input_pjall_network
    
    # (g) Pritunl MainLAN IP
    input_pritunl_mainlan_ip
    
    # (h) Pritunl VPN DMZ IP
    input_pritunl_vpndmz_ip
    
    # (i) Port Ranges
    input_port_ranges
    
    # DNS Servers
    input_dns_servers
    
    # Phase 2: Generate .env file
    echo ""
    echo "Generating configuration files"
    echo "----------------------------------------"
    generate_env
    
    # Generate SVG network diagram
    generate_svg_diagram

    echo ""
    echo "========================================"
    echo "${MSG_PHASE_COMPLETE}: Configuration complete"
    echo "========================================"
}

# Execute main function
main "$@"
