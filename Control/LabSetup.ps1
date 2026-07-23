<#
.SYNOPSIS
    One-click lab setup for the Active Directory ESC1 attack chain.
.DESCRIPTION
    Configures a domain with:
      - Users (John Willium, Orange, Mango, Dragon)
      - SMB share with hidden SQLite database
      - Anonymous / null session access
      - GenericWrite ACLs (John -> Orange, John -> Mango)
      - AD Recycle Bin
      - Vulnerable AD CS certificate template (ESC1)
      - Flags on Orange's and Administrator's desktops
.NOTES
    Run as Domain Administrator on a Domain Controller with AD CS installed.
    Adjust $GitHubRawBase if your repository structure changes.
#>

[CmdletBinding()]
param(
    # Base raw URL to the Control folder (no trailing slash)
    [string]$GitHubRawBase = "https://raw.githubusercontent.com/Aditya-k-Jangid/Labs_To_3xploit/refs/heads/main/Control"
)

$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

# =============================================
# 0. Prerequisites & environment discovery
# =============================================
Write-Information "=== Checking environment ==="

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "This script must be run as Administrator."
}

Import-Module ActiveDirectory -ErrorAction Stop

try {
    $domain = Get-ADDomain
    $domainDNS = $domain.DNSRoot
    $domainDN = $domain.DistinguishedName
    $dc = Get-ADDomainController -Discover -Service PrimaryDC -Domain $domainDNS
    $dcFQDN = $dc.HostName
    $configNC = (Get-ADRootDSE).configurationNamingContext
    $domainSID = $domain.DomainSID
    $adminSID = "$domainSID-500"
} catch {
    throw "Failed to query domain information. Are you on a domain controller? $_"
}

Write-Information "Domain: $domainDNS"
Write-Information "DC: $dcFQDN"
Write-Information "Configuration NC: $configNC"

# =============================================
# 1. Users and groups
# =============================================
Write-Information "=== Creating users ==="

$johnPW   = ConvertTo-SecureString "John2134!" -AsPlainText -Force
$orangePW = ConvertTo-SecureString "secret2!" -AsPlainText -Force
$mangoPW  = ConvertTo-SecureString "Uncracable@312" -AsPlainText -Force
$dragonPW = ConvertTo-SecureString "hell%1U^&#%" -AsPlainText -Force

$users = @(
    @{ Name = "John Willium"; Sam = "John Willium"; Password = $johnPW },
    @{ Name = "Orange"; Sam = "Orange"; Password = $orangePW },
    @{ Name = "Mango"; Sam = "Mango"; Password = $mangoPW },
    @{ Name = "Dragon"; Sam = "Dragon"; Password = $dragonPW }
)

foreach ($u in $users) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name $u.Name `
                   -SamAccountName $u.Sam `
                   -AccountPassword $u.Password `
                   -Enabled $true `
                   -PasswordNeverExpires $true `
                   -CannotChangePassword $false `
                   -Path "CN=Users,$domainDN"
        Write-Information "Created user: $($u.Name)"
    } else {
        Write-Information "User '$($u.Name)' already exists."
    }
}

Add-ADGroupMember -Identity "Remote Management Users" -Members "Orange" -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "Administrators" -Members "Dragon" -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "Remote Management Users" -Members "Dragon" -ErrorAction SilentlyContinue
Write-Information "Group memberships set."

# =============================================
# 2. SMB share with hidden SQLite database
# =============================================
Write-Information "=== Setting up SMB share ==="
$sharePath = "C:\LabShare"
$shareName = "Del_me"
$sqliteFile = "Info.sqlite3"
$sqliteDestination = Join-Path $sharePath $sqliteFile

# Clean up leftovers from any previous run
if (Test-Path (Join-Path $sharePath $shareName)) {
    Remove-Item -Path (Join-Path $sharePath $shareName) -Recurse -Force -ErrorAction SilentlyContinue
    Write-Information "Cleaned up old Del_me subdirectory."
}

