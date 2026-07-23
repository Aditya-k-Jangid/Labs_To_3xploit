<#
.SYNOPSIS
    One-click lab setup for the Active Directory ESC1 attack chain.
    FULLY AUTOMATED – installs AD CS, configures CA, creates vulnerable template.
.DESCRIPTION
    Configures:
      - Users (John Willium, Orange, Mango, Dragon)
      - SMB share with hidden SQLite database
      - Anonymous / null session access
      - GenericWrite ACLs (John -> Orange, John -> Mango)
      - AD Recycle Bin
      - AD CS installation + Enterprise Root CA
      - Vulnerable certificate template (ESC1) with exact flags & enrollment
      - PKINIT (Kerberos Authentication cert for DC)
      - Flags on Orange's and Administrator's desktops
.IMPORTANT
    Run from powershell.exe (64-bit) as Domain Administrator on a Domain Controller.
#>

[CmdletBinding()]
param(
    [string]$GitHubRawBase = "https://raw.githubusercontent.com/Aditya-k-Jangid/Labs_To_3xploit/refs/heads/main/Control",
    [string]$TemplateName = "ESC1Test"
)

$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

# =============================================
# Banner
# =============================================
$banner = @"
 _____            _             _
/  __ \          | |           | |
| /  \/ ___  _ __ | |_ _ __ ___ | |
| |    / _ \| '_ \| __| '__/ _ \| |
| \__/\ (_) | | | | |_| | | (_) | |
 \____/\___/|_| |_|\__|_|  \___/|_|

           created by Sawsage
"@
Write-Host $banner -ForegroundColor Cyan

# =============================================
# 0. Environment discovery
# =============================================
Write-Information "=== Checking environment ==="

# Check 64-bit
if (-not [System.Environment]::Is64BitProcess) {
    throw "ERROR: You are running PowerShell x86. Please use powershell.exe (64-bit)."
}

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "This script must be run as Administrator."
}

Import-Module ActiveDirectory -ErrorAction Stop
Import-Module ServerManager -ErrorAction Stop

# Discover domain with retry
$maxRetries = 3
$retryCount = 0
$domainInfo = $null

do {
    try {
        $domain = Get-ADDomain -ErrorAction Stop
        $domainDNS = $domain.DNSRoot
        $domainDN = $domain.DistinguishedName
        $dc = Get-ADDomainController -Discover -Service PrimaryDC -Domain $domainDNS -ErrorAction Stop
        $dcFQDN = $dc.HostName
        $configNC = (Get-ADRootDSE).configurationNamingContext
        $domainSID = $domain.DomainSID
        $domainInfo = $true
    } catch {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Warning "AD query failed (attempt $retryCount/$maxRetries). Retrying..."
            Start-Service ADWS -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
        } else {
            throw "Failed to query domain. Is this a DC? Error: $_"
        }
    }
} while (-not $domainInfo -and $retryCount -lt $maxRetries)

# Auto-detect CA name and DN suffix
$CAName = "$($dc.Name.Split('.')[0].ToUpper())-CA"
$CADNSuffix = ($domainDNS -replace '\.', ',DC=') -replace '^', 'DC='

Write-Information "Domain     : $domainDNS"
Write-Information "DC         : $dcFQDN"
Write-Information "CA Name    : $CAName"

# =============================================
# Helper functions
# =============================================
function Invoke-NonFatal {
    param([string]$Description, [ScriptBlock]$ScriptBlock)
    try {
        & $ScriptBlock
        Write-Information "$Description - Done."
    } catch {
        if ($_.Exception.Message -match "already exists|already a member") {
            Write-Information "$Description - Already configured."
        } else {
            Write-Warning "$Description - Error (non-fatal): $_"
        }
    }
}

function Wait-Enter {
    param([string]$Msg = "Press Enter to continue...")
    Write-Host ""
    Write-Host $Msg -ForegroundColor Green
    Read-Host | Out-Null
}

# =============================================
# 1. Users and groups
# =============================================
Write-Information "=== Creating users ==="

$users = @(
    @{Name="John Willium"; Sam="John Willium"; Pass="John2134!"},
    @{Name="Orange"; Sam="Orange"; Pass="secret2!"},
    @{Name="Mango"; Sam="Mango"; Pass="Uncracable@312"},
    @{Name="Dragon"; Sam="Dragon"; Pass="hell%1U^&#%"}
)

