#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: pritunl_install.sh
# Purpose: Pritunl installation and configuration functions
#
# Main functions/commands used:
#   - ssh: Remote command execution
#   - dnf: Package installation
#   - systemctl: Service management
#   - pritunl: CLI configuration
#
# Dependencies:
#   - common.sh: Logging functions
#
# Usage:
#   source lib/pritunl_install.sh
#
# Notes:
#   - All commands execute remotely via SSH (root user)
#   - No sudo required (VM deployed with root user)
################################################################################

################################################################################
# Function: install_pritunl_packages
# Description: Install MongoDB, OpenVPN, WireGuard, and Pritunl
#
# Parameters:
#   $1 - Pritunl VM IP address
################################################################################
install_pritunl_packages() {
    local vm_ip="$1"
    
    log_info "Installing Pritunl and dependencies on ${vm_ip}..."
    
    # Check disk space before installation
    log_info "Checking available disk space on ${vm_ip}..."
    local avail_space
    avail_space=$(ssh "root@${vm_ip}" "df -h / | awk 'NR==2 {print \$4}'")
    local avail_mb
    avail_mb=$(ssh "root@${vm_ip}" "df -m / | awk 'NR==2 {print \$4}'")
    
    log_info "Available disk space: ${avail_space} (${avail_mb} MB)"
    
    if [ "$avail_mb" -lt 2000 ]; then
        log_error "Insufficient disk space: ${avail_space} available"
        log_error "Required: At least 2GB free space"
        log_error "Current usage:"
        ssh "root@${vm_ip}" "df -h" | while IFS= read -r line; do
            log_error "  $line"
        done
        die "Disk space check failed: only ${avail_space} available, need at least 2GB"
    fi
    
        # Add MongoDB 8.0 repository
        log_info "Adding MongoDB 8.0 repository..."
        if ! ssh "root@${vm_ip}" bash <<'EOF'
cat > /etc/yum.repos.d/mongodb-org.repo <<'REPO'
[mongodb-org-8.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/8.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-8.0.asc
REPO
EOF
    then
        log_error "Failed to add MongoDB repository"
        die "MongoDB repository setup failed (exit code: $?)"
    fi
    
        # Use pritunl-openvpn provided by Pritunl RHEL repository
        # (replaces EPEL openvpn as recommended by Pritunl)

        # Add Pritunl repository (Oracle Linux 9 path per official guidance)
        log_info "Adding Pritunl repository..."
        if ! ssh "root@${vm_ip}" bash <<'EOF'
cat > /etc/yum.repos.d/pritunl.repo <<'REPO'
[pritunl]
name=Pritunl Repository
    baseurl=https://repo.pritunl.com/stable/yum/oraclelinux/9/
gpgcheck=1
enabled=1
gpgkey=https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc
REPO
sed -i 's/^\s\+//' /etc/yum.repos.d/pritunl.repo
EOF
    then
        log_error "Failed to add Pritunl repository"
        die "Pritunl repository setup failed (exit code: $?)"
    fi
    
    # Install packages
    log_info "Installing packages (this may take a few minutes)..."
    if ! ssh "root@${vm_ip}" bash <<'EOF'
dnf -y update
yum -y swap openvpn pritunl-openvpn || true
yum -y --allowerasing install pritunl-openvpn
dnf -y install pritunl pritunl-openvpn wireguard-tools mongodb-org
EOF
    then
        local exit_code=$?
        log_error "Package installation failed with exit code: ${exit_code}"
        log_error "Checking disk space after failure:"
        ssh "root@${vm_ip}" "df -h /" | tee -a "${LOG_FILE}"
        log_error "Checking rpm status:"
        ssh "root@${vm_ip}" "rpm -qa | grep -E 'pritunl|mongodb|openvpn|wireguard'" | tee -a "${LOG_FILE}"
        die "Failed to install Pritunl packages (exit code: ${exit_code}). Check disk space and logs above."
    fi
    
    log_info "Package installation completed"

    # Load Pritunl SELinux policies and relabel files
    log_info "Loading Pritunl SELinux policies..."
    if ! ssh "root@${vm_ip}" bash <<'EOF'
if command -v semodule >/dev/null 2>&1; then
    semodule_args=()
    [ -f /usr/share/selinux/packages/pritunl.pp ] && semodule_args+=(/usr/share/selinux/packages/pritunl.pp)
    [ -f /usr/share/selinux/packages/pritunl_web.pp ] && semodule_args+=(/usr/share/selinux/packages/pritunl_web.pp)
    [ -f /usr/share/selinux/packages/pritunl_dns.pp ] && semodule_args+=(/usr/share/selinux/packages/pritunl_dns.pp)
    if [ ${#semodule_args[@]} -gt 0 ]; then
        semodule -i "${semodule_args[@]}"
    fi

    restore_targets=()
    [ -f /etc/pritunl.conf ] && restore_targets+=(/etc/pritunl.conf)
    [ -d /var/lib/pritunl ] && restore_targets+=(/var/lib/pritunl)
    [ -d /var/log/pritunl ] && restore_targets+=(/var/log/pritunl)
    [ -d /run/pritunl ] && restore_targets+=(/run/pritunl)
    [ -d /var/run/pritunl ] && restore_targets+=(/var/run/pritunl)
    if [ ${#restore_targets[@]} -gt 0 ]; then
        restorecon -Rv "${restore_targets[@]}" || true
    fi
fi
EOF
    then
        log_warn "Failed to load Pritunl SELinux policies (non-fatal, continuing...)"
    fi
}

################################################################################
# Function: configure_mongodb
# Description: Configure MongoDB to bind to localhost only
#
# Parameters:
#   $1 - Pritunl VM IP address
################################################################################
configure_mongodb() {
    local vm_ip="$1"
    
    log_info "Configuring MongoDB..."
    
    # Update MongoDB configuration to bind to localhost
    ssh "root@${vm_ip}" bash <<'EOF'
sed -i 's/^  bindIp:.*/  bindIp: 127.0.0.1/' /etc/mongod.conf
EOF
    
    # Start and enable MongoDB
    log_info "Starting MongoDB service..."
    if ! ssh "root@${vm_ip}" bash <<'EOF'
systemctl start mongod
systemctl enable mongod
EOF
    then
        log_error "Failed to start/enable MongoDB service"
        log_error "MongoDB service status:"
        ssh "root@${vm_ip}" "systemctl status mongod --no-pager" | tee -a "${LOG_FILE}"
        log_error "MongoDB logs:"
        ssh "root@${vm_ip}" "journalctl -u mongod -n 50 --no-pager" | tee -a "${LOG_FILE}"
        die "MongoDB service failed to start (exit code: $?)"
    fi
    
    # Wait for MongoDB to be fully ready
    log_info "Waiting for MongoDB to be ready..."
    local max_wait=30
    local waited=0
    while [ $waited -lt $max_wait ]; do
        if ssh "root@${vm_ip}" "mongosh --quiet --eval 'db.adminCommand({ping: 1})' >/dev/null 2>&1"; then
            log_info "MongoDB is ready"
            break
        fi
        sleep 2
        waited=$((waited + 2))
    done
    
    if [ $waited -ge $max_wait ]; then
        log_warn "MongoDB readiness check timed out, but service is running"
    fi
    
    # Verify MongoDB is running
    if ssh "root@${vm_ip}" "systemctl is-active mongod" | grep -q "active"; then
        log_info "MongoDB service started successfully"
    else
        die "MongoDB service failed to start"
    fi
    
    # Test MongoDB connectivity
    if ssh "root@${vm_ip}" "mongosh --eval 'db.adminCommand({ping: 1})'" &>/dev/null; then
        log_info "MongoDB connectivity verified"
    else
        log_warn "MongoDB ping test failed (may be normal during initial startup)"
    fi
}

################################################################################
# Function: configure_pritunl_initial
# Description: Start Pritunl and retrieve setup credentials
#
# Parameters:
#   $1 - Pritunl VM IP address
################################################################################
configure_pritunl_initial() {
    local vm_ip="$1"
    
    log_info "Configuring Pritunl initial setup..."
    
    # Disable Pritunl auto-start and stop it if running
    # (We will perform configuration before first clean start)
    log_info "Ensuring Pritunl service is not running before initial configuration..."
    if ! ssh "root@${vm_ip}" bash <<'EOF'
set -e
if systemctl is-active --quiet pritunl; then
  systemctl stop pritunl || { echo "ERROR: Failed to stop pritunl"; exit 1; }
fi
systemctl disable pritunl || { echo "ERROR: Failed to disable pritunl"; exit 1; }
exit 0
EOF
    then
        log_error "Failed to prepare Pritunl service state (pre-start)"
        ssh "root@${vm_ip}" "systemctl status pritunl --no-pager" | tee -a "${LOG_FILE}" || true
        die "Pritunl pre-start service preparation failed"
    fi
}

################################################################################
# Function: apply_security_hardening
# Description: Apply security hardening (bind addresses, disable port 80)
#
# Parameters:
#   $1 - Pritunl VM IP address
################################################################################
apply_security_hardening() {
    local vm_ip="$1"
    
    log_info "Applying security hardening..."
    
    # Disabling port 80 for Pritunl GUI
    log_info "Disabling port 80 for Pritunl GUI..."
    ssh "root@${vm_ip}" bash <<EOF
pritunl set app.redirect_server false
EOF
    
    # Configure SSH to listen only on PT_IG_IP
    log_info "Configuring SSH to listen only on ${PT_IG_IP}..."
    ssh "root@${vm_ip}" bash <<EOF
# Backup original sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Add ListenAddress directive (remove any existing ones first)
sed -i '/^ListenAddress/d' /etc/ssh/sshd_config
echo "ListenAddress ${PT_IG_IP}" >> /etc/ssh/sshd_config

# Restart SSH (AlmaLinux uses 'sshd')
systemctl restart sshd
EOF
    
    log_info "Security hardening completed"
}

################################################################################
# Function: configure_system_settings
# Description: Enable IP forwarding and verify kernel modules
#
# Parameters:
#   $1 - Pritunl VM IP address
################################################################################
configure_system_settings() {
    local vm_ip="$1"
    
    log_info "Configuring system settings..."
    
    # Enable IP forwarding
    log_info "Enabling IP forwarding..."
    ssh "root@${vm_ip}" bash <<'EOF'
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Make persistent
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
EOF
    
    log_info "System settings configured"
}

################################################################################
# Function: configure_global_pritunl_settings
# Description: Configure global Pritunl settings via CLI
#
# Parameters:
#   $1 - Pritunl VM IP address
################################################################################
configure_global_pritunl_settings() {
    local vm_ip="$1"
    
    log_info "Configuring global Pritunl settings..."
    
    # Configure Pritunl before first start
    log_info "Configuring Pritunl settings before first start..."
    if ! PT_IG_IP="${PT_IG_IP}" ssh "root@${vm_ip}" bash <<'EOF'
set -e
# Backup configuration safely
cp /etc/pritunl.conf /etc/pritunl.conf.bak

# Use jq to edit JSON properly
if command -v jq >/dev/null 2>&1; then
    # Edit with jq (proper JSON manipulation)
    jq --arg bind_addr "$PT_IG_IP" '.bind_addr = $bind_addr | .mongodb_uri = "mongodb://localhost:27017/pritunl"' /etc/pritunl.conf > /etc/pritunl.conf.tmp || { 
        echo "ERROR: jq edit failed" >&2
        mv /etc/pritunl.conf.bak /etc/pritunl.conf
        exit 1
    }
    mv /etc/pritunl.conf.tmp /etc/pritunl.conf
else
    # Fallback to python3 if jq not available
    if command -v python3 >/dev/null 2>&1; then
        python3 <<'PYEOF' || { echo "ERROR: python3 edit failed" >&2; mv /etc/pritunl.conf.bak /etc/pritunl.conf; exit 1; }
import json
import os

bind_addr = os.environ.get('PT_IG_IP', '').strip()
if not bind_addr:
    raise RuntimeError('PT_IG_IP is not set')

with open('/etc/pritunl.conf', 'r') as f:
    config = json.load(f)
config['bind_addr'] = bind_addr
config['mongodb_uri'] = 'mongodb://localhost:27017/pritunl'
with open('/etc/pritunl.conf', 'w') as f:
    json.dump(config, f, indent=4)
PYEOF
    else
        echo "ERROR: Neither jq nor python3 available for JSON editing" >&2
        mv /etc/pritunl.conf.bak /etc/pritunl.conf
        exit 1
    fi
fi

# Verify JSON syntax
if command -v python3 >/dev/null 2>&1; then
    if ! python3 -m json.tool < /etc/pritunl.conf >/dev/null 2>&1; then
        echo "ERROR: Invalid JSON after edit; rolling back" >&2
        mv /etc/pritunl.conf.bak /etc/pritunl.conf
        exit 1
    fi
fi

# Verify mongodb_uri is set
if grep -q '"mongodb_uri": ""' /etc/pritunl.conf; then
    echo "ERROR: mongodb_uri still empty after edit" >&2
    mv /etc/pritunl.conf.bak /etc/pritunl.conf
    exit 1
fi

exit 0
EOF
    then
        log_error "Failed to apply initial Pritunl pre-start configuration"
        ssh "root@${vm_ip}" "cat /etc/pritunl.conf" | tee -a "${LOG_FILE}" || true
        die "Pritunl pre-start configuration failed"
    fi
    
    # Set DNS route via CLI after config file is ready
    log_info "Setting vpn.dns_route via CLI..."
    ssh "root@${vm_ip}" "pritunl set vpn.dns_route false" || log_warn "Failed to set vpn.dns_route (will continue)"
    
    # Start and enable Pritunl service
    log_info "Starting Pritunl service..."
    if ! ssh "root@${vm_ip}" bash <<'EOF'
set -e
systemctl start pritunl || { echo "ERROR: Failed to start pritunl"; exit 1; }
systemctl enable pritunl || { echo "ERROR: Failed to enable pritunl"; exit 1; }
exit 0
EOF
    then
        log_error "Failed to start/enable Pritunl service"
        log_error "Pritunl service status:"
        ssh "root@${vm_ip}" "systemctl status pritunl --no-pager" | tee -a "${LOG_FILE}"
        log_error "Pritunl logs:"
        ssh "root@${vm_ip}" "journalctl -u pritunl -n 50 --no-pager" | tee -a "${LOG_FILE}"
        die "Pritunl service failed to start (exit code: $?)"
    fi
    
    # Wait for Pritunl to be ready
    log_info "Waiting for Pritunl GUI to be ready..."
    sleep 5
    
    log_info "Global Pritunl settings configured"
}

################################################################################
# Function: setup_pritunl_orgs
# Description: Create Orgs, attach to Servers, and start Servers using helper binary
#
# Parameters:
#   $1 - Pritunl VM IP address
#   $2 - (Optional) Pritunl default password. If invalid, it will be retrieved via SSH.
#
# Main functions/commands used:
#   - lib/pritunl_build_helper: Generated helper binary
#   - ssh: Retrieve default password
################################################################################
setup_pritunl_orgs() {
    local vm_ip="$1"
    local passed_password="$2"
    local setup_script="${PROJECT_ROOT}/lib/pritunl_build_helper"
    local default_password=""
    
    log_info "Setting up Pritunl Organizations using API..."
    
    if [[ ! -f "${setup_script}" ]]; then
        log_error "Setup script not found: ${setup_script}"
        log_error "Please run scripts/build_pyinstaller.sh first."
        return 1
    fi
    
    # Use passed password if valid
    if [[ -n "$passed_password" ]]; then
        default_password="$passed_password"
    else
        log_info "Retrieving Pritunl default password..."
        if ! default_password=$(ssh -o ConnectTimeout=10 "root@${vm_ip}" "pritunl default-password" 2>&1 | tail -1 | sed 's/^.*password: *//'); then
            log_error "Failed to retrieve default password via SSH"
            return 1
        fi
        # Trim whitespace just in case
        default_password=$(echo "${default_password}" | xargs)
    fi
    
    if [[ -z "${default_password}" ]]; then
        log_error "Empty password provided or retrieved. Check Pritunl status."
        return 1
    fi
    
    log_info "Executing organization setup command..."
    # Execute binary. If it fails, we die (no fallback requested).
    if "${setup_script}" setup-orgs --vm-ip "${vm_ip}" --username "pritunl" --password "${default_password}" --env "${PROJECT_ROOT}/.env"; then
        log_info "Pritunl Organizations setup completed."
        return 0
    else
        log_error "Pritunl Organizations setup failed."
        exit 1
    fi
}

################################################################################
# Function: create_pritunl_servers_mongodb
# Description: Create Pritunl VPN servers via MongoDB direct manipulation
#              (Phase 3.9.2 automation - bypasses GUI)
#
# Parameters:
#   $1 - Pritunl VM IP address
################################################################################
create_pritunl_servers_mongodb() {
    local vm_ip="$1"

    log_info "Creating Pritunl VPN servers via MongoDB direct manipulation..."

    # Copy compiled binary helper to VM
    local binary_path="${PROJECT_ROOT}/lib/pritunl_build_helper"
    log_info "Copying compiled helper binary to VM..."
    if ! scp "${binary_path}" "root@${vm_ip}:/tmp/pritunl_build_helper"; then
        die "Failed to copy helper binary to VM"
    fi

    # Make binary executable
    ssh "root@${vm_ip}" "chmod +x /tmp/pritunl_build_helper" || die "Failed to set executable permission"

    # Run compiled binary (output to both console and log)
    log_info "Running helper binary for MongoDB server creation..."
    ssh "root@${vm_ip}" "/tmp/pritunl_build_helper mongodb --vm-ip ${vm_ip} --env /tmp/.env" 2>&1 | tee -a "${LOG_FILE}"
    local ssh_status="${PIPESTATUS[0]}"
    if [[ $ssh_status -ne 0 ]]; then
        die "Helper binary failed to create Pritunl servers"
    fi

    # Clean up
    ssh "root@${vm_ip}" "rm -f /tmp/pritunl_build_helper" || true
}

################################################################################
# Function: generate_pritunl_config_doc
# Description: Generate Pritunl configuration reference document from template
#              by replacing placeholders with NUM_PJ-based dynamic content
#
# Main commands/functions used:
#   - sed: Replace template placeholders with generated content
################################################################################
generate_pritunl_config_doc() {
    local template_file="${PROJECT_ROOT}/docs/pritunl_config_reference_template.md"
    local output_file="${PROJECT_ROOT}/docs/pritunl_config_reference.md"
    local env_file="${PROJECT_ROOT}/.env"
    local timestamp=$(date '+%a %b %d %I:%M:%S %p %Z %Y')

    # Check template exists
    if [[ ! -f "${template_file}" ]]; then
        log_info "Pritunl config template not found: ${template_file}"
        return 1
    fi

    # Check .env exists
    if [[ ! -f "${env_file}" ]]; then
        log_info ".env file not found: ${env_file}"
        return 1
    fi

    # Source .env to get NUM_PJ
    # shellcheck source=/dev/null
    source "${env_file}"

    log_info "Generating Pritunl configuration reference document..."
    log_info "Template: ${template_file}"
    log_info "Output: ${output_file}"
    log_info "NUM_PJ: ${NUM_PJ}"

    # Generate organization list
    local org_list=""
    for i in $(seq 1 "${NUM_PJ}"); do
        local pj_id=$(printf "pj%02d" "$i")
        if [[ $i -eq "${NUM_PJ}" ]]; then
            org_list+="- ${pj_id}  "
        else
            org_list+="- ${pj_id}  \n"
        fi
    done

    # Generate organization mapping
    local org_mapping=""
    for i in $(seq 1 "${NUM_PJ}"); do
        local pj_id=$(printf "pj%02d" "$i")
        local server_name=$(printf "Server%02d" "$i")
        org_mapping+="- Org \`${pj_id}\` → ${server_name}  \n"
    done

    # Generate table rows
    local table_rows=""
    for i in $(seq 1 "${NUM_PJ}"); do
        local pj_id=$(printf "pj%02d" "$i")
        local server_name=$(printf "Server%02d" "$i")
        local ovpn_pool="OVPN_POOL${i}"
        local wg_pool="WG_POOL${i}"
        local pj_cidr=$(printf "PJ%02d_CIDR" "$i")

        if [[ $i -eq 1 ]]; then
            table_rows+="| ${pj_id}   | ${server_name}   | \`${PF_ST_OV}\`          | \`${PF_ST_WG}\`        | \`\${${ovpn_pool}}\` | \`\${${wg_pool}}\`    | \`\${${pj_cidr}}\` |\n"
        else
            table_rows+="| ${pj_id}   | ${server_name}   | \`$((PF_ST_OV + i - 1))\`        | \`$((PF_ST_WG + i - 1))\`      | \`\${${ovpn_pool}}\` | \`\${${wg_pool}}\`    | \`\${${pj_cidr}}\` |\n"
        fi
    done

    # Build sed script for template substitution
    local sed_script=""
    sed_script+="s@{{ORG_LIST}}@${org_list}@g;"
    sed_script+="s@{{ORG_MAPPING}}@${org_mapping}@g;"
    sed_script+="s@{{PJ_TABLE_ROWS}}@${table_rows}@g;"

    # Read all variables from .env for ${VAR} replacement
    while IFS='=' read -r key value; do
        [[ "${key}" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${key}" ]] && continue
        value="${value%\"}"
        value="${value#\"}"
        sed_script+="s@\\\${${key}}@${value}@g;"
    done < "${env_file}"

    # Update timestamp
    sed_script+="s@Thu Dec  4 03:02:46 PM JST 2025@${timestamp}@g;"

    # Apply all substitutions
    if sed "${sed_script}" "${template_file}" > "${output_file}"; then
        log_info "Pritunl config reference generated successfully"
        log_info "File: ${output_file}"
        return 0
    else
        log_info "Failed to generate Pritunl config reference"
        return 1
    fi
}

################################################################################
# Function: save_config_to_vm_notes
# Description: Save Pritunl configuration reference to VM notes section in Proxmox
#
# Parameters:
#   $1 - VM ID
#   $2 - Pritunl VM IP address
#   $3 - (Optional) Pritunl default password. If invalid, it will be retrieved via SSH.
#
# Main commands/functions used:
#   - qm: Proxmox VM management
#   - env variable substitution: Replace placeholders with actual values
################################################################################
save_config_to_vm_notes() {
    local vmid="$1"
    local vm_ip="$2"
    local passed_password="$3"
    local default_password=""
    
    # Generate pritunl_config_reference.md from template
    generate_pritunl_config_doc
    
    log_info "Saving Pritunl configuration reference to VM notes..."
    
    # Read pritunl_config_reference.md and substitute .env variables
    if [ ! -f "docs/pritunl_config_reference.md" ]; then
        log_warn "pritunl_config_reference.md not found, skipping notes update"
        return 0
    fi
    
    # Read the file content
    local config_content
    config_content=$(cat docs/pritunl_config_reference.md)
    
    # Perform variable substitution using envsubst-like approach
    # Export all variables from .env for substitution
    set -a
    source .env
    set +a
    
    # Use eval to perform variable substitution
    config_content=$(echo "$config_content" | envsubst)
    
    # Add setup information at the top
    local setup_key
    if ! setup_key=$(ssh "root@${vm_ip}" "pritunl setup-key" 2>&1 | tail -1); then
        log_warn "Could not retrieve setup key"
        setup_key="[Unable to retrieve]"
    fi

    # Use passed password if valid
    if [[ -n "$passed_password" ]]; then
        default_password="$passed_password"
    else
        if ! default_password=$(ssh "root@${vm_ip}" "pritunl default-password" 2>&1 | tail -1 | sed 's/^.*password: *//'); then
            log_warn "Could not retrieve default password"
            default_password="[Unable to retrieve]"
        fi
    fi
    # Trim whitespace
    default_password=$(echo "${default_password}" | xargs)
    
    # Prepend setup credentials with <BR> tags for proper line breaks in Proxmox Web UI
    local notes_header="<sup>\n\n"
    notes_header+="# Pritunl Setup Credentials\n\n"
    notes_header+="**Initial Username**: pritunl<BR>\n"
    notes_header+="**Initial Password**: ${default_password}<BR>\n"
    notes_header+="## Initial credential for ssh to Pritunl VM\n\n"
    notes_header+="- User: root\n"
    notes_header+="- Password: Ze!0gx\n\n"
    notes_header+="**You should change this on first login**<BR>\n\n"
    notes_header+="---\n\n"
    
    local full_notes="${notes_header}${config_content}"
    
    # Update VM notes using qm (no escaping needed, qm handles it)
    log_info "Updating Proxmox VM ${vmid} notes..."
    if ! echo -e "$full_notes" | qm set "$vmid" --description "$(cat)" >/dev/null 2>&1; then
        log_warn "Failed to update VM notes (this is non-critical)"
    else
        log_info "VM notes updated successfully"
    fi
}

################################################################################
# Function: perform_verification
# Description: Verify all Phase 3 automated setup
#
# Parameters:
#   $1 - Pritunl VM IP address
################################################################################
perform_verification() {
    local vm_ip="$1"
    
    log_info "Performing verification..."
    
    # Verify no services listening on 0.0.0.0
    log_info "Checking for services listening on 0.0.0.0..."
    local zero_listeners
    zero_listeners=$(ssh "root@${vm_ip}" "ss -tulpn | grep -E ':22|:443|:27017' | awk '\$5 ~ /^0\.0\.0\.0:/ {print}'" || true)
    if [ -n "$zero_listeners" ]; then
        log_warn "$zero_listeners"
        die "Some services are listening on 0.0.0.0:"
    else
        log_info "No services listening on 0.0.0.0 (good)"
    fi
    
    # Verify services are active
    log_info "Verifying service status..."
    if ssh "root@${vm_ip}" "systemctl is-active pritunl mongod" | grep -q "inactive\|failed"; then
        die "Some services are not active. Check logs."
    else
        log_info "All services active (pritunl, mongod)"
    fi
    
    # Verify MongoDB connectivity
    log_info "Verifying MongoDB connectivity..."
    if ssh "root@${vm_ip}" "mongosh --eval 'db.adminCommand({ping: 1})' --quiet" | grep -q "ok.*1"; then
        log_info "MongoDB connectivity verified"
    else
        die "MongoDB ping test inconclusive"
    fi
    
    # Verify GUI accessibility
    log_info "Verifying Pritunl GUI accessibility..."
    local max_retries=20
    local retry_interval=3
    local retry_count=0
    local gui_accessible=false
    
    while [ $retry_count -lt $max_retries ]; do
        retry_count=$((retry_count + 1))
        log_info "Attempting to access Pritunl GUI (attempt ${retry_count}/${max_retries}): https://${vm_ip}/"
        
        if curl -k -s -m 10 "https://${vm_ip}/" >/dev/null 2>&1; then
            log_info "Pritunl GUI is accessible"
            gui_accessible=true
            break
        else
            if [ $retry_count -lt $max_retries ]; then
                log_info "GUI not yet accessible, retrying in ${retry_interval} seconds..."
                sleep $retry_interval
            fi
        fi
    done
    
    if [ "$gui_accessible" = false ]; then
        die "Pritunl GUI is not accessible after ${max_retries} attempts"
    fi
    
    # Verify return route exists on PVE
    log_info "Verifying return route on PVE host..."
    if ip route show | grep -q "${VPN_POOL}.*${PT_EG_IP}"; then
        log_info "Return route exists: ${VPN_POOL} via ${PT_EG_IP}"
    else
        die "Return route not found (should have been configured in Phase 1)"
    fi
    
    log_info "Verification completed"
}

################################################################################
# Function: display_vm_notes_url
# Description: Display URL to access VM notes in Proxmox Web UI
#
# Parameters:
#   $1 - VM ID
################################################################################
display_vm_notes_url() {
    local vmid="$1"
    echo ""
    echo "==============================================="
    echo " Pritunl Configuration Reference"
    echo "==============================================="
    echo ""
    echo "The configuration reference has been saved to the"
    echo "Proxmox VM notes section."
    echo ""
    echo "View it here:"
    echo "  https://${PVE_IP}:8006/#v1:0:=qemu%2F${vmid}:4:=notes"
    echo ""
    echo "==============================================="
    echo ""
}
