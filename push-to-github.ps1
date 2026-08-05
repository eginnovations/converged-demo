#
# Push changes to GitHub and trigger GitHub Actions
#
# Usage:
#   .\push-to-github.ps1 -Message "Fix CLS timing"
#
# This script:
#   1. Stages all changes
#   2. Commits with your message
#   3. Pushes to GitHub
#   4. GitHub Actions auto-triggers CI/CD
#

param(
    [Parameter(Mandatory=$true)]
    [string]$Message,

    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Pushing to GitHub ===" -ForegroundColor Cyan
Write-Host "Branch: $Branch"
Write-Host "Message: $Message"
Write-Host ""

# Check git status
$status = git status --porcelain
if (-not $status) {
    Write-Host "No changes to commit." -ForegroundColor Yellow
    exit 0
}

Write-Host "Changes detected:"
git status --short
Write-Host ""

Write-Host "Staging all changes..." -ForegroundColor Cyan
git add .

Write-Host "Committing..." -ForegroundColor Cyan
git commit -m $Message

Write-Host "Pushing to origin/$Branch..." -ForegroundColor Cyan
git push origin $Branch

Write-Host ""
Write-Host "OK: Pushed to GitHub!" -ForegroundColor Green
Write-Host ""
Write-Host "GitHub Actions is running:"
Write-Host "  1. Building Docker images"
Write-Host "  2. Pushing to Docker Hub"
Write-Host "  3. Deploying to EKS"
Write-Host ""
Write-Host "Watch progress:"
Write-Host "  GitHub repo -> Actions tab"
Write-Host "  Or: kubectl -n converged-demo get pods -w"
Write-Host ""
