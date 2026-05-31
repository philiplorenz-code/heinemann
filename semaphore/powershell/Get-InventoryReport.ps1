#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Inventory-Report: Sammelt System-Infos und gibt sie strukturiert aus.
    Cross-platform — läuft auf Linux (Alpine), macOS und Windows.
    In Semaphore als Bash-App-Typ konfiguriert, ausgeführt via pwsh.
#>
[CmdletBinding()]
param()

# Parameter aus Umgebungsvariablen (Semaphore übergibt extra_vars als CLI-Args)
$OutputFormat = $env:OUTPUT_FORMAT ?? "text"
$OutputPath   = $env:OUTPUT_PATH   ?? "/tmp/inventory-report"

$SemaphoreTaskId    = $env:SEMAPHORE_TASK_ID    ?? "local-run"
$SemaphoreProjectId = $env:SEMAPHORE_PROJECT_ID ?? "none"

Write-Host "=== Semaphore Inventory Report ===" -ForegroundColor Cyan
Write-Host "Task-ID: $SemaphoreTaskId | Projekt: $SemaphoreProjectId"
Write-Host ""

# Cross-platform System-Infos
$info = [PSCustomObject]@{
    Hostname      = [System.Net.Dns]::GetHostName()
    OS            = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    Architecture  = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
    PSVersion     = $PSVersionTable.PSVersion.ToString()
    DotNetVersion = [System.Environment]::Version.ToString()
    CPUCount      = [System.Environment]::ProcessorCount
    Timestamp     = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    SemaphoreTask = $SemaphoreTaskId
}

# Disk-Info (cross-platform)
$disk = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -ne "" } | Select-Object -First 1
if ($disk) {
    $info | Add-Member -MemberType NoteProperty -Name "DiskFreeGB"  -Value ([math]::Round($disk.Free  / 1GB, 2))
    $info | Add-Member -MemberType NoteProperty -Name "DiskTotalGB" -Value ([math]::Round(($disk.Free + $disk.Used) / 1GB, 2))
}

# Env-Variablen ausgeben die Semaphore gesetzt hat
$semaphoreEnvVars = Get-ChildItem Env: | Where-Object { $_.Name -like "SEMAPHORE_*" }

switch ($OutputFormat) {
    "json" {
        $report = @{ system = $info; semaphore_env = ($semaphoreEnvVars | ForEach-Object { @{$_.Name = $_.Value} }) }
        $report | ConvertTo-Json -Depth 3 | Tee-Object -FilePath "${OutputPath}.json"
        Write-Host "`nJSON gespeichert: ${OutputPath}.json" -ForegroundColor Green
    }
    "csv" {
        $info | Export-Csv -Path "${OutputPath}.csv" -NoTypeInformation -Encoding UTF8
        Write-Host "CSV gespeichert: ${OutputPath}.csv" -ForegroundColor Green
    }
    default {
        Write-Host "=== System ===" -ForegroundColor Yellow
        $info | Format-List *

        if ($semaphoreEnvVars) {
            Write-Host "`n=== Semaphore Kontext ===" -ForegroundColor Yellow
            $semaphoreEnvVars | ForEach-Object { Write-Host "  $($_.Name) = $($_.Value)" }
        }
    }
}

Write-Host "`n=== Report abgeschlossen ===" -ForegroundColor Green
exit 0
