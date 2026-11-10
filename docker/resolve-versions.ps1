# Compose parses .env (quotes, comments and process-environment precedence).
# Keep only version preferences; never print or evaluate other environment values.
function Get-VersionPreferences {
    param([string[]]$ComposeEnvironment)
    $preferences = @{}
    foreach ($line in $ComposeEnvironment) {
        if ($line -match '^(PHP_VERSION|FRANKENPHP_VERSION|SYMFONY_VERSION|COMPOSER_VERSION)=(.*)$') {
            $preferences[$Matches[1]] = $Matches[2]
        }
    }
    return $preferences
}

function Resolve-ProjectVersions {
    param([hashtable]$Preferences = @{})
    $headers = @{ 'User-Agent' = 'docker-symfony'; 'Accept' = 'application/json' }
    function Get-ReleaseJson([string]$Uri) {
        Invoke-RestMethod -Uri $Uri -Headers $headers -TimeoutSec 30 -ErrorAction Stop
    }
    function Assert-StableVersion([string]$Value, [string]$Name) {
        if ($Value -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
            throw "Version stable $Name invalide : '$Value'. Installation interrompue."
        }
        return $Value
    }

    $selected = @{}
    foreach ($key in @('PHP_VERSION','FRANKENPHP_VERSION','SYMFONY_VERSION','COMPOSER_VERSION')) {
        $value = if ($Preferences.ContainsKey($key)) { ([string]$Preferences[$key]).Trim() } else { 'stable' }
        if ($value -cne 'stable') {
            if ($value -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
                throw "$key invalide : '$value'. Utilisez stable ou une version exacte X.Y.Z (sans prefixe v, joker ou prerelease)."
            }
        }
        $selected[$key] = $value
    }

    $phpVersion = $selected.PHP_VERSION
    if ($phpVersion -eq 'stable') {
        $phpReleases = Get-ReleaseJson 'https://www.php.net/releases/index.php?json'
        $phpVersion = @($phpReleases.PSObject.Properties | ForEach-Object { $_.Value.version } |
            Where-Object { $_ -match '^\d+\.\d+\.\d+$' } |
            Sort-Object { [version]$_ } -Descending)[0]
        $phpVersion = Assert-StableVersion $phpVersion 'PHP'
    }

    $frankenVersion = $selected.FRANKENPHP_VERSION
    if ($frankenVersion -eq 'stable') {
        $franken = Get-ReleaseJson 'https://api.github.com/repos/php/frankenphp/releases/latest'
        if ($franken.prerelease -or $franken.draft) { throw 'La release FrankenPHP retournee n''est pas stable.' }
        $frankenVersion = Assert-StableVersion ($franken.tag_name -replace '^v', '') 'FrankenPHP'
    }

    $symfonyVersion = $selected.SYMFONY_VERSION
    if ($symfonyVersion -eq 'stable') {
        $symfony = Get-ReleaseJson 'https://symfony.com/releases.json'
        $symfonyVersion = Assert-StableVersion $symfony.symfony_versions.stable 'Symfony'
    }
    $symfonyBranch = ([version]$symfonyVersion).ToString(2)

    $composerVersion = $selected.COMPOSER_VERSION
    if ($composerVersion -eq 'stable') {
        $composer = Get-ReleaseJson 'https://getcomposer.org/versions'
        $composerVersion = @($composer.stable | Where-Object { $_.version -match '^\d+\.\d+\.\d+$' } |
            Sort-Object { [version]$_.version } -Descending)[0].version
        $composerVersion = Assert-StableVersion $composerVersion 'Composer'
    }

    [pscustomobject]@{
        PHP = $phpVersion
        FrankenPHP = $frankenVersion
        Symfony = $symfonyVersion
        SymfonyBranch = $symfonyBranch
        Composer = $composerVersion
        FrankenPHPImage = "dunglas/frankenphp:$frankenVersion-php$phpVersion-trixie"
    }
}
