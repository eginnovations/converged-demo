#
# Overall Status Dashboard
#
# Shows cluster, nodes, deployments, pods, and app URL in one view
#
# Usage:
#   .\status-dashboard.ps1
#

$ErrorActionPreference = "Stop"

Clear-Host

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    CONVERGED DEMO STATUS                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 1. Cluster Status
Write-Host "1. CLUSTER STATUS" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
$clusterStatus = aws eks describe-cluster --name converged-apm-demo --region ap-southeast-1 --query 'cluster.status' --output text
Write-Host "Cluster Status: $clusterStatus" -ForegroundColor Green
Write-Host ""

# 2. Nodes
Write-Host "2. NODES" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[3].reason,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory,AGE:.metadata.creationTimestamp
Write-Host ""

# 3. Deployments
Write-Host "3. DEPLOYMENTS" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
kubectl get deployments -n converged-demo -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas,UP-TO-DATE:.status.updatedReplicas,AGE:.metadata.creationTimestamp
Write-Host ""

# 4. Pods
Write-Host "4. PODS" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
kubectl get pods -n converged-demo -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp
Write-Host ""

# 5. Services
Write-Host "5. SERVICES & INGRESS" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
kubectl get services -n converged-demo -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].hostname
Write-Host ""

# 6. App URL
Write-Host "6. APPLICATION URL" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
$albDns = kubectl get ingress converged-demo -n converged-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null
if ($albDns) {
    Write-Host "✓ Ready: http://$albDns" -ForegroundColor Green
    Write-Host "  Login: alice.chen@shopfast.io / demo" -ForegroundColor Green
} else {
    Write-Host "⏳ ALB provisioning (wait 1-2 minutes)..." -ForegroundColor Yellow
}
Write-Host ""

# 7. Quick Commands
Write-Host "7. QUICK COMMANDS" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "View logs:         kubectl logs -f deployment/storefront -n converged-demo" -ForegroundColor Cyan
Write-Host "Scale down:        .\scale-down-nodes.ps1" -ForegroundColor Cyan
Write-Host "Scale up:          .\scale-up-nodes.ps1" -ForegroundColor Cyan
Write-Host "Deploy changes:    .\push-to-github.ps1 -Message 'Your message'" -ForegroundColor Cyan
Write-Host "Check app URL:     .\check-app-url.ps1" -ForegroundColor Cyan
Write-Host ""
