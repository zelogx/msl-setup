# ARCHITECTURE AND DESIGN PRINCIPLES

## What You Get
### Engineer’s Perspective

On a single Proxmox VE server or across a Proxmox cluster:

- Fully isolated Layer 2 project networks with dedicated VPN-secured access.
- Safe remote exposure of each project environment to teammates without putting your existing corporate or home LAN at risk.
- A zero-trust design in which no traffic other than VPN tunnels and DNS queries traverses the existing LAN.
- Automated VPN client provisioning, including user assignment, client certificate generation, and user management through the Pritunl GUI.
- Per-project VPN server control from the GUI, with support for both OpenVPN and WireGuard.
- No enterprise-grade network equipment supporting VLAN, ECMP, or BGP is required.
- **Corporate Edition only:** A self-care portal that enables project members, including VPN users, to manage VMs, snapshots, and backups within their own project network without administrator assistance.

### Manager's Perspective

- Grant access **only to what each partner/freelancer needs**, preventing cross-project leaks by design.
- Build a **private development cloud** for small/mid-size software firms or startups.
- Scalable from a single Proxmox node to a multi-node cluster, allowing low-cost adoption first and expansion later as needed.
- Safer, faster, and cheaper than giving developers full cloud freedom.
- Entirely open-source — all you need is **one small server (even a NUC)** and \~¥1,000/month for electricity.
- No vendor lock-in, no subscription required.

> Enterprise-grade solutions with similar capabilities are typically positioned at a significantly higher cost range.\
> This achieves the same goal for (almost) zero cost.

## Motivation

### The Problem: The "Flat Network" Trap in Proxmox

When I needed to share my Proxmox development environment with team members over VPN, I ran into a familiar set of problems:

- **Visibility vs. Privacy**: A typical VPN setup tends to expose too much. I wanted each team member to see their own project VMs, but not my personal lab, other clients' environments, or the host infrastructure.
- **Management Overhead**: Manually issuing, revoking, and organizing VPN profiles for multiple users across multiple projects does not scale. It’s tedious and error-prone.
- **The Isolation Gap**: Proxmox is powerful, but achieving true L2 isolation between “tenants” while still keeping VPN access simple usually means hand-rolling SDN + firewall rules. Repeating that setup reliably is hard.

### The Solution: Building the "Multiverse"

I went looking for a tool that could:

- Spin up a secure, isolated "bubble" (a tenant) per project
- Attach a dedicated VPN gateway to that bubble
- Handle the boilerplate around VPN profile management

I couldn’t find it.

So I built **Zelogx MSL Setup**.

Zelogx turns Proxmox VE into a multi-tenant lab platform.
From a single node to a cluster, it enables isolated project networks that can scale seamlessly across multiple hosts while maintaining strict tenant isolation.
It’s aimed at engineers who need to give secure, isolated access to specific resources without exposing the rest of their infrastructure.

## Architecture Benefits

### High Availability, Scalability, and Maintainability
- With floating VTEP, even if the node hosting the VXLAN gateway fails, the gateway can be automatically taken over by another node.
- The Pritunl VM can also be configured for HA by combining shared storage with Proxmox HA as needed. However, client reconnection is required when a node failure occurs.
- With Proxmox HA, connectivity to isolated networks can be maintained even when a VM / CT fails over to another node.
- This makes it possible to achieve a configuration that is easier to operate continuously, even without dedicated enterprise-grade networking equipment.

## Engineering Principles

### Pre-configuration over Runtime Overhead

Zelogx MSL Setup is designed as a **pre-configuration tool**.

- **No long-running daemons**: All SDN objects, isolation rules, and VPN gateways are provisioned up front.
- **Stable after setup**: Once the setup is complete, the configuration is applied directly to Proxmox. There is no separate Zelogx service whose failure would change the security characteristics of the isolated network.

### Pritunl Automation (VPN Provisioning)

The VPN side is fully automated using the official Pritunl HTTP API.

During the VPN setup phase, MSL Setup:

1. Boots the Pritunl VM via cloud-init.
2. Waits for the Pritunl service to become ready.
3. Uses the Pritunl API (key/secret configured inside the VM) to:
   - Create **Organizations** for projects.
   - Create the required **Servers** (OpenVPN / WireGuard)
   - **Attach Organizations to Servers**
   - **Start** the configured Servers

No web UI automation is involved — everything is provisioned through the documented REST API.

From the Proxmox host’s perspective, the Pritunl VM is treated as a black box VPN gateway:
- Proxmox SDN and nftables handle routing and isolation.
- Pritunl’s own API is used only inside that VM to define tunnel endpoints and access control.

## Comparison: Alternatives for personal / small office Proxmox multi-tenant setups

Several approaches exist for building multi-tenant environments on Proxmox.
The following table summarizes the practical differences.

| Method                 | Learning Curve | Network Isolation | Automation      | Individual-Friendly |
| ---------------------- | -------------- | ----------------- | --------------- | ------------------- |
| RBAC + Resource Pools  | **Medium**     | None              | GUI only        | Limited             |
| SDN + OPNsense         | **Very High**  | Strong            | Manual setup    | Partial             |
| **MSL Setup Basic**    | **Low**        | Strong            | Manual (Guided) setup | Excellent          |
| **MSL Setup Personal** | **Extremely Low** | Strong            | Fully automated | Excellent           |

For a deeper explanation of each approach, see the [Proxmox Multi-tenant Guide](https://github.com/zelogx/msl-setup/wiki/Proxmox-Multi%E2%80%90tenant-Guide).

## Target Audience

- “We already let our developers freely spin up AWS instances and build fast, distributed development environments. Costs and security? Well… when someone asks about that, management at a small software house just looks over at the person in charge for help.”
- “I already have my own development/lab environment at home, so I spin up VMs there and develop aggressively. Other team members? I assume they’re each figuring things out in their own way.”  
  Environments like this often lack any consistent security policy or operational control.
- “These days I use WSL and run Linux VMs on my Windows PC. Security if I lose my PC? BitLocker should take care of it… probably.”  
  Everyone develops in different environments, and integration testing ends up taking much longer than it should.
- “Even in large enterprises, sure. The servers are in a server room with strict physical access control. Basically, no personal data is stored in the development environment. We also have NDAs with everyone, of course. And naturally, access is only allowed through VDI. But the root password is the same on every VM. And they’re all on the same segment, so if someone really wanted to log into another VM… they probably could.”  
  Organizations like this still tolerate multiple project VMs sharing the same flat network.
- “Likewise in large enterprises, each project that needs it has its own VPN. If someone can log into one VM, could they get into others too? I haven’t checked, but I don’t think so. We’ve never had that kind of incident so far. Plus, we conduct security training twice a year.”  
  In organizations like this, security still depends more on habit and trust than on enforced mechanisms.

MSL Setup addresses these issues by introducing per-project isolation, dedicated VPN access, and built-in structural guardrails on top of Proxmox.

