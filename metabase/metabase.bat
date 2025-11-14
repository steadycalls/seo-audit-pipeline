@echo off
REM ============================================
REM SEO Audit Pipeline - Metabase Quick Launcher
REM ============================================

cd /d "%~dp0"

echo.
echo ============================================
echo SEO Audit Pipeline - Metabase Manager
echo ============================================
echo.
echo 1. Start Metabase
echo 2. Stop Metabase
echo 3. View Logs
echo 4. Restart Metabase
echo 5. Open Metabase in Browser
echo 6. Exit
echo.

set /p choice="Select an option (1-6): "

if "%choice%"=="1" goto start
if "%choice%"=="2" goto stop
if "%choice%"=="3" goto logs
if "%choice%"=="4" goto restart
if "%choice%"=="5" goto open
if "%choice%"=="6" goto end

echo Invalid choice. Please try again.
pause
goto end

:start
echo.
echo Starting Metabase...
docker-compose up -d
echo.
echo Metabase is starting. It will be available at http://localhost:3000 in about 30 seconds.
echo.
pause
goto end

:stop
echo.
echo Stopping Metabase...
docker-compose down
echo.
echo Metabase stopped.
echo.
pause
goto end

:logs
echo.
echo Showing Metabase logs (press Ctrl+C to exit)...
echo.
docker-compose logs -f
pause
goto end

:restart
echo.
echo Restarting Metabase...
docker-compose restart
echo.
echo Metabase restarted.
echo.
pause
goto end

:open
echo.
echo Opening Metabase in your default browser...
start http://localhost:3000
echo.
pause
goto end

:end
