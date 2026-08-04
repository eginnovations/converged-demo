#!/usr/bin/env bash
# Build the three service images directly into minikube's Docker daemon and
# deploy the whole stack. Run from the converged-demo/ directory.
set -euo pipefail

echo "==> Pointing Docker at minikube"
eval "$(minikube docker-env)"

echo "==> Building jars"
mvn -q clean package

echo "==> Building images into minikube"
docker build -t converged-demo/storefront:1.0.0            ./storefront
docker build -t converged-demo/order-service:1.0.0         ./order-service
docker build -t converged-demo/notification-worker:1.0.0   ./notification-worker

echo "==> Applying Kubernetes manifests"
kubectl apply -f k8s/

echo "==> Waiting for rollout"
kubectl -n converged-demo rollout status deploy/mysql
kubectl -n converged-demo rollout status deploy/artemis
kubectl -n converged-demo rollout status deploy/order-service
kubectl -n converged-demo rollout status deploy/notification-worker
kubectl -n converged-demo rollout status deploy/storefront

echo
echo "Checkout page:  http://$(minikube ip):30080/"
echo "Artemis console: kubectl -n converged-demo port-forward svc/artemis 8161:8161  ->  http://localhost:8161  (admin/admin)"
