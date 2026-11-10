$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../docker/resolve-versions.ps1')

# Self-contained fixtures: no Docker daemon, network, or Pester required.
$script:scenario = 'stable'
$script:requests = @()
function Invoke-RestMethod {
    param($Uri, $Headers, $TimeoutSec, $ErrorAction)
    $script:requests += $Uri
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

$versions = Resolve-ProjectVersions
if ($versions.PHP -ne '9.0.1' -or $versions.Composer -ne '3.0.1' -or
    $versions.Symfony -ne '9.2.3' -or $versions.SymfonyBranch -ne '9.2' -or
    $versions.FrankenPHPImage -ne 'dunglas/frankenphp:2.0.0-php9.0.1-trixie') {
    throw 'Stable resolution failed, including future major versions.'
}
foreach ($case in @('offline', 'prerelease', 'invalid')) {
    $script:scenario = $case
    $failed = $false
    try { Resolve-ProjectVersions | Out-Null } catch { $failed = $true }
    if (-not $failed) { throw "Expected rejection: $case" }
}
$script:scenario = 'offline'
$script:requests = @()
$pins = @{ PHP_VERSION='8.5.12'; FRANKENPHP_VERSION='1.13.5'; SYMFONY_VERSION='7.4.23'; COMPOSER_VERSION='2.11.2' }
$pinned = Resolve-ProjectVersions -Preferences $pins
if ($pinned.Symfony -ne '7.4.23' -or $pinned.SymfonyBranch -ne '7.4' -or
    $pinned.PHP -ne '8.5.12' -or $pinned.FrankenPHP -ne '1.13.5' -or
    $pinned.Composer -ne '2.11.2' -or $script:requests.Count -ne 0) {
    throw 'Exact versions must be preserved without calling stable APIs.'
}
$script:scenario = 'stable'
$script:requests = @()
$mixed = Resolve-ProjectVersions -Preferences @{ PHP_VERSION='8.4.27'; SYMFONY_VERSION='stable'; FRANKENPHP_VERSION='1.13.5'; COMPOSER_VERSION='2.11.2' }
if ($mixed.Symfony -ne '9.2.3' -or $mixed.PHP -ne '8.4.27' -or $script:requests.Count -ne 1 -or $script:requests[0] -notlike '*symfony.com*') {
    throw 'Mixed versions must resolve only the stable preference.'
}
foreach ($key in $pins.Keys) {
    foreach ($invalid in @('', 'latest', '8.5', '8.5.*', '^8.5.0', '8.6.0-RC1', 'v8.5.12', '08.5.12', '8.5.12;echo nope')) {
        $bad = $pins.Clone()
        $bad[$key] = $invalid
        $script:requests = @()
        $failed = $false
        try { Resolve-ProjectVersions -Preferences $bad | Out-Null } catch { $failed = $true }
        if (-not $failed -or $script:requests.Count -ne 0) { throw "Invalid preference accepted or API called: $key=$invalid" }
    }
}
$parsed = Get-VersionPreferences -ComposeEnvironment @('PHP_VERSION=8.4.27','SYMFONY_VERSION=stable','DATABASE_URL=private','PATH=private')
if ($parsed.Count -ne 2 -or $parsed.PHP_VERSION -ne '8.4.27') { throw 'Preference filtering failed' }
Write-Output 'PASS: default stable, exact pins without APIs, mixed preferences, invalid values, API failures, prereleases, environment filtering.'
