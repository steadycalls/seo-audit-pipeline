# ============================================
# SEO Audit Pipeline - System Health Check
# ============================================
# This script verifies that all required services are running
# and the system is ready for automated tasks
# ============================================

param(
    [string]$ConfigPath = "$PSScriptRoot\..\config\config.json"
)

# ============================================
# Logging
# ============================================

function Write-HealthLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
    
    # Also log to file if config is available
    if ($script:Config -and $script:Config.log_file_path) {
        $logDir = Split-Path -Parent $script:Config.log_file_path
        $healthLogPath = Join-Path $logDir "health_check.log"
        Add-Content -Path $healthLogPath -Value $logMessage
    }
}

# ============================================
# Health Checks
# ============================================

function Test-PostgreSQLService {
    Write-HealthLog "Checking PostgreSQL service..."
    
    # Check for PostgreSQL service (common service names)
    $pgServices = Get-Service | Where-Object { 
        $_.Name -like "*postgresql*" -or $_.DisplayName -like "*PostgreSQL*" 
    }
    
    if (-not $pgServices) {
        Write-HealthLog "PostgreSQL service not found" "WARNING"
        return $false
    }
    
    $runningServices = $pgServices | Where-Object { $_.Status -eq "Running" }
    
    if ($runningServices) {
        foreach ($service in $runningServices) {
            Write-HealthLog "PostgreSQL service '$($service.Name)' is running" "SUCCESS"
        }
        return $true
    }
    else {
        Write-HealthLog "PostgreSQL service is not running. Attempting to start..." "WARNING"
        
        try {
            $pgServices[0] | Start-Service
            Start-Sleep -Seconds 5
            
            if ((Get-Service $pgServices[0].Name).Status -eq "Running") {
                Write-HealthLog "PostgreSQL service started successfully" "SUCCESS"
                return $true
            }
            else {
                Write-HealthLog "Failed to start PostgreSQL service" "ERROR"
                return $false
            }
        }
        catch {
            Write-HealthLog "Error starting PostgreSQL service: $_" "ERROR"
            return $false
        }
    }
}

function Test-DatabaseConnection {
    param([object]$Config)
    
    Write-HealthLog "Testing database connection..."
    
    if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
        Write-HealthLog "psql command not found. Skipping database connection test." "WARNING"
        return $false
    }
    
    try {
        # Simple connection test
        $dbHost = $Config.postgres_host
        $dbPort = $Config.postgres_port
        $dbName = $Config.postgres_database
        
        # Use environment variable for password if available
        $pgPassword = $env:POSTGRES_PASSWORD
        if ($pgPassword) {
            $env:PGPASSWORD = $pgPassword
        }
        
        $result = psql -h $dbHost -p $dbPort -d $dbName -c "SELECT 1;" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-HealthLog "Database connection successful" "SUCCESS"
            return $true
        }
        else {
            Write-HealthLog "Database connection failed" "WARNING"
            return $false
        }
    }
    catch {
        Write-HealthLog "Database connection test error: $_" "WARNING"
        return $false
    }
    finally {
        Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
    }
}

function Test-NetworkConnectivity {
    Write-HealthLog "Testing network connectivity..."
    
    try {
        $testResult = Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet
        
        if ($testResult) {
            Write-HealthLog "Network connectivity confirmed" "SUCCESS"
            return $true
        }
        else {
            Write-HealthLog "Network connectivity issue detected" "WARNING"
            return $false
        }
    }
    catch {
        Write-HealthLog "Network test error: $_" "WARNING"
        return $false
    }
}

function Test-RequiredPaths {
    param([object]$Config)
    
    Write-HealthLog "Checking required directories..."
    
    $paths = @(
        $Config.base_export_path,
        $Config.db_backup_path,
        (Split-Path -Parent $Config.log_file_path)
    )
    
    $allExist = $true
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Write-HealthLog "Path exists: $path" "SUCCESS"
        }
        else {
            Write-HealthLog "Path missing: $path - Creating..." "WARNING"
            try {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
                Write-HealthLog "Created path: $path" "SUCCESS"
            }
            catch {
                Write-HealthLog "Failed to create path: $path" "ERROR"
                $allExist = $false
            }
        }
    }
    
    return $allExist
}

function Test-ScheduledTasks {
    Write-HealthLog "Checking scheduled tasks..."
    
    $taskBaseName = "SEO_Audit_Pipeline"
    $expectedTasks = @(
        "$taskBaseName`_1_Crawler",
        "$taskBaseName`_2_ETL",
        "$taskBaseName`_3_Backup"
    )
    
    $allTasksExist = $true
    
    foreach ($taskName in $expectedTasks) {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        
        if ($task) {
            $state = $task.State
            Write-HealthLog "Task '$taskName' exists (State: $state)" "SUCCESS"
        }
        else {
            Write-HealthLog "Task '$taskName' not found" "WARNING"
            $allTasksExist = $false
        }
    }
    
    return $allTasksExist
}

# ============================================
# Main Execution
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SEO Audit Pipeline - System Health Check" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-HealthLog "=== Health Check Started ==="

# Load configuration
try {
    $script:Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    Write-HealthLog "Configuration loaded"
}
catch {
    Write-HealthLog "Failed to load configuration: $_" "WARNING"
    $script:Config = $null
}

# Run health checks
$checks = @{
    "PostgreSQL Service" = Test-PostgreSQLService
    "Network Connectivity" = Test-NetworkConnectivity
}

if ($script:Config) {
    $checks["Database Connection"] = Test-DatabaseConnection -Config $script:Config
    $checks["Required Paths"] = Test-RequiredPaths -Config $script:Config
}

$checks["Scheduled Tasks"] = Test-ScheduledTasks

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Health Check Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true
foreach ($check in $checks.GetEnumerator()) {
    $status = if ($check.Value) { "PASS" } else { "FAIL"; $allPassed = $false }
    $color = if ($check.Value) { "Green" } else { "Yellow" }
    
    Write-Host "  $($check.Key): " -NoNewline
    Write-Host $status -ForegroundColor $color
}

Write-Host ""

if ($allPassed) {
    Write-HealthLog "All health checks passed" "SUCCESS"
    exit 0
}
else {
    Write-HealthLog "Some health checks failed or returned warnings" "WARNING"
    exit 0  # Don't fail the script, just warn
}
