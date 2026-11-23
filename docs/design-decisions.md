# Design Decisions

| Decision | Why |
| --- | --- |
| **AD runs in a VM, not a container** | Microsoft doesn't support a domain controller inside a container. Windows containers can join a domain but can't host AD DS, and Docker on Linux can't run Windows. |
| **Docker runs inside the Ubuntu VM, not Docker Desktop on Windows** | Docker Desktop runs containers in a hidden WSL2 VM that can't see the host NIC or VirtualBox networks. Turning on WSL2/Hyper-V can also slow VirtualBox down. |
| **Internal network (LabNet) for lab traffic** | Keeps AD's DNS and authentication traffic off the home network, so DC01 can never hand out DNS answers to real devices. |
| **NAT adapters for internet** | The DC and sensor need updates, activation and Docker images without exposing the lab to the home LAN. |
| **Client on LabNet only** | One adapter means one DNS server, DC01. Multiple adapters with different DNS servers is the most common reason domain joins and logons fail. |
| **Static IPs, no DHCP (yet)** | Predictable addresses for the DC and sensor; DHCP on DC01 is a planned exercise. |
| **Promiscuous mode only on the sensor** | Only the monitor needs to see other machines' traffic; the DC and client stay on *Deny*. |
| **Rename before promotion** | Renaming a domain controller after promotion is a multi-step, error-prone process. |
| **Windows 11 Pro, not Home** | Home edition can't join a domain. |
| **Desktop Experience on the DC** | The GUI makes learning ADUC and Group Policy Management easier; Server Core is a future exercise. |
