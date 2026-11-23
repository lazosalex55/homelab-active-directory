<#
.SYNOPSIS
    Bulk-creates the lab's OU structure, role groups and user accounts from a CSV file.

.DESCRIPTION
    Run on DC01 from an elevated PowerShell session.
    The script prompts once for a temporary password; every user must change it at first logon.
    Safe to run more than once: existing OUs, groups and users are skipped.

.EXAMPLE
    .\New-LabUsers.ps1 -CsvPath .\users.csv
#>
param(
    [string]$CsvPath = ".\users.csv"
)

Import-Module ActiveDirectory
$ErrorActionPreference = "Stop"

$domainDN = (Get-ADDomain).DistinguishedName
$upnSuffix = (Get-ADDomain).DNSRoot

function Ensure-OU([string]$Name, [string]$Path) {
    $dn = "OU=$Name,$Path"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
        Write-Host "Created OU $dn" -ForegroundColor Green
    }
    return $dn
}

# Top-level structure
$workstationsOU = Ensure-OU "Workstations" $domainDN
$usersOU        = Ensure-OU "Lab Users"    $domainDN
$groupsOU       = Ensure-OU "Groups"       $domainDN

$users = Import-Csv $CsvPath
$tempPassword = Read-Host "Temporary password for new users" -AsSecureString

foreach ($u in $users) {
    $deptOU = Ensure-OU $u.Department $usersOU

    # Role group per CSV row (e.g. HR-Users, Lab-Admins)
    if (-not (Get-ADGroup -Filter "Name -eq '$($u.Group)'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $u.Group -GroupScope Global -GroupCategory Security -Path $groupsOU
        Write-Host "Created group $($u.Group)" -ForegroundColor Green
    }

    if (Get-ADUser -Filter "SamAccountName -eq '$($u.Username)'" -ErrorAction SilentlyContinue) {
        Write-Host "Skipping existing user $($u.Username)" -ForegroundColor DarkGray
    } else {
        New-ADUser -Name "$($u.FirstName) $($u.LastName)" `
                   -GivenName $u.FirstName -Surname $u.LastName `
                   -SamAccountName $u.Username `
                   -UserPrincipalName "$($u.Username)@$upnSuffix" `
                   -Title $u.Title -Department $u.Department `
                   -Path $deptOU `
                   -AccountPassword $tempPassword `
                   -ChangePasswordAtLogon $true `
                   -Enabled $true
        Write-Host "Created user $($u.Username) in $($u.Department)" -ForegroundColor Green
    }

    Add-ADGroupMember -Identity $u.Group -Members $u.Username -ErrorAction SilentlyContinue
}

Write-Host "`nDone. Summary:" -ForegroundColor Cyan
Get-ADUser -Filter * -SearchBase $usersOU -Properties Department |
    Sort-Object Department, Name |
    Format-Table Name, SamAccountName, Department -AutoSize
