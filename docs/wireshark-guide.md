# Reading Lab Traffic in Wireshark

Wireshark runs in Docker on Monitor-Ubuntu, at `http://localhost:3000` on that VM. Capture on **`enp0s8`**, the LabNet interface. Because that adapter is in promiscuous mode, it sees traffic between *other* VMs too, such as CLIENT1 ↔ DC01.

## The three panes

| Pane | Shows |
| --- | --- |
| Packet list (top) | One row per packet: time, source, destination, protocol, length, summary |
| Packet details (middle) | The packet broken into layers: Ethernet → IP → TCP/UDP → application |
| Bytes (bottom) | Raw hex; the field you select above is highlighted |

## Display filters for an AD lab

| Filter | Shows |
| --- | --- |
| `ip.addr == 10.10.10.10` | Everything to or from DC01 |
| `dns` | Name lookups, including SRV records clients use to find a DC |
| `kerberos` | Logons: AS-REQ/AS-REP (login), TGS-REQ/TGS-REP (service tickets) |
| `ldap \|\| cldap` | Directory queries |
| `smb2` | File shares and Group Policy downloads from SYSVOL |
| `arp` | Machines finding each other's MAC addresses |
| `icmp` | Pings |

## What a domain logon looks like

Sign in to CLIENT1 as a domain user while capturing, and the traffic follows this order:

1. **DNS:** SRV lookup for `_ldap._tcp.dc._msdcs.homelab.local` to find a domain controller
2. **CLDAP:** "ping" to DC01 to confirm the domain and site
3. **Kerberos:** AS-REQ, then AS-REP (the user gets a ticket-granting ticket)
4. **Kerberos:** TGS-REQ and TGS-REP for `cifs/dc01`, `ldap/dc01` and others
5. **LDAP:** user and group lookups
6. **SMB2:** connection to `\\homelab.local\SYSVOL` to download Group Policy

## Generate test traffic from Ubuntu

```bash
ping -c 4 10.10.10.10
nslookup homelab.local 10.10.10.10
nslookup -type=SRV _ldap._tcp.homelab.local 10.10.10.10
```

## Useful views

- **Statistics → Conversations:** who talked to whom, and how much
- **Statistics → Protocol Hierarchy:** the share of traffic per protocol
- **Right-click a packet → Follow → TCP Stream:** a whole connection in order
