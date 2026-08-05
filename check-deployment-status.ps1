#
# Check Application Deployment Status
#
# Usage:
#   .\check-deployment-status.ps1
#

$ErrorActionPreference = "Stop"

Write-Host "=== Deployment Status ===" -ForegroundColor Cyan
Write-Host ""

# Check deployments
Write-Host "Deployments:" -ForegroundColor Yellow
kubectl get deployments -n converged-demo -o wide
Write-Host ""

# Check rollout status
Write-Host "Rollout Status:" -ForegroundColor Yellow
Write-Host ""

Write-Host "  Storefront:" -ForegroundColor Cyan
kubectl rollout status deployment/storefront -n converged-demo --timeout=5s 2>&1 | Select-Object -First 1
Write-Host ""

Write-Host "  Order Service:" -ForegroundColor Cyan
kubectl rollout status deployment/order-service -n converged-demo --timeout=5s 2>&1 | Select-Object -First 1
Write-Host ""

Write-Host "  Notification Worker:" -ForegroundColor Cyan
kubectl rollout status deployment/notification-worker -n converged-demo --timeout=5s 2>&1 | Select-Object -First 1
Write-Host ""

# Check replica sets
Write-Host "Replica Sets:" -ForegroundColor Yellow
kubectl get replicasets -n converged-demo -o wide
Write-Host ""

Write-Host "Usage:" -ForegroundColor Green
Write-Host "  kubectl rollout history deployment/storefront -n converged-demo           # Deployment history"
Write-Host "  kubectl rollout undo deployment/storefront -n converged-demo              # Rollback to previous"
Write-Host "  kubectl scale deployment/storefront --replicas=3 -n converged-demo        # Scale replicas"
Write-Host ""
