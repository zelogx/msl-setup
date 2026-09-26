#!/usr/bin/env python3
################################################################################
# Zelogx™ Multi-Project Secure Lab Setup
#
# © 2026 Zelogx. Zelogx™ and the Zelogx logo are trademarks
# of the Zelogx Project. All other marks are property of their respective owners.
#
# Filename: pritunl_build_helper.py
# Purpose: Helper run inside the Pritunl VM: network validation and
#          MongoDB-based VPN server creation
#
# Main functions/commands used:
#   - ip/ping/curl/nc/jq/timeout: VM validation checks
#   - mongosh/openssl: MongoDB-based server creation
#
# Dependencies:
#   - python3 (standard library only; runs with the VM's system python3)
#   - /root/.env: Environment configuration file (validate mode)
#   - External commands (validate): ip, ping, curl, jq, nc, timeout, nslookup
#   - External tools (mongodb): mongosh, openssl (local on VM)
#
# Usage:
#   python3 pritunl_build_helper.py validate
#   python3 pritunl_build_helper.py mongodb --vm-ip <IP> --env <path> [--workers N]
#   Copied to the VM and run there by 0201_createPritunlVM.sh (validate) and
#   lib/pritunl_installers/<id>/vm_install.sh (mongodb).
################################################################################

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union

# -----------------------------------------------------------------------------
# Validation (formerly validate.py)
# -----------------------------------------------------------------------------

ENV_PATH = "/root/.env"
LOG_FILE = "/var/log/pritunl_vm_validation.log"


################################################################################
# Function: run_cmd
# Description: Run an external command and return rc, stdout, stderr
#
# Main commands/functions used:
#   - subprocess.run: Execute external commands
################################################################################
def run_cmd(cmd: Union[str, List[str]], timeout: Optional[int] = None, shell: bool = None) -> Tuple[int, str, str]:
    # Auto-detect shell mode: if cmd is string, use shell=True; if list, use shell=False
    if shell is None:
        shell = isinstance(cmd, str)
    
    result = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
        check=False,
        shell=shell,
    )
    return result.returncode, result.stdout, result.stderr


################################################################################
# Function: start_cmd
# Description: Start a background command and return Popen object
#
# Main commands/functions used:
#   - subprocess.Popen: Start background process
################################################################################
def start_cmd(cmd: List[str], stdout_path: Optional[str] = None) -> subprocess.Popen:
    stdout_handle = None
    if stdout_path:
        stdout_handle = open(stdout_path, "w", encoding="utf-8")
    return subprocess.Popen(
        cmd,
        stdout=stdout_handle or subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        text=True,
    )


################################################################################
# Function: log_message
# Description: Output message to both console and log file
#
# Main commands/functions used:
#   - print: Display to console
#   - file write: Append to log file
################################################################################
def log_message(msg: str) -> None:
    print(msg, flush=True)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"{msg}\n")


################################################################################
# Function: load_env
# Description: Load environment variables from .env file
#
# Main commands/functions used:
#   - open: Read file
################################################################################
def load_env(path: str) -> Dict[str, str]:
    if not os.path.isfile(path):
        print(f"ERROR: {path} not found")
        sys.exit(1)

    env: Dict[str, str] = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip()

    os.environ.update(env)
    return env


################################################################################
# Function: get_env
# Description: Get environment variable with required check
#
# Main commands/functions used:
#   - os.environ: Access environment variables
################################################################################
def get_env(name: str, required: bool = True) -> Optional[str]:
    value = os.environ.get(name)
    if required and (value is None or value == ""):
        print(f"ERROR: Required variable {name} is not set in {ENV_PATH}")
        sys.exit(1)
    return value


################################################################################
# Function: check_nics
# Description: Verify both NIC IPs are configured
#
# Main commands/functions used:
#   - ip addr show: Display interface addresses
################################################################################
def check_nics(pt_ig_ip: str, pt_eg_ip: str) -> bool:
    rc, out, err = run_cmd(["ip", "-4", "addr", "show"])
    if rc != 0:
        print(f"ERROR: Failed to run ip addr show: {err.strip()}")
        return False

    nic0_lines = [line for line in out.splitlines() if re.search(rf"\b{re.escape(pt_ig_ip)}\b", line)]
    nic1_lines = [line for line in out.splitlines() if re.search(rf"\b{re.escape(pt_eg_ip)}\b", line)]

    if len(nic0_lines) == 0:
        print(f"ERROR: NIC0 (MainLAN) IP {pt_ig_ip} not configured")
        return False

    if len(nic1_lines) == 0:
        print(f"ERROR: NIC1 (vpndmzvn) IP {pt_eg_ip} not configured")
        return False

    print(f"OK: Both NICs configured correctly (NIC0: {pt_ig_ip}, NIC1: {pt_eg_ip})")
    return True


