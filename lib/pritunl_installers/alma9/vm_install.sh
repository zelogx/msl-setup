#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: vm_install.sh
# Purpose: Install and configure Pritunl / MongoDB inside the Pritunl VM
#          (AlmaLinux 9) and create the per-project VPN servers
#
# Main functions/commands used:
#   - dnf/yum: Package installation
#   - systemctl: Service management
#   - pritunl: CLI configuration
#   - msl_pritunl_selinux_port.sh: SELinux port labels
#   - pritunl_build_helper.py mongodb: Create VPN servers in MongoDB
#
# Dependencies:
#   - Files in the same directory (copied by 0202_configurePritunl.sh):
#       .env, msl_pritunl_selinux_port.sh, pritunl_build_helper.py
#
# Usage:
#   bash /root/msl-install/vm_install.sh
#   Run by 0202_configurePritunl.sh over SSH (as root, inside the VM).
#
# Notes:
#   - Runs as a standalone script: messages go to stdout/stderr only (English).
#     The host shows them on its console and records them in its log file.
#   - On failure, the failing command, the step and diagnostics (disk, packages,
#     service status and journal) are printed and the exit code is non-zero.
#   - Re-runs start from the VM snapshot taken by 0202, so the steps do not
#     need to be idempotent.
################################################################################

set -Eeuo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${INSTALL_DIR}/.env"
readonly TOTAL_STEPS=12
CURRENT_STEP="(start)"

################################################################################
# Function: log
# Description: Print a message line (stdout)
################################################################################
log() {
    echo "[vm_install] $*"
}

################################################################################
# Function: step
# Description: Print the step header and remember it for error reports
################################################################################
step() {
    CURRENT_STEP="[$1/${TOTAL_STEPS}] $2"
    echo ""
    echo "==> ${CURRENT_STEP}"
}

################################################################################
# Function: fail
# Description: Print an error and exit (diagnostics are printed by on_exit)
################################################################################
fail() {
    echo "[vm_install] ERROR: $*"
    exit 1
}

################################################################################
# Function: on_error
# Description: ERR trap. Report the command that failed.
################################################################################
on_error() {
    local rc="$1"
    local line="$2"
    local cmd="$3"
    echo "[vm_install] ERROR: command failed (exit ${rc}) at line ${line}: ${cmd}"
}

################################################################################
# Function: dump_diagnostics
# Description: Print information that helps to find the cause of a failure.
#              Every command is allowed to fail.
################################################################################
dump_diagnostics() {
    set +e
    echo ""
    echo "---------------- diagnostics ----------------"
    echo "# df -h /"
    df -h /
    echo "# installed packages (pritunl / mongodb / openvpn / wireguard)"
    rpm -qa | grep -E 'pritunl|mongodb|openvpn|wireguard'
    local svc
    for svc in mongod pritunl; do
        echo "# systemctl status ${svc}"
        systemctl status "${svc}" --no-pager
        echo "# journalctl -u ${svc} -n 50"
        journalctl -u "${svc}" -n 50 --no-pager
    done
    echo "---------------------------------------------"
}

################################################################################
# Function: on_exit
# Description: EXIT trap. On failure, print the step and diagnostics.
################################################################################
on_exit() {
    local rc="$1"
    # The ERR trap also fires with set +e; diagnostics commands may fail
    trap - ERR
    if [ "${rc}" -ne 0 ]; then
        echo "[vm_install] FAILED at step ${CURRENT_STEP} (exit ${rc})"
        dump_diagnostics
        echo "[vm_install] FAILED at step ${CURRENT_STEP} (exit ${rc})"
    fi
}

trap 'on_error $? $LINENO "$BASH_COMMAND"' ERR
trap 'on_exit $?' EXIT

# ------------------------------------------------------------------------------
step 1 "Checking prerequisites"
# ------------------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || fail "Must be run as root"
[ -f "${ENV_FILE}" ] || fail ".env not found: ${ENV_FILE}"
# shellcheck source=/dev/null
source "${ENV_FILE}"
for var in PT_IG_IP PF_ST_OV PF_ED_OV PF_ST_WG PF_ED_WG; do
    [ -n "${!var:-}" ] || fail "Required variable ${var} is not set in .env"
done
for f in msl_pritunl_selinux_port.sh pritunl_build_helper.py; do
    [ -f "${INSTALL_DIR}/${f}" ] || fail "File not found: ${INSTALL_DIR}/${f}"
