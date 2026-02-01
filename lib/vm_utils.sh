#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: vm_utils.sh
# Purpose: VM deployment utility functions for Pritunl VM creation
#
# Main functions/commands used:
#   - qm: Proxmox VM management
#   - wget/curl: Download cloud-init images
#   - sha256sum: Verify image integrity
#   - ssh: Verify VM accessibility
#
# Dependencies:
#   - common.sh: Logging functions
#   - qemu-guest-agent: Cloud-init completion detection
#   - wget or curl: Image download
#
# Usage:
#   source lib/vm_utils.sh
#
# Notes:
#   Must be sourced after common.sh and messages_*.sh
################################################################################

################################################################################
# Function: collect_existing_vmids
# Description: Collect all existing VMIDs as audit trail before deployment
#
# Main commands/functions used:
################################################################################
collect_existing_vmids() {
    log_info "Collecting existing VM inventory..."
    local existing_vmids
    existing_vmids=$(qm list 2>&1 | awk 'NR>1 {print $1}' | sort -n)
    
    if [ -z "$existing_vmids" ]; then
        log_info "No existing VMs found"
        echo "$MSG_VM_INVENTORY_NONE"
        return 0
    fi
    
    local vm_count
    vm_count=$(echo "$existing_vmids" | wc -l)
    printf "$MSG_VM_INVENTORY_FOUND\\n" "$vm_count"
    log_info "Found $vm_count existing VM(s)"
    
    echo "Existing VMs (before deployment):"
    for vmid in $existing_vmids; do
        local vm_name vm_status
        vm_name=$(qm config "$vmid" 2>&1 | grep '^name:' | awk '{print $2}' || echo "unknown")
        vm_status=$(qm status "$vmid" 2>&1 | awk '{print $2}' || echo "unknown")
        echo "  VMID $vmid: $vm_name (status: $vm_status)"
        log_info "  VMID $vmid: $vm_name (status: $vm_status)"
    done
    echo ""
}