foreach ($u in $users) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue)) {
        $pw = ConvertTo-SecureString $u.Pass -AsPlainText -Force
        New-ADUser -Name $u.Name -SamAccountName $u.Sam -AccountPassword $pw `
                   -Enabled $true -PasswordNeverExpires $true -Path "CN=Users,$domainDN"
        Write-Information "Created: $($u.Name)"
    } else {
        Write-Information "User '$($u.Name)' already exists."
    }
}

Invoke-NonFatal "Orange -> Remote Management Users" {
    Add-ADGroupMember -Identity "Remote Management Users" -Members "Orange" -ErrorAction Stop
}
Invoke-NonFatal "Dragon -> Administrators" {
    Add-ADGroupMember -Identity "Administrators" -Members "Dragon" -ErrorAction Stop
}
Invoke-NonFatal "Dragon -> Remote Management Users" {
    Add-ADGroupMember -Identity "Remote Management Users" -Members "Dragon" -ErrorAction Stop
}

# =============================================
# 2. SMB share with hidden SQLite database
# =============================================
Write-Information "=== Setting up SMB share ==="
$sharePath = "C:\LabShare"
$shareName = "Del_me"
$sqliteFile = "Info.sqlite3"
$sqliteDest = Join-Path $sharePath $sqliteFile

if (-not (Test-Path $sharePath)) { New-Item -ItemType Directory -Path $sharePath -Force | Out-Null }
else { icacls $sharePath /reset /T /Q 2>$null }

if (Test-Path $sqliteDest) {
    attrib -h -r -s $sqliteDest 2>$null
    Remove-Item $sqliteDest -Force
}

Invoke-WebRequest -Uri "$GitHubRawBase/Assets/$sqliteFile" -OutFile $sqliteDest -ErrorAction Stop
attrib +h $sqliteDest

if (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue) { Remove-SmbShare -Name $shareName -Force }
New-SmbShare -Name $shareName -Path $sharePath -FullAccess Everyone -Description "Lab share" -ErrorAction Stop
Write-Information "Share '$shareName' ready."

# =============================================
# 3. Anonymous access
# =============================================
Write-Information "=== Enabling anonymous access ==="
net user guest /active:yes 2>$null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymous /t REG_DWORD /d 0 /f 2>$null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v EveryoneIncludesAnonymous /t REG_DWORD /d 1 /f 2>$null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v NullSessionShares /t REG_MULTI_SZ /d $shareName /f 2>$null

try { Restart-Service LanmanServer -Force -ErrorAction Stop }
catch { net stop LanmanServer /y 2>$null; Start-Sleep 3; net start LanmanServer 2>$null }
Write-Information "Anonymous access configured."

# =============================================
# 4. ACL delegation
# =============================================
Write-Information "=== Setting ACLs ==="
function Grant-GenericWrite {
    param($Target, $Principal)
    $acl = Get-Acl "AD:\$((Get-ADUser $Target).DistinguishedName)"
    $sid = (Get-ADUser $Principal).SID
    $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        (New-Object System.Security.Principal.SecurityIdentifier($sid)),
        [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $acl.AddAccessRule($ace)
    Set-Acl -Path "AD:\$((Get-ADUser $Target).DistinguishedName)" -AclObject $acl
}
Grant-GenericWrite "Orange" "John Willium"
Grant-GenericWrite "Mango" "John Willium"
Write-Information "ACLs set."

# =============================================
# 5. AD Recycle Bin
# =============================================
Write-Information "=== Enabling AD Recycle Bin ==="
Invoke-NonFatal "AD Recycle Bin" {
    Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target $domainDNS -Confirm:$false -ErrorAction Stop
}

# =============================================
# 6. Flags
# =============================================
Write-Information "=== Writing flags ==="
$userFlag = 'Flag{9f5b2c7e4a13d8f6e0b4c8a2d1f7e6b0}'
$rootFlag = 'Flag{e3d1a7f0b9c6d5e4a3b2c1d0e9f8a7b6}'

if (-not (Test-Path "C:\Users\Orange\Desktop")) { New-Item -ItemType Directory -Path "C:\Users\Orange\Desktop" -Force | Out-Null }
if (-not (Test-Path "C:\Users\Administrator\Desktop")) { New-Item -ItemType Directory -Path "C:\Users\Administrator\Desktop" -Force | Out-Null }
Set-Content "C:\Users\Orange\Desktop\user.txt" $userFlag -Force
Set-Content "C:\Users\Administrator\Desktop\root.txt" $rootFlag -Force
Write-Information "Flags placed."

# =============================================
# 7. AD CS Installation + Configuration
# =============================================
Write-Information "=== Installing AD CS (if needed) ==="

$ca = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration" -ErrorAction SilentlyContinue

if (-not $ca) {
    Write-Information "AD CS not configured. Installing and configuring..."

    Write-Information "Installing AD CS role..."
    Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools -ErrorAction Stop
    Write-Information "AD CS role installed."

    Write-Information "Configuring CA '$CAName'..."
    Install-AdcsCertificationAuthority `
        -CAType EnterpriseRootCa `
        -CACommonName $CAName `
        -CADistinguishedNameSuffix $CADNSuffix `
        -KeyLength 2048 `
        -HashAlgorithmName SHA256 `
        -ValidityPeriod Years `
        -ValidityPeriodUnits 5 `
        -Force `
        -ErrorAction Stop

    Write-Information "CA '$CAName' configured."
    Start-Sleep -Seconds 10

    $ca = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration" -ErrorAction SilentlyContinue
    if ($ca) {
        Write-Information "AD CS installation successful!"
    } else {
        throw "AD CS installed but CA not detected. Reboot and re-run the script."
    }
} else {
    Write-Information "AD CS already installed."
}

# =============================================
# 8. ESC1 Certificate Template
# =============================================
Write-Information "=== Configuring ESC1 template ==="

