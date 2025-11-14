# ============================================
# SEO Audit Pipeline - Master Setup Script
# ============================================
# This script automates the complete setup process:
# 1. Checks and installs prerequisites
# 2. Prompts for configuration settings
# 3. Sets up the database
# 4. Configures credentials
# 5. Creates scheduled tasks
# ============================================
# Run this script as Administrator
# ============================================

param(
    [switch]$SkipPrerequisites,
    [switch]$SkipDatabase,
    [switch]$SkipCredentials,
    [switch]$SkipScheduledTasks
)

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "ADMINISTRATOR PRIVILEGES REQUIRED" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "This script must be run as Administrator to install prerequisites" -ForegroundColor Yellow
    Write-Host "and configure scheduled tasks." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please right-click this script and select 'Run as Administrator'" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# ============================================
# Global Variables
# ============================================

$script:ProjectRoot = $PSScriptRoot
$script:ConfigPath = Join-Path $ProjectRoot "config\config.json"
$script:LogFile = Join-Path $ProjectRoot "logs\setup.log"

# Ensure logs directory exists
$logsDir = Join-Path $ProjectRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

# ============================================
# Logging Functions
# ============================================

function Write-SetupLog {
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
        "HEADER" { Write-Host $logMessage -ForegroundColor Cyan }
        default { Write-Host $logMessage }
    }
    
    Add-Content -Path $script:LogFile -Value $logMessage
}

function Write-SectionHeader {
    param([string]$Title)
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================
# Prerequisite Checks and Installation
# ============================================

function Test-Chocolatey {
    Write-SetupLog "Checking for Chocolatey package manager..."
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-SetupLog "Chocolatey is already installed" "SUCCESS"
        return $true
    }
    
    Write-SetupLog "Chocolatey not found. Installing..." "WARNING"
    
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-SetupLog "Chocolatey installed successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-SetupLog "Failed to install Chocolatey: $_" "ERROR"
        return $false
    }
}

function Install-Python {
    Write-SetupLog "Checking for Python..."
    
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $pythonVersion = python --version 2>&1
        Write-SetupLog "Python is already installed: $pythonVersion" "SUCCESS"
        return $true
    }
    
    Write-SetupLog "Python not found. Installing via Chocolatey..." "WARNING"
    
    try {
        choco install python -y
        
        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-SetupLog "Python installed successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-SetupLog "Failed to install Python: $_" "ERROR"
        return $false
    }
}

function Install-PostgreSQL {
    Write-SetupLog "Checking for PostgreSQL..."
    
    if (Get-Command psql -ErrorAction SilentlyContinue) {
        $pgVersion = psql --version 2>&1
        Write-SetupLog "PostgreSQL is already installed: $pgVersion" "SUCCESS"
        return $true
    }
    
    Write-Host ""
    Write-Host "PostgreSQL is not installed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  1. Install PostgreSQL automatically via Chocolatey (recommended)" -ForegroundColor White
    Write-Host "  2. I will install PostgreSQL manually" -ForegroundColor White
    Write-Host "  3. Skip PostgreSQL installation" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Select option (1-3)"
    
    switch ($choice) {
        "1" {
            Write-SetupLog "Installing PostgreSQL via Chocolatey..."
            try {
                choco install postgresql -y --params '/Password:postgres'
                
                # Refresh environment
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                
                Write-SetupLog "PostgreSQL installed successfully" "SUCCESS"
                Write-Host ""
                Write-Host "IMPORTANT: Default PostgreSQL password is 'postgres'" -ForegroundColor Yellow
                Write-Host "Please change this password after setup is complete!" -ForegroundColor Yellow
                Write-Host ""
                Read-Host "Press Enter to continue"
                return $true
            }
            catch {
                Write-SetupLog "Failed to install PostgreSQL: $_" "ERROR"
                return $false
            }
        }
        "2" {
            Write-Host ""
            Write-Host "Please install PostgreSQL from: https://www.postgresql.org/download/windows/" -ForegroundColor Cyan
            Write-Host ""
            Read-Host "Press Enter after you have installed PostgreSQL"
            
            if (Get-Command psql -ErrorAction SilentlyContinue) {
                Write-SetupLog "PostgreSQL installation confirmed" "SUCCESS"
                return $true
            }
            else {
                Write-SetupLog "PostgreSQL still not found. Please add it to PATH and re-run setup." "ERROR"
                return $false
            }
        }
        "3" {
            Write-SetupLog "Skipping PostgreSQL installation" "WARNING"
            return $true
        }
        default {
            Write-SetupLog "Invalid choice. Skipping PostgreSQL installation." "WARNING"
            return $true
        }
    }
}

