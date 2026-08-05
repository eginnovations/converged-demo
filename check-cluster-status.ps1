#
# Check EKS Cluster and Node Status
#
# Usage:
#   .\check-cluster-status.ps1
#

$ErrorActionPreference = "Stop"

Write-Host "=== EKS Cluster Status ===" -ForegroundColor Cyan
Write-Host ""

$clusterName = "converged-apm-demo"
$region = "ap-southeast-1"

# Check cluster status
Write-Host "Cluster: $clusterName" -ForegroundColor Yellow
$cluster = aws eks describe-cluster --name $clusterName --region $region --query 'cluster.[name,status,version,createdAt]' --output text
Write-Host $cluster
Write-Host ""

# Check node group status
Write-Host "Node Group: default" -ForegroundColor Yellow
$nodegroup = aws eks describe-nodegroup --cluster-name $clusterName --nodegroup-name default --region $region --query 'nodegroup.[nodegroupName,status,scalingConfig.desiredSize,scalingConfig.minSize,scalingConfig.maxSize,createdAt]' --output text
Write-Host $nodegroup
Write-Host ""

# Check nodes
Write-Host "Nodes:" -ForegroundColor Yellow
kubectl get nodes -o wide
Write-Host ""

# Check node capacity
Write-Host "Node Capacity:" -ForegroundColor Yellow
kubectl top nodes 2>/dev/null || Write-Host "  (metrics server not ready yet)"
Write-Host ""

Write-Host "Usage:" -ForegroundColor Green
Write-Host "  .\check-pods-status.ps1       # Check pod status"
Write-Host "  .\check-deployment-status.ps1 # Check deployment status"
Write-Host "  .\check-app-url.ps1           # Get app URL"
Write-Host ""
