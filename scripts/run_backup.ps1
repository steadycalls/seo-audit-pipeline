# ============================================
# SEO Audit Pipeline - Backup Script
# ============================================
# This script backs up the PostgreSQL database and syncs
# raw exports and database backups to AWS S3
# ============================================

param(
    [string]$ConfigPath = "$PSScriptRoot\..\config\config.json"
)

# ============================================
# Functions
# ============================================

function Write-Log {
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
    
    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $logMessage
    }
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check if pg_dump is available
    try {
        $pgDumpVersion = & pg_dump --version 2>&1
        Write-Log "Found pg_dump: $pgDumpVersion"
    }
    catch {
        Write-Log "pg_dump not found. Please install PostgreSQL client tools." "ERROR"
        return $false
    }
    
    # Check if AWS CLI is available
    try {
        $awsVersion = & aws --version 2>&1
        Write-Log "Found AWS CLI: $awsVersion"
    }
    catch {
        Write-Log "AWS CLI not found. Please install AWS CLI." "ERROR"
        return $false
    }
    
    # Create backup directory if it doesn't exist
    if (-not (Test-Path $script:Config.db_backup_path)) {
        New-Item -ItemType Directory -Path $script:Config.db_backup_path -Force | Out-Null
        Write-Log "Created backup directory: $($script:Config.db_backup_path)"
    }
    
    Write-Log "All prerequisites met" "SUCCESS"
    return $true
}

function Backup-Database {
    Write-Log "Starting database backup..."
    
    $timestamp = Get-Date -Format "yyyy_MM_dd_HHmmss"
    $backupFile = Join-Path $script:Config.db_backup_path "seo_audits_$timestamp.sql"
    
    try {
        # Get database credentials from environment or prompt
        $dbHost = $script:Config.postgres_host
        $dbPort = $script:Config.postgres_port
        $dbName = $script:Config.postgres_database
        
        # Set PGPASSWORD environment variable if available
        $pgPassword = $env:POSTGRES_PASSWORD
        if (-not $pgPassword) {
            Write-Log "POSTGRES_PASSWORD environment variable not set" "WARNING"
            Write-Log "You may be prompted for the database password" "WARNING"
        }
        else {
            $env:PGPASSWORD = $pgPassword
        }
        
        # Execute pg_dump
        $pgUser = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { "seo_etl_user" }
        
        Write-Log "Running pg_dump for database: $dbName"
        & pg_dump -h $dbHost -p $dbPort -U $pgUser -d $dbName -F p -f $backupFile
        
        if ($LASTEXITCODE -eq 0) {
            $fileSize = (Get-Item $backupFile).Length / 1MB
            Write-Log "Database backup completed: $backupFile ($([math]::Round($fileSize, 2)) MB)" "SUCCESS"
            
            # Clean up old backups (keep last 30 days)
            $cutoffDate = (Get-Date).AddDays(-30)
            Get-ChildItem -Path $script:Config.db_backup_path -Filter "seo_audits_*.sql" | 
                Where-Object { $_.LastWriteTime -lt $cutoffDate } | 
                ForEach-Object {
                    Remove-Item $_.FullName -Force
                    Write-Log "Removed old backup: $($_.Name)"
                }
            
            return $backupFile
        }
        else {
            Write-Log "Database backup failed with exit code: $LASTEXITCODE" "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Database backup exception: $_" "ERROR"
        return $null
    }
    finally {
        # Clear PGPASSWORD for security
        if ($env:PGPASSWORD) {
            Remove-Item Env:\PGPASSWORD
        }
    }
}

function Sync-ToS3 {
    param(
        [string]$LocalPath,
        [string]$S3Path,
        [string]$Description
    )
    
    Write-Log "Syncing $Description to S3..."
    
    try {
        $profile = $script:Config.aws_credential_profile
        
        # Build AWS CLI command
        $awsArgs = @(
            "s3", "sync",
            $LocalPath,
            $S3Path,
            "--profile", $profile,
            "--delete"
        )
        
        Write-Log "Running: aws $($awsArgs -join ' ')"
        & aws @awsArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "$Description synced successfully" "SUCCESS"
            return $true
        }
        else {
            Write-Log "$Description sync failed with exit code: $LASTEXITCODE" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "$Description sync exception: $_" "ERROR"
        return $false
    }
}

# ============================================
# Main Execution
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SEO Audit Pipeline - Backup & Sync" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration
try {
    $script:Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    Write-Host "Configuration loaded from: $ConfigPath" -ForegroundColor Green
}
catch {
    Write-Host "Failed to load configuration: $_" -ForegroundColor Red
    exit 1
}

# Set up logging
$script:LogFilePath = $script:Config.log_file_path
$logDir = Split-Path -Parent $script:LogFilePath
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

Write-Log "=== Backup Session Started ==="

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-Log "Prerequisites check failed. Exiting." "ERROR"
    exit 1
}

# Backup database
$backupFile = Backup-Database

if (-not $backupFile) {
    Write-Log "Database backup failed. Skipping S3 sync." "ERROR"
    exit 1
}

# Sync database backups to S3
$s3Bucket = $script:Config.s3_bucket_name
$dbBackupS3Path = "s3://$s3Bucket/db_backups/"
Sync-ToS3 -LocalPath $script:Config.db_backup_path `
          -S3Path $dbBackupS3Path `
          -Description "Database backups"

# Sync raw CSV exports to S3
$exportsS3Path = "s3://$s3Bucket/raw_exports/"
Sync-ToS3 -LocalPath $script:Config.base_export_path `
          -S3Path $exportsS3Path `
          -Description "Raw CSV exports"

Write-Log "=== Backup Session Completed ==="
Write-Host ""
Write-Host "Backup and sync completed. Check log file for details: $script:LogFilePath" -ForegroundColor Green
Write-Host ""
