# Continuous browser-based RUM + APM load generator.
# Prereq: Node.js installed, and the storefront reachable at BASE_URL
#         (start the tunnel first:  app.bat url   -> keeps http://localhost:8080 open)
#
# Examples:
#   .\run.ps1                       # 2 users, forever, 70% checkout
#   $env:CONCURRENCY=4; .\run.ps1   # 4 parallel users
#   $env:HEADED=1;      .\run.ps1   # watch the browsers
#   $env:ITERATIONS=5;  .\run.ps1   # 5 journeys per worker then stop
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Node.js is required. Install it (e.g. winget install OpenJS.NodeJS.LTS) and re-run." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path node_modules)) {
    Write-Host "==> First run: installing Playwright + browsers (a few minutes)..." -ForegroundColor Cyan
    npm install
    # Chromium + Firefox engines. Chrome and Edge are used via system channels.
    npx playwright install chromium firefox
}

Write-Host "==> Starting load generator (Ctrl+C to stop)" -ForegroundColor Cyan
node generate.js
