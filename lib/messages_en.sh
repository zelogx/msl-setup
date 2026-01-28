#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: lib/messages_en.sh
# Purpose: English message definitions for interactive user input
#
# Main functions/commands used:
#   - Message variable definitions for EN locale
#
# Dependencies:
#   - None (pure variable definitions)
#
# Usage:
#   source lib/messages_en.sh
#
# Notes:
#   - All user-facing messages in English
#   - Loaded when LANG starts with 'en'
################################################################################

# Welcome messages
MSG_WELCOME="Welcome to Zelogx™ Multi-Project Secure Lab Setup"
MSG_STARTING="Starting setup..."
MSG_PHASE="Phase"

# Uninstall messages
MSG_UNINSTALL_TITLE="Zelogx™ MSL Setup - Uninstall"
MSG_UNINSTALL_PREREQ_TITLE="IMPORTANT: Prerequisites before uninstall"
MSG_UNINSTALL_PREREQ_WARN="If any VMs or CTs are using vnetpjXX interfaces, the uninstall process"
MSG_UNINSTALL_PREREQ_WARN2="may not work correctly. Please ensure the following before proceeding:"
MSG_UNINSTALL_PREREQ_ITEM1="  - Delete all VMs/CTs using vnetpjXX networks, OR"
MSG_UNINSTALL_PREREQ_ITEM2="  - Change their NICs to a different bridge (e.g., vmbr0)"
MSG_UNINSTALL_WARNING="WARNING: This will remove all MSL setup configurations:"
MSG_UNINSTALL_ITEM1="  - Selfcare portal and Pools, Users will be deleted"
MSG_UNINSTALL_ITEM2="  - Pritunl VM will be destroyed"
MSG_UNINSTALL_ITEM3="  - SDN configuration will be restored to initial state"
MSG_UNINSTALL_CONFIRM="Do you want to proceed with uninstall? [y/N]"
MSG_UNINSTALL_CANCELLED="Uninstall cancelled."
MSG_UNINSTALL_STARTING="Starting uninstall process..."
MSG_UNINSTALL_STEP1="Step 1: Deleting RBAC settings..."
MSG_UNINSTALL_STEP2="Step 2: Destroying Pritunl VM..."
MSG_UNINSTALL_STEP3="Step 3: Restoring network configuration..."
MSG_ASSUMING_NO_RBAC_OR_NO_CORPORATE_EDITION="Skipping RBAC deletion step (not Corporate Edition or script not found)."
MSG_UNINSTALL_COMPLETE="Uninstall completed successfully."
MSG_UNINSTALL_FAILED="Uninstall failed. Please check the logs."

# Network discovery messages
MSG_DISCOVERING_NETWORK="Discovering existing networks..."
MSG_DETECTING_MAINLAN="Detecting MainLAN configuration..."
MSG_DETECTING_PVE_IP="Detecting Proxmox VE IP address..."
MSG_DETECTING_EXISTING="Detecting existing network configuration..."
MSG_CHECKING_CONFLICTS="Checking for network conflicts..."
MSG_NO_CONFLICTS="No conflicts detected"
MSG_CONFLICTS_FOUND="Warning: Network conflicts detected"

# Interactive input prompts (a)-(i)
MSG_INPUT_MAINLAN_CIDR="Enter MainLAN CIDR"
MSG_INPUT_MAINLAN_GW="Enter MainLAN gateway IP"
MSG_DETECTED_MAINLAN="Detected MainLAN configuration"
MSG_CONFIRM_MAINLAN="Is this configuration correct? [Y/n]"

MSG_INPUT_PVE_IP="Enter Proxmox VE IP address"
MSG_DETECTED_PVE_IP="Detected PVE IP"
MSG_CONFIRM_PVE_IP="Is this configuration correct? [Y/n]"

MSG_INPUT_NUM_PJ="Enter number of projects (NUM_PJ)"
MSG_NUM_PJ_NOTE="Note: Must be a power of 2 (2, 4, 8, 16)"
MSG_DEFAULT_NUM_PJ="Default"
MSG_INVALID_NUM_PJ="Error: Number of projects must be 2, 4, 8, or 16"

