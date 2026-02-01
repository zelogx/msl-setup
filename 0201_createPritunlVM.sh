#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: 02_deploy_pritunl.sh
# Purpose: Deploy Pritunl VM with AlmaLinux 9.7 using cloud-init
#
# Main functions/commands used:
#   - qm: Proxmox VM management
#   - wget/curl: Download cloud-init images
#   - ssh/scp: Remote access and file transfer
#
# Dependencies:
#   - lib/common.sh: Common utility functions
#   - lib/messages_*.sh: Localized messages
#   - lib/vm_utils.sh: VM deployment functions
#   - .env: Environment configuration
#   - qemu-guest-agent: Cloud-init completion detection
#   - wget or curl: Image download
#   - jq: JSON processing for SSH key encoding
#
# Usage:
#   ./02_deploy_pritunl.sh [en|jp]
#
# Notes:
#   - Automatically allocates VMID starting from 100
#   - Creates new VM (never modifies existing VMs)
#   - Auto-generates SSH key if none exists
#   - Downloads and caches AlmaLinux 9.7 cloud-init image
#   - Validates VM network configuration remotely
################################################################################

set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ============================================================================
# Argument Parsing and Language Setup
# ============================================================================

# Default values
MSL_LANG="en"
DESTROY_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --destroy)
            DESTROY_ONLY=true
            shift
            ;;
        en|jp)
            MSL_LANG="$1"
            shift
            ;;
        *)
            echo "Usage: $0 [--destroy] [en|jp]"
            echo ""
            echo "Options:"
            echo "  --destroy    Destroy existing VM and exit (no new VM creation)"
            echo ""
            echo "Arguments:"
            echo "  en           English output (default)"
            echo "  jp           Japanese output"
            exit 1
            ;;
    esac
done

export MSL_LANG

# ============================================================================
# Load Libraries
# ============================================================================

# Load common functions
if [ ! -f "lib/common.sh" ]; then
    echo "ERROR: lib/common.sh not found"
    exit 1
fi
source lib/common.sh

# Load messages
if [ "$MSL_LANG" = "jp" ]; then
    if [ ! -f "lib/messages_jp.sh" ]; then
        die "lib/messages_jp.sh not found"
    fi
    source lib/messages_jp.sh
else
    if [ ! -f "lib/messages_en.sh" ]; then
        die "lib/messages_en.sh not found"
    fi
    source lib/messages_en.sh
fi

# Load VM utilities
if [ ! -f "lib/vm_utils.sh" ]; then
    die "lib/vm_utils.sh not found"
fi
source lib/vm_utils.sh

# ============================================================================
# Configuration
# ============================================================================

# AlmaLinux 9.7 Cloud-Init Image
readonly IMAGE_URL="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
readonly CHECKSUM_URL="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/CHECKSUM"
readonly IMAGE_CACHE_PATH="/var/lib/vz/template/iso/almalinux-9-genericcloud-latest.x86_64.qcow2"

# VM Configuration
readonly VM_NAME="pritunl-msl"
readonly VMID_START=100
readonly VMID_RECORD_FILE="${SCRIPT_DIR}/.last_created_vmid"

# Validation Script
readonly VALIDATE_SCRIPT="$SCRIPT_DIR/lib/pritunl_build_helper"

# ============================================================================
# Logging Setup
# ============================================================================

setup_logging "02_deploy_pritunl"

################################################################################
# Function: find_rule_pos_by_comment
# Description: Find the firewall rule position by its comment for the current node.
#
# Main commands/functions used:
#   - pvesh: Query node firewall rules
#   - jq: JSON filtering
################################################################################
find_rule_pos_by_comment() {
    local node_name="$1"
    local comment="$2"
    pvesh get "/nodes/${node_name}/firewall/rules" --output-format json 2>/dev/null \
        | jq -r --arg c "$comment" '.[] | select(.comment == $c) | .pos' \
        | head -n 1
}

