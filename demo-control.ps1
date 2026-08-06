#
# Converged Demo Control Center
#
# Interactive menu to manage the entire demo:
#   - Deploy changes
#   - Scale nodes up/down
#   - Start/stop cluster
#   - Check status
#   - View logs
#   - Get app URL
#

$ErrorActionPreference = "Stop"

# Configuration
$CLUSTER_NAME = "converged-apm-demo"
$REGION = "ap-southeast-1"
$NAMESPACE = "converged-demo"
$NODEGROUP = "demo-node-grp-new"

function Show-Menu {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   CONVERGED DEMO CONTROL CENTER" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DEPLOYMENT:" -ForegroundColor Yellow
    Write-Host "  1. Push changes to GitHub & deploy" -ForegroundColor White
    Write-Host ""
    Write-Host "SCALING:" -ForegroundColor Yellow
    Write-Host "  2. Scale UP nodes (1 node, ~$30/day)" -ForegroundColor White
    Write-Host "  3. Scale DOWN nodes (0 nodes, save costs)" -ForegroundColor White
    Write-Host ""
    Write-Host "CLUSTER:" -ForegroundColor Yellow
    Write-Host "  4. Start EKS cluster (if stopped)" -ForegroundColor White
    Write-Host "  5. Stop EKS cluster (pause costs)" -ForegroundColor White
    Write-Host ""
    Write-Host "STATUS & LOGS:" -ForegroundColor Yellow
    Write-Host "  6. Show full status dashboard" -ForegroundColor White
    Write-Host "  7. Get app URL" -ForegroundColor White
    Write-Host "  8. View storefront logs (live)" -ForegroundColor White
    Write-Host "  9. View order-service logs (live)" -ForegroundColor White
    Write-Host " 10. View pod status" -ForegroundColor White
    Write-Host ""
    Write-Host "UTILITIES:" -ForegroundColor Yellow
    Write-Host " 11. Check cluster health" -ForegroundColor White
    Write-Host " 12. Restart storefront deployment" -ForegroundColor White
    Write-Host " 13. Check node/pod resource usage" -ForegroundColor White
    Write-Host ""
    Write-Host "CLEANUP:" -ForegroundColor Yellow
    Write-Host " 14. STOP all converged-demo deployments" -ForegroundColor Red
    Write-Host " 15. DELETE entire converged-demo namespace" -ForegroundColor Red
    Write-Host " 16. Pause GitHub Actions (disable auto-deploy)" -ForegroundColor Red
    Write-Host " 17. Resume GitHub Actions (enable auto-deploy)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  0. Exit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Select an option (0-17):" -ForegroundColor Yellow
}

function Deploy-Changes {
    Write-Host ""
    Write-Host "Enter commit message (or press Enter for default):" -ForegroundColor Yellow
    $message = Read-Host "Message"
    if (-not $message) { $message = "Demo update" }

    Write-Host ""
    Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
    .\push-to-github.ps1 -Message $message

    Write-Host ""
    Write-Host "Deployment triggered! GitHub Actions will:" -ForegroundColor Green
    Write-Host "  1. Build Maven project" -ForegroundColor Green
    Write-Host "  2. Build Docker images" -ForegroundColor Green
    Write-Host "  3. Push to Docker Hub" -ForegroundColor Green
    Write-Host "  4. Deploy to EKS" -ForegroundColor Green
    Write-Host ""
    Write-Host "Takes ~10 minutes. Check GitHub Actions tab for progress." -ForegroundColor Green
}

function Scale-Up {
    Write-Host ""
    Write-Host "Scaling up to 1 node (costs ~$30/day)..." -ForegroundColor Cyan

    aws eks update-nodegroup-config `
      --cluster-name $CLUSTER_NAME `
      --nodegroup-name $NODEGROUP `
      --scaling-config minSize=1,maxSize=3,desiredSize=1 `
      --region $REGION

    Write-Host ""
    Write-Host "Nodes scaling up (takes 3-5 min)..." -ForegroundColor Green
    Write-Host "Monitor: kubectl get nodes" -ForegroundColor Green
}

