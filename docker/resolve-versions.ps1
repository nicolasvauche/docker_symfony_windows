# Resolve published stable releases, never preview channels or local cached values.
function Get-LatestStableVersions {
    $headers = @{ 'User-Agent' = 'docker-symfony'; 'Accept' = 'application/json' }
    function Get-ReleaseJson([string]$Uri) {
        Invoke-RestMethod -Uri $Uri -Headers $headers -TimeoutSec 30 -ErrorAction Stop
    }
    function Assert-StableVersion([string]$Value, [string]$Name) {
        if ($Value -notmatch '^\d+\.\d+\.\d+$') {
            throw "Version stable $Name invalide : '$Value'. Installation interrompue."
        }
        return $Value
    }

    $phpReleases = Get-ReleaseJson 'https://www.php.net/releases/index.php?json'
    $phpVersion = @($phpReleases.PSObject.Properties | ForEach-Object { $_.Value.version } |
        Where-Object { $_ -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_ } -Descending)[0]
    $phpVersion = Assert-StableVersion $phpVersion 'PHP'

    $franken = Get-ReleaseJson 'https://api.github.com/repos/php/frankenphp/releases/latest'
    if ($franken.prerelease -or $franken.draft) { throw 'La release FrankenPHP retournee n''est pas stable.' }
    $frankenVersion = Assert-StableVersion ($franken.tag_name -replace '^v', '') 'FrankenPHP'

    $symfony = Get-ReleaseJson 'https://symfony.com/releases.json'
    $symfonyVersion = Assert-StableVersion $symfony.symfony_versions.stable 'Symfony'
    $symfonyBranch = ([version]$symfonyVersion).ToString(2)

    $composer = Get-ReleaseJson 'https://getcomposer.org/versions'
    $composerVersion = @($composer.stable | Where-Object { $_.version -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.version } -Descending)[0].version
    $composerVersion = Assert-StableVersion $composerVersion 'Composer'

    [pscustomobject]@{
        PHP = $phpVersion
        FrankenPHP = $frankenVersion
        Symfony = $symfonyVersion
        SymfonyBranch = $symfonyBranch
        Composer = $composerVersion
        FrankenPHPImage = "dunglas/frankenphp:$frankenVersion-php$phpVersion-trixie"
    }
}