################################################################################
# Function: enable_icmp_rule_by_comment
# Description: Enable a host firewall ICMP rule by comment (no-op if missing)
#
# Main commands/functions used:
#   - hostname: Determine node name
#   - pvesh set: Toggle rule enable flag
################################################################################
enable_icmp_rule_by_comment() {
    local comment="$1"
    local desc="$2"
    local node_name
    node_name=$(hostname)

    if [[ -z "$comment" ]]; then
        log_warn "ICMP rule comment missing for ${desc}; skipping enable"
        printf "$MSG_ICMP_ENABLE_SKIP\n" "${desc:-unknown}"
        return 0
    fi

    local rule_id
    rule_id=$(find_rule_pos_by_comment "$node_name" "$comment")
    if [[ -z "$rule_id" ]]; then
        log_warn "ICMP rule not found for comment ${comment}; skipping enable"
        printf "$MSG_ICMP_ENABLE_SKIP\n" "$comment"
        return 0
    fi

    if pvesh set "/nodes/${node_name}/firewall/rules/${rule_id}" -enable 1 2>&1; then
        log_info "Enabled ICMP rule comment=${comment} (pos=${rule_id}) (${desc})"
        printf "$MSG_ICMP_ENABLE_OK\n" "$rule_id"
    else
        log_warn "Failed to enable ICMP rule comment=${comment} (pos=${rule_id}) (${desc})"
        printf "$MSG_ICMP_ENABLE_FAIL\n" "$rule_id"
    fi
}

