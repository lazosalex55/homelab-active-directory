<#
.SYNOPSIS
    Configures a fresh Windows Server 2025 VM as DC01, the first domain controller for homelab.local.

.DESCRIPTION
    Run in two stages from an elevated PowerShell session:
      .\dc01-setup.ps1 -Stage 1   # static IP, AD DS role, rename + restart
      .\dc01-setup.ps1 -Stage 2   # promote to a new forest (prompts for the DSRM password)

    No passwords are stored in this script; Install-ADDSForest prompts for them.
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet(1, 2)]
    [int]$Stage,

    [string]$LabNetAlias  = "Ethernet 2",
    [string]$IPAddress    = "10.10.10.10",
    [int]   $PrefixLength = 24,
    [string]$ComputerName = "DC01",
    [string]$DomainName   = "homelab.local"
)

$ErrorActionPreference = "Stop"

if ($Stage -eq 1) {
    Write-Host "Setting static IP $IPAddress/$PrefixLength on '$LabNetAlias'..." -ForegroundColor Cyan
    New-NetIPAddress -InterfaceAlias $LabNetAlias -IPAddress $IPAddress -PrefixLength $PrefixLength | Out-Null

    Write-Host "Installing AD DS role and management tools..." -ForegroundColor Cyan
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | Format-Table -AutoSize

    Write-Host "Renaming to $ComputerName and restarting. Run Stage 2 after signing back in." -ForegroundColor Yellow
    Rename-Computer -NewName $ComputerName -Restart
}

if ($Stage -eq 2) {
    Write-Host "Promoting to the first DC of new forest '$DomainName' with DNS..." -ForegroundColor Cyan
    Write-Host "You'll be prompted for the Directory Services Restore Mode (DSRM) password." -ForegroundColor Yellow
    Install-ADDSForest -DomainName $DomainName -InstallDns
    # The server restarts automatically. Afterwards, sign in as <NETBIOS>\Administrator.
}