function Install-AWSCLI {
    Write-SetupLog "Checking for AWS CLI..."
    
    if (Get-Command aws -ErrorAction SilentlyContinue) {
        $awsVersion = aws --version 2>&1
        Write-SetupLog "AWS CLI is already installed: $awsVersion" "SUCCESS"
        return $true
    }
    
    Write-Host ""
    Write-Host "AWS CLI is not installed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  1. Install AWS CLI automatically" -ForegroundColor White
    Write-Host "  2. I will install AWS CLI manually" -ForegroundColor White
    Write-Host "  3. Skip AWS CLI installation (backups will not work)" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Select option (1-3)"
    
    switch ($choice) {
        "1" {
            Write-SetupLog "Installing AWS CLI via Chocolatey..."
            try {
                choco install awscli -y
                
                # Refresh environment
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                
                Write-SetupLog "AWS CLI installed successfully" "SUCCESS"
                return $true
            }
            catch {
                Write-SetupLog "Failed to install AWS CLI: $_" "ERROR"
                return $false
            }
        }
        "2" {
            Write-Host ""
            Write-Host "Please install AWS CLI from: https://aws.amazon.com/cli/" -ForegroundColor Cyan
            Write-Host ""
            Read-Host "Press Enter after you have installed AWS CLI"
            
            if (Get-Command aws -ErrorAction SilentlyContinue) {
                Write-SetupLog "AWS CLI installation confirmed" "SUCCESS"
                return $true
            }
            else {
                Write-SetupLog "AWS CLI still not found. Backups may not work." "WARNING"
                return $true
            }
        }
        "3" {
            Write-SetupLog "Skipping AWS CLI installation" "WARNING"
            return $true
        }
        default {
            Write-SetupLog "Invalid choice. Skipping AWS CLI installation." "WARNING"
            return $true
        }
    }
}

function Install-PythonPackages {
    Write-SetupLog "Installing Python dependencies..."
    
    $requirementsFile = Join-Path $script:ProjectRoot "requirements.txt"
    
    if (-not (Test-Path $requirementsFile)) {
        Write-SetupLog "requirements.txt not found" "ERROR"
        return $false
    }
    
    try {
        python -m pip install --upgrade pip
        python -m pip install -r $requirementsFile
        
        Write-SetupLog "Python packages installed successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-SetupLog "Failed to install Python packages: $_" "ERROR"
        return $false
    }
}

function Test-ScreamingFrog {
    Write-SetupLog "Checking for Screaming Frog SEO Spider..."
    
    $commonPaths = @(
        "C:\Program Files\Screaming Frog SEO Spider\screamingfrogseospidercli.exe",
        "C:\Program Files (x86)\Screaming Frog SEO Spider\screamingfrogseospidercli.exe"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            Write-SetupLog "Screaming Frog found at: $path" "SUCCESS"
            return $path
        }
    }
    
    Write-Host ""
    Write-Host "Screaming Frog SEO Spider not found!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This is a REQUIRED component. Please:" -ForegroundColor Cyan
    Write-Host "  1. Download from: https://www.screamingfrog.co.uk/seo-spider/" -ForegroundColor White
    Write-Host "  2. Install the application" -ForegroundColor White
    Write-Host "  3. Purchase a license (required for CLI mode)" -ForegroundColor White
    Write-Host "  4. Enter your license in the GUI application" -ForegroundColor White
    Write-Host ""
    
    $customPath = Read-Host "Enter the path to screamingfrogseospidercli.exe (or press Enter to skip)"
    
    if ($customPath -and (Test-Path $customPath)) {
        Write-SetupLog "Screaming Frog confirmed at custom path" "SUCCESS"
        return $customPath
    }
    
    Write-SetupLog "Screaming Frog not configured. You'll need to update config.json manually." "WARNING"
    return $null
}

# ============================================
# Configuration Setup
# ============================================

