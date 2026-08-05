#
# Quick: Get Application URL
#
# Usage:
#   .\check-app-url.ps1
#

$ErrorActionPreference = "Stop"

Write-Host "=== Application URL ===" -ForegroundColor Cyan
Write-Host ""

$albDns = kubectl get ingress converged-demo -n converged-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null

if ($albDns) {
    Write-Host "App is ready at:" -ForegroundColor Green
    Write-Host ""
    Write-Host "  http://$albDns" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Login with:" -ForegroundColor Yellow
    Write-Host "  Email: alice.chen@shopfast.io" -ForegroundColor Yellow
    Write-Host "  Password: demo" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "ALB is provisioning..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Check status:" -ForegroundColor Cyan
    Write-Host "  .\check-services-status.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Wait 1-2 minutes and try again." -ForegroundColor Yellow
}
