# Complete AWS Setup Guide — From Zero to EKS

**Total time: ~30 min setup + ~15 min for EKS cluster to create**

This guide walks you through:
1. AWS Account setup (if new)
2. IAM user & access keys
3. VPC & networking
4. EKS cluster creation
5. Node group setup
6. Verification

---

## What you need

- [ ] AWS Account (sign up at https://aws.amazon.com if you don't have one)
- [ ] AWS CLI v2 installed locally
- [ ] kubectl installed locally
- [ ] Helm installed locally
- [ ] ~$30/month budget (or use free tier if eligible)

---

## Part 1: AWS Account & IAM Setup (5 min)

### 1.1 Create AWS Account (if new)

1. Go to https://aws.amazon.com
2. Click **"Create an AWS Account"**
3. Enter email, password, AWS account name
4. Add payment method (credit card)
5. Verify email + phone
6. Choose support plan: **"Basic (Free)"**

### 1.2 Create an IAM User for EKS

**Why:** Don't use your root account for day-to-day work. Create an IAM user instead.

1. **Sign in to AWS Console** with root account
2. Go to **Services → IAM** (search for "IAM")
3. Click **"Users"** in the left menu
4. Click **"Create user"**
5. **User details:**
   - User name: `eks-admin`
   - Check: ✅ **"Provide user access to AWS Management Console"**
   - Console password: Custom password (save it)
6. Click **"Next"**
7. **Set permissions:**
   - Click **"Attach policies directly"**
   - Search for: `AdministratorAccess`
   - Check: ✅ **AdministratorAccess**
   - Click **"Next" → "Create user"**
8. **Save the sign-in details** (you'll get a URL like `https://123456789012.signin.aws.amazon.com/console`)

### 1.3 Create Access Keys

1. Go to **IAM → Users → eks-admin**
2. Click the **"Security credentials"** tab
3. Scroll to **"Access keys"**
4. Click **"Create access key"**
5. Select: **"Command Line Interface (CLI)"**
6. Check: ✅ **"I understand..."**
7. Click **"Create access key"**
8. **IMPORTANT:** Copy and save:
   - Access Key ID
   - Secret Access Key
   - (This is your only chance to see the secret key!)

---

## Part 2: Install AWS CLI & Configure (5 min)

### 2.1 Install AWS CLI v2

```powershell
winget install Amazon.AWSCLI
```

Verify:
```powershell
aws --version
```

### 2.2 Configure AWS CLI

```powershell
aws configure
```

When prompted, enter:
```
AWS Access Key ID: [paste your Access Key ID]
AWS Secret Access Key: [paste your Secret Access Key]
Default region name: us-east-1
Default output format: json
```

Verify:
```powershell
aws sts get-caller-identity
```

Should output your account ID, user ARN, etc.

---

## Part 3: VPC & Networking Setup (2 min)

### 3.1 Create or use default VPC

EKS needs a VPC with public and private subnets.

**Option A: Use the default VPC (easiest)**
```powershell
aws ec2 describe-vpcs --filters Name=isDefault,Values=true
```

If output shows a VPC, you're good. If not, create one:
```powershell
aws ec2 create-default-vpc
```

**Option B: Create a custom VPC (advanced)**

Skip this unless you know what you're doing. The default VPC works fine.

### 3.2 Get Subnet IDs

```powershell
aws ec2 describe-subnets --filters Name=vpc-id,Values=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text) --query 'Subnets[].SubnetId' --output text
```

**Copy the subnet IDs** (e.g., `subnet-12345678 subnet-87654321`)

---

## Part 4: Create IAM Roles for EKS (3 min)

EKS needs two IAM roles: one for the cluster, one for the nodes.

### 4.1 Create EKS Service Role

```powershell
# Create the trust policy document
@"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@ | Out-File -FilePath eks-trust-policy.json -Encoding UTF8

# Create the role
aws iam create-role `
  --role-name eks-service-role `
  --assume-role-policy-document file://eks-trust-policy.json

# Attach the policy
aws iam attach-role-policy `
  --role-name eks-service-role `
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSServiceRolePolicy
```

**Save the Role ARN:**
```powershell
aws iam get-role --role-name eks-service-role --query 'Role.Arn' --output text
```

Copy the output (e.g., `arn:aws:iam::123456789012:role/eks-service-role`)

### 4.2 Create EKS Node Role

```powershell
# Create the trust policy document for nodes
@"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@ | Out-File -FilePath node-trust-policy.json -Encoding UTF8

# Create the role
aws iam create-role `
  --role-name eks-node-role `
  --assume-role-policy-document file://node-trust-policy.json

# Attach required policies
aws iam attach-role-policy `
  --role-name eks-node-role `
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

aws iam attach-role-policy `
  --role-name eks-node-role `
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam attach-role-policy `
  --role-name eks-node-role `
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

aws iam attach-role-policy `
  --role-name eks-node-role `
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```

**Save the Node Role ARN:**
```powershell
aws iam get-role --role-name eks-node-role --query 'Role.Arn' --output text
```

Copy the output (e.g., `arn:aws:iam::123456789012:role/eks-node-role`)

---

## Part 5: Create EKS Cluster (15 min)

### 5.1 Create the cluster

```powershell
# Set variables
$CLUSTER_NAME = "converged-demo"
$REGION = "us-east-1"
$SERVICE_ROLE_ARN = "arn:aws:iam::YOUR_ACCOUNT_ID:role/eks-service-role"
$SUBNET_IDS = "subnet-xxx,subnet-yyy"  # from Part 3.2

# Create cluster
aws eks create-cluster `
  --name $CLUSTER_NAME `
  --version 1.27 `
  --role-arn $SERVICE_ROLE_ARN `
  --resources-vpc-config subnetIds=$SUBNET_IDS `
  --region $REGION
```

**This runs in the background (15 min).** Monitor progress:

```powershell
# Check status (repeat until ACTIVE)
aws eks describe-cluster --name converged-demo --region us-east-1 --query 'cluster.status'
```

When it shows `ACTIVE`, the cluster is ready.

### 5.2 Create Node Group (while cluster is creating)

```powershell
$CLUSTER_NAME = "converged-demo"
$REGION = "us-east-1"
$NODE_ROLE_ARN = "arn:aws:iam::YOUR_ACCOUNT_ID:role/eks-node-role"
$SUBNET_IDS = "subnet-xxx,subnet-yyy"

aws eks create-nodegroup `
  --cluster-name $CLUSTER_NAME `
  --nodegroup-name default `
  --scaling-config minSize=1,maxSize=2,desiredSize=1 `
  --subnets $SUBNET_IDS `
  --node-role $NODE_ROLE_ARN `
  --region $REGION
```

Monitor progress:
```powershell
aws eks describe-nodegroup --cluster-name converged-demo --nodegroup-name default --region us-east-1 --query 'nodegroup.status'
```

Wait until status is `ACTIVE`.

---

## Part 6: Connect kubectl to EKS (2 min)

### 6.1 Update kubeconfig

```powershell
aws eks update-kubeconfig --name converged-demo --region us-east-1
```

### 6.2 Verify connection

```powershell
kubectl cluster-info
kubectl get nodes
```

Should show your cluster and 1 node.

---

## Part 7: Install AWS Load Balancer Controller (3 min)

This is needed for the ALB Ingress that exposes your app publicly.

### 7.1 Add Helm repository

```powershell
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

### 7.2 Install the controller

```powershell
helm install aws-load-balancer-controller eks/aws-load-balancer-controller `
  -n kube-system `
  --set clusterName=converged-demo
```

Verify:
```powershell
kubectl get deployment -n kube-system aws-load-balancer-controller
```

Should show 2 replicas running.

---

## Part 8: Create GitHub OIDC Provider (optional, for CI/CD)

This lets GitHub Actions deploy to EKS without storing AWS keys.

### 8.1 Get the OIDC provider thumbprint

```powershell
$THUMBPRINT = @(
  (New-Object Net.ServicePointManager).ServerCertificateValidationCallback = { $true }
  [System.Security.Cryptography.X509Certificates.X509Certificate2] $cert = `
    [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromCertFile("https://token.actions.githubusercontent.com/.well-known/jwks.json")
  $cert.Thumbprint
)
echo $THUMBPRINT
```

### 8.2 Create OIDC provider in AWS

Go to **AWS Console → IAM → Identity providers**

- Provider type: **OpenID Connect**
- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- Thumbprint: (paste from 8.1, or AWS can auto-fetch)

Click **"Add provider"**

---

## Checklist: You're done when you have

- [ ] AWS Account created
- [ ] IAM user `eks-admin` with Access Key & Secret Key
- [ ] AWS CLI configured locally
- [ ] Default VPC with subnets
- [ ] EKS Service Role ARN
- [ ] EKS Node Role ARN
- [ ] EKS Cluster `converged-demo` in `ACTIVE` state
- [ ] Node group `default` in `ACTIVE` state with 1 node
- [ ] `kubectl get nodes` shows your node
- [ ] AWS Load Balancer Controller installed in kube-system
- [ ] GitHub OIDC provider created (optional, for CI/CD)

---

## What to do next

1. **Save these ARNs and IDs:**
   - AWS Account ID
   - EKS Service Role ARN
   - EKS Node Role ARN
   - Subnet IDs

2. **On your laptop, run:**
   ```powershell
   cd C:\WorkItems\projects\RUMBTM\converged-demo
   .\local-setup.ps1
   ```

3. **Add GitHub secrets** (Settings → Secrets and variables → Actions):
   ```
   AWS_ACCESS_KEY_ID: [from Part 1.3]
   AWS_SECRET_ACCESS_KEY: [from Part 1.3]
   AWS_REGION: us-east-1
   EKS_CLUSTER_NAME: converged-demo
   DOCKER_HUB_USERNAME: [your Docker Hub username]
   DOCKER_HUB_PAT: [your Docker Hub token]
   ```

4. **Push to GitHub & GitHub Actions will deploy:**
   ```powershell
   .\push-to-github.ps1 -Message "Initial deploy"
   ```

---

## Cost estimate

| Item | Monthly |
|---|---|
| EKS control plane | $72 |
| 1 × t3.small EC2 node | $15 |
| ALB | $16 |
| Data | $2–5 |
| **Total** | **~$105/month** |

**Pause to save 80%:** Just keep control plane ($72/month) when not using.

---

## Troubleshooting

**"EKS cluster stuck in CREATING"**
- Wait 15 min. Some AWS operations take time.
- Check: `aws eks describe-cluster --name converged-demo --region us-east-1`

**"kubectl: Unable to connect to the server"**
- Verify kubeconfig: `aws eks update-kubeconfig --name converged-demo --region us-east-1`
- Check IAM user has permissions

**"Nodes not joining the cluster"**
- Check node role ARN is correct
- Verify subnets are in the same VPC as the cluster
- Wait 5 min for nodes to initialize

**"LoadBalancer Controller not running"**
- Check: `kubectl get deployment -n kube-system aws-load-balancer-controller`
- Verify RBAC permissions are correct

---

## Next: Local setup

Once AWS is ready, run:
```powershell
.\local-setup.ps1
```

This configures your laptop for GitHub, Docker Hub, and AWS. Then:
```powershell
.\push-to-github.ps1 -Message "First deploy"
```

GitHub Actions takes it from there. ✅