################################################################################
# Function: check_dns
# Description: Verify DNS resolution is working via actual name lookup
#
# Main commands/functions used:
#   - nslookup: Perform DNS resolution test
################################################################################
def check_dns() -> bool:
    if not shutil.which("nslookup"):
        print("WARNING: nslookup not available, skipping DNS resolution test")
        return True

    rc, _, _ = run_cmd(["nslookup", "google.com"])
    if rc != 0:
        print("ERROR: DNS resolution failed (nslookup google.com)")
        return False

    print("OK: DNS resolution working (nslookup google.com)")
    return True


################################################################################
# Function: check_default_route
# Description: Verify default gateway is set correctly
#
# Main commands/functions used:
#   - ip route show: Display routing table
################################################################################
def check_default_route(ml_gw: str) -> bool:
    rc, out, err = run_cmd(["ip", "route", "show", "default"])
    if rc != 0:
        print(f"ERROR: Failed to run ip route show default: {err.strip()}")
        return False

    gw = ""
    for line in out.splitlines():
        parts = line.split()
        if "default" in parts and "via" in parts:
            try:
                gw = parts[parts.index("via") + 1]
                break
            except (ValueError, IndexError):
                continue

    if not gw:
        print("ERROR: No default gateway configured")
        return False

    if gw != ml_gw:
        print(f"ERROR: Default gateway is {gw}, expected {ml_gw}")
        return False

    print(f"OK: Default route via {ml_gw}")
    return True


