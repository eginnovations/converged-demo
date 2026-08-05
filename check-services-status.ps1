#
# Check Services and Ingress Status
#
# Usage:
#   .\check-services-status.ps1
#

$ErrorActionPreference = "Stop"

Write-Host "=== Services and Ingress Status ===" -ForegroundColor Cyan
Write-Host ""

# Check services
Write-Host "Services:" -ForegroundColor Yellow
kubectl get services -n converged-demo -o wide
Write-Host ""

# Check ingress
Write-Host "Ingress (ALB):" -ForegroundColor Yellow
kubectl get ingress -n converged-demo -o wide
Write-Host ""

# Get ALB details
Write-Host "Ingress Details:" -ForegroundColor Yellow
kubectl describe ingress converged-demo -n converged-demo
Write-Host ""

# Get app URL
Write-Host "App URL:" -ForegroundColor Green
$albDns = kubectl get ingress converged-demo -n converged-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null
if ($albDns) {
    Write-Host "  http://$albDns" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Ready to access in browser"
} else {
    Write-Host "  ALB is provisioning... (wait 1-2 minutes)" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Usage:" -ForegroundColor Green
Write-Host "  .\check-app-url.ps1  # Quick app URL check"
Write-Host ""