function Scale-Down {
    Write-Host ""
    Write-Host "Scaling down to 0 nodes (saves ~$30/day)..." -ForegroundColor Yellow

    aws eks update-nodegroup-config `
      --cluster-name $CLUSTER_NAME `
      --nodegroup-name $NODEGROUP `
      --scaling-config minSize=0,maxSize=3,desiredSize=0 `
      --region $REGION

    Write-Host ""
    Write-Host "Nodes scaling down (takes ~2 min)..." -ForegroundColor Yellow
    Write-Host "Warning: Pods will be evicted when nodes go down!" -ForegroundColor Yellow
}

function Start-Cluster {
    Write-Host ""
    Write-Host "Starting EKS cluster control plane..." -ForegroundColor Cyan
    Write-Host "NOTE: Use 'Scale UP nodes' to resume deployments." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This requires AWS Console or CLI with proper permissions." -ForegroundColor Gray
    Write-Host "For now, use 'Scale UP nodes' to bring nodes back online." -ForegroundColor Gray
}

function Stop-Cluster {
    Write-Host ""
    Write-Host "Stopping EKS cluster (saves ~$72/day)..." -ForegroundColor Yellow

    Write-Host ""
    Write-Host "To fully stop:"
    Write-Host "  1. First scale down nodes:" -ForegroundColor Yellow
    Write-Host "     Option 3: Scale DOWN nodes" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  2. Then pause/delete cluster via AWS Console" -ForegroundColor Yellow
    Write-Host "     (Go to EKS → Clusters → converged-apm-demo → Delete)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This requires AWS Console access." -ForegroundColor Gray
}

function Show-Dashboard {
    .\status-dashboard.ps1
}

function Get-AppUrl {
    .\check-app-url.ps1
}

function View-StorefrontLogs {
    Write-Host ""
    Write-Host "Viewing storefront logs (press Ctrl+C to stop)..." -ForegroundColor Cyan
    kubectl logs -f deployment/storefront -n $NAMESPACE
}

function View-OrderLogs {
    Write-Host ""
    Write-Host "Viewing order-service logs (press Ctrl+C to stop)..." -ForegroundColor Cyan
    kubectl logs -f deployment/order-service -n $NAMESPACE
}

function View-PodStatus {
    Write-Host ""
    Write-Host "Pod Status:" -ForegroundColor Yellow
    kubectl get pods -n $NAMESPACE -o wide
}

function Check-ClusterHealth {
    Write-Host ""
    Write-Host "Cluster Health:" -ForegroundColor Yellow
    Write-Host ""

    $status = aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text
    Write-Host "Cluster Status: $status" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Nodes:" -ForegroundColor Yellow
    kubectl get nodes -o wide

    Write-Host ""
    Write-Host "Node Group:" -ForegroundColor Yellow
    aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODEGROUP --region $REGION --query 'nodegroup.[status,scalingConfig]' --output text
}

function Restart-Storefront {
    Write-Host ""
    Write-Host "Restarting storefront deployment..." -ForegroundColor Cyan
    kubectl rollout restart deployment/storefront -n $NAMESPACE

    Write-Host "Waiting for new pod to start..." -ForegroundColor Cyan
    kubectl rollout status deployment/storefront -n $NAMESPACE --timeout=60s

    Write-Host ""
    Write-Host "Storefront restarted!" -ForegroundColor Green
}

function Show-ResourceUsage {
    Write-Host ""
    Write-Host "Node Resource Usage:" -ForegroundColor Yellow
    kubectl top nodes 2>$null || Write-Host "  (metrics server not ready)" -ForegroundColor Gray

    Write-Host ""
    Write-Host "Pod Resource Usage:" -ForegroundColor Yellow
    kubectl top pods -n $NAMESPACE 2>$null || Write-Host "  (metrics server not ready)" -ForegroundColor Gray

    Write-Host ""
    Write-Host "Pod Status:" -ForegroundColor Yellow
    kubectl get pods -n $NAMESPACE -o custom-columns=NAME:.metadata.name,CPU:.spec.containers[0].resources.requests.cpu,MEM:.spec.containers[0].resources.requests.memory
}

