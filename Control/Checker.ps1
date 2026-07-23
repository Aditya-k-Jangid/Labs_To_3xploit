<#
.SYNOPSIS
    Verifies all components of the ESC1 lab environment.
#>

$ErrorActionPreference = "Continue"
$host.UI.RawUI.WindowTitle = "Lab Verification"

function Pass { Write-Host "[  PASS  ] " -NoNewline -ForegroundColor Green }
function Fail { Write-Host "[  FAIL  ] " -NoNewline -ForegroundColor Red }
function Info { Write-Host "[  INFO  ] " -NoNewline -ForegroundColor Cyan }

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Active Directory ESC1 Lab - Verification" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Environment discovery
try {
    $domain = Get-ADDomain
    $domainDNS = $domain.DNSRoot
    $configNC = (Get-ADRootDSE).configurationNamingContext
}
catch {
    Write-Host "ERROR: Unable to query AD." -ForegroundColor Red
    exit 1
}

# === 1. Users ===
Write-Host "== Users =="
$users = @("John Willium", "Orange", "Mango", "Dragon")
foreach ($u in $users) {
    $usr = Get-ADUser -Filter "SamAccountName -eq '$u'" -ErrorAction SilentlyContinue
    if ($usr) {
        Pass; Write-Host "User '$u' exists (Enabled: $($usr.Enabled))"
    }
    else {
        Fail; Write-Host "User '$u' MISSING"
    }
}

# === 2. Group Memberships ===
Write-Host ""
Write-Host "== Group Memberships =="

# Orange in Remote Management Users
$rmu = Get-ADGroupMember -Identity "Remote Management Users" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty SamAccountName
if ($rmu -contains "Orange") {
    Pass; Write-Host "Orange is in Remote Management Users"
}
else {
    Fail; Write-Host "Orange NOT in Remote Management Users"
}

# Dragon in Administrators
$admins = Get-ADGroupMember -Identity "Administrators" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty SamAccountName
if ($admins -contains "Dragon") {
    Pass; Write-Host "Dragon is in Administrators"
}
else {
    Fail; Write-Host "Dragon NOT in Administrators"
}

# Dragon in Remote Management Users
if ($rmu -contains "Dragon") {
    Pass; Write-Host "Dragon is in Remote Management Users"
}
else {
    Fail; Write-Host "Dragon NOT in Remote Management Users"
}

# === 3. SMB Share and SQLite Database ===
Write-Host ""
Write-Host "== SMB Share and SQLite Database =="

$shareName = "Del_me"
$sharePath = "C:\LabShare"
$sqliteFile = Join-Path $sharePath "Info.sqlite3"

$share = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
if ($share) {
    if ($share.Path -eq $sharePath) {
        Pass; Write-Host "Share '$shareName' points to '$sharePath'"
    }
    else {
        Fail; Write-Host "Share path is '$($share.Path)', expected '$sharePath'"
    }
}
else {
    Fail; Write-Host "Share '$shareName' not found"
}

# SQLite file check - robust approach
if (Test-Path $sqliteFile) {
    try {
        $item = Get-Item $sqliteFile -Force -ErrorAction Stop
        if ($item.Attributes -band [System.IO.FileAttributes]::Hidden) {
            Pass; Write-Host "SMB ALL SET"
        }
        else {
            Pass; Write-Host "File '$sqliteFile' exists but NOT hidden"
        }
    }
    catch {
        Fail; Write-Host "File '$sqliteFile' exists but cannot be read: $_"
    }
}
else {
    Fail; Write-Host "SQLite file MISSING: $sqliteFile"
}

# === 4. Anonymous Access ===
Write-Host ""
Write-Host "== Anonymous Access =="

# Check Guest account using WMI (works on all Windows versions)
$guest = Get-WmiObject -Class Win32_UserAccount -Filter "Name='Guest'" -ErrorAction SilentlyContinue
if ($guest -and $guest.Disabled -eq $false) {
    Pass; Write-Host "Guest account is enabled"
}
elseif ($guest -and $guest.Disabled -eq $true) {
    Fail; Write-Host "Guest account is DISABLED"
}
else {
    Fail; Write-Host "Guest account not found"
}

$ra = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymous" -ErrorAction SilentlyContinue
if ($ra -eq 0) {
    Pass; Write-Host "RestrictAnonymous = 0"
}
else {
    Fail; Write-Host "RestrictAnonymous is $ra (expected 0)"
}

$eia = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "EveryoneIncludesAnonymous" -ErrorAction SilentlyContinue
if ($eia -eq 1) {
    Pass; Write-Host "EveryoneIncludesAnonymous = 1"
}
else {
    Fail; Write-Host "EveryoneIncludesAnonymous is $eia (expected 1)"
}

$nss = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "NullSessionShares" -ErrorAction SilentlyContinue
if ($nss -contains $shareName) {
    Pass; Write-Host "NullSessionShares includes '$shareName'"
}
else {
    Fail; Write-Host "NullSessionShares does NOT include '$shareName'"
}

# === 5. ACL Delegation ===
Write-Host ""
Write-Host "== ACL Delegation =="

