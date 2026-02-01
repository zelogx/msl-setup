#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: 03_pritunl_setup.sh
# Purpose: Pritunl initial configuration (automated portion - free version)
#
# Main functions/commands used:
#   - ssh: Remote command execution on Pritunl VM
#   - systemctl: Service management
#   - pritunl: CLI configuration commands
#
# Dependencies:
#   - lib/common.sh: Logging and utility functions
#   - lib/messages_*.sh: Multi-language message definitions
#   - lib/pritunl_install.sh: Pritunl installation functions
#   - .env: Environment configuration
#   - Phase 2 completed: Pritunl VM deployed and accessible
#
# Usage:
#   ./03_pritunl_setup.sh [en|jp]
#
# Notes:
#   - Pritunl free version does not support API token authentication
#   - This script performs automated CLI-based setup only
#   - Organization/Server creation requires GUI (documented in Phase 3.5)
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

# Load environment variables
if [ ! -f .env ]; then
    die ".env file not found. Please run 01_setup_sdn.sh first."
fi
source .env

# Setup logging
setup_logging "03_pritunl_setup"

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
    die "Phase 2 not completed. No VM found. Please run 02_deploy_pritunl.sh first."
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

# Install Pritunl and dependencies
install_pritunl_packages "${PT_IG_IP}"

# Configure MongoDB
configure_mongodb "${PT_IG_IP}"

# Configure Pritunl initial setup
configure_pritunl_initial "${PT_IG_IP}"

# Configure system settings
configure_system_settings "${PT_IG_IP}"

# Configure global Pritunl settings (MUST be before apply_security_hardening)
configure_global_pritunl_settings "${PT_IG_IP}"

# Apply security hardening (after Pritunl is already started)
apply_security_hardening "${PT_IG_IP}"

# Copy .env to VM for helper binary (required for mongodb command)
log_info "Preparing environment configuration for helper binary..." -c
if ! scp ".env" "root@${PT_IG_IP}:/tmp/.env"; then
    die "Failed to copy .env configuration to VM"
fi

# Create VPN servers via MongoDB direct manipulation (Phase 3.9.2)
create_pritunl_servers_mongodb "${PT_IG_IP}"

# Create Organizations, Attach to Servers, and Start Servers via API
log_info "Retrieving Pritunl default password for API setup..." -c
PRITUNL_PASSWORD=$(ssh "root@${PT_IG_IP}" "pritunl default-password" 2>&1 | tail -1 | sed 's/^.*password: *//' | xargs)
log_info "Pritunl initial user and password: pritunl/${PRITUNL_PASSWORD}"
if [[ -z "${PRITUNL_PASSWORD}" ]]; then
    log_warn "Could not retrieve Pritunl password. Setup might fail." -c
fi

setup_pritunl_orgs "${PT_IG_IP}" "${PRITUNL_PASSWORD}"

# Perform verification
perform_verification "${PT_IG_IP}"

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