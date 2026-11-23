# Lab Journal

A dated log of what I built, what went wrong, and how I fixed it. Newest entries first.

---

## 2026-11-22: Group Policy planning

- Planned the OU structure (Workstations, Lab Users by department, Groups) and role-based security groups (`Lab-Admins`, `HR-Users`, `Sales-Users`).
- Designed the first GPO: give `Lab-Admins` local administrator rights on every workstation through Group Policy Preferences, instead of adding people to each PC by hand.
- **Lesson:** security filtering only *narrows* a GPO. A user or computer must also sit inside the OU the GPO is linked to. Computer settings follow computer objects; user settings follow user objects.

## 2026-11-21: Windows 11 client on LabNet

- Built **CLIENT1** (Windows 11 Pro) with a single adapter on LabNet, so DC01 is its only DNS server.
- Static IP 10.10.10.30, DNS 10.10.10.10. `Resolve-DnsName homelab.local` returned 10.10.10.10.
- **Problem:** Windows 11 setup refused to continue without internet (the old "I don't have internet" option is gone).
  **Fix:** switched the VM's adapter to NAT *while running*, finished setup, then switched back to LabNet.
- **Problem:** setup pushed for a Microsoft account.
  **Fix:** *Set up for work or school → Sign-in options → Domain join instead* created a local account.
- **Problem:** `Add-Computer` failed with *"The user name or password is incorrect."*
  **Diagnosis:** the network and DNS path worked, since the domain answered; the credential was wrong. The domain Administrator password is the DC's original local Administrator password, not the DSRM password set during promotion.
- **Found:** DNS also returns DC01's NAT address (10.0.2.15), which LabNet clients can't reach. **To do:** stop the NAT adapter registering in DNS, so clients only get 10.10.10.10.

## 2026-11-21: Monitoring sensor online

- Ubuntu VM: LabNet profile at 10.10.10.20, Docker installed, `linuxserver/wireshark` running with host networking.
- Verified: container up, ping to DC01 under 1 ms, Wireshark 4.6.0 in the browser listing the LabNet interface.
- **Lesson:** Docker Desktop on Windows can't see the host's NIC or VirtualBox networks, because it runs inside a hidden WSL2 VM. Running Docker *inside* the Ubuntu VM puts the container on the lab network.

## 2026-11-17 to 11-21: Domain controller promotion

- `Install-ADDSForest -DomainName homelab.local -InstallDns` completed; `Get-ADDomain` confirms forest `homelab.local`, PDC emulator `dc01.homelab.local`.
- **Problem:** first attempt failed with *"SafeModeAdministratorPassword cannot be null."*
  **Cause:** the password was typed while another window had keyboard focus, so the prompt got empty input.
  **Fix:** click inside the VM first, then rerun.
- **Lesson:** VirtualBox's *Save the machine state* freezes a VM mid-prompt; days later it resumes exactly there. Finish prompts, or shut down from inside the guest.

## 2026-11-16: Server install

- Downloaded the Windows Server 2025 evaluation ISO, created DC01 (8 GB RAM, 4 vCPU, 80 GB, EFI).
- **Problem:** "No bootable option or device was found."
  **Cause:** the *Press any key to boot from CD* prompt times out in a few seconds.
  **Fix:** Machine → Reset, click into the VM, press Enter repeatedly as it boots.
- **Problem:** text typed into the VM didn't appear.
  **Cause:** without Guest Additions, only real key presses reach the guest.
- Installed Standard (Desktop Experience); static IP on LabNet, AD DS role installed, renamed to DC01.
- Built the Monitor-Ubuntu VM and the LabNet internal network.