MSG_INPUT_VPNDMZ_CIDR="Enter VPN DMZ network (VPNDMZ_CIDR)"
MSG_VPNDMZ_NOTE="Note: Minimum /30 network required"
MSG_SUGGEST_VPNDMZ="Suggested"

MSG_INPUT_VPN_POOL="Enter VPN client pool (VPN_POOL)"
MSG_VPN_POOL_NOTE="Note: Will be split for OpenVPN/WireGuard and by project count"
MSG_SUGGEST_VPN_POOL="Suggested"
MSG_VPN_POOL_SPLIT="VPN Pool Split Result"

MSG_INPUT_PJALL_CIDR="Enter project networks (PJALL_CIDR)"
MSG_PJALL_NOTE="Note: Will be split into /24 per project"
MSG_SUGGEST_PJALL="Suggested"
MSG_PJALL_SPLIT="Project Network Split Result"

MSG_INPUT_PT_IG_IP="Enter Pritunl MainLAN-side IP (PT_IG_IP)"
MSG_PT_IG_NOTE="Note: This will be the port forwarding destination IP"
MSG_SUGGEST_PT_IG="Suggested"
MSG_CHECKING_ARP="Checking ARP table for IP availability..."
MSG_IP_IN_USE="Warning: This IP address may be in use"
MSG_IP_AVAILABLE="This IP address is available"

MSG_INPUT_PT_EG_IP="Enter Pritunl VPN DMZ-side IP (PT_EG_IP)"
MSG_PT_EG_NOTE="Note: This will be the VPN client egress IP to development segments"
MSG_SUGGEST_PT_EG="Suggested"

MSG_INPUT_PORT_OVPN="(i-1) Enter OpenVPN port range"
MSG_INPUT_PORT_WG="(i-2) Enter WireGuard port range"
MSG_PORT_NOTE="Note: Number of ports must match project count"
MSG_SUGGEST_PORT_OVPN="Suggested (OpenVPN)"
MSG_SUGGEST_PORT_WG="Suggested (WireGuard)"
MSG_PORT_FORMAT="Format: start_port-end_port (e.g., 11856-11863)"

MSG_INPUT_DNS1="Enter DNS server 1"
MSG_INPUT_DNS2="Enter DNS server 2"
MSG_SUGGEST_DNS="Suggested"

# Validation messages
MSG_INVALID_IP="Error: Invalid IP address"
MSG_INVALID_CIDR="Error: Invalid CIDR notation"
MSG_NOT_NETWORK_ADDR="Error: CIDR must use network address (e.g., %s)"
MSG_INVALID_PRIVATE_IP="Error: Not a private IP address range"
MSG_INVALID_PORT_RANGE="Error: Invalid port range"
MSG_INSUFFICIENT_PORTS="Error: Insufficient number of ports"
MSG_NETWORK_CONFLICT="Error: Network address conflict"

# .env generation messages
MSG_GENERATING_ENV="Generating .env file..."
MSG_ENV_GENERATED=".env file generated"
MSG_ENV_LOCATION="Location"

# SVG diagram generation messages
MSG_GENERATING_SVG="Generating network diagram (SVG)..."
MSG_SVG_GENERATED="Network diagram generated"
MSG_SVG_LOCATION="Location"
MSG_VIEW_SVG="Please review the network diagram"

# Confirmation messages
MSG_REVIEW_SETTINGS="Please review the configuration"
MSG_CONFIRM_CONTINUE="Continue with this configuration? [Y/n]"
MSG_USER_CANCELLED="Cancelled by user"
MSG_CONTINUING="Continuing..."

# Phase completion messages
MSG_PHASE_COMPLETE="Phase completed"
MSG_NEXT_PHASE="Next phase"
MSG_MANUAL_STEPS="Manual configuration required"

# Router configuration messages
MSG_ROUTER_CONFIG_TITLE="Router Configuration (Manual Steps Required)"
MSG_ROUTER_PORT_FORWARD="Port Forwarding Configuration"
MSG_ROUTER_STATIC_ROUTE="Static Route Configuration"
MSG_ROUTER_CONFIG_COMPLETE="After completing router configuration, run the next script"

