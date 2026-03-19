#!/usr/bin/env bash
set -euo pipefail

# msl_pritunl_selinux_port.sh
# Purpose:
#   Allow Pritunl/OpenVPN (domain: pritunl_t) to bind a user-selected port
#   while keeping SELinux in Enforcing mode.
#
# Behavior:
#   1) If the port is unlabeled in SELinux, add it as openvpn_port_t
#   2) If the port is already labeled openvpn_port_t, do nothing
#   3) If the port is labeled with another type, generate a minimal local
#      policy module allowing pritunl_t to name_bind only to that type/proto
#
# Requirements:
#   - Alma/Rocky/RHEL 9
#   - policycoreutils-python-utils
#   - checkpolicy
#   - policycoreutils-devel
#
# Example:
#   sudo ./msl_pritunl_selinux_port.sh udp 20048
#   sudo ./msl_pritunl_selinux_port.sh udp 20049
#   sudo ./msl_pritunl_selinux_port.sh tcp 443
#
# Notes:
#   - This script does not change firewalld/nftables.
#   - This script does not restart Pritunl automatically.
#   - If a port has multiple SELinux types, it will handle all matched types.

SCRIPT_NAME="$(basename "$0")"
WORKDIR="/root/msl-selinux-work"
mkdir -p "$WORKDIR"

log() {
  echo "[$(date '+%F %T')] $*"
}

die() {
  echo "[$(date '+%F %T')] ERROR: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

usage() {
  cat <<EOF
Usage:
  sudo $SCRIPT_NAME <udp|tcp> <port>

Examples:
  sudo $SCRIPT_NAME udp 20048
  sudo $SCRIPT_NAME udp 20049
  sudo $SCRIPT_NAME tcp 1194
EOF
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

PROTO="$1"
PORT="$2"

[[ "$PROTO" == "udp" || "$PROTO" == "tcp" ]] || die "Protocol must be udp or tcp"
[[ "$PORT" =~ ^[0-9]+$ ]] || die "Port must be numeric"
(( PORT >= 1 && PORT <= 65535 )) || die "Port must be in range 1-65535"

if [[ $EUID -ne 0 ]]; then
  die "Please run as root"
fi

need_cmd semanage
need_cmd checkmodule
need_cmd semodule_package
need_cmd semodule
need_cmd awk
need_cmd grep
need_cmd sort

log "Checking current SELinux mode"
getenforce || true

log "Looking up SELinux port labels for ${PROTO}/${PORT}"

# Collect all matching SELinux types for the exact port/protocol.
# semanage output example:
#   nfs_port_t   udp  2049, 20048-20049
#   openvpn_port_t udp 1194
#
# We parse ranges and exact ports.
mapfile -t MATCHED_TYPES < <(
  semanage port -l | awk -v proto="$PROTO" -v port="$PORT" '
    $2 == proto {
      type = $1
      gsub(/[[:space:]]+/, "", $0)
      n = split($3, arr, ",")
      for (i = 1; i <= n; i++) {
        if (arr[i] ~ /^[0-9]+-[0-9]+$/) {
          split(arr[i], r, "-")
          if (port >= r[1] && port <= r[2]) {
            print type
            break
          }
        }
        else if (arr[i] ~ /^[0-9]+$/) {
          if (port == arr[i]) {
            print type
            break
          }
        }
      }
    }
  ' | sort -u
)

if [[ ${#MATCHED_TYPES[@]} -eq 0 ]]; then
  log "Port ${PROTO}/${PORT} is unlabeled. Adding openvpn_port_t."
  semanage port -a -t openvpn_port_t -p "$PROTO" "$PORT"
  log "Added: openvpn_port_t ${PROTO}/${PORT}"
  log "Done."
  exit 0
fi

log "Matched SELinux types for ${PROTO}/${PORT}: ${MATCHED_TYPES[*]}"

# If already openvpn_port_t only, nothing to do
ONLY_OPENVPN=true
for t in "${MATCHED_TYPES[@]}"; do
  if [[ "$t" != "openvpn_port_t" ]]; then
    ONLY_OPENVPN=false
    break
  fi
done

if [[ "$ONLY_OPENVPN" == true ]]; then
  log "Port ${PROTO}/${PORT} is already allowed as openvpn_port_t. Nothing to do."
  exit 0
fi

# If openvpn_port_t is one of several types, still generate allow rules only
# for the other types, to avoid redundant failures.
NON_OPENVPN_TYPES=()
for t in "${MATCHED_TYPES[@]}"; do
  [[ "$t" == "openvpn_port_t" ]] && continue
  NON_OPENVPN_TYPES+=("$t")
done

if [[ ${#NON_OPENVPN_TYPES[@]} -eq 0 ]]; then
  log "No extra SELinux types requiring policy changes. Done."
  exit 0
fi

SOCKET_CLASS="${PROTO}_socket"
MODULE_BASENAME="msl_pritunl_bind_${PROTO}_${PORT}"
TE_FILE="${WORKDIR}/${MODULE_BASENAME}.te"
MOD_FILE="${WORKDIR}/${MODULE_BASENAME}.mod"
PP_FILE="${WORKDIR}/${MODULE_BASENAME}.pp"

log "Generating minimal SELinux module: ${MODULE_BASENAME}"

{
  echo "module ${MODULE_BASENAME} 1.0;"
  echo
  echo "require {"
  echo "    type pritunl_t;"
  for t in "${NON_OPENVPN_TYPES[@]}"; do
    echo "    type ${t};"
  done
  echo "    class ${SOCKET_CLASS} name_bind;"
  echo "}"
  echo
  for t in "${NON_OPENVPN_TYPES[@]}"; do
    echo "allow pritunl_t ${t}:${SOCKET_CLASS} name_bind;"
  done
} > "$TE_FILE"

log "Generated policy source:"
cat "$TE_FILE"
echo

log "Compiling module"
checkmodule -M -m -o "$MOD_FILE" "$TE_FILE"

log "Packaging module"
semodule_package -o "$PP_FILE" -m "$MOD_FILE"

log "Installing module"
semodule -i "$PP_FILE"

log "Installed SELinux module: ${MODULE_BASENAME}"

log "Current local SELinux customizations:"
semanage port -l -C || true

log "Installed module list (filtered):"
semodule -lfull | grep -F "$MODULE_BASENAME" || true

log "Completed successfully."
log "Candidates for next steps:"
log "  1) Keep SELinux Enforcing"
log "  2) Restart or re-start the relevant Pritunl server"
log "  3) Re-check AVCs with: ausearch -m avc,user_avc -ts recent"
