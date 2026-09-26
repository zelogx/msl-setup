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
#   - prompt_router_setup: Static route / port forward guidance (01)
#   - prompt_router_cleanup: "no longer needed" guidance (01 --restore, 99)
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
# Function: router_prompt_colors
# Description: Set ROUTER_PROMPT_COLOR / ROUTER_PROMPT_RESET (cyan) when stdout
#              is a terminal, so that the guidance stands out. Empty otherwise
#              (no escape codes in logs or pipes).
################################################################################
router_prompt_colors() {
  if [[ -t 1 ]]; then
    ROUTER_PROMPT_COLOR=$'\033[36m'
    ROUTER_PROMPT_RESET=$'\033[0m'
  else
    ROUTER_PROMPT_COLOR=""
    ROUTER_PROMPT_RESET=""
  fi
}

################################################################################
# Function: _router_prompt_load_env
# Description: Source .env of the project (values used in the guidance).
################################################################################
_router_prompt_load_env() {
  local script_dir project_root env_file
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  project_root="${PROJECT_ROOT:-$(cd "${script_dir}/.." && pwd)}"
  env_file="${project_root}/.env"

  # shellcheck disable=SC1090
  [[ -f "${env_file}" ]] && source "${env_file}"
  return 0
}

################################################################################
# Function: prompt_router_setup
# Description: Print localized router setup guidance with expanded .env values.
#              The static route points to the cluster VIP when the cluster mode
#              is enabled (MAIN_VIP in /etc/pve/mslsetup/cluster.env), otherwise
#              to PVE_IP. Shown once at the end of 01_networkSetup.sh.
#
# Main commands/functions used:
#   - awk: Read MAIN_VIP from cluster.env
#   - msg_printf: Localized lines
################################################################################
prompt_router_setup() {
  local cluster_env="/etc/pve/mslsetup/cluster.env"
  local gateway main_vip v

  _router_prompt_load_env

  # Ensure required vars exist
  local need=(PJALL_CIDR PVE_IP PF_ST_OV PF_ED_OV PF_ST_WG PF_ED_WG PT_IG_IP)
  for v in "${need[@]}"; do
    if [[ -z "${!v-}" ]]; then
      log_warn "router prompt: ${v} is missing in .env"
    fi
  done

  gateway="${PVE_IP-}"
  if [[ -f "${cluster_env}" ]]; then
    main_vip="$(awk -F'=' '/^MAIN_VIP=/{print $2; exit}' "${cluster_env}")"
    if [[ -n "${main_vip}" ]]; then
      gateway="${main_vip%%/*} (VIP)"
    fi
  fi

  router_prompt_colors
  echo
  printf '%s' "${ROUTER_PROMPT_COLOR}"
  echo "========================================"
  echo "${MSG_ROUTER_TITLE}"
  echo "----------------------------------------"
  echo "${MSG_ROUTER_INTRO}"
  echo
  msg_printf ROUTER_STATIC_ROUTE_LINE "${PJALL_CIDR-}" "${gateway}"
  msg_printf ROUTER_PF_OV_LINE "${PF_ST_OV-}" "${PF_ED_OV-}" "${PT_IG_IP-}"
  msg_printf ROUTER_PF_WG_LINE "${PF_ST_WG-}" "${PF_ED_WG-}" "${PT_IG_IP-}"
  echo "========================================"
  printf '%s' "${ROUTER_PROMPT_RESET}"
}

################################################################################
# Function: prompt_router_cleanup
# Description: After a restore / uninstall, tell the user that the static route
#              and port forwards on the router are no longer needed.
#              Shown once at the end of 01_networkSetup.sh --restore and
#              99_uninstall.sh. Prints nothing if .env has no values.
#
# Main commands/functions used:
#   - msg_printf: Localized lines
################################################################################
prompt_router_cleanup() {
  _router_prompt_load_env
  [[ -n "${PJALL_CIDR-}" ]] || return 0

  router_prompt_colors
  echo
  printf '%s' "${ROUTER_PROMPT_COLOR}"
  echo "========================================"
  echo "${MSG_ROUTER_CLEANUP_TITLE}"
  echo "----------------------------------------"
  echo "${MSG_ROUTER_CLEANUP_INTRO}"
  echo
  msg_printf ROUTER_CLEANUP_ROUTE_LINE "${PJALL_CIDR}"
  msg_printf ROUTER_PF_OV_LINE "${PF_ST_OV-}" "${PF_ED_OV-}" "${PT_IG_IP-}"
  msg_printf ROUTER_PF_WG_LINE "${PF_ST_WG-}" "${PF_ED_WG-}" "${PT_IG_IP-}"
  echo "========================================"
  printf '%s' "${ROUTER_PROMPT_RESET}"
}

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