# Error messages
MSG_ERROR_OCCURRED="An error occurred"
MSG_ABORTING="Aborting..."
MSG_CHECK_LOG="Check log file for details"


# Success messages
MSG_SUCCESS="Success"
MSG_COMPLETED="Completed"

# Backup/Restore messages
MSG_BACKING_UP="Creating backup"
MSG_BACKUP_CREATED="Backup created"
MSG_RESTORING="Restoring from backup"
MSG_RESTORED="Restore completed"

# Progress messages
MSG_PLEASE_WAIT="Please wait..."
MSG_PROCESSING="Processing..."
MSG_CALCULATING="Calculating..."

# Input prompt messages
MSG_INPUT_VPN_POOL="VPN Client Pool Configuration"
MSG_OVERLAPS_WITH="overlaps with"
MSG_NOT_PRIVATE_IP="is not a private IP address"
MSG_NUM_PJ_DESC="Enter the number of projects (2, 4, 8, or 16)"
MSG_NUM_PJ_PROMPT="Enter number of projects"
MSG_NUM_PJ_ERROR="Invalid value. Please enter 2, 4, 8, or 16."
MSG_VPNDMZ_DESC="Enter VPN DMZ network (minimum /30 required)"
MSG_VPNDMZ_PROMPT="Enter VPN DMZ CIDR"
MSG_PREFIX_TOO_SMALL="Prefix is too small (minimum /30 required)"
MSG_INPUT_VPNDMZ="VPN DMZ Network Configuration"
MSG_INPUT_MAINLAN="MainLAN Configuration"
MSG_INPUT_PVE_IP="Proxmox VE IP Configuration"
MSG_INPUT_NUM_PJ="Number of Projects Configuration"
MSG_FINDING_ALTERNATIVE="Conflict detected. Searching for alternative network..."
MSG_SEARCHING="Searching"
MSG_ALTERNATIVE_FOUND="Alternative network found"

# Router prompt (Phase0 last)
MSG_ROUTER_TITLE="Router configuration required"
MSG_ROUTER_INTRO="Please apply the following settings on your router (values expanded):"
MSG_ROUTER_NEXT_STEP="After completing router setup, proceed to the next phase"

# Port range input
MSG_PORT_RANGE_TITLE="(i) Port range input"
MSG_PORT_RANGE_HINT_OV="Enter OpenVPN port range (e.g., 11856-11863). Default uses start+NUM_PJ-1."
MSG_PORT_RANGE_HINT_WG="Enter WireGuard port range (e.g., 15952-15959). Default uses start+NUM_PJ-1."
MSG_PORT_RANGE_COUNT_ERR="Port count does not match NUM_PJ (got %d, expected %d). Please re-enter."
MSG_PORT_RANGE_FORMAT_ERR="Invalid range format. Example: 11856-11863"
MSG_PORT_RANGE_PROMPT_OV="OpenVPN port range"
MSG_PORT_RANGE_PROMPT_WG="WireGuard port range"

# SVG diagram note messages
MSG_SVG_NOTE_TITLE="Add Network Diagram to Proxmox Notes"
MSG_SVG_NOTE_QUESTION="Display the generated network diagram in Proxmox notes?"
MSG_SVG_NOTE_DETAILS="Details:"
MSG_SVG_NOTE_COPY="  - Copy SVG file to %s"
MSG_SVG_NOTE_APPEND="  - Append <img src=\"/pve2/images/%s\"> to notes"
MSG_SVG_NOTE_PRESERVE="  - Existing note content will be preserved"
MSG_SVG_NOTE_LOCATION="Display location: Datacenter > %s > Summary > Notes"
MSG_SVG_NOTE_CONFIRM="Add diagram?"

