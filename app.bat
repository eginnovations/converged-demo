@echo off
setlocal EnableExtensions
set "NS=converged-demo"
set "DIR=%~dp0"
cd /d "%DIR%"

REM ---- allow command-line use:  app.bat start|stop|restart|status|url|deploy ----
if not "%~1"=="" (
    set "ACTION=%~1"
    goto dispatch
)

:menu
cls
echo ==================================================
echo    eG Converged Demo  -  Application Control
echo ==================================================
echo    Kubernetes namespace: %NS%
echo.
echo    [1]  Start application
echo    [2]  Stop application      (frees CPU/RAM, keeps minikube up)
echo    [3]  Restart application
echo    [4]  Status                (list pods)
echo    [5]  Open checkout page in browser
echo    [6]  Deploy / Rebuild from source  (first time or after code changes)
echo    [0]  Exit
echo.
set "ACTION="
set /p "CHOICE=Enter choice: "
if "%CHOICE%"=="1" set "ACTION=start"
if "%CHOICE%"=="2" set "ACTION=stop"
if "%CHOICE%"=="3" set "ACTION=restart"
if "%CHOICE%"=="4" set "ACTION=status"
if "%CHOICE%"=="5" set "ACTION=url"
if "%CHOICE%"=="6" set "ACTION=deploy"
if "%CHOICE%"=="0" goto end
if not defined ACTION goto menu

:dispatch
call :check_minikube
if errorlevel 1 goto after

if /i "%ACTION%"=="start"   call :do_start
if /i "%ACTION%"=="stop"    call :do_stop
if /i "%ACTION%"=="restart" call :do_restart
if /i "%ACTION%"=="status"  call :do_status
if /i "%ACTION%"=="url"     call :do_url
if /i "%ACTION%"=="deploy"  call :do_deploy

:after
if "%~1"=="" (
    echo.
    pause
    goto menu
)
goto end

REM ================================ actions ================================

:check_minikube
minikube status --format "{{.Host}}" 2>nul | findstr /i "Running" >nul
if errorlevel 1 (
    echo.
    echo   minikube is NOT running.
    echo   Run  tools.bat  and choose "Start everything" first.
    exit /b 1
)
exit /b 0

:do_start
echo Starting application pods...
kubectl -n %NS% scale deployment --all --replicas=1
echo Waiting for pods to become ready...
kubectl -n %NS% wait --for=condition=available deployment --all --timeout=180s
call :do_url
exit /b 0

:do_stop
echo Stopping application pods (scaling to 0)...
kubectl -n %NS% scale deployment --all --replicas=0
echo.
echo Application stopped. minikube is still running.
echo To free ALL memory/CPU, run tools.bat and choose "Stop everything".
exit /b 0

:do_restart
echo Restarting application...
kubectl -n %NS% scale deployment --all --replicas=0
timeout /t 5 /nobreak >nul
kubectl -n %NS% scale deployment --all --replicas=1
kubectl -n %NS% wait --for=condition=available deployment --all --timeout=180s
echo Restart complete.
exit /b 0

:do_status
kubectl -n %NS% get pods -o wide
exit /b 0

:do_url
REM With the Docker driver on Windows the minikube IP is not reachable from the
REM host browser, so we open a port-forward tunnel and use http://localhost:8080/
echo Opening a tunnel to the storefront (kubectl port-forward)...
start "storefront-tunnel" cmd /k "echo Keep this window open while using the checkout page. & echo Close it to stop the tunnel. & kubectl -n %NS% port-forward svc/storefront 8080:8080"
timeout /t 3 /nobreak >nul
echo Checkout page: http://localhost:8080/
start "" "http://localhost:8080/"
echo.
echo A tunnel window was opened. Keep it open while you use the page.
exit /b 0

:do_deploy
echo Running full build + deploy (Maven + Docker + kubectl). This can take a few minutes...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%deploy.ps1"
exit /b 0

:end
endlocal
