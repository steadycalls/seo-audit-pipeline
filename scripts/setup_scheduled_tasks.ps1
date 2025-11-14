# ============================================
# SEO Audit Pipeline - Task Scheduler Setup
# ============================================
# This script creates Windows Scheduled Tasks for automated execution
# Run this script as Administrator
# ============================================

param(
    [string]$ConfigPath = "$PSScriptRoot\..\config\config.json",
    [string]$ScheduleTime = "02:00"  # Default: 2:00 AM
)

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SEO Audit Pipeline - Task Scheduler Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration
try {
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    Write-Host "✓ Configuration loaded" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to load configuration: $_" -ForegroundColor Red
    exit 1
}

# Define script paths
$scriptDir = Split-Path -Parent $PSScriptRoot
$crawlerScript = Join-Path $scriptDir "scripts\run_crawler.ps1"
$etlScript = Join-Path $scriptDir "scripts\run_etl.py"
$backupScript = Join-Path $scriptDir "scripts\run_backup.ps1"

# Verify scripts exist
$scripts = @{
    "Crawler" = $crawlerScript
    "ETL" = $etlScript
    "Backup" = $backupScript
}

foreach ($script in $scripts.GetEnumerator()) {
    if (-not (Test-Path $script.Value)) {
        Write-Host "✗ $($script.Key) script not found: $($script.Value)" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Found $($script.Key) script" -ForegroundColor Green
}

# Task names
$taskBaseName = "SEO_Audit_Pipeline"
$crawlerTaskName = "$taskBaseName`_1_Crawler"
$etlTaskName = "$taskBaseName`_2_ETL"
$backupTaskName = "$taskBaseName`_3_Backup"

# Remove existing tasks if they exist
Write-Host ""
Write-Host "Removing existing tasks (if any)..." -ForegroundColor Yellow
@($crawlerTaskName, $etlTaskName, $backupTaskName) | ForEach-Object {
    try {
        Unregister-ScheduledTask -TaskName $_ -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "  Removed: $_" -ForegroundColor Gray
    }
    catch {
        # Task doesn't exist, ignore
    }
}

# Get current user
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Write-Host ""
Write-Host "Creating scheduled tasks..." -ForegroundColor Cyan
Write-Host "  Schedule: Daily at $ScheduleTime" -ForegroundColor Gray
Write-Host "  User: $currentUser" -ForegroundColor Gray
Write-Host ""

# ============================================
# Task 1: Crawler
# ============================================

$crawlerAction = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$crawlerScript`""

$crawlerTrigger = New-ScheduledTaskTrigger -Daily -At $ScheduleTime

$crawlerSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable

Register-ScheduledTask `
    -TaskName $crawlerTaskName `
    -Action $crawlerAction `
    -Trigger $crawlerTrigger `
    -Settings $crawlerSettings `
    -User $currentUser `
    -Description "SEO Audit Pipeline - Step 1: Run Screaming Frog crawls" | Out-Null

Write-Host "✓ Created task: $crawlerTaskName" -ForegroundColor Green

# ============================================
# Task 2: ETL (runs after Crawler)
# ============================================

# Find Python executable
$pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $pythonExe) {
    $pythonExe = (Get-Command python3 -ErrorAction SilentlyContinue).Source
}
if (-not $pythonExe) {
    Write-Host "⚠ Python not found in PATH. Using 'python' as default." -ForegroundColor Yellow
    $pythonExe = "python"
}

$etlAction = New-ScheduledTaskAction `
    -Execute $pythonExe `
    -Argument "`"$etlScript`""

# Trigger: Run after crawler task completes successfully
$etlTrigger = New-ScheduledTaskTrigger -Once -At $ScheduleTime
$etlTrigger.Delay = "PT5M"  # Wait 5 minutes after crawler

$etlSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName $etlTaskName `
    -Action $etlAction `
    -Trigger $etlTrigger `
    -Settings $etlSettings `
    -User $currentUser `
    -Description "SEO Audit Pipeline - Step 2: Process CSVs and load to database" | Out-Null

Write-Host "✓ Created task: $etlTaskName" -ForegroundColor Green

# ============================================
# Task 3: Backup (runs after ETL)
# ============================================

$backupAction = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$backupScript`""

$backupTrigger = New-ScheduledTaskTrigger -Once -At $ScheduleTime
$backupTrigger.Delay = "PT10M"  # Wait 10 minutes after crawler (5 min after ETL)

$backupSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName $backupTaskName `
    -Action $backupAction `
    -Trigger $backupTrigger `
    -Settings $backupSettings `
    -User $currentUser `
    -Description "SEO Audit Pipeline - Step 3: Backup database and sync to S3" | Out-Null

Write-Host "✓ Created task: $backupTaskName" -ForegroundColor Green

# ============================================
# Summary
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Task Scheduler Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created tasks:" -ForegroundColor Cyan
Write-Host "  1. $crawlerTaskName" -ForegroundColor White
Write-Host "  2. $etlTaskName" -ForegroundColor White
Write-Host "  3. $backupTaskName" -ForegroundColor White
Write-Host ""
Write-Host "Schedule: Daily at $ScheduleTime" -ForegroundColor Cyan
Write-Host ""
Write-Host "To view tasks, run:" -ForegroundColor Yellow
Write-Host "  Get-ScheduledTask | Where-Object {`$_.TaskName -like 'SEO_Audit_Pipeline*'}" -ForegroundColor Gray
Write-Host ""
Write-Host "To test the crawler manually, run:" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName '$crawlerTaskName'" -ForegroundColor Gray
Write-Host ""
