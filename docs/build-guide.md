# Build Guide

Every setting and command used to build the lab, in the order it was done. Passwords are never written down here; each one was typed at its own prompt.

## 1. Host and media

| Item | Detail |
| --- | --- |
| Host | Windows 11 PC, 32 GB RAM, 16 logical CPUs |
| Hypervisor | Oracle VirtualBox 7.2 |
| Server ISO | Windows Server 2025 evaluation (180 days), from the [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025) |
| Client ISO | Windows 11 25H2 (English, x64) |
| Linux ISO | Ubuntu 24.04.4 Desktop |

## 2. Network design

Every VM gets an adapter on a VirtualBox **internal network** named `LabNet`, a private virtual switch that only lab VMs can see. Internet access, where it's needed, comes from a separate **NAT** adapter.

| VM | Adapter 1 | Adapter 2 |
| --- | --- | --- |
| DC01 | NAT | LabNet, 10.10.10.10/24 (static) |
| Monitor-Ubuntu | NAT | LabNet, 10.10.10.20/24 (static), **promiscuous mode: Allow All** |
| CLIENT1 | LabNet, 10.10.10.30/24 (static), DNS 10.10.10.10 | none |

To attach a VM: **Settings → Expert → Network → Adapter N → Attached to: Internal Network → Name: `LabNet`**. The name must match exactly. LabNet has no DHCP server, so every VM gets a static address.

## 3. DC01 (Windows Server 2025)

**VM:** 8192 MB RAM, 4 vCPU, 80 GB dynamic VDI, EFI on, OS type Windows Server 2025 (64-bit), unattended install off.

**Install:**
1. Press a key immediately at *Press any key to boot from CD or DVD*.
2. Install Windows Server → **Windows Server 2025 Standard Evaluation (Desktop Experience)**.
3. Set the local Administrator password; diagnostic data: *Required only*.

**Configure** (PowerShell as Administrator; also in [`scripts/dc01-setup.ps1`](../scripts/dc01-setup.ps1)):

```powershell
# Static IP on the LabNet adapter
New-NetIPAddress -InterfaceAlias "Ethernet 2" -IPAddress 10.10.10.10 -PrefixLength 24

# AD DS binaries + management tools (doesn't create a domain yet)
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# Rename BEFORE promotion; renaming a DC later is much harder
Rename-Computer DC01 -Restart

# New forest + domain with integrated DNS (prompts for the DSRM password)
Install-ADDSForest -DomainName homelab.local -InstallDns
```

After the automatic restart, sign in as `HOMELAB\Administrator`. The DNS-delegation and dynamic-IPv6 warnings are expected for a first DC in a lab.

## 4. Monitor-Ubuntu (Docker + Wireshark)

**VM:** 4096 MB RAM, 2 vCPU, 40 GB VDI, 128 MB video memory. Adapter 2 on LabNet with promiscuous mode *Allow All*, so the sensor receives frames addressed to other VMs.

**Install:** standard Ubuntu 24.04 desktop, unattended install off, no internet during install.

**Configure** (also in [`scripts/monitor-setup.sh`](../scripts/monitor-setup.sh)):

```bash
sudo nmcli con add type ethernet ifname enp0s8 con-name labnet \
  ipv4.method manual ipv4.addresses 10.10.10.20/24 ipv6.method disabled
sudo apt update && sudo apt install -y docker.io
sudo docker run -d --name wireshark --net host \
  --cap-add net_admin --cap-add net_raw \
  --restart unless-stopped lscr.io/linuxserver/wireshark
```

| Flag | Why |
| --- | --- |
| `--net host` | The container sees the VM's real interfaces, including `enp0s8` (LabNet) |
| `--cap-add net_admin --cap-add net_raw` | Allows promiscuous mode and raw packet capture |
| `--restart unless-stopped` | Wireshark comes back after a reboot |

Open Firefox on the VM at `http://localhost:3000` and capture on **enp0s8**.

## 5. CLIENT1 (Windows 11 Pro)

**VM:** 6144 MB RAM, 2 vCPU, 80 GB dynamic VDI, OS type Windows 11 (64-bit), which turns on TPM 2.0, EFI and Secure Boot. Adapter 1 on LabNet only.

**Install:**
1. Choose **Windows 11 Pro** with *I don't have a product key*. Home can't join a domain.
2. Setup insists on internet: temporarily switch the adapter to NAT (**Devices → Network → Network Settings**, live), then switch back after setup.
3. *Set up for work or school* → *Sign-in options* → *Domain join instead* creates a local account without a Microsoft account.

**Configure** (PowerShell as Administrator; also in [`scripts/client-join.ps1`](../scripts/client-join.ps1)):

```powershell
Set-NetIPInterface -InterfaceIndex 14 -Dhcp Disabled
New-NetIPAddress -InterfaceIndex 14 -IPAddress 10.10.10.30 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceIndex 14 -ServerAddresses 10.10.10.10
Resolve-DnsName homelab.local       # must return 10.10.10.10
Add-Computer -DomainName homelab.local -Credential HOMELAB\Administrator -Restart
```

## 6. Directory structure and Group Policy *(in progress)*

Planned layout, created with [`scripts/New-LabUsers.ps1`](../scripts/New-LabUsers.ps1):

```
homelab.local
├── Workstations        (computer accounts, e.g. CLIENT1)
├── Lab Users
│   ├── IT
│   ├── HR
│   └── Sales
└── Groups
    ├── Lab-Admins      (members become local admins on workstations via GPO)
    ├── HR-Users
    └── Sales-Users
```

| GPO | Linked to | Does |
| --- | --- | --- |
| Lab-Admins Local Admin Rights | Workstations OU | Adds `HOMELAB\Lab-Admins` to each workstation's local Administrators group (Computer → Preferences → Local Users and Groups) |
| Workstation Baseline | Workstations OU | Desktop wallpaper, USB storage policy, startup script |
| Default Domain Policy | Domain | Password and lockout rules |

Check on the client with `gpupdate /force` and `gpresult /r`.