function Test-GenericWrite {
    param($TargetUser, $PrincipalUser)
    $target = Get-ADUser -Identity $TargetUser -ErrorAction SilentlyContinue
    $principal = Get-ADUser -Identity $PrincipalUser -ErrorAction SilentlyContinue
    if (-not $target -or -not $principal) {
        Fail; Write-Host "Cannot resolve $TargetUser or $PrincipalUser"
        return
    }
    try {
        $acl = Get-Acl "AD:\$($target.DistinguishedName)"
        $rules = $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
        $found = $rules | Where-Object {
            $_.IdentityReference.Value -eq $principal.SID.Value -and
            $_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite -and
            $_.AccessControlType -eq 'Allow'
        }
        if ($found) {
            Pass; Write-Host "$PrincipalUser has GenericWrite on $TargetUser"
        }
        else {
            Fail; Write-Host "$PrincipalUser does NOT have GenericWrite on $TargetUser"
        }
    }
    catch {
        Fail; Write-Host "ACL check error: $_"
    }
}

Test-GenericWrite -TargetUser "Orange" -PrincipalUser "John Willium"
Test-GenericWrite -TargetUser "Mango" -PrincipalUser "John Willium"

# === 6. AD Recycle Bin ===
Write-Host ""
Write-Host "== AD Recycle Bin =="
$rb = Get-ADOptionalFeature -Filter 'name -like "Recycle Bin*"' -ErrorAction SilentlyContinue
if ($rb -and $rb.EnabledScopes) {
    Pass; Write-Host "Recycle Bin is enabled"
}
else {
    Fail; Write-Host "Recycle Bin is NOT enabled"
}

# === 7. CTF Flags ===
Write-Host ""
Write-Host "== CTF Flags =="

$userFlagFile = "C:\Users\Orange\Desktop\user.txt"
$rootFlagFile = "C:\Users\Administrator\Desktop\root.txt"
$userFlagContent = 'Flag{9f5b2c7e4a13d8f6e0b4c8a2d1f7e6b0}'
$rootFlagContent = 'Flag{e3d1a7f0b9c6d5e4a3b2c1d0e9f8a7b6}'

if (Test-Path $userFlagFile) {
    $actual = Get-Content $userFlagFile -Raw
    if ($actual.Trim() -eq $userFlagContent) {
        Pass; Write-Host "User flag correct"
    }
    else {
        Fail; Write-Host "User flag content mismatch"
    }
}
else {
    Fail; Write-Host "User flag MISSING: $userFlagFile"
}

if (Test-Path $rootFlagFile) {
    $actual = Get-Content $rootFlagFile -Raw
    if ($actual.Trim() -eq $rootFlagContent) {
        Pass; Write-Host "Root flag correct"
    }
    else {
        Fail; Write-Host "Root flag content mismatch"
    }
}
else {
    Fail; Write-Host "Root flag MISSING: $rootFlagFile"
}

# === 8. AD CS ESC1 Template ===
Write-Host ""
Write-Host "== AD CS ESC1 Template =="

$ca = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration" -ErrorAction SilentlyContinue
if (-not $ca) {
    Info; Write-Host "AD CS not installed - skipping certificate checks."
}
else {
    $caName = $ca.PSChildName
    Info; Write-Host "CA detected: $caName"

    $templateDN = "CN=ESC1Test,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"

    $tmpl = Get-ADObject -Identity $templateDN -Properties msPKI-Certificate-Name-Flag, msPKI-Enrollment-Flag, pKIExtendedKeyUsage -ErrorAction SilentlyContinue
    if ($tmpl) {
        if ($tmpl.'msPKI-Certificate-Name-Flag' -eq 1) {
            Pass; Write-Host "ESC1Test: Enrollee supplies subject"
        }
        else {
            Fail; Write-Host "ESC1Test: Name-Flag is $($tmpl.'msPKI-Certificate-Name-Flag') (expected 1)"
        }

        if ($tmpl.'msPKI-Enrollment-Flag' -eq 0) {
            Pass; Write-Host "ESC1Test: No CA approval required"
        }
        else {
            Fail; Write-Host "ESC1Test: Enrollment-Flag is $($tmpl.'msPKI-Enrollment-Flag') (expected 0)"
        }

        if ($tmpl.pKIExtendedKeyUsage -contains "1.3.6.1.5.5.7.3.2") {
            Pass; Write-Host "ESC1Test: Client Authentication EKU present"
        }
        else {
            Fail; Write-Host "ESC1Test: Client Authentication EKU missing"
        }

        try {
            $acl = Get-Acl "AD:\$templateDN"
            $orangeSID = (Get-ADUser Orange).SID
            $enrollGuid = New-Object Guid "0e10c968-78fb-11d2-90d4-00c04f79dc55"
            $rules = $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
            $enroll = $rules | Where-Object {
                $_.IdentityReference -eq $orangeSID -and
                $_.ActiveDirectoryRights -eq 'ExtendedRight' -and
                $_.ObjectType -eq $enrollGuid
            }
            if ($enroll) {
                Pass; Write-Host "Orange can Enroll on ESC1Test"
            }
            else {
                Fail; Write-Host "Orange cannot Enroll on ESC1Test"
            }
        }
        catch {
            Fail; Write-Host "Enrollment check error: $_"
        }
    }
    else {
        Fail; Write-Host "ESC1Test template NOT found"
    }

    $kerbDN = "CN=KerberosAuthentication,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"
    $kerb = Get-ADObject -Identity $kerbDN -ErrorAction SilentlyContinue
    if ($kerb) {
        Pass; Write-Host "KerberosAuthentication template exists"
    }
    else {
        Info; Write-Host "KerberosAuthentication template not found (PKINIT may still work)"
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Verification complete." -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