$caName = $ca.PSChildName
Write-Information "CA: $caName"

$templatePath = "CN=$TemplateName,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"

$templateExists = Get-ADObject -Filter "distinguishedName -eq '$templatePath'" -ErrorAction SilentlyContinue

if (-not $templateExists) {
    Write-Information "Template '$TemplateName' not found. Attempting automatic creation..."
    $autoCreated = $false
    
    try {
        $userTemplateDN = "CN=User,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"
        $userTemplate = Get-ADObject -Identity $userTemplateDN -Properties * -ErrorAction Stop
        $newTemplate = $userTemplate | Select-Object *
        $newTemplate.DistinguishedName = $templatePath
        $newTemplate.Name = $TemplateName
        $newTemplate.DisplayName = $TemplateName

        $attrList = @('distinguishedName','objectGUID','objectSid','cn','whenCreated','whenChanged',
                      'uSNCreated','uSNChanged','dSCorePropagationData','msPKI-Certificate-Application-Policy')
        foreach ($attr in $attrList) {
            $newTemplate.PSBase.Properties.Remove($attr)
        }

        $newTemplate | New-ADObject -Type "pKICertificateTemplate" -Path "CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC" -ErrorAction Stop
        $autoCreated = $true
        Write-Information "Template created automatically."
    }
    catch {
        Write-Warning "Auto-creation failed: $_"
    }

    if (-not $autoCreated) {
        Write-Host ""
        Write-Host "=" * 60 -ForegroundColor Cyan
        Write-Host "  MANUAL TEMPLATE DUPLICATION REQUIRED" -ForegroundColor Yellow
        Write-Host "=" * 60 -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  1. Run: certtmpl.msc" -ForegroundColor White
        Write-Host "  2. Right-click 'User' -> Duplicate Template" -ForegroundColor White
        Write-Host "  3. General tab: Template name = $TemplateName" -ForegroundColor Green
        Write-Host "  4. Click OK" -ForegroundColor White
        Write-Host ""
        Wait-Enter
    }
}

$templateExists = Get-ADObject -Filter "distinguishedName -eq '$templatePath'" -ErrorAction SilentlyContinue

if ($templateExists) {
    Write-Information "Template exists. Applying ESC1 configuration..."

    Set-ADObject -Identity $templatePath -Replace @{'msPKI-Certificate-Name-Flag' = 1}
    Write-Information "Name-Flag set."

    Set-ADObject -Identity $templatePath -Replace @{'msPKI-Enrollment-Flag' = 0}
    Write-Information "Enrollment-Flag set."

    $templateDN = "AD:\$templatePath"
    $acl = Get-Acl $templateDN
    $orange = Get-ADUser -Identity "Orange"
    $sid = New-Object System.Security.Principal.SecurityIdentifier($orange.SID)
    $enrollGuid = New-Object Guid "0e10c968-78fb-11d2-90d4-00c04f79dc55"
    $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        $sid,
        [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
        [System.Security.AccessControl.AccessControlType]::Allow,
        $enrollGuid
    )
    $acl.AddAccessRule($ace)
    Set-Acl -Path $templateDN -AclObject $acl
    Write-Information "Enroll permission granted."

    certutil -SetCAtemplates +$TemplateName 2>$null
    Write-Information "Template published."
}
else {
    Write-Warning "Template not found; cannot apply ESC1 configuration."
}

# =============================================
# 9. PKINIT
# =============================================
Write-Information "=== Configuring PKINIT ==="
certutil -SetCAtemplates +KerberosAuthentication 2>$null
certutil -pulse 2>$null
gpupdate /force 2>$null | Out-Null
Start-Sleep -Seconds 5
certreq -enroll -machine -q "KerberosAuthentication" 2>$null
Restart-Service kdc
Write-Information "PKINIT ready."

# =============================================
# 10. Summary
# =============================================
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "        Lab Setup Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Domain   : $domainDNS" -ForegroundColor White
Write-Host "  DC       : $dcFQDN" -ForegroundColor White
Write-Host "  CA       : $CAName" -ForegroundColor White
Write-Host "  Template : $TemplateName" -ForegroundColor White
Write-Host "  Share    : \\$dcFQDN\$shareName" -ForegroundColor White
Write-Host ""
Write-Host "  Flags placed on:" -ForegroundColor Yellow
Write-Host "    - Orange's desktop (user.txt)" -ForegroundColor White
Write-Host "    - Administrator's desktop (root.txt)" -ForegroundColor White
Write-Host ""
Write-Host "  Attack Path:" -ForegroundColor Cyan
Write-Host "    1. Anonymous SMB enumeration" -ForegroundColor White
Write-Host "    2. Extract & crack from SQLite database" -ForegroundColor White
Write-Host "    3. GenericWrite ACL exploitation" -ForegroundColor White
Write-Host "    4. ESC1 certificate request" -ForegroundColor White
Write-Host "    5. Domain Admin authentication" -ForegroundColor White
Write-Host ""
Write-Host "  Verify: iex (iwr '$GitHubRawBase/Checker.ps1')" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
