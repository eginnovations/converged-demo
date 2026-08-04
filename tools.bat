@echo off
setlocal EnableExtensions
set "DOCKER_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set "DIR=%~dp0"

REM ---- allow command-line use:  tools.bat start|deploy|stop|status ----
REM      start  = Docker + minikube only
REM      deploy = Docker + minikube + build & deploy the app
if not "%~1"=="" (
    set "ACTION=%~1"
    goto dispatch
)

:menu
cls
echo ==================================================
echo    eG Converged Demo  -  Tools Control
echo ==================================================
echo    Manages the heavy background tools so you can
echo    free CPU/RAM when you are not using the demo.
echo.
echo    [1]  Start everything          (Docker Desktop + minikube)
echo    [2]  Start everything + DEPLOY (Docker + minikube + build/deploy app)
echo    [3]  Stop everything           (minikube + Docker + WSL) - frees CPU/RAM
echo    [4]  Status
echo    [0]  Exit
echo.
set "ACTION="
set /p "CHOICE=Enter choice: "
if "%CHOICE%"=="1" set "ACTION=start"
if "%CHOICE%"=="2" set "ACTION=deploy"
if "%CHOICE%"=="3" set "ACTION=stop"
if "%CHOICE%"=="4" set "ACTION=status"
if "%CHOICE%"=="0" goto end
if not defined ACTION goto menu

:dispatch
if /i "%ACTION%"=="start"  call :do_start
if /i "%ACTION%"=="deploy" call :do_startdeploy
if /i "%ACTION%"=="stop"   call :do_stop
if /i "%ACTION%"=="status" call :do_status

if "%~1"=="" (
    echo.
    pause
    goto menu
)
goto end

REM ================================ actions ================================

:do_start
echo Starting Docker Desktop...
if exist "%DOCKER_EXE%" (
    start "" "%DOCKER_EXE%"
) else (
    echo   Could not find Docker Desktop at:
    echo     %DOCKER_EXE%
    echo   Start Docker Desktop manually, then re-run this option.
)
echo Waiting for the Docker engine to be ready...
set /a TRIES=0
:waitdocker
docker info >nul 2>&1
if not errorlevel 1 goto dockerok
set /a TRIES+=1
if %TRIES% GEQ 40 (
    echo   Docker did not become ready in time. Check Docker Desktop and retry.
    exit /b 1
)
timeout /t 3 /nobreak >nul
goto waitdocker
:dockerok
echo Docker is ready.
echo Starting minikube...
minikube start --driver=docker --cpus=4 --memory=6144
minikube status
exit /b 0

:do_startdeploy
call :do_start
if errorlevel 1 (
    echo Skipping deploy because startup did not complete.
    exit /b 1
)
echo.
echo ==================================================
echo    Deploying the application (Maven + Docker + kubectl)
echo    This can take a few minutes on the first run...
echo ==================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%deploy.ps1"
exit /b 0

:do_stop
echo Stopping minikube...
minikube stop
echo Quitting Docker Desktop...
taskkill /IM "Docker Desktop.exe" /F >nul 2>&1
taskkill /IM "com.docker.backend.exe" /F >nul 2>&1
taskkill /IM "com.docker.build.exe" /F >nul 2>&1
echo Shutting down the WSL backend to release its memory...
wsl --shutdown >nul 2>&1
echo.
echo All tools stopped. CPU and RAM have been released for your other apps.
exit /b 0

:do_status
echo --- Docker ---
docker info >nul 2>&1 && (echo Docker engine: RUNNING) || (echo Docker engine: stopped)
echo --- minikube ---
minikube status 2>nul || echo minikube: not running
exit /b 0

:end
endlocal
