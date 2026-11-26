<#
.SYNOPSIS
    Zero-RDP atomic IIS release deployment with SHA-256 verification and auto-rollback.
#>
[CmdletBinding()]
param(
    [string]$ReleaseZipPath = '',
    [string]$ExpectedSha256 = '',
    [string]$Version = '',
    [string]$ReleasesRoot = 'C:\inetpub\releases',
    [string]$SiteName = 'Default Web Site',
    [string]$HealthUrl = 'http://127.0.0.1/health.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-ReleaseChecksum {
    param([string]$Path, [string]$Expected)
    $actual = (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected.ToLowerInvariant()) {
        throw "SHA-256 checksum mismatch for '$Path': expected $Expected, got $actual."
    }
    return $true
}

function Set-IisSitePhysicalPath {
    param([string]$Name, [string]$PhysicalPath)
    Import-Module WebAdministration
    Set-ItemProperty -Path "IIS:\Sites\$Name" -Name physicalPath -Value $PhysicalPath
}

function Test-LocalHealthProbe {
    param([string]$Url)
    $resp = Invoke-RestMethod -Uri $Url -TimeoutSec 5
    return ($resp.status -eq 'ok')
}

function Invoke-AtomicIisDeploy {
    param(
        [string]$ZipPath,
        [string]$Sha256,
        [string]$ReleaseVersion,
        [string]$Root,
        [string]$Site,
        [string]$ProbeUrl
    )

    Assert-ReleaseChecksum -Path $ZipPath -Expected $Sha256 | Out-Null

    $targetDir = Join-Path $Root $ReleaseVersion
    $activeMarker = Join-Path $Root '.active'
    $prevMarker = Join-Path $Root '.previous'

    if (Test-Path $activeMarker) {
        Copy-Item -Path $activeMarker -Destination $prevMarker -Force
    }

    if (Test-Path $targetDir) {
        Remove-Item -Path $targetDir -Recurse -Force
    }
    Expand-Archive -Path $ZipPath -DestinationPath $targetDir -Force

    Set-IisSitePhysicalPath -Name $Site -PhysicalPath $targetDir
    Set-Content -Path $activeMarker -Value $ReleaseVersion -Encoding UTF8

    if (-not (Test-LocalHealthProbe -Url $ProbeUrl)) {
        if (Test-Path $prevMarker) {
            $prevVersion = (Get-Content -Path $prevMarker -Raw).Trim()
            Set-IisSitePhysicalPath -Name $Site -PhysicalPath (Join-Path $Root $prevVersion)
            Set-Content -Path $activeMarker -Value $prevVersion -Encoding UTF8
        }
        throw "Health probe failed for '$ReleaseVersion'; automatically rolled back."
    }

    return $targetDir
}

if ($MyInvocation.InvocationName -ne '.') {
    if ([string]::IsNullOrWhiteSpace($ReleaseZipPath) -or [string]::IsNullOrWhiteSpace($ExpectedSha256) -or [string]::IsNullOrWhiteSpace($Version)) {
        throw 'ReleaseZipPath, ExpectedSha256, and Version are required when executing deploy-iis-release.ps1.'
    }
    $deployed = Invoke-AtomicIisDeploy -ZipPath $ReleaseZipPath -Sha256 $ExpectedSha256 -ReleaseVersion $Version -Root $ReleasesRoot -Site $SiteName -ProbeUrl $HealthUrl
    Write-Output "Atomically deployed IIS release '$Version' at '$deployed'."
}
