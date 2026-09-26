#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: pritunl_install.sh
# Purpose: Host-side functions for installing and configuring Pritunl on the
#          Pritunl VM
#
# Main functions/commands used:
#   - run_pritunl_vm_installer: Copy the installer to the VM and run it
#   - get_pritunl_default_password: Read the initial admin password
#   - setup_pritunl_orgs: Create organizations via the Pritunl API (curl / jq)
#   - save_config_to_vm_notes: Write credentials and configuration to VM notes
#
# Dependencies:
#   - common.sh: Logging functions
#   - PRITUNL_INSTALLER_DIR: Set by the caller (0202_configurePritunl.sh)
#
# Usage:
#   source lib/pritunl_install.sh
#
# Notes:
#   - The installation itself runs inside the VM (<installer>/vm_install.sh).
#     Its output is shown on the console and recorded in the log file.
#   - All remote commands run as root over SSH.
################################################################################

# Directory on the VM that receives the installer files
readonly PRITUNL_VM_INSTALL_DIR="/root/msl-install"

################################################################################
# Function: stream_vm_output
# Description: Show each line read from stdin on the console and append it to
#              the log file with a [VM] prefix.
#
# Main commands/functions used:
#   - read/printf: Line-by-line copy
################################################################################
stream_vm_output() {
    local line ts
    while IFS= read -r line || [[ -n "${line}" ]]; do
        printf '%s\n' "${line}"
        printf -v ts '%(%Y-%m-%d %H:%M:%S)T' -1
        printf '[VM] [%s] %s\n' "${ts}" "${line}" >> "${LOG_FILE}"
    done
}

################################################################################
# Function: run_pritunl_vm_installer
# Description: Copy the installer files and .env to the VM and run
#              vm_install.sh there. Dies with the installer's exit code on
#              failure (the files are kept on the VM for inspection).
#
# Parameters:
#   $1 - Pritunl VM IP address
#
# Main commands/functions used:
#   - scp/ssh: Transfer and run the installer
#   - stream_vm_output: Console and log output
################################################################################
run_pritunl_vm_installer() {
    local vm_ip="$1"
    local files=(
        "${PRITUNL_INSTALLER_DIR}/vm_install.sh"
        "${PRITUNL_INSTALLER_DIR}/msl_pritunl_selinux_port.sh"
        "${PROJECT_ROOT}/lib/pritunl_build_helper.py"
        "${PROJECT_ROOT}/.env"
    )
    local f
    for f in "${files[@]}"; do
        [[ -f "${f}" ]] || die "Installer file not found: ${f}"
    done

    log_info "Copying installer files to ${vm_ip}:${PRITUNL_VM_INSTALL_DIR}..." -c
    ssh "root@${vm_ip}" "rm -rf '${PRITUNL_VM_INSTALL_DIR}' && mkdir -p '${PRITUNL_VM_INSTALL_DIR}'" \
        || die "Failed to prepare ${PRITUNL_VM_INSTALL_DIR} on the VM"
    scp -q "${files[@]}" "root@${vm_ip}:${PRITUNL_VM_INSTALL_DIR}/" \
        || die "Failed to copy installer files to the VM"

    log_info "Running the Pritunl installer on the VM (${PRITUNL_INSTALLER_DESC})..." -c
    local rc=0
    ssh "root@${vm_ip}" "bash '${PRITUNL_VM_INSTALL_DIR}/vm_install.sh'" 2>&1 | stream_vm_output || rc=$?
    if [[ ${rc} -ne 0 ]]; then
        log_error "Installer files are kept on the VM: ${PRITUNL_VM_INSTALL_DIR}" -c
        die "Pritunl installation failed on the VM (exit code: ${rc}). See the output above." "${rc}"
    fi

    ssh "root@${vm_ip}" "rm -rf '${PRITUNL_VM_INSTALL_DIR}'" \
        || log_warn "Failed to remove ${PRITUNL_VM_INSTALL_DIR} on the VM"
    log_info "Pritunl installation on the VM completed" -c
}