################################################################################
# Function: check_udp_port_forwarding
# Description: Verify UDP port forwarding using external probe server
#
# Main commands/functions used:
#   - curl: Call external API to trigger UDP probe
#   - nc: Listen for incoming UDP packets
################################################################################
def check_udp_port_forwarding(
    pf_st_ov: int,
    pf_ed_ov: int,
    pf_st_wg: int,
    pf_ed_wg: int,
    pt_ig_ip: str,
) -> bool:
    api_base = "https://msl-setup-probe.zelogx.com"
    magic = "ZELOGX"
    log_dir = "/tmp/udp_probe_logs"
    failed = 0
    nc_procs: List[subprocess.Popen] = []

    log_message(
        f"Checking UDP port forwarding (OpenVPN: {pf_st_ov}-{pf_ed_ov}, WireGuard: {pf_st_wg}-{pf_ed_wg})..."
    )

    if not shutil.which("jq"):
        log_message("  ERROR: jq not installed (required for UDP probe)")
        return False

    if not shutil.which("nc"):
        log_message("  ERROR: nc (netcat) not installed (required for UDP probe)")
        return False

    os.makedirs(log_dir, exist_ok=True)

    def cleanup_nc() -> None:
        for proc in nc_procs:
            if proc.poll() is None:
                try:
                    proc.terminate()
                except Exception:
                    pass

    udp_ports = list(range(pf_st_ov, pf_ed_ov + 1)) + list(range(pf_st_wg, pf_ed_wg + 1))

    log_message("  Step 1: Requesting token from probe server...")
    payload = json.dumps({"magic": magic})
    rc, out, err = run_cmd(
        [
            "curl",
            "-4",
            "-k",
            "-s",
            "-w",
            "\n%{http_code}",
            "-X",
            "POST",
            f"{api_base}/api/v1/get_token",
            "-H",
            "Content-Type: application/json",
            "-d",
            payload,
        ]
    )
    token_response = (out + err).strip()
    if not token_response:
        log_message("  ERROR: No response from probe server")
        return False

    parts = token_response.splitlines()
    http_code = parts[-1] if parts else ""
    body = "\n".join(parts[:-1]) if len(parts) > 1 else ""

    if http_code != "200":
        log_message(f"  ERROR: HTTP {http_code} from probe server")
        log_message(f"  Response: {body}")
        return False

    try:
        token = json.loads(body).get("token")
    except Exception:
        token = None

    if not token:
        log_message("  ERROR: Failed to parse token from response")
        log_message(f"  Response body: {body}")
        return False

    log_message(f"  OK: Token received (HTTP {http_code})")

    log_message(f"  Step 2: Starting UDP listeners on ports {udp_ports}...")
    for port in udp_ports:
        log_file = f"{log_dir}/udp_{port}.log"
        Path(log_file).write_text("", encoding="utf-8")
        proc = start_cmd(["timeout", "10", "nc", "-u", "-l", "-p", str(port)], stdout_path=log_file)
        nc_procs.append(proc)
        log_message(f"    Listening on UDP port {port} (PID: {proc.pid})")

    time.sleep(1)

    log_message("  Step 3: Triggering UDP probe from server...")
    probe_payload = json.dumps({"magic": magic, "token": token, "ports": udp_ports})
    rc, out, err = run_cmd(
        [
            "curl",
            "-4",
            "-k",
            "-s",
            "-X",
            "POST",
            f"{api_base}/api/v1/udp_probe",
            "-H",
            "Content-Type: application/json",
            "-d",
            probe_payload,
        ]
    )
    probe_response = (out + err).strip()
    try:
        probe_status = json.loads(probe_response).get("status")
    except Exception:
        probe_status = None

    if probe_status != "ok":
        log_message(f"  ERROR: Probe request failed: {probe_response}")
        cleanup_nc()
        return False

    log_message("  OK: Probe request sent, waiting for UDP packets...")

    time.sleep(5)

    log_message("  Step 4: Verifying received UDP packets...")
    for port in udp_ports:
        log_file = f"{log_dir}/udp_{port}.log"
        if not os.path.isfile(log_file):
            log_message(f"    Port {port}: ERROR - Log file not found")
            failed += 1
            continue

        content = Path(log_file).read_text(encoding="utf-8", errors="ignore")
        if "ZELOGX" not in content:
            log_message(f"    Port {port}: ERROR - No 'ZELOGX' packet received")
            failed += 1
        else:
            packet_count = content.count("ZELOGX")
            log_message(f"    Port {port}: OK - Received {packet_count} packet(s)")

    cleanup_nc()

    if failed > 0:
        log_message(f"  ERROR: UDP port forwarding validation failed ({failed} ports)")
        log_message("  Please verify router port forwarding configuration:")
        log_message(f"    - OpenVPN: UDP ports {pf_st_ov}-{pf_ed_ov} → {pt_ig_ip}")
        log_message(f"    - WireGuard: UDP ports {pf_st_wg}-{pf_ed_wg} → {pt_ig_ip}")
        return False

    log_message("  OK: All UDP ports forwarding correctly")
    return True


################################################################################
# Function: check_static_routes
# Description: Verify static routes to all project networks
#
# Main commands/functions used:
#   - ip route show: Display routing table
################################################################################
def check_static_routes(pjall_cidr: str, vpndmz_gw: str, env_data: Dict[str, str]) -> bool:
    pj_cidrs = [v for k, v in env_data.items() if re.match(r"^PJ\d{2}_CIDR$", k)]

    if not pj_cidrs:
        print("WARNING: No project CIDRs found in .env")
        return True

    print("Checking static routes to project networks...")
    rc, out, err = run_cmd(["ip", "route", "show", pjall_cidr])
    route_exists = ("via " + vpndmz_gw) in (out + err)

    if not route_exists:
        print(f"  ERROR: Static route to {pjall_cidr} via {vpndmz_gw} not found")
        print(f"  Route table output for {pjall_cidr}:")
        for line in (out + err).splitlines():
            print(f"    {line}")
        return False

    print(f"  OK: Static route to {pjall_cidr} via {vpndmz_gw}")
    return True