# SDN (01_setup_sdn.sh) console messages
MSG_SDN_BACKUP_START="Taking initial backup of SDN and firewall configuration..."
MSG_SDN_RESTORE_EXISTING="Existing backup found. Restoring SDN and firewall configuration to backup state..."
MSG_SDN_RESTORE_DONE="Restore to backup state completed"
MSG_SDN_RESTORE_ONLY_DONE="SDN configuration has been restored to backup state."
MSG_SDN_RESTORE_ONLY_NO_BACKUP="Restore-only requested but no backup exists; skipping restore."

MSG_SDN_APPLY_START="Applying SDN configuration..."
MSG_SDN_IPSET_START="Starting IPSet creation..."
MSG_SDN_FW_OPTIONS="Configuring datacenter firewall options..."
MSG_SDN_FW_OPTIONS_ERROR="Failed to configure firewall options"
MSG_SDN_FW_RESTORE="Restoring firewall configuration to backup state..."

MSG_SDN_CREATING_ZONES="Creating SDN zones..."
MSG_SDN_CREATING_VNETS="Creating SDN VNets..."
MSG_SDN_CREATING_SUBNETS="Creating SDN subnets..."
MSG_SDN_CREATING_IPSET="Creating IPSet: "
MSG_SDN_DELETING_IN_PROGRESS="Restoring to backup state (deleting added resources)..."

MSG_SDN_ROUTE_PERSIST="Persisting VPN pool route configuration..."
MSG_SDN_ROUTE_CONFLICT="VPN pool network is directly connected. Skipping custom route addition."
MSG_SDN_ROUTE_SKIP_NO_IFACE="vpndmzvn interface not found. Skipping return route configuration."

MSG_SDN_DONE="SDN configuration completed."
MSG_SDN_ENV_MISSING=".env file not found. Please run 00_check_env.sh first."

# Messages for VM cleanup prompts
MSG_PREV_VM_FOUND="Found previously created VM (VMID: %s)."
MSG_PREV_VM_AUTOREMOVE="Automatically removing it..."
MSG_VM_STOPPING="Stopping VM..."
MSG_VM_DESTROYING="Destroying VM..."
MSG_VM_REMOVED="Removal complete."

# Router prompt line formats
MSG_ROUTER_STATIC_ROUTE_LINE=" - Static route: destination %s -> gateway %s"
MSG_ROUTER_PF_OV_LINE=" - Port forward (OpenVPN): %s-%s/UDP -> %s"
MSG_ROUTER_PF_WG_LINE=" - Port forward (WireGuard): %s-%s/UDP -> %s"

# SVG generator messages
MSG_SVG_NOTICE="Generating network diagram now. Please review."
MSG_SVG_URL_LABEL="Network diagram URL:"
MSG_SVG_GUI_LABEL="Or via Proxmox GUI:"

# Usage / argument validation (v2.0)
MSG_USAGE_SETUP_SDN="Usage: 01_setup_sdn.sh [en|jp] [--restore]\n  en|jp       : Console language (default: en)\n  --restore   : Restore SDN/firewall to backup state and exit\nNotes:\n  - Requires .env file with network variables\n  - Will perform backup on first run, then idempotent reapply"
MSG_USAGE_ROUTER_PROMPT="Usage: router_prompt.sh [en|jp]\n  en|jp : Console language (default: en)\nNotes:\n  - Prints manual router configuration guidance (static routes & port forwards)\n  - Values are expanded from .env"

# Library usage (env & svg generators)
MSG_USAGE_ENV_GENERATOR="Usage: env_generator.sh (library)\n  This file is a library; source it after populating CONFIG associative array.\nNotes:\n  - Not intended for direct execution\n  - Generates .env when called via generate_env()"
MSG_USAGE_SVG_GENERATOR="Usage: svg_generator.sh (library)\n  This file is a library; source it then call generate_svg_diagram.\nNotes:\n  - Requires existing .env file\n  - Adds SVG to Proxmox notes if user confirms"


