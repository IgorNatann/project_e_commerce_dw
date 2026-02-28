param(
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$legacyPrefixes = @(
    "docker_sqlserver_",
    "project_e-commerce_dw_sqlserver_"
)

$volumes = docker volume ls --format "{{.Name}}"
if (-not $volumes) {
    Write-Host "Nenhum volume encontrado."
    exit 0
}

$candidates = @()
foreach ($volume in $volumes) {
    foreach ($prefix in $legacyPrefixes) {
        if ($volume.StartsWith($prefix)) {
            $candidates += $volume
            break
        }
    }
}

if ($candidates.Count -eq 0) {
    Write-Host "Nenhum volume legado encontrado."
    exit 0
}

foreach ($volume in $candidates | Sort-Object -Unique) {
    $usingContainers = docker ps -a --filter "volume=$volume" --format "{{.Names}}"
    if ($usingContainers) {
        Write-Host "[SKIP] $volume em uso por: $usingContainers"
        continue
    }

    if ($Apply) {
        docker volume rm $volume | Out-Null
        Write-Host "[REMOVIDO] $volume"
    }
    else {
        Write-Host "[DRY-RUN] removeria $volume (use -Apply para confirmar)"
    }
}