################################################################################
# Function: check_gateway_reachability
# Description: Verify all gateways are reachable via ICMP
#
# Main commands/functions used:
#   - ping: Test ICMP connectivity
################################################################################
def check_gateway_reachability(ml_gw: str, vpndmz_gw: str, env_data: Dict[str, str]) -> bool:
    failed = 0

    print("Checking gateway reachability...")

    rc, _, _ = run_cmd(["ping", "-c", "3", "-W", "5", ml_gw])
    if rc != 0:
        print(f"  ERROR: Cannot ping default gateway {ml_gw} (MainLAN)")
        failed += 1
    else:
        print(f"  OK: Default gateway {ml_gw} reachable")

    rc, _, _ = run_cmd(["ping", "-c", "3", "-W", "5", vpndmz_gw])
    if rc != 0:
        print(f"  ERROR: Cannot ping vpndmzvn gateway {vpndmz_gw}")
        failed += 1
    else:
        print(f"  OK: vpndmzvn gateway {vpndmz_gw} reachable")

    pj_gws = [v for k, v in env_data.items() if re.match(r"^PJ\d{2}_GW$", k)]
    for gw in pj_gws:
        rc, _, _ = run_cmd(["ping", "-c", "3", "-W", "5", gw])
        if rc != 0:
            print(f"  WARNING: Cannot ping project gateway {gw} (may not be configured yet)")
        else:
            print(f"  OK: Project gateway {gw} reachable")

    return failed == 0


################################################################################
# Function: check_internet_icmp
# Description: Verify internet connectivity via ICMP
#
# Main commands/functions used:
#   - ping: Test ICMP to public IP
################################################################################
def check_internet_icmp() -> bool:
    rc, _, _ = run_cmd(["ping", "-c", "3", "-W", "5", "1.1.1.1"])
    if rc != 0:
        print("ERROR: Cannot ping 1.1.1.1 (internet connectivity)")
        return False

    print("OK: Internet connectivity (ICMP to 1.1.1.1)")
    return True


################################################################################
# Function: check_dns_resolution
# Description: Verify DNS resolution is working
#
# Main commands/functions used:
#   - ping: Test DNS resolution + connectivity
################################################################################
def check_dns_resolution() -> bool:
    rc, _, _ = run_cmd(["ping", "-c", "3", "-W", "5", "google.com"])
    if rc != 0:
        print("ERROR: Cannot resolve google.com (DNS resolution)")
        return False

    print("OK: DNS resolution working")
    return True


################################################################################
# Function: run_validate
# Description: Entry point for VM validation
################################################################################
def run_validate(_: argparse.Namespace) -> int:
    env_data = load_env(ENV_PATH)

    pt_ig_ip = get_env("PT_IG_IP")
    pt_eg_ip = get_env("PT_EG_IP")
    ml_gw = get_env("ML_GW")
    vpndmz_gw = get_env("VPNDMZ_GW")
    pf_st_ov = int(get_env("PF_ST_OV"))
    pf_ed_ov = int(get_env("PF_ED_OV"))
    pf_st_wg = int(get_env("PF_ST_WG"))
    pf_ed_wg = int(get_env("PF_ED_WG"))
    pjall_cidr = get_env("PJALL_CIDR")
    dns_ip1 = get_env("DNS_IP1")
    dns_ip2 = get_env("DNS_IP2", required=False) or "none"

    print("============================================")
    print("Pritunl VM Validation")
    print("============================================")
    print("Loaded configuration:")
    print(f"  PT_IG_IP: {pt_ig_ip} (MainLAN)")
    print(f"  PT_EG_IP: {pt_eg_ip} (vpndmzvn)")
    print(f"  ML_GW: {ml_gw}")
    print(f"  VPNDMZ_GW: {vpndmz_gw}")
    print(f"  DNS_IP1: {dns_ip1}")
    print(f"  DNS_IP2: {dns_ip2}")
    print("")

    failed = 0

    if not check_nics(pt_ig_ip, pt_eg_ip):
        failed += 1
    if not check_dns():
        failed += 1
    if not check_default_route(ml_gw):
        failed += 1

    if os.path.isfile("/root/demo"):
        if not check_udp_port_forwarding(pf_st_ov, pf_ed_ov, pf_st_wg, pf_ed_wg, pt_ig_ip):
            print("=== Errors at this step are intentionally ignored for demo purposes. ===")
    else:
        if not check_udp_port_forwarding(pf_st_ov, pf_ed_ov, pf_st_wg, pf_ed_wg, pt_ig_ip):
            failed += 1

    if not check_static_routes(pjall_cidr, vpndmz_gw, env_data):
        failed += 1
    if not check_gateway_reachability(ml_gw, vpndmz_gw, env_data):
        failed += 1
    if not check_internet_icmp():
        failed += 1
    if not check_dns_resolution():
        failed += 1

    print("")
    print("============================================")
    if failed == 0:
        print("Result: All validation checks PASSED")
        print("============================================")
        return 0

    print(f"Result: {failed} validation check(s) FAILED")
    print("============================================")
    return 1


