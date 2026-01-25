#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: 99_uninstall.sh
# Purpose: Uninstall MSL setup by destroying Pritunl VM and restoring network config
#
# Main functions/commands used:
#   - 0201_createPritunlVM.sh --destroy: Remove Pritunl VM
#   - 0102_setupNetwork.sh --restore: Restore network configuration
#
# Dependencies:
#   - lib/common.sh: Common utility functions
#   - lib/messages_*.sh: Localized messages
#   - 0201_createPritunlVM.sh: VM management script
#   - 0102_setupNetwork.sh: Network configuration script
#
# Usage:
#   ./99_uninstall.sh [en|jp]
#
# Notes:
#   - Requires user confirmation before proceeding (default: No)
#   - Destroys Pritunl VM first, then restores network configuration
#   - Logs all operations for audit trail
################################################################################

set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ============================================================================
# Argument Parsing and Language Setup
# ============================================================================

# Default to English
MSL_LANG="${1:-en}"

# Validate argument
case "$MSL_LANG" in
    en|jp)
        ;;
    *)
        echo "Usage: $0 [en|jp]"
        echo ""
        echo "Arguments:"
        echo "  en    English output (default)"
        echo "  jp    Japanese output"
        exit 1
        ;;
esac

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

# ============================================================================
# Logging Setup
# ============================================================================

setup_logging "99_uninstall"

# ============================================================================
# Main Execution
# ============================================================================

log_info "========================================="
log_info "MSL Setup Uninstall"
log_info "Language: $MSL_LANG"
log_info "========================================="

echo ""
echo "========================================="
echo "$MSG_UNINSTALL_TITLE"
echo "========================================="
echo ""
echo "$MSG_UNINSTALL_PREREQ_TITLE"
echo ""
echo "$MSG_UNINSTALL_PREREQ_WARN"
echo "$MSG_UNINSTALL_PREREQ_WARN2"
echo ""
echo "$MSG_UNINSTALL_PREREQ_ITEM1"
echo "$MSG_UNINSTALL_PREREQ_ITEM2"
echo ""
echo "========================================="
echo ""
echo "$MSG_UNINSTALL_WARNING"
echo "$MSG_UNINSTALL_ITEM1"
echo "$MSG_UNINSTALL_ITEM2"
echo "$MSG_UNINSTALL_ITEM3"
echo ""

# Confirmation prompt
read -p "$MSG_UNINSTALL_CONFIRM " -r response
echo ""

# Default to No if empty response
response="${response:-n}"

# Check response (accept y/Y/yes/YES)
if [[ ! "$response" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo "$MSG_UNINSTALL_CANCELLED"
    log_info "Uninstall cancelled by user"
    exit 0
fi

# User confirmed - proceed with uninstall
log_info "User confirmed uninstall. Starting process..."
echo "$MSG_UNINSTALL_STARTING"
echo ""

# ============================================================================
# Step 1: Destroy Pritunl VM
# ============================================================================

echo "$MSG_UNINSTALL_STEP1"
log_info "Step 1: Destroying Pritunl VM..."

if [ ! -f "0201_createPritunlVM.sh" ]; then
    log_error "0201_createPritunlVM.sh not found"
    echo "$MSG_UNINSTALL_FAILED"
    die "Required script not found: 0201_createPritunlVM.sh"
fi

if ! bash 0201_createPritunlVM.sh "$MSL_LANG" --destroy; then
    log_error "Failed to destroy Pritunl VM"
    echo "$MSG_UNINSTALL_FAILED"
    die "VM destruction failed. Check logs for details."
fi

log_info "Pritunl VM destruction completed"
echo ""

# ============================================================================
# Step 2: Restore Network Configuration
# ============================================================================

echo "$MSG_UNINSTALL_STEP2"
log_info "Step 2: Restoring network configuration..."

if [ ! -f "0102_setupNetwork.sh" ]; then
    log_error "0102_setupNetwork.sh not found"
    echo "$MSG_UNINSTALL_FAILED"
    die "Required script not found: 0102_setupNetwork.sh"
fi

if ! bash 0102_setupNetwork.sh "$MSL_LANG" --restore; then
    log_error "Failed to restore network configuration"
    echo "$MSG_UNINSTALL_FAILED"
    die "Network restoration failed. Check logs for details."
fi

log_info "Network configuration restoration completed"
echo ""

# ============================================================================
# Completion
# ============================================================================

log_info "========================================="
log_info "MSL Setup Uninstall Completed"
log_info "========================================="

echo "========================================="
echo "$MSG_UNINSTALL_COMPLETE"
echo "========================================="
echo ""
log_info "Uninstall process completed successfully"
exit 0
