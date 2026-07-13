#!/usr/bin/env python3
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2025 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: 0101_configNetwork.sh
# Purpose: CUI-based AUTO/CUSTOM network configuration generator (.env)
#
# Main functions/commands used:
#   - curses: Render TUI interface
#   - subprocess: Call existing bash logic in lib/input_functions.sh and lib/network.sh
#
# Dependencies:
#   - Python 3.6+
#   - lib/input_functions.sh
#   - lib/network.sh
#   - lib/common.sh
#   - lib/env_generator.sh
#
# Usage:
#   ./0101_configNetwork.sh [en|jp]
#
# Notes:
#   - AUTO mode: only NUM_PJ and port ranges are input
#   - CUSTOM mode: executes 0101_checkConfigNetwork.sh
#   - Existing shell scripts are NOT modified
################################################################################

import curses
import json
import os
import re
import shlex
import shutil
import ssl
import subprocess
import sys
import termios
import textwrap
import tty
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from typing import Dict, List, Tuple
from ipaddress import IPv4Network, IPv4Address, ip_address

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = SCRIPT_DIR

# Generate a single timestamp for this entire session (all subprocess.run calls will share it)
MSL_TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")

TIMING_LOG = "/tmp/0101_timing.log"
MSL_LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs", f"msl-setup_{MSL_TIMESTAMP}.log")

def _tlog(msg: str) -> None:
    """Write timing message to log file, flushed immediately."""
    with open(TIMING_LOG, "a") as f:
        f.write(msg + "\n")

def _mlog(level: str, msg: str) -> None:
    """Write a structured log entry to the shared MSL log file.

    Uses the same format as lib/common.sh: [LEVEL] [YYYY-MM-DD HH:MM:SS] message
    """
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{level}] [{timestamp}] {msg}\n"
    try:
        os.makedirs(os.path.dirname(MSL_LOG), exist_ok=True)
        with open(MSL_LOG, "a") as f:
            f.write(line)
    except Exception:
        pass

DEFAULT_NUM_PJ = 8
DEFAULT_OVPN_START = 11856
DEFAULT_WG_START = 15952

# Fallback network defaults used only when bash-derived values are unavailable.
# Keep all editable network default addresses in this single block.
DEFAULT_NETWORK_CIDRS = {
    "VPNDMZ_CIDR": "192.168.80.0/24",
    "VPN_POOL": "192.168.81.0/24",
    "PJALL_CIDR": "172.16.16.0/21",
}

# Default configuration values for Demo environment (overrides DEFAULT_NETWORK_CIDRS when detected by bash logic)
# DEFAULT_NETWORK_CIDRS = {
#     "VPNDMZ_CIDR": "192.168.180.0/24",
#     "VPN_POOL": "192.168.181.0/24",
#     "PJALL_CIDR": "172.31.16.0/21",
# }

LANG_EN = "en"
LANG_JP = "jp"
UUID_FILE_PATH = os.path.join(SCRIPT_DIR, ".uuid")
MSL_SYSTEM_UUID = ""
PROBE_TOKEN_API_URL = "https://msl-setup-probe.zelogx.com/api/v1/get_token"

REQUIRED_CMD_PACKAGE_MAP = {
    "uuidgen": "uuid-runtime",
    "ipcalc": "ipcalc",
    "jq": "jq",
    "zip": "zip",
}

PACKAGE_INSTALL_FAILURE_MESSAGES = {
    LANG_EN: (
        "Failed to install required packages.\n"
        "Please check internet connectivity and repository settings "
        "(for example, no-subscription repository configuration), "
        "or simply rerun this script after a short wait."
    ),
    LANG_JP: (
        "必要パッケージの導入に失敗しました。\n"
        "インターネット接続やリポジトリ設定"
        "（例: no-subscription repository の設定漏れ）を確認してください。"
        "時間をおいて再実行すると解消する場合もあります。"
    ),
}

PACKAGE_INSTALL_PROGRESS_MESSAGES = {
    LANG_EN: "Installing required packages...",
    LANG_JP: "必要パッケージをインストール中...",
}

UUID_SAVE_FAILURE_MESSAGES = {
    LANG_EN: "Failed to save file ({reason})",
    LANG_JP: "ファイルの保存に失敗しました（{reason}）",
}

UUID_GENERATE_FAILURE_MESSAGES = {
    LANG_EN: "Failed to generate system UUID.",
    LANG_JP: "システムUUIDの生成に失敗しました。",
}

MESSAGES = {
    LANG_EN: {
        "title": "Zelogx MSL Setup Network Configuration",
        "mode_label": "Mode:",
        "mode_auto": "AUTO",
        "mode_custom": "CUSTOM",
        "num_pj_label": "Projects:",
        "ovpn_ports_label": "OpenVPN Ports:",
        "wg_ports_label": "WireGuard Ports:",
        "ok_button": "SAVE",
        "status_ready": "Tab: Next  Shift+Tab: Prev  Enter: Edit/Save  Esc: Exit  N: Networks  PgUp/PgDn: Scroll",
        "status_calc": "Calculating network configuration...",
        "status_error": "Error: ",
        "status_env_ok": "Configuration file generated successfully",
        "status_env_fail": "Failed to generate configuration file",
        "status_resize": "Terminal too small. Resize to at least 80x24.",
        "preview_empty": "(Detecting existing networks...)",
        "preview_title": "Configuration Preview",
        "section_mainlan": "MainLAN Configuration",
        "section_pritunl": "Pritunl IP Configuration",
        "section_vpndmz": "VPN DMZ Network",
        "section_projects": "Project Configuration",
        "section_vpn_pool": "VPN Client Pool",
        "section_pj_networks": "Project Networks",
        "section_ports": "Port Forwarding Configuration",
        "section_dns": "DNS Configuration",
        # Display labels for sections (user-friendly names for TUI display)
        "display_section_mainlan": "MainLAN Configuration",
        "display_section_pritunl": "Pritunl IP Configuration",
        "display_section_vpndmz": "VPN DMZ Network",
        "display_section_projects": "Project Configuration",
        "display_section_vpn_pool": "VPN Client Pool",
        "display_section_pj_networks": "Project Networks",
        "display_section_ports": "Port Forwarding Configuration",
        "display_section_dns": "DNS Configuration",
        # CUSTOM mode editable fields
        "custom_pjall_label": "Whole Isolation Network:",
        "custom_dns1_label": "DNS Server 1:",
        "custom_dns2_label": "DNS Server 2:",
        "custom_ing_label": "Ingress IP:",
        "custom_egr_label": "Egress IP:",
        "custom_vpndmz_label": "VPN DMZ CIDR:",
        "custom_vpndmz_gw_label": "VPN DMZ GW:",
        "custom_vpnpool_label": "VPN Pool:",
        # Exit confirmation dialog
        "exit_title": "Exit MSL Setup",
        "exit_msg1": "Are you sure you want to exit",
        "exit_msg2": "without saving?",
        "exit_discard": "[D] Discard",
        "exit_cancel": "[C] Cancel",
        # Configuration file generation confirmation dialog
        "generate_title": "Generate Configuration File",
        "generate_msg1": "Ready to generate configuration file",
        "generate_msg2": "with the current configuration.",
        "generate_msg3": "Continue?",
        "generate_yes": "[Y] Yes",
        "generate_no": "[N] No",
        # Configuration file save result dialogs
        "env_success_title": "Configuration Saved",
        "env_success_msg": "Configuration file saved successfully",
        "env_fail_title": "Save Failed",
        "env_fail_msg": "Failed to save configuration file",
        "env_result_ok": "[O] OK",
        # Existing configuration file load dialog
        "load_env_title": "Existing Configuration File",
        "load_env_msg": "Found an existing configuration file.",
        "load_env_msg2": "Load it?",
        "load_env_yes": "[Y] Yes",
        "load_env_no": "[N] No",
        # SVG generation dialog
        "svg_dialog_title": "Add Network Diagram to Proxmox Notes",
        "svg_dialog_msg": "Do you like to add Network Diagram",
        "svg_dialog_msg2": "to Proxmox Notes?",
        "svg_dialog_yes": "[Y] Yes",
        "svg_dialog_no": "[N] No",
        # SVG result dialogs
        "svg_success_title": "Network Diagram",
        "svg_success_msg": "Network diagram added to Proxmox notes.",
        "svg_fail_title": "Network Diagram",
        "svg_fail_msg": "Failed to add network diagram to Proxmox notes.",
        "notice_ok": "[O] OK",
        "networks_title": "Detected Existing Networks",
        "networks_empty": "No existing networks detected.",
        "networks_hint": "[Up/Down/PgUp/PgDn] Scroll  [Enter/Esc] Close",
        "networks_error": "Failed to detect existing networks",
    },
    LANG_JP: {
        "title": "Zelogx MSL Setup ネットワーク設定",
        "mode_label": "モード:",
        "mode_auto": "AUTO",
        "mode_custom": "CUSTOM",
        "num_pj_label": "プロジェクト数:",
        "ovpn_ports_label": "OpenVPN ポート:",
        "wg_ports_label": "WireGuard ポート:",
        "ok_button": "保存",
        "status_ready": "Tab: 次へ  Shift+Tab: 前へ  Enter: 編集/保存  Esc: 終了  N: Networks  PgUp/PgDn: スクロール",
        "status_calc": "ネットワーク設定を計算中...",
        "status_error": "エラー: ",
        "status_env_ok": "設定ファイルの生成に成功しました",
        "status_env_fail": "設定ファイルの生成に失敗しました",
        "status_resize": "端末サイズが小さすぎます。80x24以上にしてください。",
        "preview_empty": "(既存ネットワークの検出中です...)",
        "preview_title": "設定プレビュー",
        "section_mainlan": "MainLAN 設定",
        "section_pritunl": "Pritunl IP 設定",
        "section_vpndmz": "VPN DMZ ネットワーク",
        "section_projects": "プロジェクト設定",
        "section_vpn_pool": "VPN クライアントプール",
        "section_pj_networks": "プロジェクトネットワーク",
        "section_ports": "ポートフォワーディング設定",
        "section_dns": "DNS 設定",
        # Display labels for sections (user-friendly names for TUI display)
        "display_section_mainlan": "MainLAN 設定",
        "display_section_pritunl": "Pritunl IP 設定",
        "display_section_vpndmz": "VPN DMZ ネットワーク",
        "display_section_projects": "プロジェクト設定",
        "display_section_vpn_pool": "VPN クライアントプール",
        "display_section_pj_networks": "プロジェクトネットワーク",
        "display_section_ports": "ポートフォワーディング設定",
        "display_section_dns": "DNS 設定",
        # CUSTOM mode editable fields
        "custom_pjall_label": "隔離ネットワーク全体:",
        "custom_dns1_label": "DNS サーバ 1:",
        "custom_dns2_label": "DNS サーバ 2:",
        "custom_ing_label": "Ingress IP:",
        "custom_egr_label": "Egress IP:",
        "custom_vpndmz_label": "VPN DMZ CIDR:",
        "custom_vpndmz_gw_label": "VPN DMZ GW:",
        "custom_vpnpool_label": "VPN Pool:",
        # Exit confirmation dialog
        "exit_title": "MSL セットアップを終了",
        "exit_msg1": "変更を保存せずに終了しますか？",
        "exit_msg2": "",
        "exit_discard": "[D] 破棄",
        "exit_cancel": "[C] キャンセル",
        # 設定ファイル生成確認ダイアログ
        "generate_title": "設定ファイルを生成",
        "generate_msg1": "設定ファイルを生成する準備が",
        "generate_msg2": "できました。続行しますか？",
        "generate_msg3": "",
        "generate_yes": "[Y] はい",
        "generate_no": "[N] いいえ",
        # 設定ファイル保存結果ダイアログ
        "env_success_title": "設定ファイル保存成功",
        "env_success_msg": "設定ファイルを保存しました",
        "env_fail_title": "保存失敗",
        "env_fail_msg": "設定ファイルの保存に失敗しました",
        "env_result_ok": "[O] OK",
        # 既存設定ファイル読み込みダイアログ
        "load_env_title": "既存設定ファイル",
        "load_env_msg": "既存の設定ファイルが見つかりました。",
        "load_env_msg2": "読み込みますか？",
        "load_env_yes": "[Y] はい",
        "load_env_no": "[N] いいえ",
        # SVG generation dialog
        "svg_dialog_title": "Proxmox ノートにネットワーク図を追加",
        "svg_dialog_msg": "Proxmox ノートにネットワーク図を",
        "svg_dialog_msg2": "追加しますか？",
        "svg_dialog_yes": "[Y] はい",
        "svg_dialog_no": "[N] いいえ",
        # SVG result dialogs
        "svg_success_title": "ネットワーク図",
        "svg_success_msg": "ネットワーク図をProxmoxノートに追加しました。",
        "svg_fail_title": "ネットワーク図",
        "svg_fail_msg": "ネットワーク図の追加に失敗しました。",
        "notice_ok": "[O] OK",
        "networks_title": "検出済み既設ネットワーク",
        "networks_empty": "既設ネットワークは検出されませんでした。",
        "networks_hint": "[Up/Down/PgUp/PgDn] スクロール  [Enter/Esc] 閉じる",
        "networks_error": "既設ネットワークの検出に失敗しました",
    },
}

CEPH_NOTICE = {
    LANG_JP: """警告: Cephストレージを検出しました
MSL Setup は Proxmox Firewall を有効化します。
**Proxmox のストレージとして Ceph を利用している場合、**既存の通信要件によっては、MSL Setup 実行後にストレージへアクセスできなくなる可能性があります。
そのような環境では、MSL Setup 実行前に、必要な通信を許可する Datacenter レベルの Firewall ルールを事前に追加しておくことをお勧めします。

以下は一般的な Ceph 構成における参考例です。
実際に必要な設定は環境ごとに異なるため、詳細はご利用中の構成に合わせて調整してください。

IPSetのサンプル:
Datacenter -> Firewall -> IPSET -> Create
Name: ceph_peers
Datacenter -> Firewall -> IPSET -> ceph_peers -> IP/CIDR Add
192.168.77.60/32  <-- cephノードのIPアドレスを設定
192.168.77.61/32  <-- cephノードのIPアドレスを設定
192.168.77.62/32  <-- cephノードのIPアドレスを設定

FWルールのサンプル:
Datacenter -> Firewall -> Add
Enabled  Type  Action  Protocol  Source      Destination  D.Port     Comment
-------  ----  ------  --------  ----------  -----------  ---------  -------------
Yes      in    ACCEPT  tcp       ceph_peers  ceph_peers   6800:7300  Ceph OSD
Yes      in    ACCEPT  tcp       ceph_peers  ceph_peers   6789       Ceph Monitor1
Yes      in    ACCEPT  tcp       ceph_peers  ceph_peers   3300       Ceph Monitor2

Press any key to continue.""",
    LANG_EN: """Important Notice: Ceph storage was detected.
MSL Setup enables the Proxmox Firewall.
If your Proxmox environment uses Ceph as Proxmox storage, storage access may become unavailable after running MSL Setup, depending on the existing communication requirements.
In such environments, we recommend adding Datacenter-level firewall rules in advance to allow the required storage communication before running MSL Setup.

The following is a reference example for a typical Ceph configuration.
Actual requirements may vary depending on your environment, so please adjust the settings to match your existing configuration.

Example IPSet:
Datacenter -> Firewall -> IPSET -> Create
Name: ceph_peers
Datacenter -> Firewall -> IPSET -> ceph_peers -> IP/CIDR Add
192.168.77.60/32  <-- Replace with your Ceph node IP address
192.168.77.61/32  <-- Replace with your Ceph node IP address
192.168.77.62/32  <-- Replace with your Ceph node IP address

Example Rules:
Datacenter -> Firewall -> Add
Enabled  Type  Action  Protocol  Source      Destination  D.Port     Comment
-------  ----  ------  --------  ----------  -----------  ---------  -------------
Yes      in    ACCEPT  tcp       ceph_peers  ceph_peers   6800:7300  Ceph OSD
Yes      in    ACCEPT  tcp       ceph_peers  ceph_peers   6789       Ceph Monitor1
Yes      in    ACCEPT  tcp       ceph_peers  ceph_peers   3300       Ceph Monitor2

Press any key to continue.""",
}


