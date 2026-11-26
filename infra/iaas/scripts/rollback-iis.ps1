<#
.SYNOPSIS
    1-command atomic IIS rollback to the previous verified release directory.
#>
[CmdletBinding()]
param(
    [string]$TargetVersion = '',
    [string]$ReleasesRoot = 'C:\inetpub\releases',
    [string]$SiteName = 'Default Web Site'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RollbackVersion {
    param([string]$Root, [string]$ExplicitVersion)
    if (-not [string]::IsNullOrWhiteSpace($ExplicitVersion)) {
        return $ExplicitVersion.Trim()
    }
    $prevMarker = Join-Path $Root '.previous'
    if (-not (Test-Path $prevMarker)) {
        throw "No previous release marker found at '$prevMarker'. Pass -TargetVersion explicitly."
    }
    return (Get-Content -Path $prevMarker -Raw).Trim()
}

if ($MyInvocation.InvocationName -ne '.') {
    $version = Resolve-RollbackVersion -Root $ReleasesRoot -ExplicitVersion $TargetVersion
    $targetPath = Join-Path $ReleasesRoot $version
    if (-not (Test-Path $targetPath)) {
        throw "Rollback target directory '$targetPath' does not exist."
    }
    Import-Module WebAdministration
    Set-ItemProperty -Path "IIS:\Sites\$SiteName" -Name physicalPath -Value $targetPath
    Set-Content -Path (Join-Path $ReleasesRoot '.active') -Value $version -Encoding UTF8
    Write-Output "Rolled back IIS site '$SiteName' to '$version' ($targetPath)."
}
