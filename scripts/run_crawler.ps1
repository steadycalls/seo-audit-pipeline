# ============================================
# SEO Audit Pipeline - Batch Crawler
# ============================================
# This script runs Screaming Frog SEO Spider in batch mode
# with parallel processing and comprehensive error handling
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
    
    # Write to console
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
    
    # Write to log file if path is set
    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $logMessage
    }
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check if Screaming Frog CLI exists
    if (-not (Test-Path $script:Config.screaming_frog_cli_path)) {
        Write-Log "Screaming Frog CLI not found at: $($script:Config.screaming_frog_cli_path)" "ERROR"
        Write-Log "Please install Screaming Frog SEO Spider or update the path in config.json" "ERROR"
        return $false
    }
    
    # Check if domains CSV exists
    if (-not (Test-Path $script:Config.domains_csv_path)) {
        Write-Log "Domains CSV not found at: $($script:Config.domains_csv_path)" "ERROR"
        return $false
    }
    
    # Create export directory if it doesn't exist
    if (-not (Test-Path $script:Config.base_export_path)) {
        New-Item -ItemType Directory -Path $script:Config.base_export_path -Force | Out-Null
        Write-Log "Created export directory: $($script:Config.base_export_path)"
    }
    
    Write-Log "All prerequisites met" "SUCCESS"
    return $true
}

function Get-ActiveDomains {
    Write-Log "Loading active domains from CSV..."
    
    try {
        $domains = Import-Csv -Path $script:Config.domains_csv_path | Where-Object { $_.status -eq "active" }
        Write-Log "Found $($domains.Count) active domains"
        return $domains
    }
    catch {
        Write-Log "Failed to load domains: $_" "ERROR"
        return @()
    }
}

function Start-CrawlJob {
    param(
        [PSCustomObject]$Domain,
        [string]$ExportPath
    )
    
    $scriptBlock = {
        param($sfPath, $sfConfig, $domainName, $exportPath, $logPath)
        
        function Write-JobLog {
            param([string]$Message, [string]$Level = "INFO")
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logMessage = "[$timestamp] [$Level] [$domainName] $Message"
            Add-Content -Path $logPath -Value $logMessage
        }
        
        try {
            Write-JobLog "Starting crawl for $domainName"
            
            # Build the Screaming Frog command
            $url = "https://$domainName"
            
            # Create domain-specific export directory
            $domainExportPath = Join-Path $exportPath $domainName
            if (-not (Test-Path $domainExportPath)) {
                New-Item -ItemType Directory -Path $domainExportPath -Force | Out-Null
            }
            
            # Build command arguments
            $arguments = @(
                "--crawl", $url,
                "--headless",
                "--config", $sfConfig,
                "--export-tabs", "Internal:All",
                "--output-folder", $domainExportPath,
                "--timestamped-output"
            )
            
            # Execute Screaming Frog
            $process = Start-Process -FilePath $sfPath `
                                    -ArgumentList $arguments `
                                    -NoNewWindow `
                                    -Wait `
                                    -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-JobLog "Crawl completed successfully" "SUCCESS"
                return @{
                    Domain = $domainName
                    Status = "Success"
                    ExitCode = $process.ExitCode
                    Message = "Crawl completed successfully"
                }
            }
            else {
                Write-JobLog "Crawl failed with exit code: $($process.ExitCode)" "ERROR"
                return @{
                    Domain = $domainName
                    Status = "Failed"
                    ExitCode = $process.ExitCode
                    Message = "Process exited with code $($process.ExitCode)"
                }
            }
        }
        catch {
            Write-JobLog "Exception during crawl: $_" "ERROR"
            return @{
                Domain = $domainName
                Status = "Failed"
                ExitCode = -1
                Message = $_.Exception.Message
            }
        }
    }
    
    # Start the background job
    $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList @(
        $script:Config.screaming_frog_cli_path,
        $script:Config.screaming_frog_config_path,
        $Domain.domain,
        $ExportPath,
        $script:LogFilePath
    )
    
    return $job
}

function Wait-ForJobSlot {
    param([int]$MaxJobs)
    
    while ((Get-Job -State Running).Count -ge $MaxJobs) {
        Start-Sleep -Seconds 5
        
        # Check for completed jobs and log results
        Get-Job -State Completed | ForEach-Object {
            $result = Receive-Job -Job $_
            if ($result.Status -eq "Success") {
                Write-Log "Completed: $($result.Domain)" "SUCCESS"
            }
            else {
                Write-Log "Failed: $($result.Domain) - $($result.Message)" "ERROR"
            }
            Remove-Job -Job $_
        }
    }
}

# ============================================
# Main Execution
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SEO Audit Pipeline - Batch Crawler" -ForegroundColor Cyan
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

Write-Log "=== Crawl Session Started ==="

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-Log "Prerequisites check failed. Exiting." "ERROR"
    exit 1
}

# Get active domains
$domains = Get-ActiveDomains
if ($domains.Count -eq 0) {
    Write-Log "No active domains found. Exiting." "WARNING"
    exit 0
}

# Create today's export directory
$today = Get-Date -Format "yyyy_MM_dd"
$exportPath = Join-Path $script:Config.base_export_path $today
if (-not (Test-Path $exportPath)) {
    New-Item -ItemType Directory -Path $exportPath -Force | Out-Null
    Write-Log "Created export directory: $exportPath"
}

# Start crawling with parallel processing
Write-Log "Starting parallel crawls (max concurrent: $($script:Config.max_parallel_crawls))"
$totalDomains = $domains.Count
$currentIndex = 0

foreach ($domain in $domains) {
    $currentIndex++
    Write-Log "[$currentIndex/$totalDomains] Queuing crawl for: $($domain.domain)"
    
    # Wait for an available job slot
    Wait-ForJobSlot -MaxJobs $script:Config.max_parallel_crawls
    
    # Start the crawl job
    Start-CrawlJob -Domain $domain -ExportPath $exportPath
}

# Wait for all remaining jobs to complete
Write-Log "Waiting for all crawls to complete..."
Get-Job | Wait-Job

# Process final results
Get-Job | ForEach-Object {
    $result = Receive-Job -Job $_
    if ($result.Status -eq "Success") {
        Write-Log "Final: $($result.Domain) - SUCCESS" "SUCCESS"
    }
    else {
        Write-Log "Final: $($result.Domain) - FAILED: $($result.Message)" "ERROR"
    }
    Remove-Job -Job $_
}

Write-Log "=== Crawl Session Completed ==="
Write-Host ""
Write-Host "All crawls completed. Check log file for details: $script:LogFilePath" -ForegroundColor Green
Write-Host ""
