# Continuous SERVER-SIDE traffic generator (no browser).
# Drives APM / BTM / SQL / message-queue load by hammering the page URLs and the
# checkout endpoint in a loop. NOTE: this does NOT run egrum.js, so it produces
# NO browser RUM data — use rum-load\run.ps1 for real RUM sessions.
#
# Usage:  .\traffic.ps1 [concurrency]     (Ctrl+C to stop)
#   Start the tunnel first:  app.bat url   (keeps http://localhost:8080 open)
param([int]$Concurrency = 3)
$base = "http://localhost:8080"
$body = '{"items":["SKU-HEADPH-01","SKU-CHRG-USBC"],"amount":159.00,"currency":"USD"}'

$work = {
    param($base, $body)
    $pages = @('/index', '/product?id=h1', '/api/products', '/api/reviews?id=h1',
               '/api/related?id=h1', '/cart', '/checkout')
    while ($true) {
        foreach ($p in $pages) {
            try { Invoke-WebRequest -Uri "$base$p" -UseBasicParsing -TimeoutSec 30 | Out-Null } catch {}
        }
        try {
            Invoke-WebRequest -Uri "$base/api/placeOrder" -Method Post -ContentType 'application/json' `
                -Body $body -UseBasicParsing -TimeoutSec 30 | Out-Null
        } catch {}
    }
}

$jobs = @()
for ($i = 0; $i -lt $Concurrency; $i++) { $jobs += Start-Job -ScriptBlock $work -ArgumentList $base, $body }
Write-Host "Server-side traffic running with $Concurrency workers (APM/BTM/MQ only)." -ForegroundColor Cyan
Write-Host "This also feeds the checkout transaction + Artemis queue. Ctrl+C to stop." -ForegroundColor Cyan
try {
    while ($true) { Start-Sleep -Seconds 5; Write-Host ("[{0}] generating..." -f (Get-Date -Format T)) }
}
finally {
    $jobs | Stop-Job -ErrorAction SilentlyContinue
    $jobs | Remove-Job -ErrorAction SilentlyContinue
    Write-Host "Stopped." -ForegroundColor Green
}