# -----------------------------------------------------------------------------
# Logging (used by the MongoDB server creation)
# -----------------------------------------------------------------------------

################################################################################
# Function: log_info
# Description: Print an informational log message to stderr
################################################################################
def log_info(message: str) -> None:
    print(f"[INFO] {message}", file=sys.stderr)


################################################################################
# Function: log_error
# Description: Print an error log message to stderr
################################################################################
def log_error(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)



# -----------------------------------------------------------------------------
# MongoDB Server Creation (formerly pritunl_servers_mongodb.py)
# -----------------------------------------------------------------------------

################################################################################
# Function: log_warn
# Description: Print a warning log message to stderr
################################################################################
def log_warn(message: str) -> None:
    print(f"[WARN] {message}", file=sys.stderr)


################################################################################
# Function: read_env_mongodb
# Description: Read key-value pairs from a .env file
################################################################################
def read_env_mongodb(env_path: str) -> Dict[str, str]:
    env: Dict[str, str] = {}
    with open(env_path, "r", encoding="utf-8") as env_file:
        for line in env_file:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[len("export ") :]
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()
            if value.startswith("\"") and value.endswith("\""):
                value = value[1:-1]
            elif value.startswith("'") and value.endswith("'"):
                value = value[1:-1]
            env[key] = value
    return env


@dataclass(frozen=True)
class ServerConfig:
    index: int
    idx_str: str
    server_name: str
    ovpn_pool: str
    wg_pool: str
    route: str
    port: int
    port_wg: int


################################################################################
# Function: build_server_configs
# Description: Build per-server configuration from .env variables
################################################################################
def build_server_configs(env: Dict[str, str]) -> List[ServerConfig]:
    num_pj = int(env["NUM_PJ"])
    pf_st_ov = int(env["PF_ST_OV"])
    pf_st_wg = int(env["PF_ST_WG"])

    configs: List[ServerConfig] = []
    for i in range(1, num_pj + 1):
        idx_str = f"{i:02d}"
        ovpn_pool = env[f"OVPN_POOL{i}"]
        wg_pool = env[f"WG_POOL{i}"]
        route = env[f"PJ{idx_str}_CIDR"]
        configs.append(
            ServerConfig(
                index=i,
                idx_str=idx_str,
                server_name=f"Server{idx_str}",
                ovpn_pool=ovpn_pool,
                wg_pool=wg_pool,
                route=route,
                port=pf_st_ov + (i - 1),
                port_wg=pf_st_wg + (i - 1),
            )
        )
    return configs