# Ensure target folder exists and has clean ACLs
if (-not (Test-Path $sharePath)) {
    New-Item -ItemType Directory -Path $sharePath -Force | Out-Null
} else {
    icacls $sharePath /reset /T /Q 2>$null
    Write-Information "Reset permissions on $sharePath."
}

# Remove existing database file (even if hidden/read-only)
if (Test-Path $sqliteDestination) {
    attrib -h -r -s $sqliteDestination 2>$null
    Remove-Item -Path $sqliteDestination -Force -ErrorAction Stop
    Write-Information "Removed existing $sqliteFile."
}

# Download the database from GitHub
$sqliteUrl = "$GitHubRawBase/Assets/$sqliteFile"
Invoke-WebRequest -Uri $sqliteUrl -OutFile $sqliteDestination -ErrorAction Stop
Write-Information "Downloaded $sqliteFile to $sqliteDestination"

# Hide the file
attrib +h $sqliteDestination

# Remove old share silently, then create new one
if (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue) {
    Remove-SmbShare -Name $shareName -Force -ErrorAction SilentlyContinue
}
New-SmbShare -Name $shareName -Path $sharePath -FullAccess Everyone -Description "Lab share" -ErrorAction Stop
Write-Information "Share '$shareName' created on $sharePath"

# =============================================
# 3. Anonymous / null session access (using reg add – robust)
# =============================================
Write-Information "=== Enabling anonymous access ==="
net user guest /active:yes

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymous /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v EveryoneIncludesAnonymous /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v NullSessionShares /t REG_MULTI_SZ /d $shareName /f

Restart-Service LanmanServer -Force
Write-Information "Anonymous access configured. LanmanServer restarted."

# =============================================
# 4. ACL delegation (GenericWrite)
# =============================================
Write-Information "=== Setting ACLs ==="
$johnDN = (Get-ADUser "John Willium").DistinguishedName
$orangeDN = (Get-ADUser "Orange").DistinguishedName
$mangoDN = (Get-ADUser "Mango").DistinguishedName