function Stop-AllDeployments {
    Write-Host ""
    Write-Host "WARNING: This will STOP all deployments in $NAMESPACE" -ForegroundColor Red
    Write-Host "But the namespace and config will remain." -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Continue? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Cancelled." -ForegroundColor Gray
        return
    }

    Write-Host ""
    Write-Host "Scaling down all deployments to 0 replicas..." -ForegroundColor Cyan

    kubectl scale deployment --all --replicas=0 -n $NAMESPACE

    Write-Host ""
    Write-Host "All deployments stopped!" -ForegroundColor Green
    Write-Host "To restart: Use option 1 (Deploy) or manually scale up." -ForegroundColor Green
}

function Delete-Namespace {
    Write-Host ""
    Write-Host "WARNING: This will DELETE the entire $NAMESPACE namespace" -ForegroundColor Red
    Write-Host "All deployments, services, and data will be PERMANENTLY REMOVED." -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Type 'DELETE' to confirm"
    if ($confirm -ne "DELETE") {
        Write-Host "Cancelled." -ForegroundColor Gray
        return
    }

    Write-Host ""
    Write-Host "Deleting namespace $NAMESPACE..." -ForegroundColor Red

    kubectl delete namespace $NAMESPACE

    Write-Host ""
    Write-Host "Namespace deleted!" -ForegroundColor Green
    Write-Host "To create a new namespace: Use option 1 (Deploy) or create manually." -ForegroundColor Green
}

function Pause-GitHubActions {
    Write-Host ""
    Write-Host "Renaming GitHub Actions workflow to disable auto-deploy..." -ForegroundColor Cyan

    $workflowPath = ".github/workflows/build-deploy-docker-hub.yml"
    $pausedPath = ".github/workflows/build-deploy-docker-hub.yml.disabled"

    if (Test-Path $workflowPath) {
        Rename-Item -Path $workflowPath -NewName "build-deploy-docker-hub.yml.disabled"
        Write-Host ""
        Write-Host "GitHub Actions workflow DISABLED!" -ForegroundColor Green
        Write-Host "Git pushes will NOT trigger automatic deployments." -ForegroundColor Green
        Write-Host ""
        Write-Host "To re-enable: Use option 17 (Resume GitHub Actions)" -ForegroundColor Yellow
    } else {
        Write-Host "Workflow file not found." -ForegroundColor Yellow
    }
}

function Resume-GitHubActions {
    Write-Host ""
    Write-Host "Renaming workflow file to enable auto-deploy..." -ForegroundColor Cyan

    $pausedPath = ".github/workflows/build-deploy-docker-hub.yml.disabled"
    $workflowPath = ".github/workflows/build-deploy-docker-hub.yml"

    if (Test-Path $pausedPath) {
        Rename-Item -Path $pausedPath -NewName "build-deploy-docker-hub.yml"
        Write-Host ""
        Write-Host "GitHub Actions workflow ENABLED!" -ForegroundColor Green
        Write-Host "Next git push will trigger automatic deployment." -ForegroundColor Green
        Write-Host ""
        Write-Host "To disable: Use option 16 (Pause GitHub Actions)" -ForegroundColor Yellow
    } else {
        Write-Host "Paused workflow file not found." -ForegroundColor Yellow
    }
}

# Main loop
do {
    Show-Menu
    $choice = Read-Host "Enter option"

    Write-Host ""

    switch ($choice) {
        "1" { Deploy-Changes }
        "2" { Scale-Up }
        "3" { Scale-Down }
        "4" { Start-Cluster }
        "5" { Stop-Cluster }
        "6" { Show-Dashboard }
        "7" { Get-AppUrl }
        "8" { View-StorefrontLogs }
        "9" { View-OrderLogs }
        "10" { View-PodStatus }
        "11" { Check-ClusterHealth }
        "12" { Restart-Storefront }
        "13" { Show-ResourceUsage }
        "14" { Stop-AllDeployments }
        "15" { Delete-Namespace }
        "16" { Pause-GitHubActions }
        "17" { Resume-GitHubActions }
        "0" {
            Write-Host "Goodbye!" -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-Host "Invalid option. Try again." -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Press Enter to continue..." -ForegroundColor Gray
    Read-Host
} while ($true)
