param(
    [string]$ContainerName = "dw_dash_metas",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$localValidator = Join-Path $scriptDir "validate_dash_metas_filters.py"
$containerValidator = "/tmp/validate_dash_metas_filters.py"

if (-not (Test-Path $localValidator)) {
    Write-Error "Arquivo nao encontrado: $localValidator"
    exit 1
}

$containerIsRunning = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $ContainerName }
if (-not $containerIsRunning) {
    Write-Error "Container '$ContainerName' nao esta em execucao."
    exit 1
}

docker cp $localValidator "${ContainerName}:${containerValidator}" | Out-Null

$dockerArgs = @("exec", $ContainerName, "python", $containerValidator)
if ($Json) {
    $dockerArgs += "--json"
}

& docker @dockerArgs
$exitCode = $LASTEXITCODE

try {
    docker exec -u 0 $ContainerName sh -lc "rm -f $containerValidator" | Out-Null
} catch {
}

exit $exitCode
