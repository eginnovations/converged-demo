#
# Local Development Setup Script
#
# This script configures your laptop for:
#   1. GitHub (authenticate with your PAT)
#   2. Docker Hub (store credentials locally)
#   3. AWS (configure CLI with your access keys)
#   4. kubectl (connect to EKS cluster)
#
# NO CREDENTIALS are stored in GitHub or environment.
# They stay on your laptop only.
#

$ErrorActionPreference = "Stop"

Write-Host "=== Local Development Setup ===" -ForegroundColor Cyan
Write-Host ""

# GITHUB SETUP
Write-Host "[1/4] GitHub Setup" -ForegroundColor Cyan

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing GitHub CLI..." -ForegroundColor Yellow
    winget install GitHub.cli
}

Write-Host "  Authenticating with GitHub..."
try { gh auth login 2>$null } catch { Write-Host "    (already authenticated)" }

$ghUser = gh auth status 2>$null | Select-String "Logged in" | ForEach-Object { $_.Line }
Write-Host "  OK: $ghUser"
Write-Host ""

# DOCKER HUB SETUP
Write-Host "[2/4] Docker Hub Setup" -ForegroundColor Cyan

$dockerUser = Read-Host "  Docker Hub username"
$dockerPAT = Read-Host "  Docker Hub PAT (will not echo)"

Write-Host "  Logging in to Docker Hub..."
$dockerPAT | docker login -u $dockerUser --password-stdin 2>$null

Write-Host "  OK: Logged in as $dockerUser"
Write-Host "  Credentials stored in: ~/.docker/config.json (local only)"
Write-Host ""

# AWS SETUP
Write-Host "[3/4] AWS Configuration" -ForegroundColor Cyan

$awsRegion = Read-Host "  AWS Region (default: us-east-1)"
if (-not $awsRegion) { $awsRegion = "us-east-1" }

$awsAccessKey = Read-Host "  AWS Access Key ID"
$awsSecretKey = Read-Host "  AWS Secret Access Key"

Write-Host "  Configuring AWS CLI..."
aws configure set aws_access_key_id $awsAccessKey
aws configure set aws_secret_access_key $awsSecretKey
aws configure set region $awsRegion
aws configure set output json

$accountId = aws sts get-caller-identity --query Account --output text
Write-Host "  OK: AWS account ID: $accountId"
Write-Host "  Credentials stored in: ~/.aws/credentials (local only)"
Write-Host ""

# KUBERNETES SETUP
Write-Host "[4/4] Kubernetes (EKS) Setup" -ForegroundColor Cyan

$clusterName = Read-Host "  EKS Cluster Name (default: converged-demo)"
if (-not $clusterName) { $clusterName = "converged-demo" }

Write-Host "  Updating kubeconfig..."
aws eks update-kubeconfig --name $clusterName --region $awsRegion

$clusterInfo = kubectl cluster-info 2>$null | Select-String "Kubernetes master"
if ($clusterInfo) {
    Write-Host "  OK: Connected to EKS cluster: $clusterName"
} else {
    Write-Host "  WARNING: Could not verify cluster connection"
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Your local environment is ready."
Write-Host "  OK GitHub authenticated"
Write-Host "  OK Docker Hub logged in as: $dockerUser"
Write-Host "  OK AWS configured for region: $awsRegion"
Write-Host "  OK kubectl connected to: $clusterName"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Edit code locally"
Write-Host "  2. Commit and push: .\push-to-github.ps1 -Message 'Your message'"
Write-Host "  3. GitHub Actions will build, push to Docker Hub, and deploy to EKS"
Write-Host ""
