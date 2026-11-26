BeforeAll {
    . "$PSScriptRoot/../../infra/iaas/scripts/deploy-iis-release.ps1"
    . "$PSScriptRoot/../../infra/iaas/scripts/rollback-iis.ps1"
}

Describe 'IIS Atomic Release & Rollback Scripts' {
    It 'rejects a release ZIP when SHA-256 checksum does not match' {
        $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) "bad-release-$([guid]::NewGuid()).zip"
        Set-Content -Path $tmpFile -Value 'payload'
        try {
            { Assert-ReleaseChecksum -Path $tmpFile -Expected '0000000000000000000000000000000000000000000000000000000000000000' } | Should -Throw '*SHA-256 checksum mismatch*'
        } finally {
            Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue
        }
    }

    It 'resolves rollback version from .previous marker' {
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "iis-root-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        Set-Content -Path (Join-Path $tmpDir '.previous') -Value 'sha-1111111'
        try {
            Resolve-RollbackVersion -Root $tmpDir -ExplicitVersion '' | Should -Be 'sha-1111111'
        } finally {
            Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
