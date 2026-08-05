# Deploy to AWS EKS from GitHub

Complete guide to deploy the Converged Demo app to AWS EKS, accessible from the internet.

## Architecture

```
Your GitHub repo
       ↓
GitHub Actions (build Docker images)
       ↓
AWS ECR (container registry)
       ↓
AWS EKS (Kubernetes cluster)
       ↓
AWS ALB (Application Load Balancer — public endpoint)
       ↓
Your users access: http://[ALB-DNS-name]
```

---

## Prerequisites

On your machine, install:

```powershell
# AWS CLI v2
winget install Amazon.AWSCLI

# kubectl
winget install Kubernetes.kubectl

# helm
winget install Helm.Helm

# AWS IAM Authenticator (for kubeconfig)
winget install Amazon.AWSIAMCLI
```

Verify:
```powershell
aws --version
kubectl version --client
helm version
```

And configure AWS credentials:
```powershell
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region (e.g. us-east-1)
```

---

## Step 1: Run the AWS setup script

From the `converged-demo` folder:

```powershell
.\aws-setup.ps1 -AwsRegion us-east-1 -ClusterName converged-demo -NodeCount 3
```

This script:
- ✓ Creates 3 ECR repositories (storefront, order-service, notification-worker)
- ✓ Creates an EKS cluster with 3 worker nodes (~15 min, runs in the background)
- ✓ Installs the AWS Load Balancer Controller for ALB/Ingress
- ✓ Creates an IAM role for GitHub Actions to push images

**First time?** The cluster creation runs in the background. Check progress:
```powershell
aws eks describe-cluster --name converged-demo --region us-east-1 --query 'cluster.status'
# Wait until status is ACTIVE
```

---

## Step 2: Set up GitHub OIDC (one-time)

GitHub Actions uses OpenID Connect (OIDC) to authenticate with AWS without storing access keys. The `aws-setup.ps1` script trusts GitHub, but you need to add the OIDC provider to your AWS account.

### In AWS Console:

1. Go to **IAM → Identity providers**
2. Click **Add provider**
3. Select **OpenID Connect**
4. Provider URL: `https://token.actions.githubusercontent.com`
5. Audience: `sts.amazonaws.com`
6. Click **Get thumbprint** → **Add provider**

(The `aws-setup.ps1` script handles the role trust policy automatically.)

---

## Step 3: Add GitHub Secrets

Go to your GitHub repo **Settings → Secrets and variables → Actions**. Add:

```
AWS_REGION: us-east-1          (or your chosen region)
AWS_ACCOUNT_ID: 123456789012   (your AWS account ID, from aws sts get-caller-identity)
EKS_CLUSTER_NAME: converged-demo
```

Get your Account ID:
```powershell
aws sts get-caller-identity --query Account --output text
```

---

## Step 4: Push to GitHub

All the code is already in your repo. Push to trigger GitHub Actions:

```powershell
cd C:\WorkItems\projects\RUMBTM\converged-demo
git add .
git commit -m "Add AWS EKS deployment"
git push origin main
```

GitHub Actions will automatically:
1. Build the 3 Docker images
2. Push them to AWS ECR
3. Deploy to your EKS cluster
4. Create an AWS ALB and Ingress

---

## Step 5: Monitor the deployment

### In GitHub:
Go to **Actions** tab and watch the workflow run. It takes ~5–10 min.

### In AWS Console:
- **ECS → Clusters → converged-demo** — see the nodes
- **EC2 → Load Balancers** — watch the ALB provision (takes 1–2 min after deployment completes)

### From your terminal:
```powershell
# Check pod status
kubectl -n converged-demo get pods

# Watch in real time
kubectl -n converged-demo get pods -w

# See services
kubectl -n converged-demo get svc

# See ingress (ALB)
kubectl -n converged-demo get ingress
```

---

## Step 6: Get the public URL

Once the ALB is provisioned, get the endpoint:

