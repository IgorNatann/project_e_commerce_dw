param(
    [switch]$Json,
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$suiteDefs = @(
    @{ Name = "dash_vendas_filter_smoke"; Script = "run_dash_vendas_filter_smoke.ps1" },
    @{ Name = "dash_metas_filter_smoke"; Script = "run_dash_metas_filter_smoke.ps1" },
    @{ Name = "dash_descontos_filter_smoke"; Script = "run_dash_descontos_filter_smoke.ps1" },
    @{ Name = "dw_integrity_minimum"; Script = "run_dw_integrity_minimum.ps1" }
)

function Convert-OutputToJsonObject {
    param([object[]]$OutputLines)

    $stringLines = @($OutputLines | ForEach-Object { "$_" })
    if (-not $stringLines -or $stringLines.Count -eq 0) {
        return $null
    }

    $joined = ($stringLines -join "`n").Trim()
    $firstBrace = $joined.IndexOf("{")
    $lastBrace = $joined.LastIndexOf("}")
    if ($firstBrace -lt 0 -or $lastBrace -lt $firstBrace) {
        return $null
    }
    $jsonCandidate = $joined.Substring($firstBrace, ($lastBrace - $firstBrace + 1))

    try {
        return ($jsonCandidate | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Invoke-SuiteScript {
    param(
        [string]$SuiteName,
        [string]$ScriptName
    )

    $scriptPath = Join-Path $scriptDir $ScriptName
    if (-not (Test-Path $scriptPath)) {
        return [pscustomobject]@{
            suite = $SuiteName
            exit_code = 1
            summary = [pscustomobject]@{ total = 0; passed = 0; failed = 1 }
            raw_output = "Script nao encontrado: $scriptPath"
            payload = $null
        }
    }

    $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Json 2>&1
    $exitCode = $LASTEXITCODE
    $payload = Convert-OutputToJsonObject -OutputLines $raw

    if (-not $payload) {
        return [pscustomobject]@{
            suite = $SuiteName
            exit_code = 1
            summary = [pscustomobject]@{ total = 0; passed = 0; failed = 1 }
            raw_output = (($raw | ForEach-Object { "$_" }) -join "`n")
            payload = $null
        }
    }

    $total = 0
    $passed = 0
    $failed = 0
    if ($payload.summary.total_tests -ne $null) {
        $total = [int]$payload.summary.total_tests
        $passed = [int]$payload.summary.passed
        $failed = [int]$payload.summary.failed
    } elseif ($payload.summary.total_checks -ne $null) {
        $total = [int]$payload.summary.total_checks
        $passed = [int]$payload.summary.passed
        $failed = [int]$payload.summary.failed
    }

    return [pscustomobject]@{
        suite = $SuiteName
        exit_code = $exitCode
        summary = [pscustomobject]@{
            total = $total
            passed = $passed
            failed = $failed
        }
        raw_output = (($raw | ForEach-Object { "$_" }) -join "`n")
        payload = $payload
    }
}

$suiteResults = @()
foreach ($suiteDef in $suiteDefs) {
    $suiteResults += Invoke-SuiteScript -SuiteName $suiteDef.Name -ScriptName $suiteDef.Script
}

$totalSuites = $suiteResults.Count
$failedSuites = ($suiteResults | Where-Object { $_.exit_code -ne 0 -or $_.summary.failed -gt 0 }).Count
$passedSuites = $totalSuites - $failedSuites

$totalChecks = 0
$passedChecks = 0
$failedChecks = 0
foreach ($suiteResult in $suiteResults) {
    $totalChecks += [int]$suiteResult.summary.total
    $passedChecks += [int]$suiteResult.summary.passed
    $failedChecks += [int]$suiteResult.summary.failed
}

if ($null -eq $totalChecks) { $totalChecks = 0 }
if ($null -eq $passedChecks) { $passedChecks = 0 }
if ($null -eq $failedChecks) { $failedChecks = 0 }

$payload = [ordered]@{
    suite = "day4_recurring_tests"
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    summary = [ordered]@{
        total_suites = $totalSuites
        passed_suites = $passedSuites
        failed_suites = $failedSuites
        total_checks = [int]$totalChecks
        passed_checks = [int]$passedChecks
        failed_checks = [int]$failedChecks
    }
    suites = @(
        $suiteResults | ForEach-Object {
            [ordered]@{
                suite = $_.suite
                exit_code = $_.exit_code
                summary = $_.summary
                payload = $_.payload
                raw_output = $_.raw_output
            }
        }
    )
}

$payloadJson = $payload | ConvertTo-Json -Depth 100 -Compress

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputDir = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    Set-Content -Path $OutputPath -Value $payloadJson -Encoding UTF8
}

if ($Json) {
    Write-Output $payloadJson
} else {
    Write-Host "Suites: $passedSuites/$totalSuites aprovadas (falhas=$failedSuites)"
    Write-Host "Checks: $passedChecks/$totalChecks aprovados (falhas=$failedChecks)"
    foreach ($suite in $suiteResults) {
        Write-Host "- $($suite.suite): $($suite.summary.passed)/$($suite.summary.total) (falhas=$($suite.summary.failed), exit=$($suite.exit_code))"
    }
}

if ($failedSuites -gt 0) {
    exit 1
}
exit 0