################################################################################
# Function: get_pritunl_default_password
# Description: Read the initial admin password with 'pritunl default-password'
#              and store it in PRITUNL_PASSWORD. Retries, then dies if empty.
#
# Parameters:
#   $1 - Pritunl VM IP address
#
# Main commands/functions used:
#   - ssh: Run 'pritunl default-password' on the VM
################################################################################
get_pritunl_default_password() {
    local vm_ip="$1"
    local attempt
    PRITUNL_PASSWORD=""

    log_info "Retrieving Pritunl default password..." -c
    for attempt in $(seq 1 10); do
        PRITUNL_PASSWORD=$(ssh -o ConnectTimeout=10 "root@${vm_ip}" "pritunl default-password" 2>/dev/null \
            | tail -1 | sed 's/^.*password: *//' | xargs || true)
        if [[ -n "${PRITUNL_PASSWORD}" ]]; then
            return 0
        fi
        log_info "Default password not available yet (attempt ${attempt}/10)"
        sleep 3
    done
    die "Could not retrieve the Pritunl default password (pritunl default-password)"
}

################################################################################
# Function: pritunl_api
# Description: Call the Pritunl web API with the session cookie and CSRF token
#              set up by setup_pritunl_orgs, and print the response body.
#              Fails (curl exit code) on HTTP errors; 5xx responses and refused
#              connections are retried.
#
# Parameters:
#   $1 - HTTP method
#   $2 - Path (e.g. /organization)
#   $3 - (Optional) JSON request body (passed on stdin, not on the command line)
#
# Main commands/functions used:
#   - curl: HTTPS request (the Pritunl certificate is self-signed)
################################################################################
pritunl_api() {
    local method="$1"
    local path="$2"
    local body="${3:-}"
    local args=(
        -sS -k --fail-with-body --max-time 30
        --retry 30 --retry-delay 1 --retry-connrefused
        -b "${PRITUNL_API_COOKIE}" -c "${PRITUNL_API_COOKIE}"
        -X "${method}"
        -H "Accept: application/json, text/javascript, */*; q=0.01"
        -H "X-Requested-With: XMLHttpRequest"
    )
    if [[ -n "${PRITUNL_API_CSRF}" ]]; then
        args+=(-H "csrf-token: ${PRITUNL_API_CSRF}")
    fi

    if [[ -n "${body}" ]]; then
        curl "${args[@]}" -H "Content-Type: application/json" --data-binary @- \
            "${PRITUNL_API_URL}${path}" <<<"${body}"
    elif [[ "${method}" != "GET" ]]; then
        curl "${args[@]}" -H "Content-Length: 0" "${PRITUNL_API_URL}${path}"
    else
        curl "${args[@]}" "${PRITUNL_API_URL}${path}"
    fi
}

