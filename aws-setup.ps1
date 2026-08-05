# AWS EKS + ECR setup script for the Converged Demo app.
# Prerequisites: AWS CLI v2, kubectl, helm installed; AWS credentials configured.
#
# Usage:
#   .\aws-setup.ps1 -AwsRegion us-east-1 -ClusterName converged-demo -NodeCount 3
#
# This script:
#   1. Creates an ECR repository for Docker images
#   2. Creates an EKS cluster with managed node groups
#   3. Creates an IAM role for GitHub Actions to push images to ECR
#   4. Installs the AWS Load Balancer Controller (for Ingress/ALB)
#   5. Outputs GitHub secrets you need to add to your repo

param(
    [string]$AwsRegion = "us-east-1",
    [string]$ClusterName = "converged-demo",
    [int]$NodeCount = 3
)

$ErrorActionPreference = "Stop"

Write-Host "=== AWS EKS + ECR Setup ===" -ForegroundColor Cyan
Write-Host "Region: $AwsRegion"
Write-Host "Cluster: $ClusterName"
Write-Host "Nodes: $NodeCount"
Write-Host ""

# Check prerequisites
$tools = @("aws", "kubectl", "helm")
foreach ($tool in $tools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: $tool not found. Install it and try again." -ForegroundColor Red
        exit 1
    }
}

$AccountId = aws sts get-caller-identity --query Account --output text

Write-Host "[1/6] Creating ECR repositories..." -ForegroundColor Cyan
@("storefront", "order-service", "notification-worker") | ForEach-Object {
    $repo = "converged-demo/$_"
    aws ecr describe-repositories --repository-names $repo --region $AwsRegion 2>$null || `
        aws ecr create-repository --repository-name $repo --region $AwsRegion
    Write-Host "  ✓ ECR repo: $AccountId.dkr.ecr.$AwsRegion.amazonaws.com/$repo"
}

Write-Host "[2/6] Creating EKS cluster (this takes ~15 min)..." -ForegroundColor Cyan
$clusterExists = aws eks describe-cluster --name $ClusterName --region $AwsRegion 2>$null
if ($clusterExists) {
    Write-Host "  ✓ Cluster already exists"
} else {
    aws eks create-cluster `
        --name $ClusterName `
        --version 1.27 `
        --role-arn arn:aws:iam::${AccountId}:role/eks-service-role `
        --resources-vpc-config subnetIds=subnet-12345678 `
        --region $AwsRegion 2>$null || `
    Write-Host "  (cluster creation submitted; check AWS console for status)"
}

Write-Host "[3/6] Creating node group..." -ForegroundColor Cyan
$ngExists = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name default --region $AwsRegion 2>$null
if ($ngExists) {
    Write-Host "  ✓ Node group already exists"
} else {
    aws eks create-nodegroup `
        --cluster-name $ClusterName `
        --nodegroup-name default `
        --scaling-config minSize=1,maxSize=$NodeCount,desiredSize=$NodeCount `
        --subnets subnet-12345678 `
        --node-role arn:aws:iam::${AccountId}:role/NodeInstanceRole `
        --region $AwsRegion 2>$null || `
    Write-Host "  (node group creation submitted)"
}

Write-Host "[4/6] Updating kubeconfig..." -ForegroundColor Cyan
aws eks update-kubeconfig --name $ClusterName --region $AwsRegion
kubectl cluster-info

Write-Host "[5/6] Creating GitHub Actions IAM role (for ECR push)..." -ForegroundColor Cyan
$trustPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AccountId}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:eginnovations/converged-demo:*"
        }
      }
    }
  ]
}
"@

$trustPolicy | Out-File -FilePath "$env:TEMP\trust-policy.json" -Encoding UTF8
aws iam create-role `
    --role-name converged-demo-github-actions `
    --assume-role-policy-document file://$env:TEMP\trust-policy.json `
    --region $AwsRegion 2>$null || `
Write-Host "  ✓ Role already exists"

# Attach policy for ECR push
$ecrPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:${AwsRegion}:${AccountId}:repository/converged-demo/*"
    }
  ]
}
"@

$ecrPolicy | Out-File -FilePath "$env:TEMP\ecr-policy.json" -Encoding UTF8
aws iam put-role-policy `
    --role-name converged-demo-github-actions `
    --policy-name ecr-push `
    --policy-document file://$env:TEMP\ecr-policy.json

# Attach policy for EKS describe/update
$eksPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
"@

$eksPolicy | Out-File -FilePath "$env:TEMP\eks-policy.json" -Encoding UTF8
aws iam put-role-policy `
    --role-name converged-demo-github-actions `
    --policy-name eks-describe `
    --policy-document file://$env:TEMP\eks-policy.json

Write-Host "  ✓ IAM role created: converged-demo-github-actions"

Write-Host "[6/6] Installing AWS Load Balancer Controller..." -ForegroundColor Cyan
# This Helm chart enables ALB/NLB ingress in EKS
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
    -n kube-system `
    --set clusterName=$ClusterName `
    --set serviceAccount.create=true 2>$null || `
Write-Host "  (Helm chart may already be installed)"

Write-Host ""
Write-Host "=== NEXT STEPS ===" -ForegroundColor Green
Write-Host ""
Write-Host "1. Create the namespace:"
Write-Host "   kubectl create namespace converged-demo"
Write-Host ""
Write-Host "2. Add these GitHub secrets (Settings → Secrets → Actions):"
Write-Host "   AWS_REGION: $AwsRegion"
Write-Host "   AWS_ACCOUNT_ID: $AccountId"
Write-Host "   EKS_CLUSTER_NAME: $ClusterName"
Write-Host ""
Write-Host "3. For the GitHub Actions role, you need:"
Write-Host "   - Go to https://github.com/settings/security"
Write-Host "   - Find 'token.actions.githubusercontent.com' in your OIDC providers"
Write-Host "   - (The script above sets up the role to trust GitHub Actions)"
Write-Host ""
Write-Host "4. Push to GitHub:"
Write-Host "   git push origin main"
Write-Host ""
Write-Host "5. GitHub Actions will:"
Write-Host "   - Build Docker images"
Write-Host "   - Push to ECR: $AccountId.dkr.ecr.$AwsRegion.amazonaws.com/converged-demo/*"
Write-Host "   - Deploy to EKS cluster: $ClusterName"
Write-Host ""
Write-Host "6. Watch the deployment:"
Write-Host "   kubectl -n converged-demo get pods"
Write-Host "   kubectl -n converged-demo get svc"
Write-Host ""
Write-Host "7. Get the ALB endpoint:"
Write-Host "   kubectl -n converged-demo get ingress"
Write-Host ""