```powershell
kubectl -n converged-demo get ingress converged-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Output: `converged-demo-1234567890.us-east-1.elb.amazonaws.com`

Open in your browser:
```
http://converged-demo-1234567890.us-east-1.elb.amazonaws.com/
```

You'll be redirected to `/login` (authentication required).

---

## Accessing the app

### Login page
```
http://[ALB-DNS]/login
```

Demo users (any password):
- `alice.chen@shopfast.io`
- `marcus.lee@shopfast.io`
- `priya.sharma@shopfast.io`
- etc. (see `rum-load/generate.js`)

### Artemis console (queue backlog)
```powershell
kubectl -n converged-demo port-forward svc/artemis 8161:8161
# Then open: http://localhost:8161  (admin/admin)
```

### MySQL (database)
```powershell
kubectl -n converged-demo port-forward svc/mysql 3306:3306
# Then connect with: mysql -h 127.0.0.1 -u shop -pshoppass shopdb
```

---

## Cost estimate (AWS)

**EKS** (control plane): ~$0.10/hour ($72/month)
**EC2 nodes** (3×t3.medium): ~$0.10/hour each ($216/month)
**Data transfer**: ~$0.10 per GB (varies)
**Load Balancer**: ~$16/month

**Total: ~$300–400/month for 3 nodes.** Scale down or delete when not in use.

Delete the cluster when done:
```powershell
aws eks delete-cluster --name converged-demo --region us-east-1
aws ec2 describe-instances --filters "Name=tag:kubernetes.io/cluster/converged-demo,Values=owned" --query 'Reservations[*].Instances[*].InstanceId' --output text | xargs aws ec2 terminate-instances --instance-ids
```

---

## Troubleshooting

**"ALB not provisioning" (Ingress stuck in pending)**
```powershell
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```
If the controller isn't running, re-run: `helm upgrade --install aws-load-balancer-controller...` (from the setup script).

**"ImagePullBackOff" on pods**
ECR images are private. Ensure the EKS nodes have IAM permissions to pull from ECR. (The `aws-setup.ps1` script configures this.)

**"Pods can't reach each other"**
Check the security group of the EKS node group allows internal traffic (port 443, 53, etc.). Managed node groups usually have this pre-configured.

**"Connection refused" when trying to access the ALB**
- Wait 2–3 min for the ALB to become healthy (health checks take time).
- Check: `kubectl -n converged-demo get ingress -o yaml` for the ALB status.
- Check ALB health in AWS Console: **EC2 → Load Balancers → Target Groups → Health checks**.

**GitHub Actions fails to authenticate with AWS**
- Verify the OIDC provider exists in **IAM → Identity providers**.
- Verify the role trust policy includes your GitHub repo (check `aws-setup.ps1` output).
- Verify secrets are correct: `aws sts get-caller-identity` as a test.

---

## Next: Enable HTTPS (optional)

To add an SSL certificate and use HTTPS:

1. Buy a domain or get a free one (Route53, namecheap, etc.)
2. Request a certificate in **AWS Certificate Manager**
3. Update the Ingress to use the certificate and HTTP→HTTPS redirect
4. Update DNS to point to the ALB

See: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/

---

## Summary

| Step | Time | Action |
|---|---|---|
| 1 | 5 min | Run `aws-setup.ps1` |
| 2 | 15 min | Wait for EKS cluster (in background) |
| 3 | 2 min | Add OIDC provider to AWS |
| 4 | 2 min | Add GitHub secrets |
| 5 | 1 min | Push to GitHub |
| 6 | 5–10 min | GitHub Actions builds + deploys |
| 7 | 2 min | Wait for ALB to provision |
| 8 | 1 min | Get the ALB DNS name |
| **Total** | **~40 min** | **App is live and public** |

---

## Cost control

**Pause the cluster (keep the infra, save money):**
```powershell
aws eks update-nodegroup-config --cluster-name converged-demo --nodegroup-name default --scaling-config minSize=0,maxSize=3,desiredSize=0 --region us-east-1
```

**Resume:**
```powershell
aws eks update-nodegroup-config --cluster-name converged-demo --nodegroup-name default --scaling-config minSize=1,maxSize=3,desiredSize=3 --region us-east-1
```

**Delete everything (most cost-effective):**
```powershell
aws eks delete-cluster --name converged-demo --region us-east-1
# (Also delete ECR repos, Load Balancer, etc. from AWS Console)
```
