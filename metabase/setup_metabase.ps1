# ============================================
# SEO Audit Pipeline - Metabase Setup
# ============================================
# This script sets up Metabase dashboard using Docker
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SEO Audit Pipeline - Metabase Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# Check Prerequisites
# ============================================

function Test-Docker {
    Write-Host "Checking for Docker..." -ForegroundColor Cyan
    
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $dockerVersion = docker --version
        Write-Host "✓ Docker found: $dockerVersion" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "✗ Docker not found" -ForegroundColor Red
        Write-Host ""
        Write-Host "Docker is required to run Metabase." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Installation options:" -ForegroundColor Cyan
        Write-Host "  1. Docker Desktop (recommended for Windows):" -ForegroundColor White
        Write-Host "     https://www.docker.com/products/docker-desktop" -ForegroundColor Gray
        Write-Host ""
        
        $install = Read-Host "Would you like to open the Docker Desktop download page? (Y/N)"
        
        if ($install -eq "Y" -or $install -eq "y") {
            Start-Process "https://www.docker.com/products/docker-desktop"
        }
        
        return $false
    }
}

function Test-DockerRunning {
    Write-Host "Checking if Docker is running..." -ForegroundColor Cyan
    
    try {
        docker ps | Out-Null
        Write-Host "✓ Docker is running" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ Docker is not running" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
        return $false
    }
}

# ============================================
# Main Setup
# ============================================

# Check Docker
if (-not (Test-Docker)) {
    Write-Host ""
    Write-Host "Please install Docker and run this script again." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

if (-not (Test-DockerRunning)) {
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Navigate to metabase directory
$scriptDir = $PSScriptRoot
Set-Location $scriptDir

Write-Host ""
Write-Host "Starting Metabase..." -ForegroundColor Cyan
Write-Host ""

# Pull the latest Metabase image
Write-Host "Pulling Metabase Docker image (this may take a few minutes)..." -ForegroundColor Yellow
docker-compose pull

# Start Metabase
Write-Host ""
Write-Host "Starting Metabase container..." -ForegroundColor Yellow
docker-compose up -d

# Wait for Metabase to be ready
Write-Host ""
Write-Host "Waiting for Metabase to start (this may take 30-60 seconds)..." -ForegroundColor Yellow

$maxAttempts = 30
$attempt = 0
$metabaseReady = $false

while ($attempt -lt $maxAttempts -and -not $metabaseReady) {
    Start-Sleep -Seconds 2
    $attempt++
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000/api/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $metabaseReady = $true
        }
    }
    catch {
        Write-Host "." -NoNewline
    }
}

Write-Host ""
Write-Host ""

if ($metabaseReady) {
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Metabase is Ready!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Access Metabase at: http://localhost:3000" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Open http://localhost:3000 in your web browser" -ForegroundColor White
    Write-Host "  2. Complete the initial setup wizard" -ForegroundColor White
    Write-Host "  3. Add your PostgreSQL database connection" -ForegroundColor White
    Write-Host "  4. Import the pre-built queries from the 'sql' folder" -ForegroundColor White
    Write-Host ""
    Write-Host "Database Connection Details:" -ForegroundColor Cyan
    Write-Host "  Type: PostgreSQL" -ForegroundColor White
    Write-Host "  Host: host.docker.internal (or your PostgreSQL host)" -ForegroundColor White
    Write-Host "  Port: 5432" -ForegroundColor White
    Write-Host "  Database: seo_audits" -ForegroundColor White
    Write-Host "  Username: (your PostgreSQL username)" -ForegroundColor White
    Write-Host ""
    Write-Host "To stop Metabase, run:" -ForegroundColor Yellow
    Write-Host "  docker-compose down" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To view logs, run:" -ForegroundColor Yellow
    Write-Host "  docker-compose logs -f" -ForegroundColor Gray
    Write-Host ""
    
    # Open browser
    $openBrowser = Read-Host "Would you like to open Metabase in your browser now? (Y/N)"
    if ($openBrowser -eq "Y" -or $openBrowser -eq "y") {
        Start-Process "http://localhost:3000"
    }
}
else {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "Metabase Failed to Start" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the logs for errors:" -ForegroundColor Yellow
    Write-Host "  docker-compose logs" -ForegroundColor Gray
    Write-Host ""
}

Write-Host ""
Read-Host "Press Enter to exit"