done
command -v python3 >/dev/null 2>&1 || fail "python3 not found"

avail_mb=$(df -m / | awk 'NR==2 {print $4}')
log "Available disk space on /: ${avail_mb} MB"
if [ "${avail_mb}" -lt 2000 ]; then
    df -h
    fail "Insufficient disk space: ${avail_mb} MB available, need at least 2000 MB"
fi

# ------------------------------------------------------------------------------
step 2 "Adding MongoDB 8.2 and Pritunl repositories"
# ------------------------------------------------------------------------------
# MongoDB 8.2 packages are signed with the 8.0 server key
cat > /etc/yum.repos.d/mongodb-org.repo <<'REPO'
[mongodb-org-8.2]
name=MongoDB 8.2 Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/8.2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-8.0.asc
REPO

# Pritunl repository for AlmaLinux 9 (per official guidance)
cat > /etc/yum.repos.d/pritunl.repo <<'REPO'
[pritunl]
name=Pritunl Repository
baseurl=https://repo.pritunl.com/stable/yum/almalinux/9/
gpgcheck=1
enabled=1
gpgkey=https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc
REPO

# ------------------------------------------------------------------------------
step 3 "Installing packages (this may take a few minutes)"
# ------------------------------------------------------------------------------
dnf -y update
# Use pritunl-openvpn from the Pritunl repository instead of EPEL openvpn
# (recommended by Pritunl). The swap fails when openvpn is not installed.
yum -y swap openvpn pritunl-openvpn || true
yum -y --allowerasing install pritunl-openvpn
# SELinux policy tools are used in step 7
dnf -y install pritunl pritunl-openvpn wireguard-tools mongodb-org \
    policycoreutils-python-utils checkpolicy policycoreutils-devel
# Pinned pritunl-openvpn (kept for reference in case the latest one breaks):
# yum -y swap openvpn pritunl-openvpn-2.6.17-1.el9.almalinux || true
# yum -y --allowerasing install pritunl-openvpn-2.6.17-1.el9.almalinux
# dnf -y install pritunl wireguard-tools mongodb-org