# Additional UI messages
MSG_AUTO_DETECTED_MAINLAN="Auto-detected MainLAN (vmbr0 network):"
MSG_NETWORK="Network"
MSG_GATEWAY="Gateway"
MSG_ENTER_MAINLAN_CIDR="Enter MainLAN CIDR"
MSG_ENTER_MAINLAN_GW="Enter MainLAN Gateway"
MSG_AUTO_DETECTED_PVE="Auto-detected Proxmox VE IP (vmbr0):"
MSG_IP_ADDRESS="IP Address"
MSG_ENTER_PVE_IP="Enter Proxmox VE IP"
MSG_PROPOSED_NUM_PJ="Proposed number of projects"
MSG_PROPOSED_VPNDMZ="Proposed VPN DMZ network (minimum /30):"
MSG_VPN_POOL_SPLIT_DESC="VPN client pool will be split as follows:"
MSG_VPN_POOL_FIRST_HALF="  - First half (/25): OpenVPN clients"
MSG_VPN_POOL_SECOND_HALF="  - Second half (/25): WireGuard clients"
MSG_VPN_POOL_FURTHER_SPLIT="  - Each protocol pool is further split into %d subnets (/%d)"
MSG_VPN_POOL_MAX_CLIENTS="  - Each project can have up to %d VPN clients (per protocol)"
MSG_PROPOSED_VPN_POOL="Proposed VPN client pool:"
MSG_OVPN_POOL_PER_PJ="OpenVPN pools per project:"
MSG_WG_POOL_PER_PJ="WireGuard pools per project:"
MSG_ENTER_VPN_POOL="Enter VPN client pool CIDR"
MSG_PJ_NETWORK_SPLIT_DESC="Project networks will be split as follows:"
MSG_PJ_NETWORK_TOTAL="  - Total network: %s"
MSG_PJ_NETWORK_COUNT="  - Split into %d project networks (each /%d)"
MSG_PJ_NETWORK_DEDICATED="  - Each project has a dedicated /%d network"
MSG_PROPOSED_PJ_NETWORK="Proposed project networks:"
MSG_ENTER_PJ_NETWORK="Enter project networks CIDR"
MSG_NETWORK_CONFIG_FOR="Configuration for this network:"
MSG_TOTAL_NETWORK="Total network"
MSG_PJ_NETWORK_SPLIT="Project network split:"
MSG_PROPOSED_PT_IG="Proposed Pritunl MainLAN-side IP:"
MSG_ENTER_PT_IG="Enter Pritunl MainLAN-side IP"
MSG_PROPOSED_PT_EG="Proposed Pritunl VPN DMZ-side IP:"
MSG_ENTER_PT_EG="Enter Pritunl VPN DMZ-side IP"
MSG_PROPOSED_DNS1="Proposed DNS server 1:"
MSG_ENTER_DNS1="Enter DNS server 1"
MSG_PROPOSED_DNS2="Proposed DNS server 2 (optional):"
MSG_ENTER_DNS2="Enter DNS server 2 (Enter for default, 'skip' to omit)"
MSG_SPLIT_RESULT_PREVIEW="Split result preview:"
MSG_ERROR_PREFIX_TOO_SMALL="Error: /%d cannot be split into %d subnets (would result in /%d). A larger network is required."

# ============================================================================
# VM Deployment Messages (Phase 2)
# ============================================================================

# VM Inventory
MSG_VM_INVENTORY_COLLECT="Collecting existing VM inventory..."
MSG_VM_INVENTORY_NONE="No existing VMs found."
MSG_VM_INVENTORY_FOUND="Found %s existing VM(s)."

# VMID Allocation
MSG_VM_VMID_SEARCH="Searching for available VMID starting from %s..."
MSG_VM_VMID_ALLOCATED="Allocated VMID: %s"

# SSH Key Management
MSG_VM_SSH_KEY_CHECK="Checking for SSH keys..."
MSG_VM_SSH_KEY_FOUND="Using existing SSH key: %s"
MSG_VM_SSH_KEY_GENERATE="No SSH keys found. Generating new key..."
MSG_VM_SSH_KEY_GENERATED="Generated new SSH key: %s"