################################################################################
# Function: _pritunl_api_login
# Description: Log in to the Pritunl web API (session cookie) and get the CSRF
#              token. Right after Pritunl (re)starts, the GUI and /state already
#              answer while POST /auth/session still returns 404 for several
#              seconds, so 404 / 5xx / no connection are retried.
#
# Parameters:
#   $1 - Login request body (JSON)
#
# Main commands/functions used:
#   - curl: POST /auth/session
#   - pritunl_api: GET /state
################################################################################
_pritunl_api_login() {
    local login_json="$1"
    local max_retries=40
    local retry_interval=3
    local attempt out code body resp

    for ((attempt = 1; attempt <= max_retries; attempt++)); do
        out=$(curl -sS -k --max-time 30 \
            -b "${PRITUNL_API_COOKIE}" -c "${PRITUNL_API_COOKIE}" \
            -X POST -H "Content-Type: application/json" --data-binary @- \
            -w '\n%{http_code}' "${PRITUNL_API_URL}/auth/session" <<<"${login_json}" 2>/dev/null || true)
        code="${out##*$'\n'}"
        body="${out%$'\n'*}"
        if [[ "${code}" == "200" ]]; then
            break
        fi
        if [[ "${code}" == "404" || "${code}" == "000" || -z "${code}" || "${code}" == 5* ]]; then
            log_info "Pritunl web API not ready (POST /auth/session: HTTP ${code:-none}, attempt ${attempt}/${max_retries}), retrying in ${retry_interval} seconds..." -c
            sleep "${retry_interval}"
            continue
        fi
        log_error "Pritunl login failed (HTTP ${code}): ${body}" -c
        return 1
    done
    if [[ "${code}" != "200" ]]; then
        log_error "Pritunl login did not succeed after $((max_retries * retry_interval)) seconds (last HTTP ${code:-none})" -c
        return 1
    fi

    if ! resp=$(pritunl_api GET /state); then
        log_error "Failed to get /state: ${resp}" -c
        return 1
    fi
    PRITUNL_API_CSRF=$(jq -r '.csrf_token // empty' <<<"${resp}" 2>/dev/null || true)
    if [[ -z "${PRITUNL_API_CSRF}" ]]; then
        log_error "CSRF token not found in the /state response" -c
        return 1
    fi
    log_info "Logged in to the Pritunl API" -c
}

