#!/bin/bash
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: profile.sh
# Purpose: Host-side definition of the "alma9" Pritunl installer
#          (Pritunl on AlmaLinux 9 GenericCloud)
#
# Main functions/commands used:
#   - render_cloudinit_userdata: Print the cloud-init user-data for the VM
#
# Dependencies:
#   - Sourced by 0201_createPritunlVM.sh and 0202_configurePritunl.sh
#
# Usage:
#   source lib/pritunl_installers/alma9/profile.sh
#
# Notes:
#   - Each directory under lib/pritunl_installers/ is one installation method.
#     A new method (e.g. a newer OS) is added as a new directory with the same
#     set of files; the host scripts only use what this file defines.
#   - Files in this directory:
#       profile.sh                  : this file (host side). Image definition and
#                                     cloud-init user-data (render_cloudinit_userdata)
#       vm_install.sh               : run inside the VM by 0202 (installation)
#       msl_pritunl_selinux_port.sh : run inside the VM (SELinux port labels)
#   - lib/pritunl_build_helper.py (validate / mongodb) is shared by all
#     installation methods and run with the VM's python3.
################################################################################

PRITUNL_INSTALLER_DESC="Pritunl on AlmaLinux 9 (GenericCloud)"

# Cloud-init image
IMAGE_URL="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
CHECKSUM_URL="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/CHECKSUM"
IMAGE_CACHE_PATH="/var/lib/vz/template/iso/almalinux-9-genericcloud-latest.x86_64.qcow2"

################################################################################
# Function: render_cloudinit_userdata
# Description: Print the cloud-init user-data (#cloud-config) for the Pritunl VM.
#              Uses PT_IG_IP, PJALL_CIDR and VPNDMZ_GW from .env.
#
# Parameters:
#   $1 - VMID (used for the hostname)
#   $2 - SSH public key (content, one line)
#   $3 - Initial root password
#
# Main commands/functions used:
#   - cat: Here-document output
#
# Notes:
#   - Root login: disable_root: false keeps root's authorized_keys usable. The
#     password and sshd settings are applied in runcmd: the cloud image's
#     sshd_config.d files are removed and 99-msl.conf enables root/password
#     login and makes sshd listen only on PT_IG_IP.
################################################################################
render_cloudinit_userdata() {
    local vmid="$1"
    local ssh_pubkey="$2"
    local root_password="$3"

    cat <<EOF
#cloud-config

hostname: pritunl-vm-${vmid}
manage_etc_hosts: true
disable_root: false

packages:
  - qemu-guest-agent
  - bind-utils
  - nmap-ncat

ssh_authorized_keys:
  - ${ssh_pubkey}

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - growpart /dev/sda 1 || true
  - xfs_growfs / || true
  - fallocate -l 2G /swapfile
  - chmod 600 /swapfile
  - mkswap /swapfile
  - echo '/swapfile none swap sw 0 0' >> /etc/fstab
  - swapon /swapfile
  - rm -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
  - rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
  - |
    cat > /etc/ssh/sshd_config.d/99-msl.conf <<CFG
    PermitRootLogin yes
    PasswordAuthentication yes
    PubkeyAuthentication yes
    ListenAddress ${PT_IG_IP}
    CFG
  - systemctl daemon-reload
  - systemctl restart sshd
  - ip route add ${PJALL_CIDR} via ${VPNDMZ_GW} dev eth1
  - echo '#!/bin/sh' > /etc/rc.local
  - echo 'ip route add ${PJALL_CIDR} via ${VPNDMZ_GW} dev eth1 ' >> /etc/rc.local
  - chmod +x /etc/rc.local
  - echo 'root:${root_password}' | chpasswd
EOF
}
