Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-StrongPassword([int]$Length = 24) {
    $lower = "abcdefghjkmnpqrstuvwxyz"
    $upper = "ABCDEFGHJKMNPQRSTUVWXYZ"
    $digits = "23456789"
    $symbols = "!@#%*+-_"
    $all = "$lower$upper$digits$symbols"

    $required = @(
        $lower[(Get-Random -Minimum 0 -Maximum $lower.Length)],
        $upper[(Get-Random -Minimum 0 -Maximum $upper.Length)],
        $digits[(Get-Random -Minimum 0 -Maximum $digits.Length)],
        $symbols[(Get-Random -Minimum 0 -Maximum $symbols.Length)]
    )

    $remainingCount = [Math]::Max(0, $Length - $required.Count)
    $remaining = for ($i = 0; $i -lt $remainingCount; $i++) {
        $all[(Get-Random -Minimum 0 -Maximum $all.Length)]
    }

    $passwordChars = $required + $remaining | Sort-Object { Get-Random }
    return -join $passwordChars
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $repoRoot
try {
    $envPath = Join-Path $PSScriptRoot ".env.sqlserver"
    $envExamplePath = Join-Path $PSScriptRoot ".env.sqlserver.example"
    $composeFile = Join-Path $PSScriptRoot "docker-compose.sqlserver.yml"
    $envGenerated = $false
    if (-not (Test-Path $envPath)) {
        if (-not (Test-Path $envExamplePath)) {
            throw "Arquivo .env.sqlserver.example nao encontrado."
        }

        Copy-Item $envExamplePath $envPath
        $envGenerated = $true
    }

    $envMap = @{}
    foreach ($line in (Get-Content $envPath)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.TrimStart().StartsWith("#")) { continue }
        $index = $line.IndexOf("=")
        if ($index -lt 1) { continue }
        $key = $line.Substring(0, $index).Trim()
        $value = $line.Substring($index + 1)
        $envMap[$key] = $value
    }

    if (-not $envMap.ContainsKey("MSSQL_SA_PASSWORD") -or $envMap["MSSQL_SA_PASSWORD"] -eq "YourStrongPassword!123") {
        $envMap["MSSQL_SA_PASSWORD"] = New-StrongPassword
    }
    if ($envMap["MSSQL_SA_PASSWORD"] -match '\$') {
        $envMap["MSSQL_SA_PASSWORD"] = New-StrongPassword
    }
    if (-not $envMap.ContainsKey("MSSQL_MONITOR_PASSWORD") -or $envMap["MSSQL_MONITOR_PASSWORD"] -eq "YourStrongPassword!456") {
        $envMap["MSSQL_MONITOR_PASSWORD"] = New-StrongPassword
    }
    if ($envMap["MSSQL_MONITOR_PASSWORD"] -match '\$') {
        $envMap["MSSQL_MONITOR_PASSWORD"] = New-StrongPassword
    }
    if (-not $envMap.ContainsKey("MSSQL_BACKUP_PASSWORD") -or $envMap["MSSQL_BACKUP_PASSWORD"] -eq "YourStrongPassword!789") {
        $envMap["MSSQL_BACKUP_PASSWORD"] = New-StrongPassword
    }
    if ($envMap["MSSQL_BACKUP_PASSWORD"] -match '\$') {
        $envMap["MSSQL_BACKUP_PASSWORD"] = New-StrongPassword
    }
    if (-not $envMap.ContainsKey("SQLSERVER_BIND_IP")) {
        $envMap["SQLSERVER_BIND_IP"] = "127.0.0.1"
    }
    if (-not $envMap.ContainsKey("SQLSERVER_PORT")) {
        $envMap["SQLSERVER_PORT"] = "1433"
    }
    if (-not $envMap.ContainsKey("STREAMLIT_BIND_IP")) {
        $envMap["STREAMLIT_BIND_IP"] = "127.0.0.1"
    }
    if (-not $envMap.ContainsKey("STREAMLIT_PORT")) {
        $envMap["STREAMLIT_PORT"] = "8501"
    }
    if (-not $envMap.ContainsKey("CONNECTION_AUDIT_RETENTION_DAYS")) {
        $envMap["CONNECTION_AUDIT_RETENTION_DAYS"] = "30"
    }
    if (-not $envMap.ContainsKey("BACKUP_INTERVAL_HOURS")) {
        $envMap["BACKUP_INTERVAL_HOURS"] = "24"
    }
    if (-not $envMap.ContainsKey("BACKUP_RETENTION_DAYS")) {
        $envMap["BACKUP_RETENTION_DAYS"] = "14"
    }

    @(
        "MSSQL_SA_PASSWORD=$($envMap["MSSQL_SA_PASSWORD"])",
        "MSSQL_MONITOR_PASSWORD=$($envMap["MSSQL_MONITOR_PASSWORD"])",
        "MSSQL_BACKUP_PASSWORD=$($envMap["MSSQL_BACKUP_PASSWORD"])",
        "CONNECTION_AUDIT_RETENTION_DAYS=$($envMap["CONNECTION_AUDIT_RETENTION_DAYS"])",
        "BACKUP_INTERVAL_HOURS=$($envMap["BACKUP_INTERVAL_HOURS"])",
        "BACKUP_RETENTION_DAYS=$($envMap["BACKUP_RETENTION_DAYS"])",
        "SQLSERVER_BIND_IP=$($envMap["SQLSERVER_BIND_IP"])",
        "SQLSERVER_PORT=$($envMap["SQLSERVER_PORT"])",
        "STREAMLIT_BIND_IP=$($envMap["STREAMLIT_BIND_IP"])",
        "STREAMLIT_PORT=$($envMap["STREAMLIT_PORT"])"
    ) | Set-Content $envPath

    if ($envGenerated) {
        Write-Host "Arquivo .env.sqlserver criado com credenciais fortes e defaults seguros."
    }

    cmd /c "docker info >nul 2>nul"
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Engine nao esta disponivel."
    }

    # Evita conflito de nomes ao trocar localizacao do compose
    foreach ($legacyContainer in @("dw_etl_monitor", "dw_sql_init", "dw_sqlserver", "dw_sql_volume_init", "dw_sql_backup")) {
        cmd /c "docker rm -f $legacyContainer >nul 2>nul"
    }

    docker compose --env-file $envPath -f $composeFile up -d --build
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao subir o stack Docker (docker compose up retornou $LASTEXITCODE)."
    }

    Write-Host ""
    Write-Host "Stack iniciada."
    Write-Host "- SQL Server:  localhost:1433"
    Write-Host "- Streamlit:   http://localhost:8501"
    Write-Host "- Backup loop: ativo em dw_sql_backup (intervalo em BACKUP_INTERVAL_HOURS)"
}
finally {
    Pop-Location
}
