param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'start', 'stop', 'console', 'composer', 'logs', 'check')]
    [string]$Action = 'start',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Docker {
    param([string[]]$DockerArgs)
    & docker @DockerArgs
    if ($LASTEXITCODE -ne 0) { throw "Docker a echoue (code $LASTEXITCODE)." }
}

Push-Location $PSScriptRoot
try {
    Invoke-Docker @('info', '--format', '{{.OSType}}')
    switch ($Action) {
        'init' {
            $existing = @(Get-ChildItem -LiteralPath ./app -Force | Where-Object Name -ne '.gitkeep')
            if ($existing.Count -gt 0) { throw 'Le dossier app doit etre vide. Aucun fichier ne sera ecrase.' }
            $flavor = 'webapp'
            if ($CommandArgs.Count -gt 0) {
                if ($CommandArgs.Count -ne 1 -or $CommandArgs[0] -notin @('webapp', 'skeleton')) {
                    throw 'Utilisation : ./dev.ps1 init [webapp|skeleton]'
                }
                $flavor = $CommandArgs[0]
            }
            Invoke-Docker @('build', '--pull', '--target', 'base', '-t', 'docker-symfony-base', '.')
            $appPath = (Resolve-Path ./app).Path
            $initPath = (Resolve-Path ./docker/init-project.sh).Path
            Invoke-Docker @('run', '--rm', '--mount', "type=bind,source=$appPath,target=/export", '--mount', "type=bind,source=$initPath,target=/init-project.sh,readonly", '--entrypoint', 'sh', 'docker-symfony-base', '/init-project.sh', $flavor)
            Invoke-Docker @('compose', 'build', '--pull', 'php')
            Write-Host 'Projet cree. Lancez ./dev.ps1 start puis ouvrez http://localhost:8000'
        }
        'start' {
            if (-not (Test-Path ./app/composer.lock)) { throw 'Lancez ./dev.ps1 init avant le premier demarrage.' }
            Invoke-Docker @('compose', 'up', '--build', '--watch')
        }
        'stop' { Invoke-Docker @('compose', 'down') }
        'logs' { Invoke-Docker @('compose', 'logs', '-f', 'php') }
        'console' {
            Invoke-Docker (@('compose', 'run', '--rm', '--no-deps', 'tools', 'php', 'bin/console') + $CommandArgs)
        }
        'composer' {
            Invoke-Docker (@('compose', 'run', '--rm', '--no-deps', 'tools', 'composer') + $CommandArgs)
            # Rebuild to install the new lockfile in the HTTP image as well.
            Invoke-Docker @('compose', 'build', 'php')
            Write-Host 'Dependances reconstruites. Watch recree le service ; sinon relancez ./dev.ps1 start.'
        }
        'check' {
            Invoke-Docker @('compose', 'exec', 'php', 'php', '-v')
            Invoke-Docker @('compose', 'exec', 'php', 'frankenphp', 'version')
            Invoke-Docker @('compose', 'exec', 'php', 'composer', 'check-platform-reqs')
            Invoke-Docker @('compose', 'exec', 'php', 'php', 'bin/console', 'about')
            Invoke-Docker @('compose', 'exec', 'php', 'php', '/usr/local/lib/check-extensions.php')
        }
    }
} finally {
    Pop-Location
}