function Initialize-Configuration {
    Write-SectionHeader "Configuration Setup"
    
    Write-Host "Let's configure your SEO Audit Pipeline..." -ForegroundColor Cyan
    Write-Host ""
    
    # Load existing config or create new
    if (Test-Path $script:ConfigPath) {
        $config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
        Write-Host "Existing configuration found. You can update the values below." -ForegroundColor Yellow
        Write-Host ""
    }
    else {
        $config = @{}
    }
    
    # Screaming Frog path
    $sfPath = Test-ScreamingFrog
    if ($sfPath) {
        $config.screaming_frog_cli_path = $sfPath
    }
    else {
        $config.screaming_frog_cli_path = "C:\Program Files\Screaming Frog SEO Spider\screamingfrogseospidercli.exe"
    }
    
    # Base paths
    Write-Host ""
    Write-Host "Base Directory Configuration" -ForegroundColor Cyan
    Write-Host "----------------------------" -ForegroundColor Cyan
    
    $defaultBasePath = "C:\sf_batch"
    $basePath = Read-Host "Enter base directory for the pipeline (default: $defaultBasePath)"
    if (-not $basePath) { $basePath = $defaultBasePath }
    
    # Create directories
    $directories = @(
        $basePath,
        "$basePath\config",
        "$basePath\exports",
        "$basePath\exports_archive",
        "$basePath\db_backups",
        "$basePath\logs"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-SetupLog "Created directory: $dir"
        }
    }
    
    # Update config paths
    $config.screaming_frog_config_path = "$basePath\config\rankdre_default.seospider"
    $config.domains_csv_path = "$basePath\config\domains.csv"
    $config.base_export_path = "$basePath\exports"
    $config.db_backup_path = "$basePath\db_backups"
    $config.log_file_path = "$basePath\logs\pipeline.log"
    
    # Copy config files to base path
    $sourceConfigDir = Join-Path $script:ProjectRoot "config"
    Copy-Item "$sourceConfigDir\domains.csv" "$basePath\config\" -Force
    
    # Parallel crawls
    Write-Host ""
    $maxParallel = Read-Host "Maximum parallel crawls (recommended: 3, default: 3)"
    if (-not $maxParallel) { $maxParallel = 3 }
    $config.max_parallel_crawls = [int]$maxParallel
    
    # Database settings
    Write-Host ""
    Write-Host "Database Configuration" -ForegroundColor Cyan
    Write-Host "---------------------" -ForegroundColor Cyan
    
    $dbHost = Read-Host "PostgreSQL host (default: localhost)"
    if (-not $dbHost) { $dbHost = "localhost" }
    $config.postgres_host = $dbHost
    
    $dbPort = Read-Host "PostgreSQL port (default: 5432)"
    if (-not $dbPort) { $dbPort = 5432 }
    $config.postgres_port = [int]$dbPort
    
    $dbName = Read-Host "Database name (default: seo_audits)"
    if (-not $dbName) { $dbName = "seo_audits" }
    $config.postgres_database = $dbName
    
    # AWS S3 settings
    Write-Host ""
    Write-Host "AWS S3 Configuration" -ForegroundColor Cyan
    Write-Host "-------------------" -ForegroundColor Cyan
    
    $s3Bucket = Read-Host "S3 bucket name for backups (e.g., my-seo-audits)"
    if ($s3Bucket) {
        $config.s3_bucket_name = $s3Bucket
    }
    else {
        $config.s3_bucket_name = "rankdre-sf-audits"
    }
    
    $awsProfile = Read-Host "AWS CLI profile name (default: s3_backup_user)"
    if (-not $awsProfile) { $awsProfile = "s3_backup_user" }
    $config.aws_credential_profile = $awsProfile
    
    # Other settings
    $config.db_credential_name = "Postgres_ETL_User"
    $config.archive_processed_files = $true
    
    # Save configuration
    $config | ConvertTo-Json -Depth 10 | Set-Content $script:ConfigPath
    
    # Also save to base path
    $config | ConvertTo-Json -Depth 10 | Set-Content "$basePath\config\config.json"
    
    Write-SetupLog "Configuration saved to: $script:ConfigPath" "SUCCESS"
    Write-SetupLog "Configuration also saved to: $basePath\config\config.json" "SUCCESS"
    
    return $config
}

# ============================================
# Database Setup
# ============================================