################################################################################
# Function: create_server
# Description: Create a single Pritunl server document via MongoDB
#
# Main commands/functions used:
#   - mongosh/openssl: Run on the VM
#   - json: Build MongoDB insert document
################################################################################
def create_server(
    vm_ip: str,
    host_id: str,
    pt_ig_ip: str,
    dns_ip1: str,
    config: ServerConfig,
) -> Tuple[str, bool, str]:
    try:
        rc, dh_params, dh_err = run_cmd("openssl dhparam 2048")
        if rc != 0 or not dh_params.strip():
            return (config.idx_str, False, f"DH params generation failed: {dh_err}")

        server_doc = {
            "bind_address": pt_ig_ip,
            "block_outside_dns": False,
            "ca_certificate": "",
            "cipher": "aes128",
            "debug": False,
            "device_auth": False,
            "dh_param_bits": 2048,
            "dh_params": dh_params,
            "dns_mapping": False,
            "dns_servers": ["1.1.1.1"],
            "dynamic_firewall": False,
            "force_connect": False,
            "fragment": None,
            "geo_sort": False,
            "groups": [],
            "hash": "sha1",
            "hosts": [host_id],
            "inactive_timeout": None,
            "instances": [],
            "instances_count": 0,
            "inter_client": False,
            "ipv6": False,
            "ipv6_firewall": True,
            "jumbo_frames": False,
            "link_ping_interval": 1,
            "link_ping_timeout": 5,
            "links": [],
            "lzo_compression": False,
            "max_clients": 2000,
            "max_devices": 0,
            "mss_fix": None,
            "multi_device": False,
            "multihome": False,
            "name": config.server_name,
            "network": config.ovpn_pool,
            "network_end": "",
            "network_mode": "tunnel",
            "network_start": "",
            "network_wg": config.wg_pool,
            "organizations": [],
            "otp_auth": False,
            "ping_interval": 10,
            "ping_interval_wg": 30,
            "ping_timeout": 60,
            "ping_timeout_wg": 120,
            "port": config.port,
            "port_wg": config.port_wg,
            "pre_connect_msg": None,
            "primary_organization": None,
            "primary_user": None,
            "protocol": "udp",
            "replica_count": 1,
            "restrict_routes": True,
            "route_dns": False,
            "routes": [
                {
                    "network": config.route,
                    "comment": f"Project {config.idx_str} network",
                    "metric": None,
                    "nat": False,
                    "nat_interface": None,
                    "nat_netmap": None,
                    "advertise": False,
                    "vpc_region": None,
                    "vpc_id": None,
                    "net_gateway": False,
                    "server_link": False,
                }
            ],
            "search_domain": None,
            "session_timeout": None,
            "sso_auth": False,
            "start_timestamp": None,
            "status": "offline",
            "tls_auth": True,
            "tun_mtu": None,
            "vxlan": True,
            "wg": True,
            "pool_cursor": None,
            "allowed_devices": None,
            "availability_group": None,
        }

        insert_js = "db.servers.insertOne(" + json.dumps(server_doc, separators=(",", ":")) + ")"
        insert_cmd = "mongosh pritunl --quiet --eval " + shlex.quote(insert_js)
        rc, insert_out, insert_err = run_cmd(insert_cmd)
        if rc != 0:
            return (config.idx_str, False, f"Insert failed: {insert_err}")
        return (config.idx_str, True, "")
    except Exception as exc:
        return (config.idx_str, False, str(exc))


################################################################################
# Function: validate_env_mongodb
# Description: Validate required .env variables for server creation
################################################################################
def validate_env_mongodb(env: Dict[str, str]) -> None:
    required_keys = [
        "NUM_PJ",
        "PF_ST_OV",
        "PF_ST_WG",
        "PT_IG_IP",
        "DNS_IP1",
    ]
    missing = [key for key in required_keys if key not in env or env[key] == ""]

    if "NUM_PJ" in env:
        num_pj = int(env["NUM_PJ"])
        for i in range(1, num_pj + 1):
            idx_str = f"{i:02d}"
            dynamic_keys = [
                f"OVPN_POOL{i}",
                f"WG_POOL{i}",
                f"PJ{idx_str}_CIDR",
            ]
            for key in dynamic_keys:
                if key not in env or env[key] == "":
                    missing.append(key)
    if missing:
        raise ValueError(f"Missing required .env variables: {', '.join(sorted(set(missing)))}")