# ------------------------------------------------------------------------------
step 4 "Loading Pritunl SELinux policies"
# ------------------------------------------------------------------------------
if command -v semodule >/dev/null 2>&1; then
    semodule_args=()
    for pp in pritunl pritunl_web pritunl_dns; do
        if [ -f "/usr/share/selinux/packages/${pp}.pp" ]; then
            semodule_args+=("/usr/share/selinux/packages/${pp}.pp")
        fi
    done
    if [ ${#semodule_args[@]} -gt 0 ]; then
        semodule -i "${semodule_args[@]}"
    fi

    restore_targets=()
    if [ -f /etc/pritunl.conf ]; then
        restore_targets+=(/etc/pritunl.conf)
    fi
    for d in /var/lib/pritunl /var/log/pritunl /run/pritunl /var/run/pritunl; do
        if [ -d "${d}" ]; then
            restore_targets+=("${d}")
        fi
    done
    if [ ${#restore_targets[@]} -gt 0 ]; then
        restorecon -Rv "${restore_targets[@]}" || true
    fi
else
    log "semodule not found; skipping"
fi

# ------------------------------------------------------------------------------
step 5 "Configuring and starting MongoDB"
# ------------------------------------------------------------------------------
sed -i 's/^  bindIp:.*/  bindIp: 127.0.0.1/' /etc/mongod.conf
grep -q '^setParameter:' /etc/mongod.conf \
    || printf '\nsetParameter:\n  diagnosticDataCollectionEnabled: false\n' >> /etc/mongod.conf
systemctl enable --now mongod

log "Waiting for MongoDB to answer ping (up to 30s)..."
mongo_ready=false
for _ in $(seq 1 15); do
    if mongosh --quiet --eval 'db.adminCommand({ping: 1})' >/dev/null 2>&1; then
        mongo_ready=true
        break
    fi
    sleep 2
done
[ "${mongo_ready}" = true ] || fail "MongoDB did not answer ping within 30s"
log "MongoDB is ready"

# ------------------------------------------------------------------------------
step 6 "Stopping Pritunl before the initial configuration"
# ------------------------------------------------------------------------------
if systemctl is-active --quiet pritunl; then
    systemctl stop pritunl
fi
systemctl disable pritunl

# ------------------------------------------------------------------------------
step 7 "Configuring SELinux UDP ports (OpenVPN ${PF_ST_OV}-${PF_ED_OV}, WireGuard ${PF_ST_WG}-${PF_ED_WG})"
# ------------------------------------------------------------------------------
chmod +x "${INSTALL_DIR}/msl_pritunl_selinux_port.sh"
for port in $(seq "${PF_ST_OV}" "${PF_ED_OV}") $(seq "${PF_ST_WG}" "${PF_ED_WG}"); do
    "${INSTALL_DIR}/msl_pritunl_selinux_port.sh" udp "${port}"
done

log "Installing policy module pritunl_bind_openvpn_ports (pritunl_t -> openvpn_port_t udp bind)"
te_dir=$(mktemp -d)
cat > "${te_dir}/pritunl_bind_openvpn_ports.te" <<'TEEOF'
module pritunl_bind_openvpn_ports 1.0;

require {
    type pritunl_t;
    type openvpn_port_t;
    class udp_socket name_bind;
}

allow pritunl_t openvpn_port_t:udp_socket name_bind;
TEEOF
checkmodule -M -m -o "${te_dir}/pritunl_bind_openvpn_ports.mod" "${te_dir}/pritunl_bind_openvpn_ports.te"
semodule_package -o "${te_dir}/pritunl_bind_openvpn_ports.pp" -m "${te_dir}/pritunl_bind_openvpn_ports.mod"
semodule -i "${te_dir}/pritunl_bind_openvpn_ports.pp"
rm -rf "${te_dir:?}" /root/msl-selinux-work

# ------------------------------------------------------------------------------
step 8 "Enabling IP forwarding"
# ------------------------------------------------------------------------------
cat > /etc/sysctl.d/99-msl-pritunl.conf <<'SYSCTL'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
SYSCTL
sysctl -p /etc/sysctl.d/99-msl-pritunl.conf

# ------------------------------------------------------------------------------
step 9 "Editing /etc/pritunl.conf (local MongoDB)"
# ------------------------------------------------------------------------------
# bind_addr is left as installed (0.0.0.0). WireGuard clients send their
# keepalive to the server's tunnel address (e.g. wg0) on port 443, so the web
# server must not listen on PT_IG_IP only.
cp /etc/pritunl.conf /etc/pritunl.conf.bak
python3 - <<'PYEOF'
import json

path = '/etc/pritunl.conf'
with open(path) as f:
    config = json.load(f)
config['mongodb_uri'] = 'mongodb://localhost:27017/pritunl'
with open(path, 'w') as f:
    json.dump(config, f, indent=4)
PYEOF

# ------------------------------------------------------------------------------
step 10 "Starting Pritunl"
# ------------------------------------------------------------------------------
pritunl set vpn.dns_route false || log "WARN: Failed to set vpn.dns_route (continuing)"
systemctl enable --now pritunl
# Do not listen on port 80 (HTTP redirect)
pritunl set app.redirect_server false

# ------------------------------------------------------------------------------
step 11 "Creating VPN servers in MongoDB"
# ------------------------------------------------------------------------------
python3 "${INSTALL_DIR}/pritunl_build_helper.py" mongodb --vm-ip "${PT_IG_IP}" --env "${ENV_FILE}"

# ------------------------------------------------------------------------------
step 12 "Verifying services"
# ------------------------------------------------------------------------------
# SSH (22) and MongoDB (27017) must not listen on a wildcard address.
# The web server (443) listens on all addresses on purpose (see step 9).
wildcard_listeners=$(ss -Htuln | awk '$5 ~ /^(0\.0\.0\.0|\*|\[::\]):(22|27017)$/' || true)
if [ -n "${wildcard_listeners}" ]; then
    echo "${wildcard_listeners}"
    fail "Some services are listening on a wildcard address"
fi
log "No wildcard listeners on 22/27017"

for svc in mongod pritunl; do
    systemctl is-active --quiet "${svc}" || fail "Service is not active: ${svc}"
done
log "Services active: mongod, pritunl"

mongosh --quiet --eval 'db.adminCommand({ping: 1})' | grep -q 'ok.*1' \
    || fail "MongoDB ping failed"
log "MongoDB ping OK"

echo ""
log "Pritunl installation completed"
