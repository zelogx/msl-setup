#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: lib/router_prompt.sh
# Purpose: Print router configuration guidance (localized, values expanded)
#
# Main functions/commands used:
#   - source .env: load generated values
#   - log_info: formatted info output
#
# Dependencies:
#   - .env, lib/common.sh, messages_*.sh
################################################################################

print_usage_router() {
  cat <<'USAGE'
Usage: router_prompt.sh [en|jp]
  en|jp : Console language (default: en)
Notes:
  - Prints manual router configuration guidance (static routes & port forwards)
  - Values are expanded from .env
USAGE
}

parse_args_router() {
  MSL_LANG=""
  local LANG_SET=false
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      en|jp)
        if [[ "$LANG_SET" == true ]]; then
          echo "[ERROR] Multiple language codes specified"; print_usage_router; return 1
        fi
        MSL_LANG="$1"
        LANG_SET=true
        shift ;;
      -h|--help)
        print_usage_router; return 1 ;;
      *)
        echo "[ERROR] Unknown argument: $1"; print_usage_router; return 1 ;;
    esac
  done
  
  # Default to English if no language specified
  if [[ -z "$MSL_LANG" ]]; then
    MSL_LANG="en"
  fi
  export MSL_LANG
}

################################################################################
# Function: prompt_router_setup
# Description: Print localized router setup guidance with expanded .env values.
################################################################################
prompt_router_setup() {
  local script_dir project_root env_file
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  project_root="${PROJECT_ROOT:-$(cd "${script_dir}/.." && pwd)}"
  env_file="${project_root}/.env"

  # shellcheck disable=SC1090
  [[ -f "${env_file}" ]] && source "${env_file}"

  # Ensure required vars exist
  local need=(PJALL_CIDR ML_GW PF_ST_OV PF_ED_OV PF_ST_WG PF_ED_WG PT_IG_IP PT_IG_IP_LO)
  for v in "${need[@]}"; do
    if [[ -z "${!v-}" ]]; then
      log_warn "router prompt: ${v} is missing in .env"
    fi
  done

  echo
  echo "========================================"
  echo "${MSG_ROUTER_TITLE}"
  echo "----------------------------------------"
  echo "${MSG_ROUTER_INTRO}"
  echo

  # Build messages dynamically with values
  # Use localized format strings from messages
  msg_printf ROUTER_STATIC_ROUTE_LINE "${PJALL_CIDR}" "${PVE_IP}"
  msg_printf ROUTER_PF_OV_LINE "${PF_ST_OV}" "${PF_ED_OV}" "${PT_IG_IP}"
  msg_printf ROUTER_PF_WG_LINE "${PF_ST_WG}" "${PF_ED_WG}" "${PT_IG_IP}"

  echo
  # Localized follow-up message
  msg_printf ROUTER_NEXT_STEP
}

# Allow direct invocation
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if ! parse_args_router "$@"; then
    exit 1
  fi
  # Load messages after language resolution
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ "$MSL_LANG" == en ]]; then
    # shellcheck disable=SC1090
    source "$script_dir/messages_en.sh"
  else
    # shellcheck disable=SC1090
    source "$script_dir/messages_jp.sh"
  fi
  prompt_router_setup
fi