# Cloud-Init Image
MSG_VM_IMAGE_DOWNLOAD="Downloading Ubuntu 24.04 cloud-init image..."
MSG_VM_IMAGE_CACHED="Using cached cloud-init image."
MSG_VM_IMAGE_VERIFY="Verifying image hash..."
MSG_VM_IMAGE_HASH_OK="Image hash verified successfully."
MSG_VM_IMAGE_HASH_FAIL="Image hash verification failed. Re-downloading..."
MSG_VM_IMAGE_STORAGE_MULTIPLE="Multiple image storages found. Which one would you like to use?"
MSG_VM_IMAGE_STORAGE_SELECT="Selection (1-%s): "
MSG_VM_IMAGE_STORAGE_INVALID="Invalid selection. Please try again."
MSG_VM_IMAGE_STORAGE_MULTIPLE="Multiple image storages found. Which one would you like to use?"
MSG_VM_IMAGE_STORAGE_SELECT="Selection (1-%s): "
MSG_VM_IMAGE_STORAGE_INVALID="Invalid selection. Please try again."

# VM Creation
MSG_VM_CREATE_START="Creating Pritunl VM (VMID: %s)..."
MSG_VM_CREATE_SUCCESS="VM created successfully."
MSG_VM_START="Starting VM..."

# Cloud-Init
MSG_VM_CLOUDINIT_WAIT="Waiting for cloud-init to complete (timeout: %ss)..."
MSG_VM_CLOUDINIT_DONE="Cloud-init completed successfully."
MSG_VM_CLOUDINIT_TIMEOUT="Cloud-init timeout. Check VM console: qm terminal %s"

# SSH Access
MSG_VM_SSH_VERIFY="Verifying SSH access..."
MSG_VM_SSH_OK="SSH access verified."
MSG_VM_SSH_FAIL="SSH access failed after %s retries."

# File Copy and Validation
MSG_VM_COPY_ENV="Copying .env to VM..."
MSG_VM_COPY_SCRIPT="Copying validation binary to VM..."
MSG_VM_RUN_VALIDATION="Running remote validation on VM..."
MSG_VM_VALIDATION_OK="VM validation completed successfully."
MSG_VM_VALIDATION_FAIL="VM validation failed. Check logs for details."
MSG_ICMP_ENABLE_START="Enabling temporary ICMP allow rules for validation..."
MSG_ICMP_ENABLE_OK="Enabled ICMP rule (ID: %s)"
MSG_ICMP_ENABLE_SKIP="ICMP rule ID missing/invalid (%s); skipped."
MSG_ICMP_ENABLE_FAIL="Failed to enable ICMP rule (ID: %s)"
MSG_ICMP_DISABLE_START="Disabling temporary ICMP allow rules..."
MSG_ICMP_DISABLE_OK="Disabled ICMP rule (ID: %s)"
MSG_ICMP_DISABLE_SKIP="ICMP rule ID missing/invalid (%s); skipped."
MSG_ICMP_DISABLE_FAIL="Failed to disable ICMP rule (ID: %s)"

# Completion
MSG_VM_DEPLOY_COMPLETE="Pritunl VM deployment completed successfully!"
MSG_VM_ACCESS_INFO="VM Access Information:\n  VMID: %s\n  SSH: ssh root@%s"

# ============================================================================
# RBAC Self-Care Portal Messages (Phase 3.5)
# ============================================================================

# Phase header
MSG_SELFCARE_PHASE_TITLE="Phase 3.5: RBAC Self-Care Portal Setup"
MSG_SELFCARE_PHASE_DESC="Setting up Proxmox RBAC for VPN user VM management"

# Backup/Restore
MSG_SELFCARE_BACKUP_CHECK="Checking for existing RBAC backup..."
MSG_SELFCARE_BACKUP_FOUND="Backup found. Restoring to backup state before proceeding..."
MSG_SELFCARE_BACKUP_NOT_FOUND="No backup found. Creating initial backup..."
MSG_SELFCARE_BACKUP_CREATED="Initial RBAC state backed up to ./rbac_backup/"
MSG_SELFCARE_RESTORE_START="Restoring RBAC configuration to backup state..."
MSG_SELFCARE_RESTORE_COMPLETE="Restore completed successfully."
MSG_SELFCARE_RESTORE_ONLY="Restore-only mode: Exiting after restore."
MSG_SELFCARE_RESTORE_NO_BACKUP="ERROR: No backup found. Cannot restore."