function Grant-GenericWrite {
    param($TargetDN, $PrincipalDN)
    $acl = Get-Acl "AD:\$TargetDN"
    $sid = (Get-ADUser -Identity $PrincipalDN).SID
    $identity = New-Object System.Security.Principal.SecurityIdentifier($sid)
    $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        $identity,
        [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $acl.AddAccessRule($ace)
    Set-Acl -Path "AD:\$TargetDN" -AclObject $acl
}

Grant-GenericWrite -TargetDN $orangeDN -PrincipalDN $johnDN
Write-Information "Granted John Willium GenericWrite over Orange."

Grant-GenericWrite -TargetDN $mangoDN -PrincipalDN $johnDN
Write-Information "Granted John Willium GenericWrite over Mango (rabbit hole)."

# =============================================
# 5. Enable AD Recycle Bin
# =============================================
Write-Information "=== Enabling AD Recycle Bin ==="
Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target $domainDNS -Confirm:$false
Write-Information "AD Recycle Bin enabled (if not already)."

# =============================================
# 6. Place flags (CTF style)
# =============================================
Write-Information "=== Writing flags ==="
$userFlag = 'Flag{9f5b2c7e4a13d8f6e0b4c8a2d1f7e6b0}'
$rootFlag = 'Flag{e3d1a7f0b9c6d5e4a3b2c1d0e9f8a7b6}'

$orangeDesktop = "C:\Users\Orange\Desktop"
$adminDesktop  = "C:\Users\Administrator\Desktop"

if (-not (Test-Path $orangeDesktop)) { New-Item -ItemType Directory -Path $orangeDesktop -Force | Out-Null }
Set-Content -Path (Join-Path $orangeDesktop "user.txt") -Value $userFlag -Force

if (-not (Test-Path $adminDesktop)) { New-Item -ItemType Directory -Path $adminDesktop -Force | Out-Null }
Set-Content -Path (Join-Path $adminDesktop "root.txt") -Value $rootFlag -Force

Write-Information "Flags written."

# =============================================
# 7. ESC1 vulnerable certificate template
# =============================================
Write-Information "=== Configuring AD CS ESC1 ==="

$ca = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration" -ErrorAction SilentlyContinue
if (-not $ca) {
    Write-Warning "AD CS does not appear to be installed. Skipping certificate template setup."
} else {
    $caName = $ca.PSChildName
    Write-Information "Found CA: $caName"

    $templateName = "ESC1Test"
    $templateDN = "CN=$templateName,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"
    $userTemplateDN = "CN=User,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"

    if (Get-ADObject -Filter "distinguishedName -eq '$templateDN'" -ErrorAction SilentlyContinue) {
        Write-Warning "ESC1Test template already exists. Removing and recreating..."
        Remove-ADObject -Identity $templateDN -Recursive -Confirm:$false
    }

    $userTemplate = Get-ADObject -Identity $userTemplateDN -Properties *
    $newTemplate = $userTemplate | Select-Object *
    $newTemplate.DistinguishedName = $templateDN
    $newTemplate.Name = $templateName
    $newTemplate.DisplayName = $templateName

    $newTemplate.'msPKI-Certificate-Name-Flag' = 1
    $newTemplate.'msPKI-Enrollment-Flag' = 0
    $newTemplate.'msPKI-Certificate-Application-Policy' = @("1.3.6.1.5.5.7.3.2")

    $attrList = @('distinguishedName','objectGUID','objectSid','cn','whenCreated','whenChanged','uSNCreated','uSNChanged','dSCorePropagationData')
    foreach ($attr in $attrList) {
        $newTemplate.PSBase.Properties.Remove($attr)
    }

    $newTemplate | New-ADObject -Type "pKICertificateTemplate" -Path "CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"
    Write-Information "ESC1Test template created."

    $templateACL = Get-Acl "AD:\$templateDN"
    $orangeSID = (Get-ADUser Orange).SID
    $identity = New-Object System.Security.Principal.SecurityIdentifier($orangeSID)
    $enrollGuid = New-Object Guid "0e10c968-78fb-11d2-90d4-00c04f79dc55"
    $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        $identity,
        [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
        [System.Security.AccessControl.AccessControlType]::Allow,
        $enrollGuid
    )
    $templateACL.AddAccessRule($ace)
    Set-Acl -Path "AD:\$templateDN" -AclObject $templateACL
    Write-Information "Orange granted Enroll permission on ESC1Test."

    certutil -SetCAtemplates +$templateName
    Write-Information "Template published to CA."

    Write-Information "Configuring DC Kerberos Authentication certificate..."
    certutil -SetCAtemplates +KerberosAuthentication
    certutil -pulse
    gpupdate /force | Out-Null
    Start-Sleep -Seconds 5

    certreq -enroll -machine -q KerberosAuthentication
    Write-Information "DC enrollment requested."

    Restart-Service kdc
    Write-Information "KDC service restarted."
}

# =============================================
# 8. Summary
# =============================================
Write-Information "========================================="
Write-Information "Lab setup complete!"
Write-Information ""
Write-Information "User flag : $userFlag"
Write-Information "Root flag : $rootFlag"
Write-Information "SMB share : \\$dcFQDN\$shareName (hidden DB: $sqliteFile)"
Write-Information ""
Write-Information "Attack path:"
Write-Information "  1. Enumerate SMB anonymously -> find & download Info.sqlite3"
Write-Information "  2. Crack John Willium's password (hint inside DB)"
Write-Information "  3. Use John's GenericWrite over Orange to take control"
Write-Information "  4. As Orange, request ESC1 cert for Administrator with -sid"
Write-Information "  5. Authenticate with the cert -> Domain Admin"
Write-Information "========================================="
