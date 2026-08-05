# Secure Local Development + GitHub Actions + EKS Deployment

**Zero credentials in GitHub.** All sensitive data stays on your laptop. GitHub Actions uses only the secrets you add once.

---

## Prerequisites

Install on your laptop:
```powershell
winget install Amazon.AWSCLI Kubernetes.kubectl Helm.Helm GitHub.cli Docker.DockerDesktop
```

Verify:
```powershell
aws --version
kubectl version --client
helm version
gh --version
docker --version
```

---

## One-time Setup (5 min)

### Step 1: Run local setup script

This prompts you for credentials and stores them locally (never in GitHub):

```powershell
cd C:\WorkItems\projects\RUMBTM\converged-demo

.\local-setup.ps1
```

**What it does:**
- ✓ Authenticates with GitHub (via `gh auth login`)
- ✓ Logs you into Docker Hub (stored in `~/.docker/config.json`)
- ✓ Configures AWS CLI (stored in `~/.aws/credentials`)
- ✓ Connects kubectl to your EKS cluster

**Credentials stay local.** None go to GitHub, Docker Hub, or AWS GitHub actions.

---

### Step 2: Add GitHub Secrets (one-time)

Go to your repo **Settings → Secrets and variables → Actions** and add:

```
DOCKER_HUB_USERNAME: your_docker_hub_username
DOCKER_HUB_PAT: your_docker_hub_personal_access_token
AWS_ACCESS_KEY_ID: your_aws_access_key
AWS_SECRET_ACCESS_KEY: your_aws_secret_key
AWS_REGION: us-east-1
EKS_CLUSTER_NAME: converged-demo
```

**Get Docker Hub PAT:**
1. Log in to Docker Hub → **Account Settings → Security → New Access Token**
2. Copy the token

**Get AWS credentials:**
```powershell
aws sts get-caller-identity  # verify your account
```

---

## Daily Development Workflow

### 1. Edit code locally

Use Claude to help:
```
# In Claude:
"I want to change the CLS delay from 5s to 8s on the product page. 
Which file should I edit and what's the exact change?"
```

Claude will tell you the file and exact edit. You make the change locally.

### 2. Commit and push to GitHub

One simple command triggers the entire CI/CD pipeline:

```powershell
.\push-to-github.ps1 -Message "Increase CLS delay to 8s"
```

**What this does:**
- ✓ Stages your changes
- ✓ Commits with your message
- ✓ Pushes to GitHub
- ✓ GitHub Actions auto-triggers

### 3. GitHub Actions runs (5–10 min)

Automatically:
1. Builds Maven project
2. Builds 3 Docker images
3. Pushes to Docker Hub: `docker.io/YOUR_USERNAME/converged-demo-*`
4. Deploys to your EKS cluster
5. Creates AWS ALB (public endpoint)

**Watch it in GitHub:**
- Go to **Actions** tab
- Click the workflow run
- See real-time logs

**Or watch in the terminal:**
```powershell
# See pod status
kubectl -n converged-demo get pods -w

# See ingress (ALB) endpoint
kubectl -n converged-demo get ingress -w
```

### 4. Access your app

Once the ALB is ready (1–2 min after deployment):

```powershell
kubectl -n converged-demo get ingress converged-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Open in browser:
```
http://[ALB-DNS]/login
```

Login with demo user (e.g. `alice.chen@shopfast.io`, password: `demo`)

---

## Workflow diagram

```
Your laptop
   ↓
Edit code + run push-to-github.ps1
   ↓
GitHub (code + secrets)
   ↓
GitHub Actions
   ├→ Build (Maven)
   ├→ Build Docker images
   ├→ Push to Docker Hub (using DOCKER_HUB_* secrets)
   └→ Deploy to EKS (using AWS_* secrets)
   ↓
EKS Cluster
   ↓
ALB (public)
   ↓
