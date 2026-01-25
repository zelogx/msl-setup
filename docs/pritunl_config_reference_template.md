# Pritunl Manual Configuration Reference
<sup>

**Generated**: Thu Dec  4 03:02:46 PM JST 2025  

## Next Steps to finalize initial configuration.

1. Access the Pritunl GUI using the URL https://${PT_IG_IP}/setup.
2. Complete the initial setup wizard to change initial password for GUI.

## Day-to-day Operations
1. Create/Delete/Enable/DIsable users under **Users** tab.
2. Download VPN client configurations from the **Users** tab.
3. Send VPN client configurations to users.

---

## Appendix

### VPN Server Ports and IP Address Pool Mapping

| Project | ServerName | OVPN Port (UDP)        | WG Port (UDP)        | OpenVPN Pool    | WireGuard Pool  | Project Network |
|--------|------------|------------------------|----------------------|------------------|------------------|-----------------|
{{PJ_TABLE_ROWS}}

---

## Enabling NAT.

All Servers are created with **NAT is disabled**.

> **Note:**  
> If you intentionally want VPN clients to use NAT, you may change NAT setting as below.  

```bash
# SSH into the Pritunl server
ssh root@${PT_IG_IP}

# Check NAT settings in MongoDB
mongosh pritunl --eval "db.servers.find({}, {name: 1, 'routes.nat': 1}).pretty()"

# Enable NAT if any route has nat: true
mongosh pritunl --eval 'db.servers.updateMany({}, { $set: { "routes.$[].nat": true}});'

# Restart Pritunl
systemctl restart pritunl
```

</sup> 