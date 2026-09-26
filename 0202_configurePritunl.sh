#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: 0202_configurePritunl.sh
# Purpose: Install and configure Pritunl / MongoDB on the Pritunl VM and
#          create per-project servers and organizations
#
# Main functions/commands used:
#   - run_pritunl_vm_installer: Run <installer>/vm_install.sh inside the VM
#   - setup_pritunl_orgs: Create organizations via the Pritunl API
#   - save_config_to_vm_notes: Write credentials and configuration to VM notes
#
# Dependencies:
#   - lib/common.sh: Logging and utility functions
#   - lib/messages_*.sh: Multi-language message definitions
#   - lib/pritunl_install.sh: Pritunl installation functions
#   - lib/pritunl_installers/<id>/: Installer files (helper binary, SELinux helper)
#   - .env: Environment configuration
#   - Phase 2 completed: Pritunl VM deployed and accessible
#
# Usage:
#   ./0202_configurePritunl.sh [en|jp]
#   Normally called from 02_vpnSetup.sh.
#
# Notes:
#   - The installation runs inside the VM (lib/pritunl_installers/<id>/vm_install.sh).
#     Servers are inserted into MongoDB by pritunl_build_helper inside the VM;
#     organizations are created, attached and started via the Pritunl HTTP API
#     from the host (initial admin account). No Web UI automation.
#   - Takes a VM snapshot on first run and rolls back to it on re-runs
#   - VM deployed with root user (cloud-init disable_root: false)
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Language selection (default: English)
MSL_LANG="${1:-en}"

# Validate language parameter
if [[ "$MSL_LANG" != "en" && "$MSL_LANG" != "jp" ]]; then
    echo "ERROR: Invalid parameter: $MSL_LANG" >&2
    echo "Usage: $0 [en|jp]" >&2
    echo "  en: English (default)" >&2
    echo "  jp: Japanese" >&2
    exit 1
fi

export MSL_LANG

# Load libraries
source lib/common.sh
source "lib/messages_${MSL_LANG}.sh"
source lib/pritunl_install.sh

# Pritunl installer (installation method). Only "alma9" exists for now.
readonly PRITUNL_INSTALLER_ID="alma9"
readonly PRITUNL_INSTALLER_DIR="${SCRIPT_DIR}/lib/pritunl_installers/${PRITUNL_INSTALLER_ID}"
if [ ! -f "${PRITUNL_INSTALLER_DIR}/profile.sh" ]; then
    die "Pritunl installer not found: ${PRITUNL_INSTALLER_DIR}/profile.sh"
fi
source "${PRITUNL_INSTALLER_DIR}/profile.sh"

# Load environment variables
if [ ! -f .env ]; then
    die ".env file not found. Please run ./00_configNetwork.sh first."
fi
source .env

# Setup logging
setup_logging "0202_configurePritunl"

################################################################################
# Function: refresh_ssh_known_hosts
# Description: Remove stale SSH host key entries for a target host
################################################################################
refresh_ssh_known_hosts() {
    local host_ip="$1"
    if [ -f "${HOME}/.ssh/known_hosts" ]; then
        ssh-keygen -R "${host_ip}" >/dev/null 2>&1 || true
    fi
}

################################################################################
# Main execution
################################################################################

log_info "=============================================="
log_info "Phase 3: Pritunl Initial Configuration"
log_info "=============================================="
log_info "Language: ${MSL_LANG}"
log_info "Pritunl MainLAN IP: ${PT_IG_IP}"
log_info "Pritunl vpndmzvn IP: ${PT_EG_IP}"
log_info ""

# Verify Phase 2 completion
log_info "Verifying Phase 2 completion..."
if [ ! -f .last_created_vmid ]; then
    die "Phase 2 not completed. No VM found. Please run ./02_vpnSetup.sh first."
fi

VMID=$(cat .last_created_vmid)
log_info "Found Pritunl VM: VMID ${VMID}"

# Verify VM is running
if ! qm status "$VMID" | grep -q "running"; then
    log_error "Pritunl VM (VMID ${VMID}) is not running"
    die "Please start the VM first: qm start ${VMID}"
fi

# Verify SSH connectivity (host key should already be in known_hosts from Phase 2)
log_info "Verifying SSH connectivity to ${PT_IG_IP}..."
refresh_ssh_known_hosts "${PT_IG_IP}"
if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "root@${PT_IG_IP}" "echo 'SSH OK'" &>/dev/null; then
    die "Cannot connect to Pritunl VM via SSH at ${PT_IG_IP}"
fi
log_info "SSH connectivity verified"

# Handle VM snapshot for retry capability
log_info "Checking for existing snapshot..." -c
latest_snap=$(check_vm_snapshot_exists "$VMID" || true)
if [ -n "$latest_snap" ]; then
    log_info "Found existing snapshot: ${latest_snap}" -c
    log_info "Rolling back to snapshot checkpoint before setup..." -c
    if ! restore_from_vm_snapshot "$VMID" "$latest_snap"; then
        log_error "CRITICAL: Failed to restore from snapshot. Setup cannot continue."
        die "Snapshot restore failed. Please check Proxmox logs and retry."
    fi
    
    log_info "Snapshot rollback completed" -c
    # Give VM time to stabilize after restore
    sleep 5
    
    # Re-verify SSH connectivity after restore
    log_info "Re-verifying SSH connectivity after snapshot rollback..." -c
    refresh_ssh_known_hosts "${PT_IG_IP}"
    retry_count=0
    while [ $retry_count -lt 30 ]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "root@${PT_IG_IP}" "echo 'SSH OK'" &>/dev/null; then
            log_info "SSH connectivity re-verified after rollback" -c
            break
        fi
        retry_count=$((retry_count + 1))
        sleep 1
    done
    
    if [ $retry_count -ge 30 ]; then
        log_error "SSH connectivity lost after snapshot rollback"
        die "Cannot reconnect to VM after rollback"
    fi
else
    # First run - no existing snapshot
    log_info "No existing snapshot found - this is first run" -c
    log_info "Creating snapshot checkpoint for future retries..." -c
    
    # Create snapshot now (before setup begins)
    snap_name="msl-phase3-$(date +%s)"
    if ! take_vm_snapshot "$VMID" "$snap_name"; then
        log_error "CRITICAL: Failed to create initial snapshot"
        die "Cannot create snapshot. This is required for retry capability."
    fi
    log_info "Snapshot created: ${snap_name}" -c
fi

# Install and configure Pritunl / MongoDB and create the VPN servers inside the VM
run_pritunl_vm_installer "${PT_IG_IP}"

# Initial admin password (used for the API setup and the VM notes)
get_pritunl_default_password "${PT_IG_IP}"
log_info "Pritunl initial user and password: pritunl/${PRITUNL_PASSWORD}"

# Create Organizations, Attach to Servers, and Start Servers via API
setup_pritunl_orgs "${PT_IG_IP}" "${PRITUNL_PASSWORD}"

# Save configuration reference to VM notes
save_config_to_vm_notes "${VMID}" "${PT_IG_IP}" "${PRITUNL_PASSWORD}"

# Display VM notes URL
display_vm_notes_url "${VMID}"

log_info "" -c
log_info "==============================================" -c
log_info "Phase 3 Automated Setup: COMPLETED" -c
log_info "Logs: ${LOG_FILE}" -c
log_info "==============================================" -c
log_info "" -c
log_info "Snapshot checkpoint saved for future retries" -c