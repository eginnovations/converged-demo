#
# Scale up EKS node group to 1 (resume deployment)
#
# Usage:
#   .\scale-up-nodes.ps1
#
# This brings EC2 nodes back online.
# Costs: ~$105/month (cluster + compute)
#

$ErrorActionPreference = "Stop"

Write-Host "=== Scaling Up EKS Nodes ===" -ForegroundColor Cyan
Write-Host ""

$clusterName = "converged-apm-demo"
$region = "ap-southeast-1"
$nodegroupName = "default"

Write-Host "Cluster: $clusterName" -ForegroundColor Yellow
Write-Host "Region: $region" -ForegroundColor Yellow
Write-Host "Node Group: $nodegroupName" -ForegroundColor Yellow
Write-Host ""

Write-Host "Scaling up to 1 node..." -ForegroundColor Cyan
aws eks update-nodegroup-config `
  --cluster-name $clusterName `
  --nodegroup-name $nodegroupName `
  --scaling-config minSize=1,maxSize=3,desiredSize=1 `
  --region $region

Write-Host ""
Write-Host "OK: Node group scaling up (takes ~3-5 min)" -ForegroundColor Green
Write-Host ""
Write-Host "Check status:"
Write-Host "  kubectl get nodes"
Write-Host ""
Write-Host "Monitor pods restarting:"
Write-Host "  kubectl get pods -n converged-demo -w"
Write-Host ""
Write-Host "Get app URL once pods are ready:"
Write-Host "  kubectl -n converged-demo get ingress converged-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
Write-Host ""
