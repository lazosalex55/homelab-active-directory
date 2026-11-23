<#
.SYNOPSIS
    Gives a Windows 11 Pro VM a static LabNet address, points DNS at DC01, and joins homelab.local.

.DESCRIPTION
    Run from an elevated PowerShell session on the client.
    Add-Computer prompts for the domain admin password; nothing is stored in this script.
#>
param(
    [string]$IPAddress    = "10.10.10.30",
    [int]   $PrefixLength = 24,
    [string]$DnsServer    = "10.10.10.10",
    [string]$DomainName   = "homelab.local",
    [string]$DomainAdmin  = "HOMELAB\Administrator"
)

$ErrorActionPreference = "Stop"

# The client has a single adapter on LabNet
$nic = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1
Write-Host "Using adapter '$($nic.Name)' (index $($nic.ifIndex))" -ForegroundColor Cyan

Set-NetIPInterface -InterfaceIndex $nic.ifIndex -Dhcp Disabled
New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $IPAddress -PrefixLength $PrefixLength | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $DnsServer

Write-Host "Checking that DNS finds the domain..." -ForegroundColor Cyan
$answer = Resolve-DnsName $DomainName -Type A -ErrorAction SilentlyContinue
if (-not ($answer.IPAddress -contains $DnsServer)) {
    throw "DNS did not return $DnsServer for $DomainName. Check the DNS setting before joining."
}

Write-Host "Joining $DomainName (you'll be prompted for the password)..." -ForegroundColor Cyan
Add-Computer -DomainName $DomainName -Credential $DomainAdmin -Restart