################################################################################
# Function: run_mongodb
# Description: Entry point for MongoDB-based Pritunl server creation
################################################################################
def run_mongodb(args: argparse.Namespace) -> int:
    env_path = os.path.abspath(args.env)
    if not os.path.isfile(env_path):
        log_error(f".env file not found: {env_path}")
        return 1

    env = read_env_mongodb(env_path)
    try:
        validate_env_mongodb(env)
    except ValueError as exc:
        log_error(str(exc))
        return 1

    num_pj = int(env["NUM_PJ"])
    workers = args.workers if args.workers > 0 else min(num_pj, os.cpu_count() or 1)
    if workers < 1:
        workers = 1

    log_info("Stopping Pritunl service...")
    try:
        returncode, stdout, stderr = run_cmd("systemctl is-active --quiet pritunl && systemctl stop pritunl")
        if returncode != 0:
            log_warn(f"Pritunl service not active or stop failed (rc={returncode})")
    except Exception as exc:
        log_error(f"Failed to stop Pritunl service: {exc}")
        return 1

    log_info("Retrieving Host ID...")
    try:
        returncode, stdout, stderr = run_cmd("pritunl get-host-id")
        if returncode != 0:
            log_error(f"pritunl get-host-id failed: {stderr}")
            return 1
        host_id = stdout.strip()
    except Exception as exc:
        log_error(f"Failed to retrieve Host ID: {exc}")
        return 1

    if not host_id:
        log_error("Host ID is empty")
        return 1

    log_info(f"Host ID: {host_id}")

    configs = build_server_configs(env)
    log_info(f"Generating {num_pj} Pritunl VPN servers with {workers} workers...")

    success = True
    completed = 0

    try:
        with ProcessPoolExecutor(max_workers=workers) as executor:
            futures = [
                executor.submit(
                    create_server,
                    args.vm_ip,
                    host_id,
                    env["PT_IG_IP"],
                    env["DNS_IP1"],
                    config,
                )
                for config in configs
            ]

            for future in as_completed(futures):
                idx_str, ok, detail = future.result()
                completed += 1
                if ok:
                    log_info(f"Server {idx_str} created ({completed}/{num_pj})")
                else:
                    success = False
                    log_error(f"Server {idx_str} failed: {detail}")
    finally:
        log_info("Restarting Pritunl service...")
        try:
            returncode, stdout, stderr = run_cmd("systemctl start pritunl")
            if returncode != 0:
                log_warn(f"Pritunl service start failed: {stderr}")
        except Exception as exc:
            log_error(f"Failed to restart Pritunl service: {exc}")

    if not success:
        return 1

    log_info("Verifying server insertion...")
    try:
        count_js = "db.servers.countDocuments({})"
        count_cmd = f"mongosh pritunl --quiet --eval {shlex.quote(count_js)}"
        rc, count_out, count_err = run_cmd(count_cmd)
        if rc != 0:
            log_error(f"mongosh count failed: {count_err}")
            return 1
        count = count_out.strip()
        log_info(f"Server count in database: {count}")
        if str(count) != str(num_pj):
            log_warn(f"Expected {num_pj} servers, but found {count}")
    except Exception as exc:
        log_error(f"Failed to count servers: {exc}")
        return 1

    log_info("Verifying NAT is disabled for all servers...")
    try:
        nat_js = (
            'db.servers.find({"routes.nat": true}, {name: 1, "routes.nat": 1}).pretty()'
        )
        nat_cmd = f"mongosh pritunl --quiet --eval {shlex.quote(nat_js)}"
        rc, nat_enabled, nat_err = run_cmd(nat_cmd)
        if rc != 0:
            log_warn(f"NAT check failed: {nat_err}")
        else:
            nat_enabled = nat_enabled.strip()
            if nat_enabled and nat_enabled != "{}":
                log_warn("Some servers have NAT enabled (should be disabled)")
                log_warn(nat_enabled)
            else:
                log_info("NAT verified as disabled for all servers")
    except Exception as exc:
        log_error(f"Failed to verify NAT settings: {exc}")
        return 1

    log_info("MongoDB server insertion completed")
    return 0


# -----------------------------------------------------------------------------
# Main entry
# -----------------------------------------------------------------------------

################################################################################
# Function: main
# Description: CLI entry point for helper subcommands
################################################################################
def main() -> int:
    parser = argparse.ArgumentParser(
        description="Unified helper for validation and Pritunl setup tasks"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate", help="Run VM validation")
    validate_parser.set_defaults(func=run_validate)

    mongodb_parser = subparsers.add_parser("mongodb", help="Create VPN servers via MongoDB")
    mongodb_parser.add_argument("--vm-ip", required=True, help="Pritunl VM IP address")
    mongodb_parser.add_argument(
        "--env",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"),
        help="Path to .env file",
    )
    mongodb_parser.add_argument(
        "--workers",
        type=int,
        default=0,
        help="Number of worker processes (default: CPU count or NUM_PJ)",
    )
    mongodb_parser.set_defaults(func=run_mongodb)

    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    # Force line-buffered stdout so output appears in real-time even without a TTY
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        try:
            import io
            sys.stdout = io.TextIOWrapper(sys.stdout.buffer, line_buffering=True)
        except Exception:
            pass

    sys.exit(main())
