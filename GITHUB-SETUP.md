# GitHub + CI/CD Setup

Push this project to GitHub and automatically build/deploy to any Kubernetes cluster.

## Step 1: Create a GitHub repository

```bash
cd converged-demo
git init
git add .
git commit -m "Initial commit: eG Converged Demo application"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/converged-demo.git
git push -u origin main
```

## Step 2: Configure GitHub secrets

Go to **Settings → Secrets and variables → Actions** and add:

### Container registry (choose one)

**Docker Hub:**
```
REGISTRY_URL: docker.io
REGISTRY_USERNAME: your_docker_username
REGISTRY_PASSWORD: your_docker_personal_access_token
```

**AWS ECR:**
```
REGISTRY_URL: your_account_id.dkr.ecr.us-east-1.amazonaws.com
REGISTRY_USERNAME: AWS
REGISTRY_PASSWORD: (leave blank — Actions will assume IAM role)
AWS_ACCESS_KEY_ID: your_key_id
AWS_SECRET_ACCESS_KEY: your_secret_key
```

**GCP GCR:**
```
REGISTRY_URL: gcr.io
REGISTRY_USERNAME: _json_key
REGISTRY_PASSWORD: your_gcp_service_account_json
```

**Azure ACR:**
```
REGISTRY_URL: yourregistry.azurecr.io
REGISTRY_USERNAME: your_username
REGISTRY_PASSWORD: your_password
```

### Kubernetes cluster (choose one)

**AWS EKS:**
```
AWS_REGION: us-east-1
AWS_ACCESS_KEY_ID: your_key_id
AWS_SECRET_ACCESS_KEY: your_secret_key
EKS_CLUSTER_NAME: your-cluster-name
```

**Google GKE:**
```
GCP_PROJECT_ID: your-project-id
GCP_SA_KEY: (the full JSON service account key)
GKE_CLUSTER_NAME: your-cluster
GKE_ZONE: us-central1-a
```

**Azure AKS:**
```
AZURE_RESOURCE_GROUP: your-rg
AZURE_SUBSCRIPTION_ID: your-subscription
AKS_CLUSTER_NAME: your-cluster-name
```

**minikube (local):**
- No secrets needed for minikube; just configure kubeconfig on your machine.
- (The workflow will skip deployment steps if no cloud secrets are set.)

## Step 3: Update K8s manifests for your registry

If using a remote registry (not minikube), update `k8s/` manifests to point to your images:

In `k8s/20-order-service.yaml`, `k8s/21-notification-worker.yaml`, `k8s/22-storefront.yaml`:

```yaml
image: your_registry/your_username/converged-demo/order-service:latest
imagePullPolicy: Always
```

Or let the GitHub Action inject the image SHA at deploy time (recommended — see workflow step "Update K8s images").

## Step 4: Trigger the workflow

**Automatic:** Push to `main` or `develop`:
```bash
git push origin main
```

**Manual:** Go to **Actions → Build and Deploy → Run workflow** and pick your target environment.

## Step 5: Monitor the deployment

Check **Actions** tab to watch the build/push/deploy pipeline. Each step logs its progress.

---

## Deployment targets

### minikube (local development)
- No cloud secrets needed.
- The workflow builds but skips the push/deploy steps.
- Use the local `app.bat` / `deploy.ps1` to manage minikube.

### AWS EKS (production / staging)
- Set the `AWS_*`, `EKS_*` secrets.
- Workflow builds images, pushes to ECR, and updates the cluster.
- Make sure the namespace `converged-demo` exists:
  ```bash
  kubectl create namespace converged-demo
  kubectl apply -f k8s/ -n converged-demo
  ```

### Google GKE (production / staging)
- Set the `GCP_*`, `GKE_*` secrets.
- Images push to `gcr.io/YOUR_PROJECT/converged-demo/...`.
- Pre-create the namespace:
  ```bash
  kubectl create namespace converged-demo
  kubectl apply -f k8s/ -n converged-demo
  ```

### Azure AKS (production / staging)
- Set the `AZURE_*` secrets.
- Images push to your ACR.
- Pre-create the namespace:
  ```bash
  kubectl create namespace converged-demo
  kubectl apply -f k8s/ -n converged-demo
  ```

---

## Notes

- **Image tags:** The workflow tags images as `latest` and `git_commit_sha`. Use the SHA for pinpointed rollbacks.
- **Private registry:** If your registry is private, ensure the K8s cluster has a pull secret (the workflow doesn't create this for you; set it up manually).
- **Rollback:** If a deployment fails, use `kubectl rollout undo deployment/name -n converged-demo`.
- **Logs:** Use `kubectl logs -f deploy/name -n converged-demo` to tail the running pods.

---

## Quick reference

### First time (local minikube):
```bash
cd converged-demo
git init && git add . && git commit -m "init"
git remote add origin https://github.com/YOUR/repo.git
git push -u origin main
# (no secrets needed for minikube; just run: app.bat, deploy.ps1, etc. locally)
```

### Deploying to EKS:
```bash
git push origin main
# (GitHub Actions automatically builds, pushes to ECR, and updates your EKS cluster)
```

### Manual deploy (if you want to skip GitHub):
```bash
# Build locally
mvn clean package
docker build -t myregistry/converged-demo/storefront:1.0 ./storefront
docker push myregistry/converged-demo/storefront:1.0

# Update K8s
kubectl set image deployment/storefront storefront=myregistry/converged-demo/storefront:1.0 -n converged-demo
kubectl rollout status deployment/storefront -n converged-demo
```
