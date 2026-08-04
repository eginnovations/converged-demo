# Drive checkout traffic so the notification queue backs up and RUM/APM light up.
# Usage:  .\load-test.ps1 [count] [concurrency]
#   .\load-test.ps1 40 4
param(
    [int]$Count = 40,
    [int]$Concurrency = 4
)
$ErrorActionPreference = "Stop"

# Uses the port-forward tunnel (localhost:8080). Start it first with:
#   app.bat url      (or)   kubectl -n converged-demo port-forward svc/storefront 8080:8080
$url = "http://localhost:8080/api/placeOrder"
$body = '{"items":["SKU-HEADPH-01","SKU-CHRG-USBC"],"amount":159.00,"currency":"USD"}'

Write-Host "Firing $Count orders ($Concurrency at a time) at $url" -ForegroundColor Cyan

# Throttled parallel requests using background jobs.
$jobs = @()
for ($i = 1; $i -le $Count; $i++) {
    while (@($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $Concurrency) {
        Start-Sleep -Milliseconds 100
    }
    $jobs += Start-Job -ScriptBlock {
        param($n, $u, $b)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $r = Invoke-WebRequest -Uri $u -Method Post -ContentType 'application/json' -Body $b -UseBasicParsing
            "order $n -> $($r.StatusCode) in $([math]::Round($sw.Elapsed.TotalSeconds,2))s"
        } catch {
            "order $n -> ERROR $($_.Exception.Message)"
        }
    } -ArgumentList $i, $url, $body
}

$jobs | Wait-Job | Receive-Job | ForEach-Object { Write-Host $_ }
$jobs | Remove-Job

Write-Host "Done. Check the Artemis console (order.notifications) for the growing backlog." -ForegroundColor Green