################################################################################
# Function: select_image_storage
# Description: Detect available storage for VM disk/cloud-init images and
#              prompt user to select when multiple enabled storages exist.
# Sets global: IMAGE_STORAGE
################################################################################
select_image_storage() {
    # Use pvesh JSON output to avoid stray stderr lines from pvesm
    if ! command -v pvesh >/dev/null 2>&1; then
        log_error "pvesh command not found; cannot detect image storage. Aborting."
        die "pvesh not found on this host"
    fi

    log_info "Querying storage list via pvesh..."
    local storage_json
    storage_json=$(pvesh get /storage --output-format json 2>/dev/null) || true
    if [ -z "$storage_json" ]; then
        log_error "pvesh returned empty storage list"
        die "No storage available (pvesh returned empty)"
    fi

    # Extract storages that are enabled and support 'images' content
    mapfile -t choices < <(echo "$storage_json" | jq -r '.[] | select((.enabled==1) or (.enabled? == null)) | select(.content | test("(^|,)images(,|$)")) | .storage' 2>/dev/null || true)

    if [ ${#choices[@]} -eq 0 ]; then
        log_error "No enabled storage with 'images' content found"
        die "No image storage available (no enabled storages with images)"
    elif [ ${#choices[@]} -eq 1 ]; then
        IMAGE_STORAGE="${choices[0]}"
        log_info "Auto-selected image storage: $IMAGE_STORAGE"
        return 0
    else
        echo "$MSG_VM_IMAGE_STORAGE_MULTIPLE"
        local i=1
        for c in "${choices[@]}"; do
            echo "  $i) $c"
            i=$((i+1))
        done

        while true; do
            printf "$MSG_VM_IMAGE_STORAGE_SELECT" "${#choices[@]}"
            read -r sel
            if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#choices[@]} ]; then
                IMAGE_STORAGE="${choices[$((sel-1))]}"
                log_info "User selected image storage: $IMAGE_STORAGE"
                break
            else
                echo "$MSG_VM_IMAGE_STORAGE_INVALID"
            fi
        done
        return 0
    fi
}

# Note: Do NOT run `select_image_storage` at source time here.
# Selection should be performed by the caller (e.g. 02_deploy_pritunl.sh)
# so that scripts can control when interactive prompts or pvesm calls occur.

################################################################################
# Function: find_available_vmid
# Description: Find first available VMID starting from given number
#
# Main commands/functions used:
#   - qm status: Check VMID availability
################################################################################
find_available_vmid() {
    local start_vmid="${1:-100}"
    local candidate="$start_vmid"
    
    printf "$MSG_VM_VMID_SEARCH\\n" "$start_vmid"
    log_info "Searching for available VMID starting from $start_vmid"
    
    while qm status "$candidate" >/dev/null 2>&1; do
        log_info "  VMID $candidate is in use, trying next..."
        candidate=$((candidate + 1))
    done
    
    printf "$MSG_VM_VMID_ALLOCATED\\n" "$candidate"
    log_info "Allocated VMID: $candidate"
    echo "$candidate"
}

################################################################################
# Function: ensure_ssh_key
# Description: Ensure SSH key exists, create if missing
#
# Main commands/functions used:
#   - ssh-keygen: Generate SSH key pair
################################################################################
ensure_ssh_key() {
    echo "$MSG_VM_SSH_KEY_CHECK"
    log_info "Checking for existing SSH keys..."
    
    local key_types=("ed25519" "rsa" "ecdsa")
    local found_key=""
    
    # Check for existing keys
    for key_type in "${key_types[@]}"; do
        local key_file="$HOME/.ssh/id_$key_type"
        if [ -f "$key_file" ] && [ -f "${key_file}.pub" ]; then
            found_key="$key_file"
            printf "$MSG_VM_SSH_KEY_FOUND\\n" "$found_key"
            log_info "Found existing SSH key: $found_key"
            echo "$found_key"
            return 0
        fi
    done
    
    # No keys found, generate new one
    local new_key="$HOME/.ssh/id_ed25519"
    echo "$MSG_VM_SSH_KEY_GENERATE"
    log_info "No SSH keys found. Generating new ed25519 key pair..."
    
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    if ssh-keygen -t ed25519 -f "$new_key" -N "" -C "pritunl-msl-auto-generated" 2>&1; then
        printf "$MSG_VM_SSH_KEY_GENERATED\\n" "$new_key"
        log_info "Generated new SSH key: $new_key"
        echo "$new_key"
        return 0
    else
        log_error "Failed to generate SSH key"
        die "SSH key generation failed"
    fi
}

################################################################################
# Function: download_cloud_image
# Description: Download cloud-init image with hash verification
#
# Main commands/functions used:
#   - wget/curl: Download image and checksum file
#   - sha256sum: Verify image hash
################################################################################
download_cloud_image() {
    local image_url="$1"
    local checksum_url="$2"
    local cache_path="$3"
    local image_filename
    image_filename=$(basename "$image_url")
    
    log_info "Downloading cloud-init image..."
    log_info "  URL: $image_url"
    log_info "  Cache path: $cache_path"
    
    # Create cache directory
    local cache_dir
    cache_dir=$(dirname "$cache_path")
    mkdir -p "$cache_dir"
    
    # Download image
    echo "$MSG_VM_IMAGE_DOWNLOAD"
    if command -v wget >/dev/null 2>&1; then
        if ! wget -q -O "$cache_path" "$image_url"; then
            log_error "wget failed to download image"
            rm -f "$cache_path"
            die "Failed to download cloud-init image"
        fi
    elif command -v curl >/dev/null 2>&1; then
        if ! curl -s -L -o "$cache_path" "$image_url"; then
            log_error "curl failed to download image"
            rm -f "$cache_path"
            die "Failed to download cloud-init image"
        fi
    else
        die "Neither wget nor curl found. Please install wget or curl."
    fi
    
    log_info "Download completed: $cache_path"
    
    # Verify hash
    if ! verify_image_hash "$cache_path" "$checksum_url" "$image_filename"; then
        log_error "Hash verification failed after download"
        rm -f "$cache_path"
        die "Cloud-init image hash verification failed"
    fi
    
    echo "$MSG_VM_IMAGE_HASH_OK"
    log_info "Image download and verification successful"
}

################################################################################
# Function: verify_image_hash
# Description: Verify cached image hash against official checksum
#
# Main commands/functions used:
#   - sha256sum: Calculate file hash
#   - grep/awk: Extract expected hash from SHA256SUMS
################################################################################
verify_image_hash() {
    local cache_path="$1"
    local checksum_url="$2"
    local image_filename="$3"
    
    echo "$MSG_VM_IMAGE_VERIFY"
    log_info "Verifying image hash..."
    
    # Download checksum file
    local checksum_file="/tmp/SHA256SUMS.$$"
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$checksum_file" "$checksum_url" || {
            log_error "Failed to download checksum file"
            rm -f "$checksum_file"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -sL -o "$checksum_file" "$checksum_url" || {
            log_error "Failed to download checksum file"
            rm -f "$checksum_file"
            return 1
        }
    else
        log_error "Neither wget nor curl found"
        return 1
    fi
    
    # Extract expected hash for the specific image
    local expected_hash
    expected_hash=$(grep "$image_filename" "$checksum_file" | awk '{print $1}')
    rm -f "$checksum_file"
    
    if [ -z "$expected_hash" ]; then
        log_error "Could not find hash for $image_filename in checksum file"
        return 1
    fi
    
    # Calculate actual hash
    local actual_hash
    actual_hash=$(sha256sum "$cache_path" | awk '{print $1}')
    
    log_info "Expected hash: $expected_hash"
    log_info "Actual hash:   $actual_hash"
    
    if [ "$actual_hash" = "$expected_hash" ]; then
        log_info "Hash verification successful"
        return 0
    else
        log_error "Hash mismatch!"
        return 1
    fi
}

################################################################################
# Function: ensure_cloud_image
# Description: Ensure cloud-init image exists in cache, download if needed
#
# Main commands/functions used:
#   - verify_image_hash: Check cached image
#   - download_cloud_image: Download if needed
################################################################################
ensure_cloud_image() {
    local image_url="$1"
    local checksum_url="$2"
    local cache_path="$3"
    local image_filename
    image_filename=$(basename "$image_url")
    
    # Check if cached image exists
    if [ -f "$cache_path" ]; then
        echo "$MSG_VM_IMAGE_CACHED"
        log_info "Cached image found: $cache_path"
        
        # Verify hash
        if verify_image_hash "$cache_path" "$checksum_url" "$image_filename"; then
            echo "$MSG_VM_IMAGE_HASH_OK"
            log_info "Cached image hash verified, reusing"
            return 0
        else
            echo "$MSG_VM_IMAGE_HASH_FAIL"
            log_warn "Cached image hash verification failed, re-downloading..."
            rm -f "$cache_path"
        fi
    fi
    
    # Download image
    download_cloud_image "$image_url" "$checksum_url" "$cache_path"
}

################################################################################
# Function: create_pritunl_vm
# Description: Create Pritunl VM with cloud-init configuration
#
# Main commands/functions used:
#   - qm create: Create new VM
#   - qm importdisk: Import cloud-init image as VM disk
#   - qm set: Configure VM hardware and cloud-init parameters
################################################################################
create_pritunl_vm() {
    local vmid="$1"
    local vm_name="$2"
    local image_path="$3"
    local ssh_pubkey_file="$4"
    
    printf "$MSG_VM_CREATE_START\\n" "$vmid"
    log_info "Creating Pritunl VM: VMID=$vmid, Name=$vm_name"
    
    # Read SSH public key and write to temp file for Proxmox --sshkeys parameter
    local ssh_pubkey temp_sshkey_file
    ssh_pubkey=$(cat "$ssh_pubkey_file")
    temp_sshkey_file="/var/lib/vz/snippets/pritunl-vm-${vmid}-sshkey.pub"
    [[ ! -d "/var/lib/vz/snippets" ]] && mkdir -p /var/lib/vz/snippets
    echo "$ssh_pubkey" > "$temp_sshkey_file"
    log_info "SSH public key prepared: $temp_sshkey_file"
    
    # Calculate netmasks
    local ml_netmask vpndmz_netmask
    ml_netmask=$(echo "$ML_CIDR" | cut -d/ -f2)
    vpndmz_netmask=$(echo "$VPNDMZ_CIDR" | cut -d/ -f2)
    
    log_info "Network configuration:"
    log_info "  NIC0 (vmbr0): $PT_IG_IP/$ml_netmask, GW: $ML_GW"
    log_info "  NIC1 (vpndmzvn): $PT_EG_IP/$vpndmz_netmask, GW: $VPNDMZ_GW"
    log_info "  DNS: $DNS_IP1${DNS_IP2:+, $DNS_IP2}"
    
    # Read SSH public key content
    local ssh_pubkey
    ssh_pubkey=$(cat "$ssh_pubkey_file")
    log_info "SSH public key loaded for cloud-init user-data"
    
    # Prepare cloud-init user-data with qemu-guest-agent, ssh keys, and static routes
    local userdata_file="/tmp/pritunl_vm_${vmid}_userdata.yml"
    cat > "$userdata_file" <<EOF
#cloud-config

hostname: pritunl-vm-${vmid}
manage_etc_hosts: true
disable_root: false
ssh_pwauth: true

packages:
  - qemu-guest-agent
  - bind-utils
  - nmap-ncat

ssh_authorized_keys:
  - $ssh_pubkey

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - growpart /dev/sda 1 || true
  - xfs_growfs / || true
  - rm -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
  - rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
  - |
    cat > /etc/ssh/sshd_config.d/99-msl.conf <<CFG
    PermitRootLogin yes
    PasswordAuthentication yes
    PubkeyAuthentication yes
    ListenAddress $PT_IG_IP
    CFG
  - systemctl daemon-reload
  - systemctl restart sshd
  - ip route add $PJALL_CIDR via $VPNDMZ_GW dev eth1
  - echo '#!/bin/sh' > /etc/rc.local
  - echo 'ip route add $PJALL_CIDR via $VPNDMZ_GW dev eth1 ' >> /etc/rc.local
  - chmod +x /etc/rc.local
  - echo 'root:Ze!0gx' | chpasswd
  - mkdir -p /tmp/.meipass && chmod 1777 /tmp/.meipass
  - mkdir -p /var/tmp/.meipass && chmod 1777 /var/tmp/.meipass
EOF
    
    
    # Create VM with basic settings (NICs have firewall enabled)
    log_info "Step 1: Creating VM with basic settings (firewall=1 on NICs)..."
    if ! qm create "$vmid" \
        --name "$vm_name" \
        --machine q35 \
        --cpu host \
        --memory 2048 \
        --cores 2 \
        --net0 virtio,bridge=vmbr0,firewall=1 \
        --net1 virtio,bridge=vpndmzvn,firewall=1 \
        --agent 1; then
        log_error "Failed to create VM"
        die "VM creation failed at step 1"
    fi
    
    # Import cloud-init image as disk
    log_info "Step 2: Importing cloud-init image as disk..."
    local import_output
    import_output=$(qm importdisk "$vmid" "$image_path" "$IMAGE_STORAGE" 2>&1)
    log_info "Import output: $import_output"
    
    # Extract imported disk name (e.g., "vm-100-disk-0")
    local disk_name
    disk_name=$(echo "$import_output" | grep -oP "${IMAGE_STORAGE}:vm-\\d+-disk-\\d+" | head -1)
    
    if [ -z "$disk_name" ]; then
        log_error "Failed to extract disk name from import output"
        qm destroy "$vmid" || true
        die "VM creation failed at step 2 (disk import)"
    fi
    
    log_info "Imported disk: $disk_name"
    
    # Attach disk and configure boot (with performance & integrity options)
    # Using virtio-scsi-single to properly support iothread=1
    # Requested disk options: aio=threads,cache=writeback,discard=on,iothread=1,ssd=1
    log_info "Step 3: Attaching disk and configuring boot (virtio-scsi-single, aio=threads, cache=writeback, discard=on, iothread=1, ssd=1)..."
    if ! qm set "$vmid" \
        --scsihw virtio-scsi-single \
        --scsi0 "${disk_name},aio=threads,cache=writeback,discard=on,iothread=1,ssd=1" \
        --boot order=scsi0 \
        --scsi1 "${IMAGE_STORAGE}:cloudinit"; then
        log_error "Failed to attach disk and configure boot"
        qm destroy "$vmid" || true
        die "VM creation failed at step 3 (disk attach)"
    fi
    
    # Resize disk to 20GB (cloud-init image default is 3.5GB, insufficient for Pritunl stack)
    log_info "Step 3.5: Resizing disk to 20GB..."
    if ! qm resize "$vmid" scsi0 20G; then
        log_error "Failed to resize disk"
        qm destroy "$vmid" || true
        die "VM creation failed at step 3.5 (disk resize)"
    fi
    
    # Configure cloud-init (with --cipassword for root password)
    log_info "Step 4: Configuring cloud-init..."
    # Build nameserver parameter (DNS_IP2 may be empty/unset)
    local nameserver_param="$DNS_IP1"
    if [ -n "${DNS_IP2:-}" ]; then
        nameserver_param="$DNS_IP1 $DNS_IP2"
    fi
    
    if ! qm set "$vmid" \
        --ipconfig0 "ip=$PT_IG_IP/$ml_netmask,gw=$ML_GW" \
        --ipconfig1 "ip=$PT_EG_IP/$vpndmz_netmask" \
        --nameserver "$nameserver_param" \
        --cicustom "user=local:snippets/pritunl-vm-${vmid}-userdata.yml" \
        --ciuser root \
        --citype nocloud; then
        log_error "Failed to configure cloud-init"
        qm destroy "$vmid" || true
        rm -f "$userdata_file" "$temp_sshkey_file" 2>&1 || true
        die "VM creation failed at step 4 (cloud-init config)"
    fi
    
    # Copy user-data to Proxmox snippets directory
    mkdir -p /var/lib/vz/snippets
    cp "$userdata_file" "/var/lib/vz/snippets/pritunl-vm-${vmid}-userdata.yml"
    rm -f "$userdata_file" "$temp_sshkey_file"
    
    echo "$MSG_VM_CREATE_SUCCESS"
    log_info "VM created successfully: VMID=$vmid"
}

################################################################################
# Function: wait_for_cloudinit
# Description: Wait for cloud-init to complete inside VM via guest agent
#              AlmaLinux may not auto-create boot-finished, so poll for SSH and
#              check if cloud-init processes have finished instead.
#
# Main commands/functions used:
#   - ssh: Verify SSH accessibility and cloud-init status
#   - ps: Check cloud-init process completion (via guest exec or SSH)
################################################################################
wait_for_cloudinit() {
    local vmid="$1"
    local timeout="${2:-240}"
    local interval=3
    local elapsed=0
    
    printf "$MSG_VM_CLOUDINIT_WAIT\\n" "$timeout"
    log_info "Waiting for cloud-init to complete (timeout: ${timeout}s)..."
    log_info "Polling for SSH connectivity and cloud-init process completion..."
    
    # Poll for SSH connectivity (cloud-init restarts SSH as part of runcmd)
    while [ $elapsed -lt $timeout ]; do
        # Try SSH to verify system is accessible
        if timeout 3 ssh -o ConnectTimeout=2 \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o LogLevel=ERROR \
            root@"$PT_IG_IP" "true" >/dev/null 2>&1; then
            
            log_info "SSH connectivity established at ${elapsed}s"
            
            # SSH works, now verify cloud-init has completed
            # Check if cloud-init process is done (not running any main cloud-init processes)
            if timeout 3 ssh -o ConnectTimeout=2 \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o LogLevel=ERROR \
                root@"$PT_IG_IP" "[ -f /var/lib/cloud/instance/boot-finished ] || systemctl is-system-running --wait >/dev/null 2>&1" >/dev/null 2>&1; then
                
                echo "$MSG_VM_CLOUDINIT_DONE"
                log_info "Cloud-init completion verified via SSH after ${elapsed}s"
                return 0
            fi
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
        
        # Progress update every 30 seconds
        if [ $((elapsed % 30)) -eq 0 ]; then
            log_info "Still waiting for SSH and cloud-init... (${elapsed}s elapsed)"
        fi
    done
    
    # Timeout occurred
    log_warn "Timeout after ${timeout}s waiting for cloud-init completion"
    log_warn "Attempting to verify system is at least accessible..."
    
    # Last attempt: just verify SSH works
    if timeout 3 ssh -o ConnectTimeout=2 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        root@"$PT_IG_IP" "true" >/dev/null 2>&1; then
        
        log_warn "System is SSH-accessible but cloud-init completion could not be verified"
        log_info "Manual verification: ssh root@${PT_IG_IP} 'tail -20 /var/log/cloud-init-output.log'"
        return 1
    fi
    
    # Can't reach SSH at all
    log_error "System is not SSH-accessible after ${timeout}s"
    log_info "VM VMID $vmid is still running. Manual check: qm status $vmid"
    return 1
}

################################################################################
# Function: copy_files_to_vm
# Description: Copy .env and validation script to VM
#
# Main commands/functions used:
#   - scp: Secure copy files to VM
################################################################################
copy_files_to_vm() {
    local vm_ip="$1"
    local env_file="$2"
    local script_file="$3"
    
    echo "$MSG_VM_COPY_ENV"
    echo "$MSG_VM_COPY_SCRIPT"
    log_info "Copying .env and validation binary to VM..."
    
    local scp_output
    if ! scp_output=$(scp -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        "$env_file" "$script_file" root@"$vm_ip":/root 2>&1); then
        log_error "Failed to copy .env & validation binary to VM"
        log_error "SCP error output: $scp_output"
        log_error "Target: root@$vm_ip:/root"
        log_error "Files: $env_file, $script_file"
        return 1
    fi
    
    log_info "Files copied successfully"
    return 0
}

################################################################################
# Function: run_vm_validation
# Description: Execute validation script on VM
#
# Main commands/functions used:
#   - ssh: Execute remote command
################################################################################
run_vm_validation() {
    local vm_ip="$1"
    
    echo "$MSG_VM_RUN_VALIDATION"
    log_info "Running validation on VM..."
    
    # For demo purposes, create /root/demo file if it exists locally
    if [ -f /root/demo ]; then
        ssh -o ConnectTimeout=30 \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o LogLevel=ERROR \
           root@"$vm_ip" "touch /root/demo"
    fi

     # Execute validation binary and show output in real-time
    ssh -o ConnectTimeout=30 \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -o LogLevel=ERROR \
         root@"$vm_ip" "chmod +x /root/pritunl_build_helper" || true

    if ssh -o ConnectTimeout=30 \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o LogLevel=ERROR \
              root@"$vm_ip" "/root/pritunl_build_helper validate"; then
        echo "$MSG_VM_VALIDATION_OK"
        log_info "VM validation completed successfully"
        return 0
    else
        local ssh_exit_code=$?
        echo "$MSG_VM_VALIDATION_FAIL"
        log_error "VM validation failed with exit code: $ssh_exit_code"
        log_error "Target: root@$vm_ip"
        log_error "Binary: /root/pritunl_build_helper (validate)"
        log_error "See validation output above for details"
        return 1
    fi
}
