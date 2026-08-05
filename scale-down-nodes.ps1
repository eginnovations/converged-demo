#
# Scale down EKS node group to 0 (save costs when not using)
#
# Usage:
#   .\scale-down-nodes.ps1
#
# This stops all EC2 nodes but keeps the EKS cluster alive.
# Costs: ~$72/month (cluster only, no compute)
#

$ErrorActionPreference = "Stop"

Write-Host "=== Scaling Down EKS Nodes ===" -ForegroundColor Cyan
Write-Host ""

$clusterName = "converged-apm-demo"
$region = "ap-southeast-1"
$nodegroupName = "default"

Write-Host "Cluster: $clusterName" -ForegroundColor Yellow
Write-Host "Region: $region" -ForegroundColor Yellow
Write-Host "Node Group: $nodegroupName" -ForegroundColor Yellow
Write-Host ""

Write-Host "Scaling down to 0 nodes..." -ForegroundColor Cyan
aws eks update-nodegroup-config `
  --cluster-name $clusterName `
  --nodegroup-name $nodegroupName `
  --scaling-config minSize=0,maxSize=3,desiredSize=0 `
  --region $region

Write-Host ""
Write-Host "OK: Nodes scaling down (takes ~2 min)" -ForegroundColor Green
Write-Host ""
Write-Host "Check status:"
Write-Host "  aws eks describe-nodegroup --cluster-name $clusterName --nodegroup-name $nodegroupName --region $region --query 'nodegroup.scalingConfig'"
Write-Host ""
Write-Host "When ready to resume:"
Write-Host "  .\scale-up-nodes.ps1"
Write-Host ""
