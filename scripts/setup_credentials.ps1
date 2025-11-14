# ============================================
# SEO Audit Pipeline - Credential Setup Helper
# ============================================
# This script helps you securely store credentials in Windows Credential Manager
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SEO Audit Pipeline - Credential Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This script will help you set up credentials for:" -ForegroundColor Yellow
Write-Host "  1. PostgreSQL database access" -ForegroundColor White
Write-Host "  2. AWS S3 backup access" -ForegroundColor White
Write-Host ""

# ============================================
# PostgreSQL Credentials
# ============================================

Write-Host "PostgreSQL Database Credentials" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Cyan
Write-Host ""

$setupPostgres = Read-Host "Do you want to set up PostgreSQL credentials? (Y/N)"

if ($setupPostgres -eq "Y" -or $setupPostgres -eq "y") {
    Write-Host ""
    Write-Host "You can store credentials in:" -ForegroundColor Yellow
    Write-Host "  Option 1: Environment Variables (recommended for automation)" -ForegroundColor White
    Write-Host "  Option 2: Windows Credential Manager (more secure)" -ForegroundColor White
    Write-Host ""
    
    $credMethod = Read-Host "Choose method (1 or 2)"
    
    if ($credMethod -eq "1") {
        # Environment Variables
        Write-Host ""
        Write-Host "Setting up environment variables..." -ForegroundColor Cyan
        
        $pgUser = Read-Host "PostgreSQL username (e.g., seo_etl_user)"
        $pgPassword = Read-Host "PostgreSQL password" -AsSecureString
        $pgPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pgPassword)
        )
        
        # Set user environment variables
        [System.Environment]::SetEnvironmentVariable("POSTGRES_USER", $pgUser, "User")
        [System.Environment]::SetEnvironmentVariable("POSTGRES_PASSWORD", $pgPasswordPlain, "User")
        
        Write-Host "✓ Environment variables set successfully" -ForegroundColor Green
        Write-Host ""
        Write-Host "Note: You may need to restart your PowerShell session for changes to take effect" -ForegroundColor Yellow
    }
    elseif ($credMethod -eq "2") {
        # Windows Credential Manager (requires keyring Python package)
        Write-Host ""
        Write-Host "To use Windows Credential Manager, you need the Python 'keyring' package." -ForegroundColor Yellow
        Write-Host "Install it with: pip install keyring" -ForegroundColor Gray
        Write-Host ""
        
        $pgUser = Read-Host "PostgreSQL username (e.g., seo_etl_user)"
        $pgPassword = Read-Host "PostgreSQL password" -AsSecureString
        $pgPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pgPassword)
        )
        
        # Use cmdkey to store credentials
        $credName = "Postgres_ETL_User"
        
        # Store username
        cmdkey /generic:"$credName`_username" /user:"$pgUser" /pass:"$pgUser" | Out-Null
        
        # Store password
        cmdkey /generic:"$credName`_password" /user:"password" /pass:"$pgPasswordPlain" | Out-Null
        
        Write-Host "✓ Credentials stored in Windows Credential Manager" -ForegroundColor Green
        Write-Host "  Target name: $credName" -ForegroundColor Gray
    }
}

# ============================================
# AWS Credentials
# ============================================

Write-Host ""
Write-Host "AWS S3 Credentials" -ForegroundColor Cyan
Write-Host "------------------" -ForegroundColor Cyan
Write-Host ""

$setupAWS = Read-Host "Do you want to set up AWS credentials? (Y/N)"

if ($setupAWS -eq "Y" -or $setupAWS -eq "y") {
    Write-Host ""
    Write-Host "AWS credentials are best managed using AWS CLI." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To set up AWS credentials, run:" -ForegroundColor Cyan
    Write-Host "  aws configure --profile s3_backup_user" -ForegroundColor White
    Write-Host ""
    Write-Host "You will be prompted for:" -ForegroundColor Gray
    Write-Host "  - AWS Access Key ID" -ForegroundColor Gray
    Write-Host "  - AWS Secret Access Key" -ForegroundColor Gray
    Write-Host "  - Default region (e.g., us-east-1)" -ForegroundColor Gray
    Write-Host "  - Default output format (e.g., json)" -ForegroundColor Gray
    Write-Host ""
    
    $runAwsConfigure = Read-Host "Do you want to run this command now? (Y/N)"
    
    if ($runAwsConfigure -eq "Y" -or $runAwsConfigure -eq "y") {
        aws configure --profile s3_backup_user
        Write-Host "✓ AWS credentials configured" -ForegroundColor Green
    }
}

# ============================================
# Summary
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Credential Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Test database connection with the ETL script" -ForegroundColor White
Write-Host "  2. Test AWS S3 access with the backup script" -ForegroundColor White
Write-Host "  3. Set up scheduled tasks with setup_scheduled_tasks.ps1" -ForegroundColor White
Write-Host ""
