# AWS Setup — Quick Summary

## What you need to do (in order)

### Phase 1: AWS Account Setup (15 min)
```
☐ Create AWS Account at https://aws.amazon.com
☐ Create IAM user "eks-admin" with AdministratorAccess
☐ Create Access Keys for eks-admin (save the Access Key ID & Secret Key)
☐ Save the AWS Account ID (from console top right)
```

### Phase 2: AWS CLI Configuration (5 min)
```
☐ Install AWS CLI: winget install Amazon.AWSCLI
☐ Run: aws configure
  - Access Key ID: [from Phase 1]
  - Secret Access Key: [from Phase 1]
  - Region: us-east-1
  - Output: json
☐ Verify: aws sts get-caller-identity
```

### Phase 3: AWS Networking & Roles (10 min)
```
☐ Create default VPC: aws ec2 create-default-vpc
☐ Get subnet IDs (save them)
☐ Create EKS Service Role (copy the ARN)
☐ Create EKS Node Role (copy the ARN)
```

### Phase 4: Create EKS Cluster (20 min — runs in background)
```
☐ Create EKS cluster: aws eks create-cluster ... (runs in background)
☐ While that's creating, create node group: aws eks create-nodegroup ...
☐ Wait for cluster status = ACTIVE (check every 2 min)
☐ Wait for node group status = ACTIVE
```

### Phase 5: Configure kubectl (2 min)
```
☐ Update kubeconfig: aws eks update-kubeconfig --name converged-demo --region us-east-1
☐ Verify: kubectl get nodes (should show 1 node)
```

### Phase 6: Install AWS Load Balancer Controller (3 min)
```
☐ Install Helm: winget install Helm.Helm
☐ Add Helm repo: helm repo add eks https://aws.github.io/eks-charts
☐ Install controller: helm install aws-load-balancer-controller ...
```

### Phase 7: GitHub OIDC Provider (2 min, optional for CI/CD)
```
☐ Go to AWS Console → IAM → Identity providers
☐ Add OpenID Connect provider: https://token.actions.githubusercontent.com
☐ Audience: sts.amazonaws.com
```

---

## What you have after Phase 1-7

```
✓ AWS Account with IAM user
✓ AWS CLI configured on your laptop
✓ 1-node EKS cluster running in AWS
✓ kubectl connected and working
✓ ALB Controller ready to expose apps
✓ GitHub can deploy via OIDC (no stored keys)
```

**Total cost:** ~$105/month (can pause to save 80%)

---

## Then: Local Setup (5 min)

```powershell
cd C:\WorkItems\projects\RUMBTM\converged-demo
.\local-setup.ps1
```

This prompts for:
- Docker Hub username & PAT
- Confirms AWS is configured
- Connects kubectl

**Everything stays local. No secrets in GitHub.**

---

## Then: Add GitHub Secrets (2 min)

Go to repo **Settings → Secrets and variables → Actions** and add:

```
AWS_ACCESS_KEY_ID: [from Phase 1]
AWS_SECRET_ACCESS_KEY: [from Phase 1]
AWS_REGION: us-east-1
EKS_CLUSTER_NAME: converged-demo
DOCKER_HUB_USERNAME: [your Docker Hub username]
DOCKER_HUB_PAT: [your Docker Hub token]
```

---

## Then: Deploy (1 command)

```powershell
.\push-to-github.ps1 -Message "First deploy"
```

GitHub Actions:
- Builds Maven project
- Builds 3 Docker images
- Pushes to Docker Hub
- Deploys to EKS
- Creates ALB (public endpoint)

Takes ~10 min.

---

## Then: Access your app

```powershell
kubectl -n converged-demo get ingress converged-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Opens: `http://[ALB-DNS]/login`

Login: `alice.chen@shopfast.io` (password: `demo`)

---

## The three commands you'll use daily

```powershell
# 1. Edit code locally, then push
.\push-to-github.ps1 -Message "Your change here"

# 2. Check deployment status
kubectl -n converged-demo get pods

# 3. Get app URL
kubectl -n converged-demo get ingress converged-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## Full guide

See `AWS-SETUP-COMPLETE.md` for detailed step-by-step with all commands.