################################################################################
# Function: disable_icmp_rule_by_comment
# Description: Disable a host firewall ICMP rule by comment (no-op if missing)
#
# Main commands/functions used:
#   - hostname: Determine node name
#   - pvesh set: Toggle rule enable flag
################################################################################
disable_icmp_rule_by_comment() {
    local comment="$1"
    local desc="$2"
    local node_name
    node_name=$(hostname)

    if [[ -z "$comment" ]]; then
        log_warn "ICMP rule comment missing for ${desc}; skipping disable"
        printf "$MSG_ICMP_DISABLE_SKIP\n" "${desc:-unknown}"
        return 0
    fi

    local rule_id
    rule_id=$(find_rule_pos_by_comment "$node_name" "$comment")
    if [[ -z "$rule_id" ]]; then
        log_warn "ICMP rule not found for comment ${comment}; skipping disable"
        printf "$MSG_ICMP_DISABLE_SKIP\n" "$comment"
        return 0
    fi

    if pvesh set "/nodes/${node_name}/firewall/rules/${rule_id}" -enable 0 2>&1; then
        log_info "Disabled ICMP rule comment=${comment} (pos=${rule_id}) (${desc})"
        printf "$MSG_ICMP_DISABLE_OK\n" "$rule_id"
    else
        log_warn "Failed to disable ICMP rule comment=${comment} (pos=${rule_id}) (${desc})"
        printf "$MSG_ICMP_DISABLE_FAIL\n" "$rule_id"
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

log_info "========================================="
log_info "Phase 2: Pritunl VM Deployment"
log_info "Language: $MSL_LANG"
log_info "========================================="

echo "$MSG_WELCOME"
echo ""
printf "$MSG_PHASE 2: Pritunl VM Deployment\\n"

# Load environment configuration
if [ ! -f ".env" ]; then
    echo "$MSG_SDN_ENV_MISSING"
    die ".env file not found. Please run Phase 1 first."
fi

log_info "Loading .env configuration..."
source .env

# Validate required variables
log_info "Validating environment variables..."
required_vars=(
    "PT_IG_IP"
    "PT_EG_IP"
    "ML_CIDR"
    "ML_GW"
    "VPNDMZ_CIDR"
    "VPNDMZ_GW"
    "DNS_IP1"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        die "Required variable $var is not set in .env"
    fi
    log_info "  $var = ${!var}"
done

# Check prerequisites
log_info "Checking prerequisites..."

# Check if there's a previously created VM by this script
if [ -f "$VMID_RECORD_FILE" ]; then
    PREVIOUS_VMID=$(cat "$VMID_RECORD_FILE")
    if qm status "$PREVIOUS_VMID" >/dev/null 2>&1; then
        echo ""
        msg_printf PREV_VM_FOUND "$PREVIOUS_VMID"
        if [ "$DESTROY_ONLY" = true ]; then
            msg_printf PREV_VM_AUTOREMOVE
        else
            msg_printf PREV_VM_AUTOREMOVE
        fi
        log_info "Found previously created VM (VMID: $PREVIOUS_VMID) by this script"
        
        # Stop VM if running
        vm_status=$(qm status "$PREVIOUS_VMID" 2>&1 | awk '{print $2}')
        if [ "$vm_status" = "running" ]; then
            msg_printf VM_STOPPING
            qm stop "$PREVIOUS_VMID"
            sleep 2
        fi
        
        # Destroy and purge
        msg_printf VM_DESTROYING
        qm destroy "$PREVIOUS_VMID" --purge
        log_info "Previous VM (VMID: $PREVIOUS_VMID) has been purged"
        
        # Clean up known_hosts
        if [ -n "$PT_IG_IP" ]; then
            ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$PT_IG_IP" &>/dev/null || true
        fi
        
        msg_printf VM_REMOVED
        
        # If --destroy mode, exit here
        if [ "$DESTROY_ONLY" = true ]; then
            rm -f "$VMID_RECORD_FILE"
            log_info "Destroy-only mode: VM removal completed. Exiting."
            echo ""
            echo "VM removal completed. Exiting."
            exit 0
        fi
    else
        # VM record exists but VM not found
        if [ "$DESTROY_ONLY" = true ]; then
            echo ""
            echo "No existing VM found (VMID: $PREVIOUS_VMID not found in Proxmox)."
            log_info "Destroy-only mode: No VM to destroy. Exiting."
            rm -f "$VMID_RECORD_FILE"
            exit 0
        fi
    fi
    # Remove record file as we'll create a new one (only in non-destroy mode)
    if [ "$DESTROY_ONLY" = false ]; then
        rm -f "$VMID_RECORD_FILE"
    fi
else
    # No record file exists
    if [ "$DESTROY_ONLY" = true ]; then
        echo ""
        echo "No existing VM found (no previous VMID record)."
        log_info "Destroy-only mode: No VM to destroy. Exiting."
        exit 0
    fi
fi

# Check vpndmzvn exists
if ! ip link show vpndmzvn >/dev/null 2>&1; then
    die "vpndmzvn interface not found. Please run Phase 1 (01_setup_sdn.sh) first."
fi
log_info "  vpndmzvn interface: OK"

# Check vmbr0 exists
if ! ip link show vmbr0 >/dev/null 2>&1; then
    die "vmbr0 interface not found. Please check Proxmox configuration."
fi
log_info "  vmbr0 interface: OK"

# Check required commands
for cmd in qm wget sha256sum jq ssh scp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "Required command not found: $cmd"
    fi
done
log_info "  Required commands: OK"

# Check validation script exists
if [ ! -f "$VALIDATE_SCRIPT" ]; then
    die "Validation script not found: $VALIDATE_SCRIPT"
fi
log_info "  Validation script: OK"

# Step 1: Collect existing VM inventory
# Select image storage now (do this just before inventory/creation steps)
log_info "Selecting image storage for importdisk..."
if [ -z "${IMAGE_STORAGE:-}" ]; then
    select_image_storage
else
    log_info "IMAGE_STORAGE already set: $IMAGE_STORAGE"
fi

log_info "Step 1: Collecting existing VM inventory..."
collect_existing_vmids

# Step 2: Ensure SSH key exists
log_info "Step 2: Ensuring SSH key exists..."
# Capture only the last line (key path) from ensure_ssh_key stdout to avoid mixing with messages
SSH_KEY_FILE=$(ensure_ssh_key | tail -n1)
SSH_PUBKEY_FILE="${SSH_KEY_FILE}.pub"
log_info "Using SSH public key: $SSH_PUBKEY_FILE"

# Step 3: Find available VMID
log_info "Step 3: Allocating VMID..."
# Capture only the last line (numeric VMID) from find_available_vmid output
VMID=$(find_available_vmid "$VMID_START" | tail -n1)
log_info "VM will be created with VMID: $VMID"

# Step 4: Ensure cloud-init image
log_info "Step 4: Ensuring cloud-init image..."
ensure_cloud_image "$IMAGE_URL" "$CHECKSUM_URL" "$IMAGE_CACHE_PATH"

# Step 5: Create Pritunl VM
log_info "Step 5: Creating Pritunl VM..."
create_pritunl_vm "$VMID" "$VM_NAME" "$IMAGE_CACHE_PATH" "$SSH_PUBKEY_FILE"

# Record the created VMID for next run
echo "$VMID" > "$VMID_RECORD_FILE"
log_info "Recorded VMID $VMID to $VMID_RECORD_FILE for next run cleanup"

# Step 6: Start VM
log_info "Step 6: Starting VM..."
echo "$MSG_VM_START"
if ! qm start "$VMID"; then
    log_error "Failed to start VM $VMID"
    die "VM start failed. Check with: qm status $VMID"
fi
log_info "VM $VMID started successfully"

# Step 7: Wait for cloud-init completion
log_info "Step 7: Waiting for cloud-init to complete..."
if ! wait_for_cloudinit "$VMID" 120; then
    die "Cloud-init timeout. VM remains running for inspection."
fi
echo ""

# Step 8: Verify SSH access [deleted]
# First, add host key to known_hosts using ssh-keyscan
log_info "Adding $PT_IG_IP to $HOME/.ssh/known_hosts..."
if ssh-keyscan -T 5 -t ed25519 "$PT_IG_IP" >> "$HOME/.ssh/known_hosts" 2>&1; then
    log_info "Host key added to known_hosts"
else
    log_error "Failed to retrieve SSH host key from $PT_IG_IP"
    log_error "ssh-keyscan command failed. VM may not be ready or SSH service not started."
    die "SSH host key retrieval failed. VM remains running for inspection."
fi

# Step 9: Copy files to VM
log_info "Step 9: Copying configuration files to VM..."
if ! copy_files_to_vm "$PT_IG_IP" ".env" "$VALIDATE_SCRIPT"; then
    log_error "Failed to copy files to VM"
    die "File copy failed. VM remains running for inspection."
fi
echo ""

# Step 10: Run remote validation
log_info "Step 10: Running remote validation..."
echo "$MSG_ICMP_ENABLE_START"
enable_icmp_rule_by_comment "${ICMP_RULE_COMMENT1:-}" "vpndmz gateway"
enable_icmp_rule_by_comment "${ICMP_RULE_COMMENT2:-}" "devpjs"
enable_icmp_rule_by_comment "${ICMP_RULE_COMMENT3:-}" "mainlan any"
echo ""
if ! run_vm_validation "$PT_IG_IP"; then
    log_error "VM validation failed"
    echo ""
    echo "VM has been deployed but validation checks failed."
    echo "Please review the validation output above and fix any issues."
    echo ""
    echo "VM Access: ssh root@$PT_IG_IP"
    echo "Check routes: ip route show"
    echo "Check DNS: nslookup google.com"
    echo ""
    die "VM validation failed. VM remains running for inspection."
fi
echo ""

# Disable temporary ICMP allow rules after successful validation
echo "$MSG_ICMP_DISABLE_START"
disable_icmp_rule_by_comment "${ICMP_RULE_COMMENT1:-}" "vpndmz gateway"
disable_icmp_rule_by_comment "${ICMP_RULE_COMMENT2:-}" "devpjs"
disable_icmp_rule_by_comment "${ICMP_RULE_COMMENT3:-}" "mainlan any"
echo ""

# ============================================================================
# Completion
# ============================================================================

log_info "========================================="
log_info "Pritunl VM Deployment Completed"
log_info "========================================="
log_info "VMID: $VMID"
log_info "VM Name: $VM_NAME"
log_info "MainLAN IP: $PT_IG_IP"
log_info "vpndmzvn IP: $PT_EG_IP"
log_info "SSH Access: ssh root@$PT_IG_IP"
log_info "========================================="

echo ""
echo "$MSG_VM_DEPLOY_COMPLETE"
echo ""
printf "$MSG_VM_ACCESS_INFO\\n" "$VMID" "$PT_IG_IP"
echo ""
echo "Next Steps:"
echo "  1. Proceed to next step: ./0202_configurePritunl.sh $MSL_LANG"
echo ""

log_info "Phase 2 deployment script completed successfully"
exit 0
