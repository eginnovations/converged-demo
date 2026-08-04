# Build the three service images directly into minikube's Docker daemon and
# deploy the whole stack. Run from the converged-demo\ directory in PowerShell:
#   .\deploy.ps1
$ErrorActionPreference = "Stop"

Write-Host "==> Pointing Docker at minikube" -ForegroundColor Cyan
& minikube docker-env --shell powershell | Invoke-Expression

Write-Host "==> Building jars" -ForegroundColor Cyan
& mvn -q clean package
if ($LASTEXITCODE -ne 0) { throw "Maven build failed" }

Write-Host "==> Building images into minikube" -ForegroundColor Cyan
docker build -t converged-demo/storefront:1.0.0          .\storefront
docker build -t converged-demo/order-service:1.0.0       .\order-service
docker build -t converged-demo/notification-worker:1.0.0 .\notification-worker

Write-Host "==> Applying Kubernetes manifests" -ForegroundColor Cyan
kubectl apply -f k8s

# The image tag (1.0.0) does not change between builds, so `kubectl apply` alone
# sees "no change" and keeps the OLD pods running. Force the app tiers to
# recreate so they pick up the freshly built images.
Write-Host "==> Restarting app tiers to pick up new images" -ForegroundColor Cyan
kubectl -n converged-demo rollout restart deploy/storefront
kubectl -n converged-demo rollout restart deploy/order-service
kubectl -n converged-demo rollout restart deploy/notification-worker

Write-Host "==> Waiting for rollout" -ForegroundColor Cyan
kubectl -n converged-demo rollout status deploy/mysql
kubectl -n converged-demo rollout status deploy/artemis
kubectl -n converged-demo rollout status deploy/order-service
kubectl -n converged-demo rollout status deploy/notification-worker
kubectl -n converged-demo rollout status deploy/storefront

Write-Host ""
Write-Host "Deployment complete." -ForegroundColor Green
Write-Host ""
Write-Host "NOTE: with the Docker driver on Windows the minikube IP is NOT reachable" -ForegroundColor Yellow
Write-Host "from your browser. Open the checkout page through a tunnel instead:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Checkout page:" -ForegroundColor Green
Write-Host "    kubectl -n converged-demo port-forward svc/storefront 8080:8080   ->  http://localhost:8080/"
Write-Host "    (or just run:  app.bat url )"
Write-Host ""
Write-Host "  Artemis console:" -ForegroundColor Green
Write-Host "    kubectl -n converged-demo port-forward svc/artemis 8161:8161      ->  http://localhost:8161  (admin/admin)"
