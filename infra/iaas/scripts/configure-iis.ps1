<#
.SYNOPSIS
    Idempotently installs and hardens IIS on Windows Server 2022 for Track B (IaaS).
#>
[CmdletBinding()]
param(
    [string]$ReleasesRoot = 'C:\inetpub\releases',
    [string]$SiteName = 'Default Web Site'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Initialize-IisDirectories {
    param([string]$Root)
    if (-not (Test-Path -Path $Root)) {
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
    }
    $initialRelease = Join-Path $Root 'initial'
    if (-not (Test-Path -Path $initialRelease)) {
        New-Item -ItemType Directory -Path $initialRelease -Force | Out-Null
        '{"status":"ok"}' | Set-Content -Path (Join-Path $initialRelease 'health.json') -Encoding UTF8
    }
    return $initialRelease
}

function Set-TlsHardeningRegistry {
    $protocolsPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    foreach ($weak in @('TLS 1.0', 'TLS 1.1', 'SSL 3.0')) {
        $serverKey = Join-Path $protocolsPath "$weak\Server"
        New-Item -Path $serverKey -Force | Out-Null
        New-ItemProperty -Path $serverKey -Name 'Enabled' -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $serverKey -Name 'DisabledByDefault' -Value 1 -PropertyType DWord -Force | Out-Null
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Install-WindowsFeature -Name Web-Server, Web-Static-Compression, Web-Scripting-Tools -IncludeManagementTools | Out-Null
    Import-Module WebAdministration
    $initialPath = Initialize-IisDirectories -Root $ReleasesRoot
    Set-ItemProperty -Path "IIS:\Sites\$SiteName" -Name physicalPath -Value $initialPath
    Set-TlsHardeningRegistry
    Write-Output "IIS provisioned and hardened with root '$initialPath'."
}