Your users access: http://[ALB-DNS]
```

---

## Common tasks

### Pull latest from GitHub (after a teammate pushed)
```powershell
git pull origin main
```

### View logs of a pod
```powershell
kubectl -n converged-demo logs -f deployment/storefront
```

### SSH into a running pod (for debugging)
```powershell
kubectl -n converged-demo exec -it deploy/storefront -- /bin/sh
```

### Roll back to previous deployment
```powershell
kubectl -n converged-demo rollout undo deployment/storefront
```

### Scale pods up/down manually
```powershell
kubectl -n converged-demo scale deployment storefront --replicas=3
```

### View Docker images on Docker Hub
```
https://hub.docker.com/repositories/YOUR_USERNAME
```

---

## Security checklist

✓ **No credentials in GitHub:**
  - Local setup script stores them locally only
  - GitHub secrets are masked in logs
  - Docker credentials in `~/.docker/config.json` (git-ignored)
  - AWS credentials in `~/.aws/credentials` (git-ignored)

✓ **Git is configured correctly:**
  ```powershell
  git config --global user.name "Your Name"
  git config --global user.email "your@email.com"
  git config --global credential.helper manager-core
  ```

✓ **GitHub secrets are added:**
  - Settings → Secrets and variables → Actions
  - 6 secrets: `DOCKER_HUB_*`, `AWS_*`, `EKS_*`

✓ **.gitignore is protecting secrets:**
  ```
  .env
  ~/.docker/config.json
  ~/.aws/credentials
  ```

---

## Costs (daily)

| Service | Cost/day | Notes |
|---|---|---|
| GitHub Actions | $0 | Free tier (2000 min/month) |
| Docker Hub push | $0 | Free for public images |
| Docker Hub → EKS | $0 | Inbound to AWS is free |
| EKS nodes | ~$1 | 3 × t3.medium |
| ALB | $0.50 | Load balancer |
| **Total** | **~$1.50/day** | Pause nodes to save 80% |

---

## Pause/resume the cluster (save $35/month)

When you're not demoing:
```powershell
# Pause (scale nodes to 0)
aws eks update-nodegroup-config --cluster-name converged-demo --nodegroup-name default --scaling-config minSize=0,maxSize=3,desiredSize=0 --region us-east-1

# Resume (scale back up)
aws eks update-nodegroup-config --cluster-name converged-demo --nodegroup-name default --scaling-config minSize=1,maxSize=3,desiredSize=3 --region us-east-1
```

---

## Troubleshooting

**"local-setup.ps1: command not found"**
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\local-setup.ps1
```

**"Push to GitHub fails - 'Repository not found'"**
```powershell
gh auth logout
.\local-setup.ps1  # re-authenticate
```

**"Docker images failed to push"**
- Check Docker Hub credentials are correct
- Verify your Docker Hub username matches the secret

**"EKS deploy fails - 'ImagePullBackOff'"**
- Verify images were pushed to Docker Hub
- Check pod logs: `kubectl -n converged-demo logs deploy/storefront`

**"ALB not getting an IP (stuck in pending)"**
- Wait 2–3 min, ALBs take time to provision
- Check: `kubectl -n converged-demo get ingress -o yaml`

---

## Next steps

1. ✓ Run `.\local-setup.ps1` (one time)
2. ✓ Add GitHub secrets (one time)
3. ✓ Edit code locally
4. ✓ Run `.\push-to-github.ps1 -Message "Your message"`
5. ✓ GitHub Actions builds and deploys automatically
6. ✓ Access your app at the ALB endpoint

**That's it.** Zero manual kubectl, no SSH to pods, no credentials in GitHub.

---

## Questions?

Ask Claude to help with any local edits:

```
"Help me change the login page greeting from 'Sign in' to 'Welcome back'. 
Which file? What's the exact change?"
```

Claude will guide you to the file and the exact edit. You make it, push with `push-to-github.ps1`, and GitHub Actions handles the rest.