def _wait_for_any_key() -> None:
    """Wait for a single keypress without requiring Enter."""
    if not sys.stdin.isatty():
        return

    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    print("", flush=True)


def _check_ceph_installed() -> bool:
    """Return True when `pveceph status` exits successfully."""
    try:
        result = subprocess.run(
            ["pveceph", "status"],
            cwd=SCRIPT_DIR,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        )
        return result.returncode == 0
    except Exception:
        return False


def _show_ceph_notice(lang: str) -> None:
    notice = CEPH_NOTICE.get(lang, CEPH_NOTICE[LANG_EN])
    print(notice, flush=True)
    _wait_for_any_key()


class BashRunner:
    """Run existing bash logic without modifying shell scripts."""

    def __init__(self, lang: str) -> None:
        self.lang = lang
        self._base_config: Dict[str, str] = {}  # cached from first bash run
        self._existing_networks: List[str] = []

    def _run_bash(self, script: str) -> Tuple[int, str, str]:
        env = os.environ.copy()
        env["MSL_LANG"] = self.lang
        env["MSL_TIMESTAMP"] = MSL_TIMESTAMP  # Pass unified timestamp to subprocess
        result = subprocess.run(
            ["bash", "-c", script],
            cwd=SCRIPT_DIR,
            env=env,
            capture_output=True,
            text=True,
        )
        return result.returncode, result.stdout, result.stderr

    def _calculate_subnet_py(self, parent_cidr: str, num_pj: int) -> Dict[str, str]:
        """Calculate subnets using Python ipaddress module (fast, no ipcalc)."""
        result: Dict[str, str] = {}
        try:
            parent_net = IPv4Network(parent_cidr, strict=False)
            # Calculate bits needed for num_pj subnets (power of 2)
            subnet_bits = (num_pj - 1).bit_length()
            new_prefix = parent_net.prefixlen + subnet_bits
            if new_prefix > 30:
                raise ValueError(f"Cannot split {parent_cidr} into {num_pj} subnets")

            subnets = list(parent_net.subnets(new_prefix=new_prefix))[:num_pj]
            for i, subnet in enumerate(subnets, 1):
                pj_id = f"{i:02d}"
                result[f"PJ{pj_id}_CIDR"] = str(subnet)
                # Gateway = last usable IP (or second-to-last if /31, or broadcast if /32)
                if subnet.prefixlen >= 31:
                    gw = subnet.broadcast_address
                else:
                    gw = subnet.broadcast_address
                result[f"PJ{pj_id}_GW"] = str(gw)
        except Exception as e:
            raise RuntimeError(f"Python subnet calculation failed: {e}")
        return result

    def _split_pool_py(self, pool_cidr: str, num_pj: int) -> Dict[str, str]:
        """Split VPN client pool into OpenVPN and WireGuard pools (fast, no ipcalc)."""
        result: Dict[str, str] = {}
        try:
            pool_net = IPv4Network(pool_cidr, strict=False)
            # Split into two halves: OpenVPN (/25) and WireGuard (/25)
            ovpn_net, wg_net = list(pool_net.subnets(new_prefix=pool_net.prefixlen + 1))

            result["VPN_POOL"] = pool_cidr
            result["OVPN_POOL"] = str(ovpn_net)
            result["WG_POOL"] = str(wg_net)

            # Further split each half into NUM_PJ subnets (/28 for /25)
            ovpn_subnets = list(ovpn_net.subnets(new_prefix=ovpn_net.prefixlen + (num_pj - 1).bit_length()))[:num_pj]
            wg_subnets = list(wg_net.subnets(new_prefix=wg_net.prefixlen + (num_pj - 1).bit_length()))[:num_pj]

            for i, subnet in enumerate(ovpn_subnets, 1):
                result[f"OVPN_POOL{i}"] = str(subnet)
            for i, subnet in enumerate(wg_subnets, 1):
                result[f"WG_POOL{i}"] = str(subnet)
        except Exception as e:
            raise RuntimeError(f"Python pool split calculation failed: {e}")
        return result

    def _run_base_config(self) -> Dict[str, str]:
        """Run bash once to get MainLAN/PVE/DMZ/Pritunl/DNS config (slow, cached)."""
        import time
        t0 = time.time()
        _tlog(f"[TIMING] _run_base_config START")
        script = f"""
    set -euo pipefail
    SCRIPT_DIR="{SCRIPT_DIR}"
    source "{SCRIPT_DIR}/lib/common.sh"
    source "{SCRIPT_DIR}/lib/network.sh"
source "{SCRIPT_DIR}/lib/input_functions.sh"
if [[ "${{MSL_LANG:-en}}" == "jp" ]]; then
  source "{SCRIPT_DIR}/lib/messages_jp.sh"
else
  source "{SCRIPT_DIR}/lib/messages_en.sh"
fi

# Cache existing networks once for this run
mapfile -t DETECTED_EXISTING_NETWORKS < <(detect_existing_networks || true)
detect_existing_networks() {{
    printf "%s\n" "${{DETECTED_EXISTING_NETWORKS[@]}}"
}}

declare -A CONFIG
CONFIG[NUM_PJ]="8"

# Override slow functions with no-ops for base config collection
input_port_ranges() {{ :; }}

# Override interactive PT_IG_IP prompt to avoid confirmation loops in non-interactive mode.
# This prefill path is only used to collect initial defaults for the TUI.
input_pritunl_mainlan_ip() {{
    local ml_network="${{CONFIG[ML_CIDR]%/*}}"
    local base_ip="${{ml_network%.*}}"
    local candidate="${{base_ip}}.9"

    if is_ip_reachable "$candidate"; then
        local octet
        for octet in {{10..253}}; do
            local next_candidate="${{base_ip}}.${{octet}}"
            if ! is_ip_reachable "$next_candidate"; then
                candidate="$next_candidate"
                break
            fi
        done
    fi

    CONFIG[PT_IG_IP]="$candidate"
}}

exec 3<&0
exec 0< <(yes "")
{{
    input_mainlan
    input_pve_ip
    input_vpndmz_network
    input_vpn_pool
    input_pjall_network
    input_pritunl_mainlan_ip
    input_pritunl_vpndmz_ip
    input_port_ranges
    input_dns_servers
}} >/dev/null 2>&1
exec 0<&3
exec 3<&-

printf "__OUTPUT__\n"
for key in "${{!CONFIG[@]}}"; do
  printf "%s=%s\n" "$key" "${{CONFIG[$key]}}"
done
"""
        code, out, err = self._run_bash(script)
        _tlog(f"[TIMING] _run_base_config END: {(time.time()-t0)*1000:.1f}ms")
        if code != 0:
            raise RuntimeError(err.strip() or "bash base config failed")
        lines = out.splitlines()
        try:
            start = lines.index("__OUTPUT__") + 1
        except ValueError:
            raise RuntimeError("Missing output marker from bash base config")
        config: Dict[str, str] = {}
        for line in lines[start:]:
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            config[key.strip()] = value.strip()
        return config

    def get_existing_networks(self) -> List[str]:
        """Get existing networks from lib/network.sh (cached)."""
        if self._existing_networks:
            return list(self._existing_networks)

        script = f"""
    set -euo pipefail
    SCRIPT_DIR=\"{SCRIPT_DIR}\"
    source \"{SCRIPT_DIR}/lib/common.sh\"
    source \"{SCRIPT_DIR}/lib/network.sh\"
    printf "__OUTPUT__\\n"
    detect_existing_networks || true
"""
        bash_networks: List[str] = []
        code, out, err = self._run_bash(script)
        if code != 0:
            _mlog("WARN", f"detect_existing_networks (bash) failed: {err.strip() or 'unknown error'}")
        else:
            lines = out.splitlines()
            try:
                start = lines.index("__OUTPUT__") + 1
                for line in lines[start:]:
                    cidr = line.strip()
                    if cidr and self._is_valid_cidr(cidr):
                        bash_networks.append(str(IPv4Network(cidr, strict=False)))
            except ValueError:
                _mlog("WARN", "detect_existing_networks (bash) output marker not found")

        if bash_networks:
            _mlog("INFO", f"detect_existing_networks (bash) valid entries: {len(bash_networks)}")
        else:
            _mlog("INFO", "detect_existing_networks (bash) returned no valid CIDRs")

        # Python runtime detection is the primary source because it is more reliable
        # in this TUI context; bash results are merged as supplemental hints.
        py_networks = self._collect_existing_networks_fallback()

        merged: List[IPv4Network] = []
        seen = set()
        for cidr in py_networks + bash_networks:
            try:
                net = IPv4Network(cidr, strict=False)
                key = str(net)
                if key not in seen:
                    merged.append(net)
                    seen.add(key)
            except Exception:
                continue

        merged.sort(key=lambda n: (int(n.network_address), n.prefixlen))
        networks = [str(n) for n in merged]

        self._existing_networks = networks
        _mlog(
            "INFO",
            f"Existing networks detected ({len(networks)}): {', '.join(networks) if networks else '(none)'}",
        )
        return list(self._existing_networks)

    def _collect_existing_networks_fallback(self) -> List[str]:
        """Collect existing networks from OS/Proxmox runtime sources as fallback."""
        discovered: List[str] = []

        def add_cidr(cidr: str) -> None:
            cidr = (cidr or "").strip()
            if not cidr:
                return
            try:
                net = IPv4Network(cidr, strict=False)
                if net.prefixlen == 0:
                    return
                if net.network_address.is_loopback:
                    return
                discovered.append(str(net))
            except Exception:
                return

        # 1) Kernel routes
        try:
            res = subprocess.run(
                ["ip", "-o", "-4", "route", "show"],
                capture_output=True,
                text=True,
                check=False,
            )
            if res.returncode == 0:
                for line in res.stdout.splitlines():
                    parts = line.split()
                    if not parts:
                        continue
                    dst = parts[0]
                    if dst in ("default", "0.0.0.0/0"):
                        continue
                    if re.match(r"^\d+\.\d+\.\d+\.\d+/\d+$", dst):
                        add_cidr(dst)
        except Exception:
            pass

        # 2) Interface addresses
        try:
            res = subprocess.run(
                ["ip", "-o", "-4", "addr", "show", "scope", "global"],
                capture_output=True,
                text=True,
                check=False,
            )
            if res.returncode == 0:
                for line in res.stdout.splitlines():
                    m = re.search(r"\binet\s+(\d+\.\d+\.\d+\.\d+/\d+)\b", line)
                    if m:
                        add_cidr(m.group(1))
        except Exception:
            pass

        # 3) Static config files (CIDR literals)
        for cfg_path in ("/etc/network/interfaces", "/etc/pve/sdn/subnets.cfg", "/etc/pve/sdn/vnets.cfg"):
            try:
                if os.path.isfile(cfg_path):
                    with open(cfg_path, "r", encoding="utf-8", errors="ignore") as f:
                        text = f.read()
                    for m in re.findall(r"\b\d+\.\d+\.\d+\.\d+/\d+\b", text):
                        add_cidr(m)
            except Exception:
                pass

        # 4) Proxmox SDN subnets
        try:
            res = subprocess.run(
                ["pvesh", "get", "/cluster/sdn/subnets", "--output-format", "json"],
                capture_output=True,
                text=True,
                check=False,
            )
            if res.returncode == 0 and res.stdout.strip():
                data = json.loads(res.stdout)
                if isinstance(data, list):
                    for item in data:
                        if isinstance(item, dict):
                            add_cidr(str(item.get("subnet", "")))
        except Exception:
            pass

        # Normalize, deduplicate, and drop child subnets included by larger networks.
        unique_nets: List[IPv4Network] = []
        seen = set()
        for cidr in discovered:
            try:
                net = IPv4Network(cidr, strict=False)
                if str(net) not in seen:
                    unique_nets.append(net)
                    seen.add(str(net))
            except Exception:
                continue

        reduced: List[IPv4Network] = []
        for net in unique_nets:
            if any(net != other and net.subnet_of(other) for other in unique_nets):
                continue
            reduced.append(net)

        reduced.sort(key=lambda n: (int(n.network_address), n.prefixlen))
        result_cidrs = [str(n) for n in reduced]
        _mlog("INFO", f"Python fallback found {len(result_cidrs)} existing network(s): {', '.join(result_cidrs) if result_cidrs else '(none)'}")
        return result_cidrs

    def _is_valid_cidr(self, cidr: str) -> bool:
        """Return True if cidr can be parsed as IPv4 CIDR."""
        try:
            IPv4Network((cidr or "").strip(), strict=False)
            return True
        except Exception:
            return False

    def _cidr_overlaps(self, cidr1: str, cidr2: str) -> bool:
        """Return True when two CIDRs overlap."""
        try:
            net1 = IPv4Network(cidr1.strip(), strict=False)
            net2 = IPv4Network(cidr2.strip(), strict=False)
            return net1.overlaps(net2)
        except Exception:
            return False

    def _pick_parent_cidrs(self, num_pj: int) -> Dict[str, str]:
        """Pick parent CIDRs, preferring DEFAULT_NETWORK_CIDRS when safe.

        Selection policy:
        1) Prefer values in DEFAULT_NETWORK_CIDRS.
        2) If preferred value conflicts with existing networks or already selected
           parent CIDRs, fall back to bash-derived value from self._base_config.
        """
        result: Dict[str, str] = {}
        existing = self.get_existing_networks()
        _mlog("INFO", f"_pick_parent_cidrs: evaluating DEFAULT_NETWORK_CIDRS against {len(existing)} existing network(s)")

        keys = ("VPNDMZ_CIDR", "VPN_POOL", "PJALL_CIDR")
        for key in keys:
            preferred = (DEFAULT_NETWORK_CIDRS.get(key, "") or "").strip()
            fallback = (self._base_config.get(key, "") or "").strip()

            chosen = fallback
            preferred_has_conflict = False
            if self._is_valid_cidr(preferred):
                conflict = False
                conflict_with = ""
                for existing_cidr in existing:
                    if self._is_valid_cidr(existing_cidr) and self._cidr_overlaps(preferred, existing_cidr):
                        conflict = True
                        conflict_with = existing_cidr
                        break
                if not conflict:
                    for selected_key, selected_cidr in result.items():
                        if self._is_valid_cidr(selected_cidr) and self._cidr_overlaps(preferred, selected_cidr):
                            conflict = True
                            conflict_with = f"{selected_key}={selected_cidr} (already selected)"
                            break
                if not conflict:
                    chosen = preferred
                    _mlog("INFO", f"  {key}: DEFAULT {preferred} -> no conflict, adopted")
                else:
                    preferred_has_conflict = True
                    _mlog("WARN", f"  {key}: DEFAULT {preferred} conflicts with {conflict_with}; falling back to bash value '{fallback}'")
            else:
                if preferred:
                    _mlog("WARN", f"  {key}: DEFAULT value '{preferred}' is not a valid CIDR; skipping")

            # Only use preferred as last resort when it has NO conflict.
            # If preferred conflicts with existing networks, keep chosen=fallback (even if empty).
            if not chosen and not preferred_has_conflict:
                chosen = preferred if preferred else fallback

            result[key] = chosen
            _mlog("INFO", f"  {key}: final choice = '{chosen}'")

        return result

    def compute_config(self, num_pj: int, ovpn_start: int, wg_start: int) -> Dict[str, str]:
        """Compute full configuration: bash once (cached) + Python for subnets/pools."""
        import time
        start_time = time.time()
        _tlog(f"\n[TIMING] compute_config START NUM_PJ={num_pj}")

        # Run bash only on first call; reuse cache on subsequent calls
        if not self._base_config:
            self._base_config = self._run_base_config()
        
        # Fast Python calculations for subnet/pool (no bash, no ipcalc)
        t0 = time.time()
        pj_networks: Dict[str, str] = {}
        pool_splits: Dict[str, str] = {}
        # Prefer DEFAULT_NETWORK_CIDRS when they are safe to use;
        # otherwise, fall back to bash-derived proposals.
        selected_parents = self._pick_parent_cidrs(num_pj)
        vpndmz = selected_parents.get("VPNDMZ_CIDR", "")
        pjall = selected_parents.get("PJALL_CIDR", "")
        vpn_pool = selected_parents.get("VPN_POOL", "")
        try:
            pj_networks = self._calculate_subnet_py(pjall, num_pj)
            pool_splits = self._split_pool_py(vpn_pool, num_pj)
        except Exception:
            pass
        _tlog(f"[TIMING] Python calc: {(time.time()-t0)*1000:.1f}ms")

        # Merge: base config + Python-calculated values + port ranges
        config = dict(self._base_config)
        config.update(pj_networks)
        config.update(pool_splits)
        # Restore parent CIDRs from resolved/fallback values.
        config["VPNDMZ_CIDR"] = vpndmz
        config["PJALL_CIDR"] = pjall
        config["VPN_POOL"] = vpn_pool
        config["NUM_PJ"] = str(num_pj)
        config["PF_ST_OV"] = str(ovpn_start)
        config["PF_ED_OV"] = str(ovpn_start + num_pj - 1)
        config["PF_ST_WG"] = str(wg_start)
        config["PF_ED_WG"] = str(wg_start + num_pj - 1)

        _tlog(f"[TIMING] compute_config TOTAL: {(time.time()-start_time)*1000:.1f}ms")
        return config

    def generate_env(self, config: Dict[str, str]) -> None:
        """Generate .env file using lib/env_generator.sh."""
        config_lines = []
        for key, value in sorted(config.items()):
            qval = shlex.quote(value)
            config_lines.append(f"CONFIG[{shlex.quote(key)}]={qval}")

        pool_lines = []
        for key, value in sorted(config.items()):
            if key.startswith("OVPN_POOL") or key.startswith("WG_POOL"):
                pool_lines.append(f"{key}={shlex.quote(value)}")

        script = f"""
    set -euo pipefail
    SCRIPT_DIR="{SCRIPT_DIR}"
    source "{SCRIPT_DIR}/lib/common.sh"
    source "{SCRIPT_DIR}/lib/network.sh"
source "{SCRIPT_DIR}/lib/env_generator.sh"

declare -A CONFIG
{os.linesep.join(config_lines)}
{os.linesep.join(pool_lines)}

if [[ -f "${{PROJECT_ROOT}}/.env" ]]; then
  backup_file "${{PROJECT_ROOT}}/.env"
fi

generate_env
"""
        code, out, err = self._run_bash(script)
        if code != 0:
            raise RuntimeError(err.strip() or "generate_env failed")

    def generate_svg(self) -> None:
        """Generate SVG network diagram and update Proxmox notes (pure Python implementation)."""
        import re
        import shutil
        import socket
        
        # Paths
        env_file = os.path.join(SCRIPT_DIR, ".env")
        output_dir = os.path.join(SCRIPT_DIR, "docs", "generated")
        output_file = os.path.join(output_dir, "network-diagram.svg")
        
        # Read .env file
        if not os.path.isfile(env_file):
            raise RuntimeError(f".env file not found: {env_file}")
        
        env_vars = {}
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    key, value = line.split("=", 1)
                    # Remove quotes
                    value = value.strip('"').strip("'")
                    env_vars[key.strip()] = value
        
        # Get NUM_PJ to select template
        num_pj = env_vars.get("NUM_PJ", "8")
        template_file = os.path.join(SCRIPT_DIR, "docs", "assets", f"zelogx-MSL-Setup-template-{num_pj}.svg")
        
        if not os.path.isfile(template_file):
            raise RuntimeError(f"SVG template not found: {template_file} (NUM_PJ={num_pj})")
        
        # Read template
        with open(template_file, "r", encoding="utf-8") as f:
            svg_content = f.read()
        
        # Replace all placeholders ${VAR} with values from .env
        for key, value in env_vars.items():
            placeholder = f"${{{key}}}"
            svg_content = svg_content.replace(placeholder, value)
        
        # Create output directory
        os.makedirs(output_dir, exist_ok=True)
        
        # Write SVG file
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(svg_content)
        
        # Copy SVG to Proxmox web directory
        svg_web_name = "msl-setup-network-diagram.svg"
        svg_web_path = f"/usr/share/pve-manager/images/{svg_web_name}"
        
        try:
            shutil.copy2(output_file, svg_web_path)
            os.chmod(svg_web_path, 0o644)
        except Exception as e:
            raise RuntimeError(f"Failed to copy SVG to {svg_web_path}: {e}")
        
        # Update Proxmox notes
        node_name = socket.gethostname()
        
        # Get current notes via pvesh
        result = subprocess.run(
            ["pvesh", "get", f"/nodes/{node_name}/config", "--output-format", "json"],
            capture_output=True,
            text=True
        )
        
        existing_notes = ""
        if result.returncode == 0:
            try:
                import json
                data = json.loads(result.stdout)
                existing_notes = data.get("description", "").rstrip()
            except:
                pass
        
        # Create new notes content
        new_content = f"""
---
MSL Setup - Network Diagram

<img src="/pve2/images/{svg_web_name}">"""
        
        # Remove existing MSL Setup diagram block if present
        if "msl-setup-network-diagram.svg" in existing_notes or "MSL Setup - Network Diagram" in existing_notes:
            # Remove from marker to end
            lines = existing_notes.split("\n")
            new_lines = []
            skip = False
            for line in lines:
                if "MSL Setup - Network Diagram" in line:
                    skip = True
                if not skip:
                    new_lines.append(line)
            # Remove trailing separator if present
            while new_lines and new_lines[-1].strip() == "---":
                new_lines.pop()
            existing_notes = "\n".join(new_lines)
        
        full_notes = existing_notes + new_content
        
        # Update notes via pvesh
        result = subprocess.run(
            ["pvesh", "set", f"/nodes/{node_name}/config", "--description", full_notes],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            raise RuntimeError(f"Failed to update Proxmox notes: {result.stderr}")



class TUIApp:
    """Curses-based TUI for AUTO/CUSTOM configuration."""

    def __init__(self, stdscr: "curses._CursesWindow", lang: str) -> None:
        self.stdscr = stdscr
        self.lang = lang
        self.msg = MESSAGES[lang]
        self.runner = BashRunner(lang)

        self.mode = "AUTO"
        self.num_pj = DEFAULT_NUM_PJ
        self.ovpn_start = DEFAULT_OVPN_START
        self.wg_start = DEFAULT_WG_START

        self.focus_index = 0
        self.edit_field = None
        self.edit_buffer = ""
        self.edit_cursor = 0
        self.edit_insert_mode = True

        self.config: Dict[str, str] = {}
        self.last_good_config: Dict[str, str] = {}
        self.status = self.msg["status_calc"]
        self.preview_scroll = 0
        self.dialog_error = ""  # Error message for input dialog
        self.status_warning = ""  # Warning message (e.g., port auto-adjust)

        # CUSTOM mode editable fields (key, label_msg_key, section_msg_key)
        self.custom_fields = [
            ("PJALL_CIDR", "custom_pjall_label", "section_pj_networks"),
            ("DNS_IP1", "custom_dns1_label", "section_dns"),
            ("DNS_IP2", "custom_dns2_label", "section_dns"),
            ("VPNDMZ_CIDR", "custom_vpndmz_label", "section_vpndmz"),
            ("VPNDMZ_GW", "custom_vpndmz_gw_label", "section_vpndmz"),
            ("PT_IG_IP", "custom_ing_label", "section_pritunl"),
            ("PT_EG_IP", "custom_egr_label", "section_pritunl"),
            ("VPN_POOL", "custom_vpnpool_label", "section_vpn_pool"),
        ]

        self._init_curses()
        self._recalculate_config()

    def _init_curses(self) -> None:
        curses.curs_set(0)
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_WHITE, curses.COLOR_BLUE)
        curses.init_pair(2, curses.COLOR_WHITE, -1)
        curses.init_pair(3, curses.COLOR_BLACK, curses.COLOR_YELLOW)  # Yellow bg for warnings
        curses.init_pair(4, curses.COLOR_WHITE, -1)
        curses.init_pair(5, curses.COLOR_WHITE, curses.COLOR_RED)  # Red bg for errors

    def _get_max_focus(self) -> int:
        """Return max focus_index based on current mode."""
        if self.mode == "CUSTOM":
            # focus_index: 0=mode, 1=NUM_PJ, 2=OVPN, 3=WG, 4-11=custom_fields, 12=SAVE
            return 13  # 0-12: total 13 items
        else:
            # focus_index: 0=mode, 1=NUM_PJ, 2=OVPN, 3=WG, 4=SAVE
            return 5  # Mode, NUM_PJ, OVPN_Ports, WG_Ports, SAVE button in AUTO mode

    def _recalculate_config(self) -> None:
        self.status = self.msg["status_calc"]
        self._render()
        try:
            # Save CUSTOM mode field values before recalculating
            saved_custom_fields = {}
            if self.mode == "CUSTOM":
                for field_key, _, _ in self.custom_fields:
                    if field_key in self.config:
                        saved_custom_fields[field_key] = self.config[field_key]
            
            new_config = self.runner.compute_config(self.num_pj, self.ovpn_start, self.wg_start)
            self.config = new_config
            self.last_good_config = dict(new_config)
            
            # In CUSTOM mode, restore custom fields and recalculate auto-fields
            if saved_custom_fields:
                # Restore CUSTOM field values (e.g., VPN_POOL = 192.168.181.0/24)
                self.config.update(saved_custom_fields)
            
            # Recalculate all auto-fields based on custom fields (especially VPN_POOL)
            self._apply_port_ranges()
            self.status = self.msg["status_ready"]
            self.preview_scroll = 0
        except Exception as exc:
            if self.last_good_config:
                self.config = dict(self.last_good_config)
            self.status = f"{self.msg['status_error']}{exc}"
        self._render()

    def _get_display_width(self, text: str) -> int:
        """Calculate display width of text, considering Japanese takes 2 cells."""
        width = 0
        for char in text:
            if ord(char) > 127:  # Non-ASCII (Japanese, etc.)
                width += 2
            else:
                width += 1
        return width

    def _extract_last_octet(self, ip_or_cidr: str) -> str:
        """Extract last octet from IP address (e.g., 192.168.1.5 -> .5)."""
        try:
            ip_part = ip_or_cidr.split('/')[0]
            return '.' + ip_part.split('.')[-1]
        except (IndexError, ValueError):
            return ""

    def _looks_like_auto_calculated(self, current_ip: str, expected_auto_ip: str) -> bool:
        """Check if current IP appears to be auto-calculated (not user-edited).
        
        Heuristic: If last octet is 1 or 2, it's likely auto-generated from network+1 or network+2.
        Returns True if should be updated, False if user likely set it manually.
        """
        try:
            last_octet = int(current_ip.split('.')[-1])
            # Only auto-update if last octet is 1 or 2 (typical for .+1 and .+2)
            return last_octet in (1, 2)
        except (ValueError, IndexError):
            return False

    def _calculate_project_cidrs(self, pjall_cidr: str, num_pj: int) -> Dict[str, str]:
        """Calculate PJ01_CIDR through PJxx_CIDR from PJALL_CIDR.
        
        Example:
            PJALL_CIDR = 172.16.16.0/20, NUM_PJ = 8
            → /20 + 3 bits (for 8 subnets) = /23
            → PJ01_CIDR = 172.16.16.0/23, PJ02_CIDR = 172.16.18.0/23, ...
        """
        result = {}
        try:
            import math
            pjall_net = IPv4Network(pjall_cidr, strict=False)
            pjall_prefix = int(pjall_cidr.split('/')[1])
            
            # Calculate bits needed for num_pj subnets
            # e.g., num_pj=8 → 3 bits, num_pj=16 → 4 bits
            bits_needed = math.ceil(math.log2(max(num_pj, 1)))
            target_prefix = pjall_prefix + bits_needed
            
            # Generate subnets
            subnets = list(pjall_net.subnets(new_prefix=target_prefix))
            
            # Assign to PJ01 through PJxx
            for i in range(min(num_pj, len(subnets))):
                pj_num = f"{i+1:02d}"
                result[f"PJ{pj_num}_CIDR"] = str(subnets[i])
                # Gateway is .254 in each subnet (unless subnet is /31 or /32)
                try:
                    gw_ip = str(subnets[i].network_address + subnets[i].num_addresses - 2)
                    result[f"PJ{pj_num}_GW"] = gw_ip
                    result[f"PJ{pj_num}_GW_LO"] = self._extract_last_octet(gw_ip)
                except:
                    # For very small subnets, use network address + 1
                    gw_ip = str(subnets[i].network_address + 1)
                    result[f"PJ{pj_num}_GW"] = gw_ip
                    result[f"PJ{pj_num}_GW_LO"] = self._extract_last_octet(gw_ip)
        except (ValueError, IndexError, AttributeError):
            pass
        
        return result

    def _calculate_vpn_pools(self, vpn_pool: str, num_pj: int) -> Dict[str, str]:
        """Calculate OpenVPN and WireGuard pools split by NUM_PJ.
        
        Example:
            VPN_POOL = 192.168.81.0/24, NUM_PJ = 8
            → OVPN_POOL = 192.168.81.0/25 (128 clients)
            → WG_POOL = 192.168.81.128/25 (128 clients)
            → OVPN_POOL1~8 = .0/28, .16/28, ... (14 clients each)
            → WG_POOL1~8 = .128/28, .144/28, ... (14 clients each)
        """
        result = {}
        try:
            vpn_net = IPv4Network(vpn_pool, strict=False)
            
            # Split VPN_POOL into OpenVPN and WireGuard (half each)
            # Always split by incrementing prefix by 1, regardless of current prefix
            next_prefix = vpn_net.prefixlen + 1
            halves = list(vpn_net.subnets(new_prefix=next_prefix))
            if len(halves) >= 2:
                ovpn_pool = halves[0]
                wg_pool = halves[1]
                
                result["OVPN_POOL"] = str(ovpn_pool)
                result["WG_POOL"] = str(wg_pool)
                
                # Further split each half into NUM_PJ pools.
                # bits_needed: 2->1, 4->2, 8->3, 16->4
                bits_needed = (max(num_pj, 1) - 1).bit_length()
                pj_prefix = ovpn_pool.prefixlen + bits_needed
                if pj_prefix > 30:
                    return result
                ovpn_subnets = list(ovpn_pool.subnets(new_prefix=pj_prefix))[:num_pj]
                wg_subnets = list(wg_pool.subnets(new_prefix=pj_prefix))[:num_pj]
                
                for i in range(num_pj):
                    pool_num = i + 1
                    if i < len(ovpn_subnets):
                        result[f"OVPN_POOL{pool_num}"] = str(ovpn_subnets[i])
                    if i < len(wg_subnets):
                        result[f"WG_POOL{pool_num}"] = str(wg_subnets[i])
        except (ValueError, IndexError, AttributeError):
            pass
        
        return result

    def _apply_port_ranges(self) -> None:
        """Apply port ranges and calculate derived fields."""
        self.config["NUM_PJ"] = str(self.num_pj)
        self.config["PF_ST_OV"] = str(self.ovpn_start)
        self.config["PF_ED_OV"] = str(self.ovpn_start + self.num_pj - 1)
        self.config["PF_ST_WG"] = str(self.wg_start)
        self.config["PF_ED_WG"] = str(self.wg_start + self.num_pj - 1)
        
        # Calculate derived fields from custom inputs
        # Last octets
        if "ML_CIDR" in self.config:
            self.config["ML_GW_LO"] = self._extract_last_octet(self.config.get("ML_GW", ""))
        if "PVE_IP" in self.config:
            self.config["PVE_IP_LO"] = self._extract_last_octet(self.config["PVE_IP"])
        if "PT_IG_IP" in self.config:
            self.config["PT_IG_IP_LO"] = self._extract_last_octet(self.config["PT_IG_IP"])
        if "PT_EG_IP" in self.config:
            self.config["PT_EG_IP_LO"] = self._extract_last_octet(self.config["PT_EG_IP"])
        if "VPNDMZ_CIDR" in self.config:
            self.config["VPNDMZ_GW_LO"] = self._extract_last_octet(self.config.get("VPNDMZ_GW", ""))
        
        # Auto-calculate VPNDMZ_GW and PT_EG_IP when VPNDMZ_CIDR changes
        # (only update if they appear to be auto-generated from a previous calculation)
        if "VPNDMZ_CIDR" in self.config and self.config["VPNDMZ_CIDR"]:
            try:
                vpndmz_net = IPv4Network(self.config["VPNDMZ_CIDR"], strict=False)
                vpndmz_gw_auto = str(vpndmz_net.network_address + 1)
                pt_eg_ip_auto = str(vpndmz_net.network_address + 2)
                
                # Update VPNDMZ_GW if not set or matches previous auto-calculated pattern
                current_gw = self.config.get("VPNDMZ_GW", "").strip()
                if not current_gw or self._looks_like_auto_calculated(current_gw, vpndmz_gw_auto):
                    self.config["VPNDMZ_GW"] = vpndmz_gw_auto
                    self.config["VPNDMZ_GW_LO"] = self._extract_last_octet(vpndmz_gw_auto)
                
                # Update PT_EG_IP if not set or matches previous auto-calculated pattern
                current_pt_eg = self.config.get("PT_EG_IP", "").strip()
                if not current_pt_eg or self._looks_like_auto_calculated(current_pt_eg, pt_eg_ip_auto):
                    self.config["PT_EG_IP"] = pt_eg_ip_auto
                    self.config["PT_EG_IP_LO"] = self._extract_last_octet(pt_eg_ip_auto)
            except (ValueError, IndexError, AttributeError):
                pass
        
        # Project network CIDRs from PJALL_CIDR
        if "PJALL_CIDR" in self.config and self.config["PJALL_CIDR"]:
            pj_cidrs = self._calculate_project_cidrs(self.config["PJALL_CIDR"], self.num_pj)
            self.config.update(pj_cidrs)
        
        # VPN pools from VPN_POOL
        if "VPN_POOL" in self.config and self.config["VPN_POOL"]:
            # Clear previous per-project pool keys to avoid stale entries
            # when NUM_PJ or VPN_POOL changes (e.g., 8 -> 16 or 16 -> 4).
            stale_pool_keys = [
                k for k in list(self.config.keys())
                if re.match(r"^(OVPN_POOL\d+|WG_POOL\d+)$", k)
            ]
            for key in stale_pool_keys:
                self.config.pop(key, None)

            vpn_pools = self._calculate_vpn_pools(self.config["VPN_POOL"], self.num_pj)
            self.config.update(vpn_pools)

    def _validate_ports(self) -> Tuple[bool, str]:
        """Validate port ranges and return (is_valid, error_message)."""
        if not (1024 <= self.ovpn_start <= 65535):
            return (False, "OpenVPN port must be 1024-65535")
        if not (1024 <= self.wg_start <= 65535):
            return (False, "WireGuard port must be 1024-65535")
        if self.ovpn_start + self.num_pj - 1 > 65535:
            return (False, f"OpenVPN ports exceed max (need {self.num_pj} ports from {self.ovpn_start})")
        if self.wg_start + self.num_pj - 1 > 65535:
            return (False, f"WireGuard ports exceed max (need {self.num_pj} ports from {self.wg_start})")
        ovpn_range = set(range(self.ovpn_start, self.ovpn_start + self.num_pj))
        wg_range = set(range(self.wg_start, self.wg_start + self.num_pj))
        if ovpn_range & wg_range:
            return (False, f"Port conflict: OpenVPN ({min(ovpn_range)}-{max(ovpn_range)}) overlaps WireGuard ({min(wg_range)}-{max(wg_range)})")
        return (True, "")

    def _validate_network_conflicts_before_save(self) -> Tuple[bool, str]:
        """Validate network overlaps against existing networks before saving."""
        try:
            existing_networks = self.runner.get_existing_networks()
        except Exception:
            existing_networks = []

        # Parent CIDRs must not overlap each other.
        parent_keys = ("VPNDMZ_CIDR", "VPN_POOL", "PJALL_CIDR")
        parent_values = []
        for key in parent_keys:
            value = (self.config.get(key, "") or "").strip()
            if value and self._is_valid_cidr(value):
                parent_values.append((key, value))

        for i, (k1, c1) in enumerate(parent_values):
            for k2, c2 in parent_values[i + 1:]:
                if self._cidr_overlaps(c1, c2):
                    return (False, f"{k1} overlaps with {k2} ({c2})")

        # Check effective proposed CIDRs (parents + split subnets) against existing networks.
        candidate_cidrs: List[Tuple[str, str]] = []
        for key, value in self.config.items():
            if key in parent_keys or re.match(r"^(OVPN_POOL\d+|WG_POOL\d+|PJ\d{2}_CIDR)$", key):
                cidr = (value or "").strip()
                if cidr and self._is_valid_cidr(cidr):
                    candidate_cidrs.append((key, cidr))

        for key, cidr in candidate_cidrs:
            for existing in existing_networks:
                if self._is_valid_cidr(existing) and self._cidr_overlaps(cidr, existing):
                    return (False, f"{key} ({cidr}) overlaps with existing network {existing}")

        return (True, "")

    def _show_dialog(
        self,
        mode: str,
        title: str,
        lines: List[str],
        yes_text: str = "",
        no_text: str = "",
        ok_text: str = "",
        default_yes: bool = True,
        refresh_screen: bool = False,
    ) -> bool | None:
        """Show a dialog (confirm or notice).

        mode: "confirm" or "notice"
        Returns True/False for confirm, None for notice.
        """
        if refresh_screen:
            try:
                self.stdscr.erase()
                self._render()
                self.stdscr.refresh()
            except curses.error:
                pass

        h, w = self.stdscr.getmaxyx()
        dialog_h = 10 if mode == "confirm" else 8
        dialog_w = 70
        y = max(2, (h - dialog_h) // 2)
        x = max(0, (w - dialog_w) // 2)

        dialog_w = min(dialog_w, w - 2)
        dialog_h = min(dialog_h, h - 2)

        # Extract keys from button texts (e.g., "[D]" -> "D", "[Y]" -> "Y")
        yes_key = "Y"
        no_key = "N"
        ok_key = "O"
        
        if yes_text:
            match = re.search(r'\[([A-Za-z])\]', yes_text)
            if match:
                yes_key = match.group(1).upper()
        if no_text:
            match = re.search(r'\[([A-Za-z])\]', no_text)
            if match:
                no_key = match.group(1).upper()
        if ok_text:
            match = re.search(r'\[([A-Za-z])\]', ok_text)
            if match:
                ok_key = match.group(1).upper()

        # Focus state: 0=yes/left/ok, 1=no/right
        focused = 0 if default_yes else 1

        def draw_dialog():
            """Draw the dialog with current focus state."""
            # Background
            for row in range(y, min(y + dialog_h, h)):
                try:
                    self.stdscr.addstr(row, x, " " * (dialog_w - 1), curses.color_pair(1) | curses.A_REVERSE)
                except curses.error:
                    pass

            # Border
            try:
                for col in range(x, x + dialog_w - 1):
                    self.stdscr.addch(y, col, curses.ACS_HLINE, curses.color_pair(1))
                    self.stdscr.addch(y + dialog_h - 1, col, curses.ACS_HLINE, curses.color_pair(1))
                for row in range(y, y + dialog_h - 1):
                    self.stdscr.addch(row, x, curses.ACS_VLINE, curses.color_pair(1))
                    self.stdscr.addch(row, x + dialog_w - 2, curses.ACS_VLINE, curses.color_pair(1))
                self.stdscr.addch(y, x, curses.ACS_ULCORNER, curses.color_pair(1))
                self.stdscr.addch(y, x + dialog_w - 2, curses.ACS_URCORNER, curses.color_pair(1))
                self.stdscr.addch(y + dialog_h - 1, x, curses.ACS_LLCORNER, curses.color_pair(1))
                self.stdscr.addch(y + dialog_h - 1, x + dialog_w - 2, curses.ACS_LRCORNER, curses.color_pair(1))
            except curses.error:
                pass

            # Title
            try:
                self.stdscr.addstr(y, x + 2, title[:dialog_w - 4], curses.color_pair(1) | curses.A_BOLD)
            except curses.error:
                pass

            # Message lines
            msg_lines = [line for line in lines if line]
            for i, line in enumerate(msg_lines[:3]):
                try:
                    self.stdscr.addstr(y + 2 + i, x + 2, line[:dialog_w - 4], curses.color_pair(1))
                except curses.error:
                    pass

            # Buttons with focus highlighting
            try:
                if mode == "confirm":
                    # Left button (Yes/Discard)
                    left_attr = curses.color_pair(1) | curses.A_BOLD | curses.A_REVERSE if focused == 0 else curses.color_pair(1) | curses.A_BOLD
                    self.stdscr.addstr(y + 6, x + 10, yes_text[:20], left_attr)
                    # Right button (No/Cancel)
                    right_attr = curses.color_pair(1) | curses.A_BOLD | curses.A_REVERSE if focused == 1 else curses.color_pair(1)
                    self.stdscr.addstr(y + 6, x + 30, no_text[:20], right_attr)
                else:
                    # OK button (always focused in notice mode)
                    self.stdscr.addstr(y + 5, x + 15, ok_text[:dialog_w - 30], curses.color_pair(1) | curses.A_BOLD)
            except curses.error:
                pass

            self.stdscr.refresh()

        # Initial draw
        draw_dialog()

        while True:
            try:
                ch = self.stdscr.getch()
                
                if mode == "confirm":
                    # Tab or arrow keys to toggle focus between buttons
                    if ch in (9, curses.KEY_RIGHT, curses.KEY_BTAB, curses.KEY_LEFT):
                        focused = 1 - focused  # Toggle: 0↔1
                        draw_dialog()
                        continue
                    
                    # Enter key: execute focused option
                    if ch in (10, 13, curses.KEY_ENTER):
                        return focused == 0
                    
                    # Direct key shortcuts
                    if ch in (ord(yes_key), ord(yes_key.lower())):
                        return True
                    if ch in (ord(no_key), ord(no_key.lower())):
                        return False
                else:
                    # Notice mode: OK button
                    if ch in (ord(ok_key), ord(ok_key.lower()), 10, 13, curses.KEY_ENTER):
                        return None
            except:
                pass

    def _show_exit_confirm(self) -> bool:
        """Show exit confirmation dialog with Discard/Cancel options."""
        title = self.msg.get("exit_title", "Exit MSL Setup")
        msg1 = self.msg.get("exit_msg1", "Are you sure you want to exit")
        msg2 = self.msg.get("exit_msg2", "without saving?")
        discard_opt = self.msg.get("exit_discard", "[D] Discard")
        cancel_opt = self.msg.get("exit_cancel", "[C] Cancel")
        result = self._show_dialog(
            "confirm",
            title,
            [msg1, msg2],
            yes_text=discard_opt,
            no_text=cancel_opt,
            default_yes=False,
        )
        # Keep semantics explicit for this screen:
        # Discard -> exit loop (False), Cancel -> continue loop (True).
        if result is True:
            return False
        self.status = self.msg["status_ready"]
        return True

    def _show_generate_confirm(self) -> bool:
        """Show .env generation confirmation dialog."""
        title = self.msg.get("generate_title", "Generate Configuration File")
        msg1 = self.msg.get("generate_msg1", "Ready to generate configuration file")
        msg2 = self.msg.get("generate_msg2", "with the current configuration.")
        msg3 = self.msg.get("generate_msg3", "Continue?")
        yes_opt = self.msg.get("generate_yes", "[Y] Yes")
        no_opt = self.msg.get("generate_no", "[N] No")
        result = self._show_dialog(
            "confirm",
            title,
            [msg1, msg2, msg3],
            yes_text=yes_opt,
            no_text=no_opt,
            default_yes=True,
        )
        if result is False:
            self.status = self.msg["status_ready"]
        return bool(result)

    def _show_env_result(self, success: bool, error_msg: str = "") -> None:
        """Show result dialog after .env save attempt (success or failure)."""
        if success:
            title = self.msg.get("env_success_title", "Configuration Saved")
            msg = self.msg.get("env_success_msg", "Configuration file saved successfully")
        else:
            title = self.msg.get("env_fail_title", "Save Failed")
            msg = error_msg if error_msg else self.msg.get("env_fail_msg", "Failed to save configuration file")
        ok_text = self.msg.get("env_result_ok", "[O] OK")
        self._show_dialog("notice", title, [msg], ok_text=ok_text)

    def _show_notice_dialog(self, title: str, msg: str) -> None:
        """Show a simple notice dialog with OK button."""
        ok_text = self.msg.get("notice_ok", "[O] OK")
        self._show_dialog("notice", title, [msg], ok_text=ok_text)

    def _show_networks_dialog(self) -> None:
        """Show detected existing networks in a scrollable dialog."""
        title = self.msg.get("networks_title", "Detected Existing Networks")
        try:
            networks = self.runner.get_existing_networks()
        except Exception as exc:
            self._show_notice_dialog(
                title,
                f"{self.msg.get('networks_error', 'Failed to detect existing networks')}: {exc}",
            )
            return

        lines = list(networks) if networks else [self.msg.get("networks_empty", "No existing networks detected.")]
        scroll = 0

        while True:
            h, w = self.stdscr.getmaxyx()
            dialog_h = min(max(10, len(lines) + 6), h - 2)
            dialog_w = min(90, w - 2)
            y = max(1, (h - dialog_h) // 2)
            x = max(0, (w - dialog_w) // 2)

            # Draw background
            for row in range(y, min(y + dialog_h, h)):
                try:
                    self.stdscr.addstr(row, x, " " * (dialog_w - 1), curses.color_pair(1) | curses.A_REVERSE)
                except curses.error:
                    pass

            # Border
            try:
                for col in range(x, x + dialog_w - 1):
                    self.stdscr.addch(y, col, curses.ACS_HLINE, curses.color_pair(1))
                    self.stdscr.addch(y + dialog_h - 1, col, curses.ACS_HLINE, curses.color_pair(1))
                for row in range(y, y + dialog_h - 1):
                    self.stdscr.addch(row, x, curses.ACS_VLINE, curses.color_pair(1))
                    self.stdscr.addch(row, x + dialog_w - 2, curses.ACS_VLINE, curses.color_pair(1))
                self.stdscr.addch(y, x, curses.ACS_ULCORNER, curses.color_pair(1))
                self.stdscr.addch(y, x + dialog_w - 2, curses.ACS_URCORNER, curses.color_pair(1))
                self.stdscr.addch(y + dialog_h - 1, x, curses.ACS_LLCORNER, curses.color_pair(1))
                self.stdscr.addch(y + dialog_h - 1, x + dialog_w - 2, curses.ACS_LRCORNER, curses.color_pair(1))
            except curses.error:
                pass

            try:
                header = f"{title} ({len(networks)})"
                self.stdscr.addstr(y, x + 2, header[: dialog_w - 4], curses.color_pair(1) | curses.A_BOLD)
            except curses.error:
                pass

            body_top = y + 2
            body_h = max(1, dialog_h - 5)
            max_scroll = max(0, len(lines) - body_h)
            scroll = max(0, min(scroll, max_scroll))

            for i in range(body_h):
                idx = scroll + i
                if idx >= len(lines):
                    break
                try:
                    text = f"{idx + 1:>2}. {lines[idx]}"
                    self.stdscr.addstr(body_top + i, x + 2, text[: dialog_w - 4], curses.color_pair(1))
                except curses.error:
                    pass

            try:
                hint = self.msg.get("networks_hint", "[Up/Down/PgUp/PgDn] Scroll  [Enter/Esc] Close")
                self.stdscr.addstr(y + dialog_h - 2, x + 2, hint[: dialog_w - 4], curses.color_pair(1))
            except curses.error:
                pass

            self.stdscr.refresh()

            ch = self.stdscr.getch()
            if ch in (10, 13, 27, ord("q"), ord("Q")):
                return
            if ch == curses.KEY_UP:
                scroll -= 1
            elif ch == curses.KEY_DOWN:
                scroll += 1
            elif ch == curses.KEY_PPAGE:
                scroll -= max(1, body_h - 1)
            elif ch == curses.KEY_NPAGE:
                scroll += max(1, body_h - 1)
            elif ch == curses.KEY_HOME:
                scroll = 0
            elif ch == curses.KEY_END:
                scroll = max_scroll

    def _show_svg_dialog(self) -> bool:
        """Show SVG generation dialog after .env save.

        Returns True if user wants to generate SVG, False otherwise.
        """
        title = self.msg.get("svg_dialog_title", "Add Network Diagram to Proxmox Notes")
        msg1 = self.msg.get("svg_dialog_msg", "Do you like to add Network Diagram")
        msg2 = self.msg.get("svg_dialog_msg2", "to Proxmox Notes?")
        yes_text = self.msg.get("svg_dialog_yes", "[Y] Yes")
        no_text = self.msg.get("svg_dialog_no", "[N] No")
        return bool(
            self._show_dialog(
                "confirm",
                title,
                [msg1, msg2],
                yes_text=yes_text,
                no_text=no_text,
                default_yes=True,
                refresh_screen=True,
            )
        )

    def _load_env_from_file(self) -> bool:
        """Load configuration from .env file.
        
        Returns True if successful, False otherwise.
        """
        env_path = os.path.join(SCRIPT_DIR, ".env")
        if not os.path.isfile(env_path):
            return False
        
        try:
            with open(env_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if "=" in line:
                        key, value = line.split("=", 1)
                        self.config[key.strip()] = value.strip()
            
            # After loading, update self.num_pj, ovpn_start, wg_start from config
            if "NUM_PJ" in self.config:
                try:
                    self.num_pj = int(self.config["NUM_PJ"])
                except ValueError:
                    pass
            if "PF_ST_OV" in self.config:
                try:
                    self.ovpn_start = int(self.config["PF_ST_OV"])
                except ValueError:
                    pass
            if "PF_ST_WG" in self.config:
                try:
                    self.wg_start = int(self.config["PF_ST_WG"])
                except ValueError:
                    pass
            
            # Check if CUSTOM fields exist in loaded config
            custom_field_keys = [field_key for field_key, _, _ in self.custom_fields]
            has_custom_fields = any(key in self.config for key in custom_field_keys)
            
            # If CUSTOM fields are present, switch to CUSTOM mode
            if has_custom_fields:
                self.mode = "CUSTOM"
            
            # Recalculate all derived values (CUSTOM fields will be preserved)
            self._recalculate_config()
            return True
        except Exception:
            return False

    def _show_load_env_dialog(self) -> bool:
        """Show dialog asking to load existing .env file.

        Returns True if user wants to load, False if user wants to skip.
        """
        title = self.msg.get("load_env_title", "Existing Configuration File")
        msg1 = self.msg.get("load_env_msg", "Found an existing configuration file.")
        msg2 = self.msg.get("load_env_msg2", "Load it?")
        yes_opt = self.msg.get("load_env_yes", "[Y] Yes")
        no_opt = self.msg.get("load_env_no", "[N] No")
        result = self._show_dialog(
            "confirm",
            title,
            [msg1, msg2],
            yes_text=yes_opt,
            no_text=no_opt,
            default_yes=True,
        )
        return bool(result)

    def _render_input_dialog(self) -> None:
        """Render an input dialog overlay when editing with original value and error messages."""
        if not self.edit_field:
            return

        h, w = self.stdscr.getmaxyx()
        dialog_h = 12  # Keep room for wrapped error lines
        dialog_w = 70
        y = max(2, (h - dialog_h) // 2)
        x = max(0, (w - dialog_w) // 2)
        
        # Constrain dialog to fit within screen
        dialog_w = min(dialog_w, w - 2)
        dialog_h = min(dialog_h, h - 2)

        # Get field label and original value
        field_label = "Edit Field"
        original_value = ""
        if self.edit_field.startswith("custom_"):
            try:
                field_idx = int(self.edit_field.split("_")[1])
                if field_idx < len(self.custom_fields):
                    field_key = self.custom_fields[field_idx][0]
                    field_label = f"Edit {field_key}"
                    original_value = self.config.get(field_key, "") or ""
            except (ValueError, IndexError):
                pass

        # Draw to stdscr directly to avoid pad issues
        # Background (invert colors)
        for row in range(y, min(y + dialog_h, h)):
            try:
                self.stdscr.addstr(row, x, " " * (dialog_w - 1), curses.color_pair(1) | curses.A_REVERSE)
            except curses.error:
                pass

        # Title
        try:
            self.stdscr.addstr(y, x + 2, field_label[:dialog_w - 4], curses.color_pair(1) | curses.A_BOLD)
        except curses.error:
            pass
        
        # Original value label
        try:
            self.stdscr.addstr(y + 1, x + 2, f"Original: {original_value[:dialog_w - 15]}", curses.color_pair(2))
        except curses.error:
            pass
        
        # Input label and current edit buffer value
        input_text = self.edit_buffer if self.edit_buffer is not None else original_value
        try:
            mode_label = "INS" if self.edit_insert_mode else "OVR"
            self.stdscr.addstr(y + 3, x + 2, f"New Value ({mode_label}):", curses.color_pair(1))
            field_x = x + 20
            field_w = max(8, dialog_w - 22)

            # Horizontal viewport that follows the cursor.
            cursor = max(0, min(self.edit_cursor, len(input_text)))
            if len(input_text) <= field_w:
                offset = 0
            else:
                offset = max(0, min(cursor - field_w + 1, len(input_text) - field_w))

            display_text = input_text[offset: offset + field_w]
            self.stdscr.addstr(y + 3, field_x, display_text, curses.color_pair(1) | curses.A_BOLD)

            # Draw cursor at logical edit position (not always at end).
            cursor_in_view_raw = cursor - offset
            cursor_in_view = max(0, min(cursor_in_view_raw, field_w - 1))
            cursor_x = min(field_x + cursor_in_view, w - 1)

            # Keep the original character visible and underline it.
            # Only show '_' when the cursor is at end-of-text and there is room.
            if 0 <= cursor_in_view_raw < len(display_text):
                cursor_char = display_text[cursor_in_view_raw]
                self.stdscr.addstr(
                    y + 3,
                    min(field_x + cursor_in_view_raw, w - 1),
                    cursor_char,
                    curses.color_pair(1) | curses.A_BOLD | curses.A_UNDERLINE,
                )
            else:
                self.stdscr.addstr(y + 3, cursor_x, "_", curses.color_pair(1) | curses.A_BOLD)
        except curses.error:
            pass
        
        # Error message (if any)
        instruction_y = y + 9
        if self.dialog_error:
            try:
                max_width = max(10, dialog_w - 4)
                wrapped = textwrap.wrap(f"Error: {self.dialog_error}", width=max_width)
                # Keep dialog readable in small terminals.
                wrapped = wrapped[:3]
                for i, line in enumerate(wrapped):
                    self.stdscr.addstr(y + 5 + i, x + 2, line[:max_width], curses.color_pair(5))
                instruction_y = y + 5 + len(wrapped) + 1
            except curses.error:
                pass
        
        # Instructions
        try:
            instruction_text = "[Enter] Save  [ESC] Cancel  [<-/->/Home/End] Move  [Ins] Toggle"
            self.stdscr.addstr(
                instruction_y,
                x + 2,
                instruction_text[: max(0, dialog_w - 4)],
                curses.color_pair(1),
            )
        except curses.error:
            pass

    def _edit_char_allowed(self, ch: str) -> bool:
        """Return whether typed character is allowed for current edit field."""
        if self.edit_field in ("ovpn", "wg"):
            return ch.isdigit()
        if self.edit_field and self.edit_field.startswith("custom_"):
            return ch.isdigit() or ch in (".", "/")
        return False

    def _edit_max_len(self) -> int:
        """Return max input length for current edit field."""
        if self.edit_field in ("ovpn", "wg"):
            return 5
        return 20

    def _handle_edit_input(self, ch: int) -> bool:
        """Handle in-dialog text editing with cursor movement and insert/overwrite mode."""
        if not self.edit_field:
            return False

        # Cursor movement
        if ch == curses.KEY_LEFT:
            self.edit_cursor = max(0, self.edit_cursor - 1)
            return True
        if ch == curses.KEY_RIGHT:
            self.edit_cursor = min(len(self.edit_buffer), self.edit_cursor + 1)
            return True
        if ch == curses.KEY_HOME:
            self.edit_cursor = 0
            return True
        if ch == curses.KEY_END:
            self.edit_cursor = len(self.edit_buffer)
            return True

        # Toggle insert/overwrite mode
        if ch == curses.KEY_IC:
            self.edit_insert_mode = not self.edit_insert_mode
            return True

        # Delete before cursor
        if ch in (curses.KEY_BACKSPACE, 127, 8):
            if self.edit_cursor > 0:
                self.edit_buffer = self.edit_buffer[: self.edit_cursor - 1] + self.edit_buffer[self.edit_cursor :]
                self.edit_cursor -= 1
            return True

        # Delete at cursor
        if ch == curses.KEY_DC:
            if self.edit_cursor < len(self.edit_buffer):
                self.edit_buffer = self.edit_buffer[: self.edit_cursor] + self.edit_buffer[self.edit_cursor + 1 :]
            return True

        # Character input
        if 32 <= ch <= 126:
            typed = chr(ch)
            if not self._edit_char_allowed(typed):
                return True

            max_len = self._edit_max_len()
            if self.edit_insert_mode:
                if len(self.edit_buffer) >= max_len:
                    return True
                self.edit_buffer = (
                    self.edit_buffer[: self.edit_cursor]
                    + typed
                    + self.edit_buffer[self.edit_cursor :]
                )
                self.edit_cursor += 1
                return True

            # Overwrite mode
            if self.edit_cursor < len(self.edit_buffer):
                self.edit_buffer = (
                    self.edit_buffer[: self.edit_cursor]
                    + typed
                    + self.edit_buffer[self.edit_cursor + 1 :]
                )
                self.edit_cursor += 1
                return True

            if len(self.edit_buffer) < max_len:
                self.edit_buffer += typed
                self.edit_cursor += 1
            return True

        # Ignore unsupported keys while editing
        return True

    def _render(self) -> None:
        self.stdscr.erase()
        height, width = self.stdscr.getmaxyx()
        if width < 80 or height < 24:
            self.stdscr.addstr(0, 0, self.msg["status_resize"], curses.color_pair(5))
            self.stdscr.noutrefresh()
            curses.doupdate()
            return

        left_w = max(24, width * 25 // 100)
        right_w = width - left_w - 1

        self._render_title(width)
        self._render_left_panel(1, height - 2, 0, left_w)
        self._render_separator(1, height - 2, left_w)
        self._render_status(height - 1, width)

        # Mark stdscr for update without physically refreshing yet
        self.stdscr.noutrefresh()

        # Render pad (will also call noutrefresh)
        self._render_right_panel(1, height - 2, left_w + 1, right_w)

        # Render input dialog if editing
        if self.edit_field:
            self._render_input_dialog()

        # Now physically update the terminal with all pending changes
        curses.doupdate()

    def _render_title(self, width: int) -> None:
        title = self.msg["title"]
        self.stdscr.attron(curses.color_pair(1) | curses.A_BOLD)
        self.stdscr.addstr(0, 0, " " * width)
        self.stdscr.addstr(0, 2, title)
        self.stdscr.attroff(curses.color_pair(1) | curses.A_BOLD)

    def _render_separator(self, y: int, h: int, x: int) -> None:
        for i in range(y, y + h):
            self.stdscr.addch(i, x, "|")

    def _render_left_panel(self, y: int, h: int, x: int, w: int) -> None:
        line = y
        focus = self.focus_index

        def draw(text: str, is_focus: bool = False) -> None:
            attr = curses.color_pair(3) if is_focus else curses.color_pair(2)
            self.stdscr.addstr(line, x + 1, text.ljust(w - 2)[: w - 2], attr)

        # Mode
        draw(f"{self.msg['mode_label']}")
        line += 1
        auto_mark = "*" if self.mode == "AUTO" else " "
        custom_mark = "*" if self.mode == "CUSTOM" else " "
        mode_text = f"({auto_mark}) {self.msg['mode_auto']}  ({custom_mark}) {self.msg['mode_custom']}"
        draw(mode_text, focus == 0)
        line += 2

        # NUM_PJ
        draw(f"{self.msg['num_pj_label']}")
        line += 1
        options = [2, 4, 8, 16]
        opt_text = " ".join([f"({'*' if self.num_pj == v else ' '}){v}" for v in options])
        draw(opt_text, focus == 1)
        line += 2

        # Show port ranges in both AUTO and CUSTOM modes (editable)
        # OpenVPN Ports
        draw(self.msg["ovpn_ports_label"])
        line += 1
        for i in range(self.num_pj):
            port = self.ovpn_start + i
            if i == 0:
                if self.edit_field == "ovpn":
                    display = f"[{self.edit_buffer or str(port)}]"
                else:
                    display = f"[{port}]"
                draw(display, focus == 2)
            else:
                draw(f" {port}")
            line += 1
            if line >= y + h - 6:
                break

        line += 1
        draw(self.msg["wg_ports_label"])
        line += 1
        for i in range(self.num_pj):
            port = self.wg_start + i
            if i == 0:
                if self.edit_field == "wg":
                    display = f"[{self.edit_buffer or str(port)}]"
                else:
                    display = f"[{port}]"
                draw(display, focus == 3)
            else:
                draw(f" {port}")
            line += 1
            if line >= y + h - 3:
                break

        line += 1
        # Draw separator line above SAVE button
        draw("─" * (w - 4))
        line += 1
        # SAVE button position: focus 4 (AUTO) or focus 12 (CUSTOM)
        if self.mode == "AUTO":
            draw(f"[ {self.msg['ok_button']} ]", focus == 4)
        else:  # CUSTOM mode
            draw(f"[ {self.msg['ok_button']} ]", focus == 12)

    def _render_right_panel(self, y: int, h: int, x: int, w: int) -> None:
        # Both AUTO and CUSTOM modes use the same AUTO preview
        self._render_right_auto(y, h, x, w)

    def _render_right_auto(self, y: int, h: int, x: int, w: int) -> None:
        """Render AUTO mode preview (with CUSTOM mode highlight support)."""
        pad = curses.newpad(400, w)
        
        # In CUSTOM mode, use white text; in AUTO mode, use dim
        if self.mode == "CUSTOM":
            pad.attron(curses.color_pair(4))  # White text on default background
        else:
            pad.attron(curses.A_DIM)  # Dim text for AUTO mode

        lines = self._build_preview_lines(w)
        
        # In CUSTOM mode, track which preview lines correspond to editable fields
        custom_field_lines = self._get_custom_field_line_mapping(lines) if self.mode == "CUSTOM" else {}

        target_line_idx = None
        target_field_value = ""
        if self.mode == "CUSTOM" and 4 <= self.focus_index <= 11:
            field_idx = self.focus_index - 4
            target_field_value = self.config.get(self.custom_fields[field_idx][0], "") if self.config and field_idx < len(self.custom_fields) else ""
            for line_idx, mapped_field_idx in custom_field_lines.items():
                if mapped_field_idx == field_idx:
                    target_line_idx = line_idx
                    break
        
        for i, text in enumerate(lines):
            if i >= 400:
                break
            
            # In CUSTOM mode, highlight the focused field's value (not the entire line)
            if self.mode == "CUSTOM" and self.focus_index >= 4 and self.focus_index <= 11 and i == target_line_idx:
                field_idx = self.focus_index - 4
                if field_idx < len(self.custom_fields):
                    field_value = target_field_value
                    
                    # Check if this line contains the field value
                    if field_value and field_value in text:
                        # Find and highlight the value portion
                        value_start = text.find(field_value)
                        if value_start != -1:
                            value_end = value_start + len(field_value)
                            
                            # Calculate display column positions (accounting for Japanese 2-byte chars)
                            col_before_value = self._get_display_width(text[:value_start])
                            col_value_width = self._get_display_width(text[value_start:value_end])
                            col_after_value = col_before_value + col_value_width
                            
                            # Write everything before value
                            if value_start > 0:
                                pad.addstr(i, 0, text[:value_start], curses.color_pair(4))
                            
                            # Write value with reverse (use display column position)
                            pad.attron(curses.A_REVERSE | curses.color_pair(4))
                            pad.addstr(i, col_before_value, text[value_start:value_end])
                            pad.attroff(curses.A_REVERSE | curses.color_pair(4))
                            pad.attron(curses.color_pair(4))
                            
                            # Write everything after value (use display column position)
                            if value_end < len(text):
                                pad.addstr(i, col_after_value, text[value_end:])
                        else:
                            pad.addstr(i, 0, text[: w - 1], curses.color_pair(4))
                    else:
                        pad.addstr(i, 0, text[: w - 1], curses.color_pair(4))
                else:
                    pad.addstr(i, 0, text[: w - 1], curses.color_pair(4))
            else:
                if self.mode == "AUTO":
                    pad.addstr(i, 0, text[: w - 1], curses.A_DIM)
                else:
                    pad.addstr(i, 0, text[: w - 1], curses.color_pair(4))

        max_scroll = max(0, len(lines) - h)
        self.preview_scroll = max(0, min(self.preview_scroll, max_scroll))
        pad.noutrefresh(self.preview_scroll, 0, y, x, y + h - 1, x + w - 1)

        max_scroll = max(0, len(lines) - h)
        self.preview_scroll = max(0, min(self.preview_scroll, max_scroll))
        pad.noutrefresh(self.preview_scroll, 0, y, x, y + h - 1, x + w - 1)

    def _get_custom_field_line_mapping(self, lines: List[str]) -> Dict[int, int]:
        """Map preview line numbers to custom field indices (0-7) for highlighting."""
        mapping: Dict[int, int] = {}
        cfg = self.config or self.last_good_config
        used_lines = set()
        
        for field_idx, (key, label_msg_key, _) in enumerate(self.custom_fields):
            # Get the value of this field from config
            field_value = cfg.get(key, "") if cfg else ""
            if not field_value:
                continue

            label = self.msg.get(label_msg_key, key)
            expected = f"{label} {field_value}"

            # Prefer exact "label + value" match first.
            for line_idx, line in enumerate(lines):
                if line_idx in used_lines:
                    continue
                if expected in line:
                    mapping[line_idx] = field_idx
                    used_lines.add(line_idx)
                    break
            else:
                # Fallback: value-only match on an unused line.
                for line_idx, line in enumerate(lines):
                    if line_idx in used_lines:
                        continue
                    if field_value in line:
                        mapping[line_idx] = field_idx
                        used_lines.add(line_idx)
                        break
        
        return mapping


    def _get_field_label(self, field_key: str) -> str:
        """Get display label for a field key. Returns the label from custom_fields, or the key itself as fallback."""
        for key, label_msg_key, _ in self.custom_fields:
            if key == field_key:
                return self.msg.get(label_msg_key, field_key)
        return field_key

    def _build_preview_blocks(self) -> List[List[str]]:
        cfg = self.config or self.last_good_config
        blocks: List[List[str]] = []

        header = [self.msg["preview_title"], "----------------------------------------"]
        if not cfg:
            header.append(self.msg["preview_empty"])
            header.append("")
            return [header]

        blocks.append(header)

        def add_section(key: str, entries: List[Tuple[str, str]]) -> None:
            """Add section using display label (or fallback to section key)."""
            display_key = f"display_{key}"
            title = self.msg.get(display_key, self.msg.get(key, key))
            block = [title]
            for field_key, val in entries:
                if val:
                    # Use field label instead of field key
                    label = self._get_field_label(field_key)
                    block.append(f"  {label} {val}")
            block.append("")
            blocks.append(block)

        add_section("section_mainlan", [
            ("ML_CIDR", cfg.get("ML_CIDR", "")),
            ("ML_GW", cfg.get("ML_GW", "")),
        ])

        add_section("section_vpndmz", [
            ("VPNDMZ_CIDR", cfg.get("VPNDMZ_CIDR", "")),
            ("VPNDMZ_GW", cfg.get("VPNDMZ_GW", "")),
        ])

        add_section("section_pritunl", [
            ("PT_IG_IP", cfg.get("PT_IG_IP", "")),
            ("PT_EG_IP", cfg.get("PT_EG_IP", "")),
        ])

        add_section("section_projects", [
            ("NUM_PJ", str(self.num_pj)),
        ])

        # VPN Pool section (manual block)
        display_vpn_pool = self.msg.get("display_section_vpn_pool", self.msg.get("section_vpn_pool", "VPN Client Pool"))
        pool_block = [display_vpn_pool]
        # Use label for VPN_POOL
        vp_label = self._get_field_label("VPN_POOL")
        pool_block.append(f"  {vp_label} {cfg.get('VPN_POOL', '')}")
        pool_block.append(f"  OVPN_POOL = {cfg.get('OVPN_POOL', '')}")
        pool_block.append("  OpenVPN Pools:")
        for i in range(1, self.num_pj + 1):
            pool_block.append(f"    OVPN_POOL{i} = {cfg.get(f'OVPN_POOL{i}', '')}")
        pool_block.append(f"  WG_POOL   = {cfg.get('WG_POOL', '')}")
        pool_block.append("  WireGuard Pools:")
        for i in range(1, self.num_pj + 1):
            pool_block.append(f"    WG_POOL{i} = {cfg.get(f'WG_POOL{i}', '')}")
        pool_block.append("")
        blocks.append(pool_block)

        # Project Networks section (manual block)
        display_pj_networks = self.msg.get("display_section_pj_networks", self.msg.get("section_pj_networks", "Project Networks"))
        pj_block = [display_pj_networks]
        # Use label for PJALL_CIDR
        pjall_label = self._get_field_label("PJALL_CIDR")
        pj_block.append(f"  {pjall_label} {cfg.get('PJALL_CIDR', '')}")
        pj_block.append("")
        pj_block.append("PJID | CIDR               | GW")
        pj_block.append("-----+--------------------+-----------------")
        for i in range(1, self.num_pj + 1):
            pj = f"{i:02d}"
            cidr = cfg.get(f"PJ{pj}_CIDR", "")
            gw = cfg.get(f"PJ{pj}_GW", "")
            row = f"PJ{pj} | {cidr.ljust(18)} | {gw}"
            pj_block.append(row)
        pj_block.append("")
        blocks.append(pj_block)

        # Port Forwarding section (manual block)
        display_ports = self.msg.get("display_section_ports", self.msg.get("section_ports", "Port Forwarding Configuration"))
        ports_block = [display_ports]
        ports_block.append(
            f"OpenVPN:  {self.ovpn_start} - {self.ovpn_start + self.num_pj - 1}"
        )
        ports_block.append(
            f"WireGuard: {self.wg_start} - {self.wg_start + self.num_pj - 1}"
        )
        ports_block.append("")
        blocks.append(ports_block)

        add_section("section_dns", [
            ("DNS_IP1", cfg.get("DNS_IP1", "")),
            ("DNS_IP2", cfg.get("DNS_IP2", "")),
        ])

        return blocks

    def _build_preview_lines(self, width: int) -> List[str]:
        blocks = self._build_preview_blocks()
        if width < 60 or len(blocks) <= 1:
            lines: List[str] = []
            for block in blocks:
                lines.extend(block)
            return lines

        col_gap = 2
        col_width = max(20, (width - col_gap) // 2)

        # Use display labels for comparison (blocks now use display labels)
        left_titles = [
            self.msg.get("display_section_mainlan", self.msg.get("section_mainlan", "MainLAN Configuration")),
            self.msg.get("display_section_projects", self.msg.get("section_projects", "Project Configuration")),
            self.msg.get("display_section_pj_networks", self.msg.get("section_pj_networks", "Project Networks")),
            self.msg.get("display_section_ports", self.msg.get("section_ports", "Port Forwarding Configuration")),
            self.msg.get("display_section_dns", self.msg.get("section_dns", "DNS Configuration")),
        ]
        right_titles = [
            self.msg.get("display_section_pritunl", self.msg.get("section_pritunl", "Pritunl IP Configuration")),
            self.msg.get("display_section_vpndmz", self.msg.get("section_vpndmz", "VPN DMZ Network")),
            self.msg.get("display_section_vpn_pool", self.msg.get("section_vpn_pool", "VPN Client Pool")),
        ]

        left_blocks: List[List[str]] = []
        right_blocks: List[List[str]] = []
        for block in blocks:
            title = block[0] if block else ""
            if title in left_titles:
                left_blocks.append(block)
            elif title in right_titles:
                right_blocks.append(block)
            else:
                left_blocks.append(block)

        left_lines: List[str] = []
        right_lines: List[str] = []
        for block in left_blocks:
            left_lines.extend(block)
        for block in right_blocks:
            right_lines.extend(block)

        # Calculate actual display width of entire left column (accounting for Japanese 2-byte chars)
        left_max_display_width = max((self._get_display_width(line) for line in left_lines), default=0)
        # Use the greater of the display width or col_width
        actual_left_width = max(left_max_display_width, col_width)

        total_rows = max(len(left_lines), len(right_lines))
        lines: List[str] = []
        for i in range(total_rows):
            left = left_lines[i] if i < len(left_lines) else ""
            right = right_lines[i] if i < len(right_lines) else ""
            
            # Pad left to actual_left_width (accounting for display width)
            left_display_width = self._get_display_width(left)
            left_padding_needed = actual_left_width - left_display_width
            left_padded = left + " " * max(0, left_padding_needed)
            
            # Right column gets remaining space
            right_col_width = max(20, width - actual_left_width - col_gap)
            right = right[:right_col_width]
            lines.append(f"{left_padded}{' ' * col_gap}{right}")

        return lines

    def _render_status(self, y: int, width: int) -> None:
        # Determine which message and color to display
        display_text = self.status
        attr = curses.color_pair(2)
        
        # Priority: warning > error > normal
        if self.status_warning:
            display_text = self.status_warning
            attr = curses.color_pair(3)  # Yellow bg with black text for warnings
        elif self.status.startswith(self.msg["status_error"]):
            attr = curses.color_pair(5)  # Red bg with white text for errors
        else:
            attr = curses.color_pair(2)  # Normal white text
        
        try:
            self.stdscr.attron(attr)
            if y >= 0 and width > 0:
                self.stdscr.addstr(y, 0, display_text.ljust(width - 1)[: width - 1])
            self.stdscr.attroff(attr)
        except curses.error:
            pass

    def _handle_key(self, ch: int) -> bool:
        if not self.edit_field and ch in (ord("n"), ord("N")):
            self._show_networks_dialog()
            self.status = self.msg["status_ready"]
            return True

        # ESC key: close dialog if open, or show exit confirmation
        if ch in (27,):
            if self.edit_field:
                # Dialog is open: close it and discard changes
                self.edit_field = None
                self.edit_buffer = ""
                self.edit_cursor = 0
                self.dialog_error = ""
                return True
            else:
                # Normal screen: show exit confirmation
                return self._show_exit_confirm()
        
        if ch == curses.KEY_PPAGE:
            self.preview_scroll = max(0, self.preview_scroll - 5)
            return True
        if ch == curses.KEY_NPAGE:
            self.preview_scroll += 5
            return True

        # Ignore Tab/Shift+Tab when dialog is open (edit_field is set), but allow other keys
        if self.edit_field and ch in (9, curses.KEY_BTAB):
            return True
        
        if ch == 9:
            self._commit_edit()
            self.status = self.msg["status_ready"]
            self.status_warning = ""  # Clear warning on navigation
            self.focus_index = (self.focus_index + 1) % self._get_max_focus()
            return True
        if ch == curses.KEY_BTAB:
            self._commit_edit()
            self.status = self.msg["status_ready"]
            self.status_warning = ""  # Clear warning on navigation
            self.focus_index = (self.focus_index - 1) % self._get_max_focus()
            return True

        if ch in (curses.KEY_LEFT, curses.KEY_RIGHT):
            # Ignore LEFT/RIGHT when dialog is open (edit_field is set)
            if self.edit_field:
                return self._handle_edit_input(ch)
            
            self.status = self.msg["status_ready"]
            if self.focus_index == 0:
                self.mode = "CUSTOM" if self.mode == "AUTO" else "AUTO"
                # Keep focus at mode selector, don't auto-move to next panel
                return True
            if self.focus_index == 1:
                options = [2, 4, 8, 16]
                idx = options.index(self.num_pj)
                if ch == curses.KEY_LEFT:
                    idx = (idx - 1) % len(options)
                else:
                    idx = (idx + 1) % len(options)
                new_num_pj = options[idx]
                
                # Auto-adjust WireGuard port start to avoid conflict with OpenVPN when NUM_PJ increases
                port_adjusted = False
                if new_num_pj > self.num_pj:
                    # NUM_PJ increased: auto-adjust WireGuard port to avoid collision
                    new_ovpn_end = self.ovpn_start + new_num_pj - 1
                    new_wg_start = new_ovpn_end + 1
                    if new_wg_start <= 65535 and new_wg_start + new_num_pj - 1 <= 65535:
                        self.wg_start = new_wg_start
                        port_adjusted = True
                
                self.num_pj = new_num_pj
                self._recalculate_config()
                
                # Show warning if port was adjusted
                if port_adjusted:
                    self.status_warning = f"WireGuard port auto-adjusted to {self.wg_start} to avoid conflict"
                else:
                    self.status_warning = ""
                
                return True
            
            # CUSTOM mode: LEFT/RIGHT switches between left and right panel
            if self.mode == "CUSTOM":
                if ch == curses.KEY_RIGHT and self.focus_index <= 1:
                    self.focus_index = 4  # Jump to first custom field
                    return True
                # Right panel (focus_index 4+): LEFT goes back to left panel
                elif ch == curses.KEY_LEFT and self.focus_index >= 4:
                    self.focus_index = 1  # Go back to NUM_PJ
                    return True
            
            return True

        if ch in (curses.KEY_UP, curses.KEY_DOWN):
            # Ignore UP/DOWN when dialog is open (edit_field is set)
            if self.edit_field:
                return True
            
            self._commit_edit()
            self.status = self.msg["status_ready"]
            self.status_warning = ""  # Clear warning on navigation
            
            if self.mode == "CUSTOM":
                # CUSTOM mode: cycle through 0-12 (5 left items + 8 right items)
                if ch == curses.KEY_UP:
                    self.focus_index = (self.focus_index - 1) % self._get_max_focus()
                else:
                    self.focus_index = (self.focus_index + 1) % self._get_max_focus()
            else:
                # AUTO mode: cycle through 0-4
                if ch == curses.KEY_UP:
                    self.focus_index = (self.focus_index - 1) % self._get_max_focus()
                else:
                    self.focus_index = (self.focus_index + 1) % self._get_max_focus()
            return True

        if ch in (10, 13):
            if self.edit_field:
                # Validate custom fields before committing
                if self.edit_field.startswith("custom_"):
                    field_idx = int(self.edit_field.split("_")[1])
                    if field_idx < len(self.custom_fields):
                        field_key = self.custom_fields[field_idx][0]
                        is_valid, error_msg = self._validate_custom_field(field_key, self.edit_buffer)
                        if not is_valid:
                            self.dialog_error = error_msg
                            return True  # Keep dialog open with error message
                # Validation passed or not a custom field
                self._commit_edit()
                self.dialog_error = ""
                return True
            
            if self.mode == "CUSTOM":
                # Left panel: focus 0-1 mode/NUM_PJ (no action on Enter)
                if self.focus_index <= 1:
                    return True
                # Left panel: focus 2-3 port editing
                elif self.focus_index in (2, 3):
                    self.edit_field = "ovpn" if self.focus_index == 2 else "wg"
                    self.edit_buffer = str(self.ovpn_start if self.focus_index == 2 else self.wg_start)
                    self.edit_cursor = len(self.edit_buffer)
                    return True
                # Left panel: focus 4 SAVE button (AUTO mode only)
                elif self.focus_index == 4 and self.mode == "AUTO":
                    is_valid, error_msg = self._validate_ports()
                    if not is_valid:
                        self.status = f"{self.msg['status_error']}{error_msg}"
                        return True
                    
                    # CUSTOM mode: validate all custom fields before generating .env
                    if self.mode == "CUSTOM":
                        # Check all 8 custom fields are filled and valid
                        for field_key, _, _ in self.custom_fields:
                            field_value = self.config.get(field_key, "").strip()
                            if not field_value:
                                self.status = f"{self.msg['status_error']}{field_key} is required"
                                return True
                            is_valid, error_msg = self._validate_custom_field(field_key, field_value)
                            if not is_valid:
                                self.status = f"{self.msg['status_error']}{error_msg}"
                                return True
                    
                    # Show generation confirmation dialog
                    if not self._show_generate_confirm():
                        return True  # User cancelled
                    
                    try:
                        self.runner.generate_env(self.config)
                        self._show_env_result(True)  # Show success dialog
                        # Ask about SVG generation
                        if self._show_svg_dialog():
                            try:
                                self.runner.generate_svg()
                                self._show_notice_dialog(
                                    self.msg.get("svg_success_title", "Network Diagram"),
                                    self.msg.get("svg_success_msg", "Network diagram added to Proxmox notes."),
                                )
                            except Exception as svg_exc:
                                self._show_notice_dialog(
                                    self.msg.get("svg_fail_title", "Network Diagram"),
                                    f"{self.msg.get('svg_fail_msg', 'Failed to add network diagram to Proxmox notes.')} ({svg_exc})",
                                )
                        return False  # Exit successfully
                    except Exception as exc:
                        self._show_env_result(False, str(exc))  # Show failure dialog
                        return True
                # Left panel (right side): focus 12 SAVE button (CUSTOM mode only)
                elif self.focus_index == 12 and self.mode == "CUSTOM":
                    is_valid, error_msg = self._validate_ports()
                    if not is_valid:
                        self.status = f"{self.msg['status_error']}{error_msg}"
                        return True

                    is_valid, error_msg = self._validate_network_conflicts_before_save()
                    if not is_valid:
                        self.status = f"{self.msg['status_error']}{error_msg}"
                        return True
                    
                    # CUSTOM mode: validate all custom fields before generating .env
                    # Check all 8 custom fields are filled and valid
                    for field_key, _, _ in self.custom_fields:
                        field_value = self.config.get(field_key, "").strip()
                        if not field_value:
                            self.status = f"{self.msg['status_error']}{field_key} is required"
                            return True
                        is_valid, error_msg = self._validate_custom_field(field_key, field_value)
                        if not is_valid:
                            self.status = f"{self.msg['status_error']}{error_msg}"
                            return True
                    
                    # Show generation confirmation dialog
                    if not self._show_generate_confirm():
                        return True  # User cancelled
                    
                    try:
                        self.runner.generate_env(self.config)
                        self._show_env_result(True)  # Show success dialog
                        # Ask about SVG generation
                        if self._show_svg_dialog():
                            try:
                                self.runner.generate_svg()
                                self._show_notice_dialog(
                                    self.msg.get("svg_success_title", "Network Diagram"),
                                    self.msg.get("svg_success_msg", "Network diagram added to Proxmox notes."),
                                )
                            except Exception as svg_exc:
                                self._show_notice_dialog(
                                    self.msg.get("svg_fail_title", "Network Diagram"),
                                    f"{self.msg.get('svg_fail_msg', 'Failed to add network diagram to Proxmox notes.')} ({svg_exc})",
                                )
                        return False  # Exit successfully
                    except Exception as exc:
                        self._show_env_result(False, str(exc))  # Show failure dialog
                        return True  # Return to editor, don't exit
                # Right panel: focus 4-11 editable fields (maps to custom_fields 0-7) in CUSTOM mode
                elif self.mode == "CUSTOM" and 4 <= self.focus_index <= 11:
                    field_idx = self.focus_index - 4
                    self.edit_field = f"custom_{field_idx}"
                    # Initialize edit_buffer with the current value
                    if field_idx < len(self.custom_fields):
                        field_key = self.custom_fields[field_idx][0]
                        self.edit_buffer = self.config.get(field_key, "") or ""
                    else:
                        self.edit_buffer = ""
                    self.edit_cursor = len(self.edit_buffer)
                    self.dialog_error = ""  # Clear error when starting new edit
                    return True
                return True
            
            # AUTO mode: focus 4 is OK button, focus 2-3 are port fields
            if self.focus_index == 4:
                is_valid, error_msg = self._validate_ports()
                if not is_valid:
                    self.status = f"{self.msg['status_error']}{error_msg}"
                    return True
                is_valid, error_msg = self._validate_network_conflicts_before_save()
                if not is_valid:
                    self.status = f"{self.msg['status_error']}{error_msg}"
                    return True
                try:
                    self.runner.generate_env(self.config)
                    self._show_env_result(True)  # Show success dialog
                    # Ask about SVG generation
                    if self._show_svg_dialog():
                        try:
                            self.runner.generate_svg()
                            self._show_notice_dialog(
                                self.msg.get("svg_success_title", "Network Diagram"),
                                self.msg.get("svg_success_msg", "Network diagram added to Proxmox notes."),
                            )
                        except Exception as svg_exc:
                            self._show_notice_dialog(
                                self.msg.get("svg_fail_title", "Network Diagram"),
                                f"{self.msg.get('svg_fail_msg', 'Failed to add network diagram to Proxmox notes.')} ({svg_exc})",
                            )
                    return False
                except Exception as exc:
                    self._show_env_result(False, str(exc))  # Show failure dialog
                    return True
            if self.focus_index in (2, 3):
                self.edit_field = "ovpn" if self.focus_index == 2 else "wg"
                self.edit_buffer = str(self.ovpn_start if self.focus_index == 2 else self.wg_start)
                self.edit_cursor = len(self.edit_buffer)
                return True
            return True

        if ch in (32,):
            if self.focus_index == 0:
                self.mode = "CUSTOM" if self.mode == "AUTO" else "AUTO"
                # Keep focus at mode selector, don't auto-move
                return True

        if self.focus_index in (2, 3):
            if ch in range(ord("0"), ord("9") + 1):
                self.edit_field = "ovpn" if self.focus_index == 2 else "wg"
                self.edit_buffer = ""
                self.edit_cursor = 0
                return self._handle_edit_input(ch)
            if ch in (curses.KEY_BACKSPACE, 127, 8, curses.KEY_DC):
                return True

        # In-dialog editing for both port and CUSTOM fields.
        if self.edit_field:
            return self._handle_edit_input(ch)

        return True

    def _is_valid_ipv4(self, ip_str: str) -> bool:
        """Check if string is valid IPv4 address (0.0.0.0 - 255.255.255.255)."""
        try:
            # Use regex similar to bash validate_ip
            if not re.match(r'^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$', ip_str.strip()):
                return False
            octets = ip_str.strip().split('.')
            return all(0 <= int(o) <= 255 for o in octets)
        except (ValueError, AttributeError):
            return False

    def _is_valid_cidr(self, cidr_str: str) -> bool:
        """Check if string is valid CIDR notation (e.g., 192.168.0.0/24)."""
        try:
            cidr_str = cidr_str.strip()
            if not re.match(r'^[0-9\.]+/[0-9]+$', cidr_str):
                return False
            ip, prefix_str = cidr_str.split('/')
            prefix = int(prefix_str)
            if not self._is_valid_ipv4(ip):
                return False
            if prefix < 0 or prefix > 32:
                return False
            return True
        except (ValueError, AttributeError):
            return False

    def _is_network_aligned(self, cidr_str: str) -> bool:
        """Check if CIDR is aligned to its network address (e.g., 192.168.0.0/24 not 192.168.1.1/24)."""
        try:
            # Use ipcalc-style validation: check if network address matches
            cidr_str = cidr_str.strip()
            net = IPv4Network(cidr_str, strict=False)  # Allow host bits for now
            # Get the network address
            network_addr = str(net.network_address)
            cidr_prefix = str(cidr_str.split('/')[1])
            expected_network = f"{network_addr}/{cidr_prefix}"
            
            # Check if input matches expected network notation
            if cidr_str != expected_network:
                return False
            return True
        except ValueError:
            return False

    def _get_aligned_network_cidr(self, cidr_str: str) -> str:
        """Return canonical network CIDR for given input while preserving prefix.

        Example:
            192.168.180.0/20 -> 192.168.176.0/20
        """
        try:
            cidr_str = cidr_str.strip()
            net = IPv4Network(cidr_str, strict=False)
            prefix = cidr_str.split("/")[1]
            return f"{net.network_address}/{prefix}"
        except Exception:
            return ""

    def _network_alignment_error(self, field_key: str, cidr_str: str) -> str:
        """Build a user-friendly error for host-address CIDR input."""
        suggested = self._get_aligned_network_cidr(cidr_str)
        if suggested and suggested != cidr_str.strip():
            return (
                f"{field_key}: '{cidr_str}' is not a network address "
                f"(host bits are set). Suggested: {suggested}"
            )
        return f"{field_key}: must use network address, not host address"

    def _is_private_ip(self, ip_str: str) -> bool:
        """Check if IP is in RFC1918 private range (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)."""
        try:
            addr = IPv4Address(ip_str.strip())
            return addr.is_private
        except (ValueError, AttributeError):
            return False

    def _is_valid_host_address_in_subnet(self, ip: str, subnet_cidr: str) -> Tuple[bool, str]:
        """Check if IP is a valid host address within subnet (not network or broadcast address).
        
        Returns:
            (True, "") if valid host address
            (False, error_msg) if invalid (includes network/broadcast addresses)
        """
        try:
            subnet = IPv4Network(subnet_cidr, strict=False)
            addr = ip_address(ip.strip())
            
            # Check if within subnet
            if addr not in subnet:
                return (False, f"address {ip} is not within {subnet_cidr}")
            
            # Exclude network address
            if addr == subnet.network_address:
                return (False, f"cannot use network address {ip} (network CIDR: {subnet_cidr})")
            
            # Exclude broadcast address
            if addr == subnet.broadcast_address:
                return (False, f"cannot use broadcast address {ip} (network CIDR: {subnet_cidr})")
            
            return (True, "")
        except (ValueError, TypeError) as e:
            return (False, f"invalid address or subnet: {str(e)}")

    def _cidr_overlaps(self, cidr1: str, cidr2: str) -> bool:
        """Check whether two CIDRs overlap."""
        try:
            net1 = IPv4Network(cidr1.strip(), strict=False)
            net2 = IPv4Network(cidr2.strip(), strict=False)
            return net1.overlaps(net2)
        except Exception:
            return False

    def _validate_cidr_conflicts(self, field_key: str, value: str, cfg: Dict[str, str]) -> Tuple[bool, str]:
        """Validate CIDR conflicts against existing networks and peer CIDR fields."""
        cidr_fields = ("VPNDMZ_CIDR", "VPN_POOL", "PJALL_CIDR")

        # Check against existing networks discovered from host/Proxmox state.
        try:
            existing_networks = self.runner.get_existing_networks()
        except Exception:
            existing_networks = []

        for existing_cidr in existing_networks:
            if self._is_valid_cidr(existing_cidr) and self._cidr_overlaps(value, existing_cidr):
                return (False, f"{field_key}: overlaps with existing network {existing_cidr}")

        # Check against other configured parent CIDRs in CUSTOM mode.
        for other_key in cidr_fields:
            if other_key == field_key:
                continue
            other_cidr = (cfg.get(other_key, "") or "").strip()
            if other_cidr and self._is_valid_cidr(other_cidr) and self._cidr_overlaps(value, other_cidr):
                return (False, f"{field_key}: overlaps with {other_key} ({other_cidr})")

        return (True, "")

    def _validate_custom_field(self, field_key: str, value: str) -> Tuple[bool, str]:
        """Validate a custom field value. Returns (is_valid, error_message)."""
        value = value.strip()
        if not value:
            return (False, f"{field_key}: value required")
        
        cfg = self.config or self.last_good_config
        
        # CIDR fields (with /XX notation)
        if field_key == "PJALL_CIDR":
            if not self._is_valid_cidr(value):
                return (False, f"{field_key}: invalid CIDR format (e.g., 172.16.0.0/24)")
            if not self._is_network_aligned(value):
                return (False, self._network_alignment_error(field_key, value))
            if not self._is_private_ip(value.split('/')[0]):
                return (False, f"{field_key}: must be private IP range")
            is_ok, err = self._validate_cidr_conflicts(field_key, value, cfg)
            if not is_ok:
                return (False, err)
            return (True, "")
        
        elif field_key == "VPNDMZ_CIDR":
            if not self._is_valid_cidr(value):
                return (False, f"{field_key}: invalid CIDR format (e.g., 192.168.80.0/24)")
            if not self._is_network_aligned(value):
                return (False, self._network_alignment_error(field_key, value))
            if not self._is_private_ip(value.split('/')[0]):
                return (False, f"{field_key}: must be private IP range")
            try:
                prefix = int(value.split('/')[1])
                if prefix > 30:
                    return (False, f"{field_key}: minimum /30 required for gateway assignment")
            except (ValueError, IndexError):
                pass
            is_ok, err = self._validate_cidr_conflicts(field_key, value, cfg)
            if not is_ok:
                return (False, err)
            return (True, "")
        
        elif field_key == "VPN_POOL":
            if not self._is_valid_cidr(value):
                return (False, f"{field_key}: invalid CIDR format (e.g., 192.168.81.0/24)")
            if not self._is_network_aligned(value):
                return (False, self._network_alignment_error(field_key, value))
            if not self._is_private_ip(value.split('/')[0]):
                return (False, f"{field_key}: must be private IP range")
            is_ok, err = self._validate_cidr_conflicts(field_key, value, cfg)
            if not is_ok:
                return (False, err)
            return (True, "")
        
        # Host address fields (no /XX notation)
        elif field_key == "DNS_IP1":
            if not self._is_valid_ipv4(value):
                return (False, f"{field_key}: invalid IPv4 format (e.g., 192.168.77.254)")
            # DNS can be public or private
            return (True, "")
        
        elif field_key == "DNS_IP2":
            if not self._is_valid_ipv4(value):
                return (False, f"{field_key}: invalid IPv4 format (e.g., 192.168.77.254)")
            # DNS can be public or private
            return (True, "")
        
        elif field_key == "PT_IG_IP":
            if not self._is_valid_ipv4(value):
                return (False, f"{field_key}: invalid IPv4 format (e.g., 192.168.77.9)")
            if not self._is_private_ip(value):
                return (False, f"{field_key}: must be private IP address")
            # Check if within ML_CIDR and is valid host address
            if cfg and "ML_CIDR" in cfg and cfg["ML_CIDR"]:
                is_valid, error_msg = self._is_valid_host_address_in_subnet(value, cfg["ML_CIDR"])
                if not is_valid:
                    return (False, f"{field_key}: {error_msg}")
            # Check if same as ML_GW
            if cfg and "ML_GW" in cfg and cfg["ML_GW"] and value == cfg["ML_GW"]:
                return (False, f"{field_key}: cannot be same as ML_GW ({cfg['ML_GW']})")
            # Check if same as PVE_IP
            if cfg and "PVE_IP" in cfg and cfg["PVE_IP"] and value == cfg["PVE_IP"]:
                return (False, f"{field_key}: cannot be same as PVE_IP ({cfg['PVE_IP']})")
            return (True, "")
        
        elif field_key == "PT_EG_IP":
            if not self._is_valid_ipv4(value):
                return (False, f"{field_key}: invalid IPv4 format (e.g., 192.168.80.2)")
            if not self._is_private_ip(value):
                return (False, f"{field_key}: must be private IP address")
            # Check if within VPNDMZ_CIDR and is valid host address
            if cfg and "VPNDMZ_CIDR" in cfg and cfg["VPNDMZ_CIDR"]:
                is_valid, error_msg = self._is_valid_host_address_in_subnet(value, cfg["VPNDMZ_CIDR"])
                if not is_valid:
                    return (False, f"{field_key}: {error_msg}")
            # Check if same as VPNDMZ_GW
            if cfg and "VPNDMZ_GW" in cfg and cfg["VPNDMZ_GW"] and value == cfg["VPNDMZ_GW"]:
                return (False, f"{field_key}: cannot be same as VPNDMZ_GW ({cfg['VPNDMZ_GW']})")
            return (True, "")
        
        elif field_key == "VPNDMZ_GW":
            if not self._is_valid_ipv4(value):
                return (False, f"{field_key}: invalid IPv4 format (e.g., 192.168.80.1)")
            if not self._is_private_ip(value):
                return (False, f"{field_key}: must be private IP address")
            # Check if within VPNDMZ_CIDR and is valid host address
            if cfg and "VPNDMZ_CIDR" in cfg and cfg["VPNDMZ_CIDR"]:
                is_valid, error_msg = self._is_valid_host_address_in_subnet(value, cfg["VPNDMZ_CIDR"])
                if not is_valid:
                    return (False, f"{field_key}: {error_msg}")
            # Check if same as PT_EG_IP
            if cfg and "PT_EG_IP" in cfg and cfg["PT_EG_IP"] and value == cfg["PT_EG_IP"]:
                return (False, f"{field_key}: cannot be same as PT_EG_IP ({cfg['PT_EG_IP']})")
            return (True, "")
        
        return (True, "")

    def _commit_edit(self) -> None:
        if not self.edit_field:
            return
        
        # CUSTOM mode: save field value and recalculate derived fields
        if self.edit_field.startswith("custom_"):
            if self.edit_buffer:
                # Extract field index from edit_field (e.g., "custom_0" → 0)
                field_idx = int(self.edit_field.split("_")[1])
                if field_idx < len(self.custom_fields):
                    key = self.custom_fields[field_idx][0]
                    # Validate field value
                    is_valid, error_msg = self._validate_custom_field(key, self.edit_buffer)
                    if is_valid:
                        self.config[key] = self.edit_buffer
                        self.status = f"Saved {key}"
                        # Recalculate derived fields after custom field change
                        self._apply_port_ranges()
                    else:
                        self.status = f"{self.msg['status_error']}{error_msg}"
            self.edit_field = None
            self.edit_buffer = ""
            self.edit_cursor = 0
            return
        
        # AUTO mode: save port value
        if self.edit_buffer:
            value = int(self.edit_buffer)
            prev_ovpn = self.ovpn_start
            prev_wg = self.wg_start
            if self.edit_field == "ovpn":
                self.ovpn_start = value
            else:
                self.wg_start = value

            is_valid, error_msg = self._validate_ports()
            if not is_valid:
                self.ovpn_start = prev_ovpn
                self.wg_start = prev_wg
                self.status = f"{self.msg['status_error']}{error_msg}"
            else:
                self._apply_port_ranges()
                self.status = self.msg["status_ready"]
        self.edit_field = None
        self.edit_buffer = ""
        self.edit_cursor = 0

    def _exec_custom(self) -> None:
        try:
            # For CUSTOM mode, we still need to generate .env with edited values
            self.runner.generate_env(self.config)
            self._show_env_result(True)  # Show success dialog
            curses.endwin()
            script_path = os.path.join(SCRIPT_DIR, "0101_checkConfigNetwork.sh")
            os.execvp("bash", ["bash", script_path, self.lang])
        except Exception as exc:
            self._show_env_result(False, str(exc))  # Show failure dialog

    def run(self) -> None:
        # Check if .env file exists and ask to load
        env_path = os.path.join(SCRIPT_DIR, ".env")
        if os.path.isfile(env_path):
            # Show load dialog
            self._render()  # Initial render before showing dialog
            if self._show_load_env_dialog():
                # User wants to load .env
                if self._load_env_from_file():
                    # Successfully loaded
                    self.status = self.msg["status_ready"]
                else:
                    # Failed to load
                    self.status = f"{self.msg['status_error']}Failed to load configuration file"
            else:
                # User skipped loading
                self.status = self.msg["status_ready"]
        
        while True:
            self._render()
            ch = self.stdscr.getch()
            if not self._handle_key(ch):
                break


def _check_vmbr0_single_ipv4() -> None:
    """Check that vmbr0 has exactly one IPv4 address.
    
    Exit with error if none or multiple IPv4 addresses detected.
    """
    result = subprocess.run(
        ["bash", "-c", "ip -4 -o addr show dev vmbr0 scope global | awk '{print $4}'"],
        capture_output=True,
        text=True,
        cwd=SCRIPT_DIR
    )
    ips = [ip.strip() for ip in result.stdout.strip().split('\n') if ip.strip()]
    
    if len(ips) == 0:
        print()
        print("No IPv4 address detected on vmbr0.")
        print("MSL Setup cannot safely determine the management IP.")
        print("Please configure vmbr0 with one IPv4 address and run 00_configNetwork.sh again.")
        print()
        sys.exit(1)

    if len(ips) > 1:
        print()
        print("Detected multiple IPv4 addresses on vmbr0.")
        print("MSL Setup cannot safely determine which address is the intended management IP.")
        print("Please temporarily remove extra test/migration IPs and run 00_configNetwork.sh again.")
        print()
        sys.exit(1)


def _ensure_required_packages(lang: str) -> bool:
    """Ensure required system packages are installed via apt on Proxmox."""
    missing_cmds = [cmd for cmd in REQUIRED_CMD_PACKAGE_MAP if shutil.which(cmd) is None]
    if not missing_cmds:
        return True

    packages = sorted({REQUIRED_CMD_PACKAGE_MAP[cmd] for cmd in missing_cmds})
    env = os.environ.copy()
    env["DEBIAN_FRONTEND"] = "noninteractive"

    print()
    print(PACKAGE_INSTALL_PROGRESS_MESSAGES.get(lang, PACKAGE_INSTALL_PROGRESS_MESSAGES[LANG_EN]))
    print()

    try:
        subprocess.run(
            ["apt", "update", "-y"],
            capture_output=True,
            text=True,
            check=True,
            cwd=SCRIPT_DIR,
            env=env,
        )
        subprocess.run(
            ["apt", "install", "-y", *packages],
            capture_output=True,
            text=True,
            check=True,
            cwd=SCRIPT_DIR,
            env=env,
        )
    except subprocess.CalledProcessError as exc:
        stderr_text = (exc.stderr or "").strip()
        _mlog("ERROR", f"Failed to install required packages ({' '.join(packages)}): {stderr_text}")
        print()
        print(PACKAGE_INSTALL_FAILURE_MESSAGES.get(lang, PACKAGE_INSTALL_FAILURE_MESSAGES[LANG_EN]))
        print()
        return False

    still_missing = [cmd for cmd in REQUIRED_CMD_PACKAGE_MAP if shutil.which(cmd) is None]
    if still_missing:
        _mlog("ERROR", f"Required commands are still missing after installation: {' '.join(still_missing)}")
        print()
        print(PACKAGE_INSTALL_FAILURE_MESSAGES.get(lang, PACKAGE_INSTALL_FAILURE_MESSAGES[LANG_EN]))
        print()
        return False

    return True


def _load_or_create_system_uuid(lang: str) -> bool:
    """Load .uuid if exists, otherwise generate and persist a new UUID."""
    global MSL_SYSTEM_UUID

    if os.path.isfile(UUID_FILE_PATH):
        try:
            existing_uuid = ""
            with open(UUID_FILE_PATH, "r", encoding="utf-8") as f:
                existing_uuid = f.read().strip()
            if existing_uuid:
                MSL_SYSTEM_UUID = existing_uuid
                os.environ["MSL_UUID"] = MSL_SYSTEM_UUID
                return True
        except OSError as exc:
            _mlog("WARN", f"Failed to read .uuid file; regenerating UUID: {exc}")

    try:
        result = subprocess.run(
            ["uuidgen"],
            capture_output=True,
            text=True,
            check=True,
            cwd=SCRIPT_DIR,
        )
    except subprocess.CalledProcessError as exc:
        stderr_text = (exc.stderr or "").strip()
        _mlog("ERROR", f"Failed to generate UUID using uuidgen: {stderr_text}")
        print()
        print(UUID_GENERATE_FAILURE_MESSAGES.get(lang, UUID_GENERATE_FAILURE_MESSAGES[LANG_EN]))
        print()
        return False

    new_uuid = result.stdout.strip()
    if not new_uuid:
        _mlog("ERROR", "uuidgen returned empty output")
        print()
        print(UUID_GENERATE_FAILURE_MESSAGES.get(lang, UUID_GENERATE_FAILURE_MESSAGES[LANG_EN]))
        print()
        return False

    try:
        with open(UUID_FILE_PATH, "w", encoding="utf-8") as f:
            f.write(f"{new_uuid}\n")
    except OSError as exc:
        reason = str(exc)
        _mlog("ERROR", f"Failed to save .uuid file: {reason}")
        print()
        print(UUID_SAVE_FAILURE_MESSAGES.get(lang, UUID_SAVE_FAILURE_MESSAGES[LANG_EN]).format(reason=reason))
        print()
        return False

    MSL_SYSTEM_UUID = new_uuid
    os.environ["MSL_UUID"] = MSL_SYSTEM_UUID
    return True


def _post_start_probe(system_uuid: str) -> None:
    """Post startup probe event with UUID. Non-fatal on failures."""
    src_value = f"{system_uuid}_00_start"
    query = urllib.parse.urlencode({"src": src_value})
    endpoint = f"{PROBE_TOKEN_API_URL}?{query}"
    body = json.dumps({"magic": "ZELOGX"}).encode("utf-8")
    request = urllib.request.Request(
        endpoint,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    ssl_context = ssl._create_unverified_context()

    try:
        with urllib.request.urlopen(request, timeout=8, context=ssl_context) as response:
            _mlog("INFO", f"Probe token request sent successfully (status={response.status})")
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
        _mlog("WARN", f"Probe token request failed: {exc}")


def main() -> int:
    lang = LANG_EN
    if len(sys.argv) > 1:
        arg = sys.argv[1].strip().lower()
        if arg in (LANG_EN, LANG_JP):
            lang = arg
        else:
            print("Usage: ./0101_configNetwork.sh [en|jp]")
            return 1

    if not _ensure_required_packages(lang):
        return 1

    if not _load_or_create_system_uuid(lang):
        return 1

    _post_start_probe(MSL_SYSTEM_UUID)

    # Check vmbr0 has exactly one IPv4 before proceeding
    _check_vmbr0_single_ipv4()

    if _check_ceph_installed():
        _show_ceph_notice(lang)

    def _run(stdscr: "curses._CursesWindow") -> None:
        app = TUIApp(stdscr, lang)
        app.run()

    try:
        curses.wrapper(_run)
    except KeyboardInterrupt:
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