################################################################################
# Function: _setup_pritunl_orgs_api
# Description: Log in, then for each project create the organization pjNN
#              (unless it exists), attach it to ServerNN and start the server.
#              Returns 1 on the first error (errors are logged).
#
# Parameters:
#   $1 - Pritunl default password
#
# Main commands/functions used:
#   - _pritunl_api_login / pritunl_api: Pritunl web API calls
#   - jq: Build request bodies and parse responses
################################################################################
_setup_pritunl_orgs_api() {
    local password="$1"
    local resp login_json i pj server org_id server_id

    # The password goes through the environment and stdin, not argv
    login_json=$(PRITUNL_LOGIN_PASSWORD="${password}" jq -cn '{username: "pritunl", password: env.PRITUNL_LOGIN_PASSWORD}') \
        || { log_error "Failed to build the login request" -c; return 1; }
    _pritunl_api_login "${login_json}" || return 1

    for ((i = 1; i <= NUM_PJ; i++)); do
        printf -v pj 'pj%02d' "${i}"
        printf -v server 'Server%02d' "${i}"
        log_info "--- ${pj} / ${server} ---" -c

        # Organization (reuse one with the same name)
        if ! resp=$(pritunl_api GET /organization); then
            log_error "Failed to list organizations: ${resp}" -c
            return 1
        fi
        org_id=$(jq -r --arg n "${pj}" \
            '(if type == "object" and has("organizations") then .organizations else . end)
             | .[] | select(.name == $n) | .id' <<<"${resp}" 2>/dev/null | head -n 1)
        if [[ -n "${org_id}" ]]; then
            log_info "Organization ${pj} already exists (${org_id})" -c
        else
            if ! resp=$(pritunl_api POST /organization "$(jq -cn --arg n "${pj}" '{name: $n, user_groups: []}')"); then
                log_error "Failed to create organization ${pj}: ${resp}" -c
                return 1
            fi
            org_id=$(jq -r '.id // empty' <<<"${resp}" 2>/dev/null || true)
            if [[ -z "${org_id}" ]]; then
                log_error "No id in the response when creating organization ${pj}: ${resp}" -c
                return 1
            fi
            log_info "Organization created: ${pj} (${org_id})" -c
        fi

        # Server (created in MongoDB by vm_install.sh)
        if ! resp=$(pritunl_api GET /server); then
            log_error "Failed to list servers: ${resp}" -c
            return 1
        fi
        server_id=$(jq -r --arg n "${server}" '.[] | select(.name == $n) | .id' <<<"${resp}" 2>/dev/null | head -n 1)
        if [[ -z "${server_id}" ]]; then
            log_error "Server ${server} not found" -c
            return 1
        fi

        if ! resp=$(pritunl_api PUT "/server/${server_id}/organization/${org_id}" \
                "$(jq -cn --arg o "${org_id}" --arg s "${server_id}" '{id: $o, server: $s, name: null}')"); then
            log_error "Failed to attach ${pj} to ${server}: ${resp}" -c
            return 1
        fi
        log_info "Attached ${pj} to ${server}" -c

        if ! resp=$(pritunl_api PUT "/server/${server_id}/operation/start"); then
            log_error "Failed to start ${server}: ${resp}" -c
            return 1
        fi
        log_info "Started ${server}" -c
    done
    return 0
}

################################################################################
# Function: setup_pritunl_orgs
# Description: Create the organizations pj01..pjNN, attach them to
#              Server01..ServerNN and start the servers via the Pritunl web API
#              (curl from the host). Dies on failure.
#
# Parameters:
#   $1 - Pritunl VM IP address
#   $2 - Pritunl default password
#
# Main commands/functions used:
#   - _setup_pritunl_orgs_api: API calls
#   - mktemp: Session cookie file (removed afterwards)
################################################################################
setup_pritunl_orgs() {
    local vm_ip="$1"
    local password="$2"
    local rc=0

    [[ -n "${password}" ]] || die "Pritunl default password is empty"
    [[ "${NUM_PJ:-}" =~ ^[0-9]+$ ]] || die "NUM_PJ is not set in .env"

    log_info "Setting up Pritunl Organizations using API (NUM_PJ=${NUM_PJ})..." -c
    PRITUNL_API_URL="https://${vm_ip}"
    PRITUNL_API_CSRF=""
    PRITUNL_API_COOKIE=$(mktemp) || die "Failed to create a temporary cookie file"

    _setup_pritunl_orgs_api "${password}" || rc=$?
    command rm -f "${PRITUNL_API_COOKIE}"
    PRITUNL_API_CSRF=""

    [[ ${rc} -eq 0 ]] || die "Pritunl Organizations setup failed"
    log_info "Pritunl Organizations setup completed" -c
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
#   $3 - Pritunl default password
#
# Main commands/functions used:
#   - qm: Proxmox VM management
#   - env variable substitution: Replace placeholders with actual values
################################################################################
save_config_to_vm_notes() {
    local vmid="$1"
    local vm_ip="$2"
    local default_password="$3"
    
    # Generate pritunl_config_reference.md from template
    generate_pritunl_config_doc
    
    log_info "Saving Pritunl configuration reference to VM notes..."
    
    # Read pritunl_config_reference.md and substitute .env variables
    if [ ! -f "docs/pritunl_config_reference.md" ]; then
        log_warn "pritunl_config_reference.md not found, skipping notes update"
        return 0
    fi
    
    # Read generated file content as-is.
    # NOTE: Do not run envsubst here because it would also expand literal
    # MongoDB operators such as "$set" in code examples.
    local config_content
    config_content=$(cat docs/pritunl_config_reference.md)
    
    # Add setup information at the top
    local setup_key
    if ! setup_key=$(ssh "root@${vm_ip}" "pritunl setup-key" 2>&1 | tail -1); then
        log_warn "Could not retrieve setup key"
        setup_key="[Unable to retrieve]"
    fi

    # Prepend setup credentials with <BR> tags for proper line breaks in Proxmox Web UI
    local notes_header="<sup>\n\n"
    notes_header+="# Pritunl Setup Credentials\n\n"
    notes_header+="[![Pritunl GUI](https://img.shields.io/badge/Pritunl-GUI-blue.svg)](https://${vm_ip})\n\n"
    notes_header+="<sub>💡 Open in new tab: Ctrl+Click / Cmd+Click</sub>\n\n"
    notes_header+="**Initial Username**: pritunl<BR>\n"
    notes_header+="**Initial Password**: ${default_password}<BR>\n"
    notes_header+="## Initial credential for ssh to Pritunl VM\n\n"
    notes_header+="- User: root\n"
    notes_header+="- Password: ${PRITUNL_VM_ROOT_PASSWORD}\n\n"
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