function Setup-Database {
    param([object]$Config)
    
    Write-SectionHeader "Database Setup"
    
    Write-Host "Do you want to set up the PostgreSQL database now?" -ForegroundColor Cyan
    Write-Host "This will create the database and tables." -ForegroundColor Cyan
    Write-Host ""
    
    $setupDb = Read-Host "Set up database? (Y/N)"
    
    if ($setupDb -ne "Y" -and $setupDb -ne "y") {
        Write-SetupLog "Skipping database setup" "WARNING"
        return
    }
    
    $dbName = $Config.postgres_database
    $dbHost = $Config.postgres_host
    $dbPort = $Config.postgres_port
    
    Write-Host ""
    $dbUser = Read-Host "PostgreSQL superuser username (default: postgres)"
    if (-not $dbUser) { $dbUser = "postgres" }
    
    $dbPassword = Read-Host "PostgreSQL superuser password" -AsSecureString
    $dbPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassword)
    )
    
    # Set PGPASSWORD for this session
    $env:PGPASSWORD = $dbPasswordPlain
    
    try {
        # Create database
        Write-SetupLog "Creating database: $dbName"
        
        $createDbSql = "CREATE DATABASE $dbName;"
        $checkDbSql = "SELECT 1 FROM pg_database WHERE datname = '$dbName';"
        
        $dbExists = psql -h $dbHost -p $dbPort -U $dbUser -d postgres -t -c $checkDbSql 2>&1
        
        if ($dbExists -match "1") {
            Write-SetupLog "Database already exists" "WARNING"
        }
        else {
            psql -h $dbHost -p $dbPort -U $dbUser -d postgres -c $createDbSql
            Write-SetupLog "Database created successfully" "SUCCESS"
        }
        
        # Run schema script
        $schemaScript = Join-Path $script:ProjectRoot "sql\01_create_schema.sql"
        
        if (Test-Path $schemaScript) {
            Write-SetupLog "Creating database schema..."
            psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -f $schemaScript
            Write-SetupLog "Database schema created successfully" "SUCCESS"
        }
        
        Write-Host ""
        Write-Host "Database setup complete!" -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-SetupLog "Database setup failed: $_" "ERROR"
    }
    finally {
        Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
    }
}

# ============================================
# Main Setup Flow
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SEO AUDIT PIPELINE - MASTER SETUP" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-SetupLog "=== Setup Started ===" "HEADER"

# Step 1: Prerequisites
if (-not $SkipPrerequisites) {
    Write-SectionHeader "Step 1: Installing Prerequisites"
    
    Test-Chocolatey
    Install-Python
    Install-PostgreSQL
    Install-AWSCLI
    Install-PythonPackages
}
else {
    Write-SetupLog "Skipping prerequisite installation (--SkipPrerequisites flag)" "WARNING"
}

# Step 2: Configuration
Write-SectionHeader "Step 2: Configuration"
$config = Initialize-Configuration

# Step 3: Database Setup
if (-not $SkipDatabase) {
    Setup-Database -Config $config
}
else {
    Write-SetupLog "Skipping database setup (--SkipDatabase flag)" "WARNING"
}

# Step 4: Credentials
if (-not $SkipCredentials) {
    Write-SectionHeader "Step 4: Credential Setup"
    
    $credScript = Join-Path $script:ProjectRoot "scripts\setup_credentials.ps1"
    if (Test-Path $credScript) {
        & $credScript
    }
}
else {
    Write-SetupLog "Skipping credential setup (--SkipCredentials flag)" "WARNING"
}

# Step 5: Scheduled Tasks
if (-not $SkipScheduledTasks) {
    Write-SectionHeader "Step 5: Scheduled Tasks"
    
    Write-Host "Do you want to create automated scheduled tasks now?" -ForegroundColor Cyan
    Write-Host ""
    
    $setupTasks = Read-Host "Create scheduled tasks? (Y/N)"
    
    if ($setupTasks -eq "Y" -or $setupTasks -eq "y") {
        $taskScript = Join-Path $script:ProjectRoot "scripts\setup_scheduled_tasks.ps1"
        if (Test-Path $taskScript) {
            & $taskScript -ConfigPath $script:ConfigPath
        }
    }
    else {
        Write-SetupLog "Skipping scheduled task creation" "WARNING"
    }
}
else {
    Write-SetupLog "Skipping scheduled task setup (--SkipScheduledTasks flag)" "WARNING"
}

# ============================================
# Setup Complete
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "SETUP COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Edit the domains list:" -ForegroundColor White
Write-Host "   $($config.domains_csv_path)" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Test the crawler manually:" -ForegroundColor White
Write-Host "   .\scripts\run_crawler.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Test the ETL process:" -ForegroundColor White
Write-Host "   python .\scripts\run_etl.py" -ForegroundColor Gray
Write-Host ""
Write-Host "4. View the logs:" -ForegroundColor White
Write-Host "   $($config.log_file_path)" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Connect Power BI or your preferred BI tool to PostgreSQL" -ForegroundColor White
Write-Host ""

Write-SetupLog "=== Setup Completed ===" "HEADER"

Write-Host ""
Read-Host "Press Enter to exit"