# ACL Conflict Check
MSG_SELFCARE_ACL_CHECK="Checking for ACL conflicts..."
MSG_SELFCARE_ACL_CONFLICT="ERROR: ACL conflict detected. The following paths already exist:"
MSG_SELFCARE_ACL_OK="No ACL conflicts detected."

# Storage Selection
MSG_SELFCARE_STORAGE_TITLE="Storage Selection for Project Pools"
MSG_SELFCARE_STORAGE_PROMPT="Available storage:"
MSG_SELFCARE_STORAGE_INPUT="Enter storage numbers (comma-separated, e.g., 1,2) or press Enter for all: "
MSG_SELFCARE_STORAGE_CONFIRM_TITLE="Confirm storage selection:"
MSG_SELFCARE_STORAGE_SELECTED="  ✓ Selected"
MSG_SELFCARE_STORAGE_NOT_SELECTED="    Not selected"
MSG_SELFCARE_STORAGE_CONFIRM="Apply this storage configuration to all projects? [Y/n]: "
MSG_SELFCARE_STORAGE_CANCELLED="Storage selection cancelled."
MSG_SELFCARE_STORAGE_INVALID="ERROR: Invalid storage number(s). Please try again."

# Pool/Group/User Creation
MSG_SELFCARE_CREATE_POOLS="Creating %s project pools..."
MSG_SELFCARE_CREATE_POOL="Creating pool: %s"
MSG_SELFCARE_CREATE_GROUPS="Creating %s project groups..."
MSG_SELFCARE_CREATE_GROUP="Creating group: %s"
MSG_SELFCARE_CREATE_USERS="Creating %s project users..."
MSG_SELFCARE_CREATE_USER="Creating user: %s"

# Permission Assignment
MSG_SELFCARE_ASSIGN_PERMS="Assigning permissions to pools and SDN zones..."
MSG_SELFCARE_ASSIGN_POOL_PERM="Assigning pool permission: /pool/%s → %s (PVEAdmin)"
MSG_SELFCARE_ASSIGN_SDN_PERM="Assigning SDN permission: %s → %s (PVEAdmin)"
MSG_SELFCARE_ASSIGN_STORAGE="Assigning storage to pools: %s"

# Firewall Rules
MSG_SELFCARE_FW_CREATE="Adding node firewall rules for Proxmox dashboard access..."
MSG_SELFCARE_FW_RULE="Adding rule: vpn_guest_pool → vnetpj%s-gateway:8006"
MSG_SELFCARE_FW_COMPLETE="Added %s firewall rules."

# Password Display
MSG_SELFCARE_PASS_TITLE="╔════════════════════════════════════════════════════════════════╗"
MSG_SELFCARE_PASS_HEADER="║  IMPORTANT: Save these credentials immediately!               ║"
MSG_SELFCARE_PASS_FOOTER="╚════════════════════════════════════════════════════════════════╝"
MSG_SELFCARE_PASS_TABLE_HEADER="Project | Username        | Password"
MSG_SELFCARE_PASS_TABLE_SEPARATOR="--------|-----------------|----------------------------------"
MSG_SELFCARE_PASS_INSTRUCTION="Please copy the above credentials to a secure location."
MSG_SELFCARE_PASS_WARN="These passwords will NOT be displayed again."

# Completion
MSG_SELFCARE_COMPLETE="RBAC Self-Care Portal setup completed successfully!"
MSG_SELFCARE_SUMMARY="Summary: Created %s pools, %s groups, %s users, and %s firewall rules."

# Error Messages
MSG_SELFCARE_ERR_POOL_EXISTS="ERROR: Pool '%s' already exists."
MSG_SELFCARE_ERR_GROUP_EXISTS="ERROR: Group '%s' already exists."
MSG_SELFCARE_ERR_USER_EXISTS="ERROR: User '%s' already exists."
MSG_SELFCARE_ERR_NO_STORAGE="ERROR: No storage available for pool assignment."
MSG_SELFCARE_ERR_CMD_FAILED="ERROR: Command failed: %s"

