Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $repoRoot
try {
    $envPath = Join-Path $PSScriptRoot ".env.sqlserver"
    $composeFile = Join-Path $PSScriptRoot "docker-compose.sqlserver.yml"
    docker compose --env-file $envPath -f $composeFile down
}
finally {
    Pop-Location
}
