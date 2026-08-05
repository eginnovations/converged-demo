#
# Check Pod Status in converged-demo Namespace
#
# Usage:
#   .\check-pods-status.ps1
#

$ErrorActionPreference = "Stop"

Write-Host "=== Pod Status ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "All Pods in converged-demo namespace:" -ForegroundColor Yellow
kubectl get pods -n converged-demo -o wide
Write-Host ""

Write-Host "Pod Details (with events):" -ForegroundColor Yellow
kubectl describe pods -n converged-demo 2>/dev/null | Select-String -Pattern "Name:|Status:|Restart|Events" -Context 1
Write-Host ""

Write-Host "Usage:" -ForegroundColor Green
Write-Host "  kubectl logs -n converged-demo <pod-name>                    # View pod logs"
Write-Host "  kubectl describe pod <pod-name> -n converged-demo            # Pod details"
Write-Host "  kubectl logs -f deployment/storefront -n converged-demo      # Follow storefront logs"
Write-Host "  kubectl logs -f deployment/order-service -n converged-demo   # Follow order-service logs"
Write-Host "  kubectl logs -f deployment/notification-worker -n converged-demo  # Follow worker logs"
Write-Host ""
