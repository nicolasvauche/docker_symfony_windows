$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../docker/resolve-versions.ps1')

# Self-contained fixtures: no Docker daemon, network, or Pester required.
$script:scenario = 'stable'
function Invoke-RestMethod {
    param($Uri, $Headers, $TimeoutSec, $ErrorAction)
    if ($script:scenario -eq 'offline') { throw 'Network unavailable' }
    switch -Wildcard ($Uri) {
        '*php.net*' { return '{"9":{"version":"9.0.1"},"8":{"version":"8.9.99"},"next":{"version":"10.0.0RC1"}}' | ConvertFrom-Json }
        '*github.com*' {
            if ($script:scenario -eq 'prerelease') { return '{"tag_name":"v2.0.0","draft":false,"prerelease":true}' | ConvertFrom-Json }
            return '{"tag_name":"v2.0.0","draft":false,"prerelease":false}' | ConvertFrom-Json
        }
        '*symfony.com*' {
            if ($script:scenario -eq 'invalid') { return '{"symfony_versions":{"stable":"10.0.0-BETA1"}}' | ConvertFrom-Json }
            return '{"symfony_versions":{"stable":"9.2.3","next":"10.0.0-BETA1"}}' | ConvertFrom-Json
        }
        '*getcomposer.org*' { return '{"stable":[{"version":"2.2.99"},{"version":"3.0.1"}],"preview":[{"version":"4.0.0-RC1"}]}' | ConvertFrom-Json }
        default { throw "Unexpected URL: $Uri" }
    }
}

$versions = Get-LatestStableVersions
if ($versions.PHP -ne '9.0.1' -or $versions.Composer -ne '3.0.1' -or
    $versions.Symfony -ne '9.2.3' -or $versions.SymfonyBranch -ne '9.2' -or
    $versions.FrankenPHPImage -ne 'dunglas/frankenphp:2.0.0-php9.0.1-trixie') {
    throw 'Stable resolution failed, including future major versions.'
}
foreach ($case in @('offline', 'prerelease', 'invalid')) {
    $script:scenario = $case
    $failed = $false
    try { Get-LatestStableVersions | Out-Null } catch { $failed = $true }
    if (-not $failed) { throw "Expected rejection: $case" }
}
Write-Output 'PASS: stable selection, future majors, exact image tag, offline failure, prerelease rejection, malformed stable rejection.'
