# Production Cloud-Native Platform on AWS

A production-grade DevOps platform built on AWS, demonstrating end-to-end infrastructure automation, container orchestration, CI/CD pipelines, and full-stack observability.

**Live URLs:**
- API: https://rashel-mia.site
- Grafana: https://grafana.rashel-mia.site (admin / GrafanaAdmin123)

---

## Architecture

```
GitHub Push
     │
     ▼
GitHub Actions (CI/CD)
     │  test → build → push to ECR → rolling deploy to EKS
     ▼
Amazon ECR (container registry)
     │
     ▼
Amazon EKS Cluster (us-east-1, private subnets)
     │
  ┌──┴──────────────────────────────────┐
  │  Pod: Node.js App  │  Pod: Python App │
  │  (Express / :3000) │  (FastAPI / :8000)│
  └──┬──────────────────────────────────┘
     │
     ▼
Application Load Balancer (HTTPS + HTTP→HTTPS redirect)
     │
     ▼
Route 53 → rashel-mia.site

Monitoring: EKS → Prometheus → Grafana (grafana.rashel-mia.site)
Secrets:    AWS Secrets Manager → CSI Driver → Pod environment
Database:   Amazon RDS PostgreSQL (private subnet)
```

---

## Tech Stack

| Category | Technology |
|---|---|
| Cloud | AWS (EKS, RDS, ECR, ACM, ALB, Route 53, Secrets Manager) |
| Infrastructure as Code | Terraform |
| Container Orchestration | Kubernetes (EKS 1.29) |
| CI/CD | GitHub Actions with OIDC (no static credentials) |
| Containers | Docker (multi-stage builds) |
| Monitoring | Prometheus + Grafana (kube-prometheus-stack) |
| Secret Management | AWS Secrets Manager + CSI Secrets Store Driver |
| Autoscaling | Horizontal Pod Autoscaler (HPA) |
| DNS & TLS | Route 53 + ACM (HTTPS) |

---

## Project Structure

```
.
├── terraform/
│   ├── main.tf                    # Root module
│   ├── variables.tf
│   ├── outputs.tf
│   ├── modules/
│   │   ├── vpc/                   # VPC, subnets, NAT gateway
│   │   ├── eks/                   # EKS cluster + node groups
│   │   ├── rds/                   # PostgreSQL database
│   │   ├── ecr/                   # Container registries
│   │   └── acm/                   # SSL certificate
│   └── environments/
│       ├── dev/
│       └── prod/
├── kubernetes/
│   ├── namespace.yaml
│   ├── nodejs-deployment.yaml
│   ├── nodejs-service.yaml
│   ├── python-deployment.yaml
│   ├── python-service.yaml
│   ├── ingress.yaml               # ALB ingress with HTTPS
│   ├── grafana-ingress.yaml
│   ├── hpa.yaml                   # Horizontal Pod Autoscaler
│   ├── network-policies.yaml
│   ├── secret-provider.yaml       # CSI secrets store
│   └── servicemonitor.yaml        # Prometheus scraping
├── services/
│   ├── nodejs-app/                # Express.js API with Prometheus metrics
│   └── python-app/                # FastAPI with Prometheus metrics
└── .github/
    └── workflows/
        ├── rollback.yaml
        ├── deploy-nodejs.yaml
        └── deploy-python.yaml

```

---

## Features

**Infrastructure as Code**
- All AWS resources provisioned with Terraform using modular structure
- Remote state stored in S3 with DynamoDB locking
- Separate environments (dev/prod) with shared modules

**Kubernetes**
- Two microservices (Node.js + Python) deployed to EKS
- Horizontal Pod Autoscaler (2–20 replicas based on CPU)
- Network policies for zero-trust pod-to-pod communication
- Liveness and readiness probes on all pods

**CI/CD Pipeline**
- GitHub Actions workflows triggered on push to `main`
- OIDC authentication — no AWS access keys stored in GitHub
- Pipeline stages: Test → Build → Push to ECR → Deploy to EKS → Smoke test
- Manual approval gate before production deploy

**Security**
- No static AWS credentials anywhere — OIDC for GitHub Actions
- Secrets injected via AWS Secrets Manager + CSI driver (never in YAML)
- HTTPS enforced with HTTP → HTTPS redirect
- EKS nodes in private subnets, only ALB is public

**Observability**
- Prometheus scrapes both services every 15 seconds
- Grafana dashboards: Node Exporter Full, Kubernetes Pods, custom app metrics
- Custom metrics: `http_requests_total`, `http_request_duration_seconds`

---

## Deploy from Scratch

### Prerequisites

```bash
aws --version        # AWS CLI v2
terraform --version  # >= 1.6
kubectl version      # >= 1.28
helm version         # >= 3.0
eksctl version       # >= 0.180
docker --version
```

### Step 1 — Bootstrap Terraform state (one time only)

```bash
aws s3api create-bucket --bucket devops-tfstate-<suffix> --region us-east-1
aws s3api put-bucket-versioning \
  --bucket devops-tfstate-<suffix> \
  --versioning-configuration Status=Enabled
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Step 2 — Deploy infrastructure

```bash
cd terraform
terraform init -backend-config=environments/dev/backend.tf
terraform apply -var-file=environments/dev/terraform.tfvars
```

This creates: VPC, EKS cluster, RDS PostgreSQL, ECR repositories, ACM certificate.

### Step 3 — Connect kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name devops-dev
kubectl get nodes
```

### Step 4 — Install cluster add-ons

```bash
# ALB Controller
eksctl create iamserviceaccount \
  --cluster devops-dev --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve --region us-east-1

helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=devops-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# CSI Secrets Driver
helm repo add secrets-store-csi-driver \
  https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system --set syncSecret.enabled=true
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml

# Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prom prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.service.type=ClusterIP \
  --set grafana.adminPassword=GrafanaAdmin123 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

### Step 5 — Deploy Kubernetes resources

```bash
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/secret-provider.yaml
kubectl apply -f kubernetes/nodejs-deployment.yaml
kubectl apply -f kubernetes/nodejs-service.yaml
kubectl apply -f kubernetes/python-deployment.yaml
kubectl apply -f kubernetes/python-service.yaml
kubectl apply -f kubernetes/ingress.yaml
kubectl apply -f kubernetes/grafana-ingress.yaml
kubectl apply -f kubernetes/hpa.yaml
kubectl apply -f kubernetes/network-policies.yaml
kubectl apply -f kubernetes/servicemonitor.yaml
```

### Step 6 — Push Docker images

```bash
ECR="<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com"
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR

docker build -t $ECR/devops-platform/nodejs-app:latest services/nodejs-app
docker push $ECR/devops-platform/nodejs-app:latest

docker build -t $ECR/devops-platform/python-app:latest services/python-app
docker push $ECR/devops-platform/python-app:latest
```

### Step 7 — Set up GitHub Actions

In GitHub → Settings → Environments → create `staging` and `production`, add these variables:

| Variable | Value |
|---|---|
| `AWS_ROLE_ARN` | arn:aws:iam::\<ACCOUNT_ID\>:role/devops-platform-dev-github-actions |
| `AWS_REGION` | us-east-1 |
| `EKS_CLUSTER_NAME` | devops-dev |

---

## API Endpoints

```bash
# Health check
curl https://rashel-mia.site/health
# {"status":"ok","service":"nodejs-app","version":"1.0.1"}

# Node.js CRUD
curl https://rashel-mia.site/api/items
curl -X POST https://rashel-mia.site/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"test","value":"123"}'

# Python stats
curl https://rashel-mia.site/api/stats
```

---

## Cleanup

```bash
# Remove Helm releases first (they own AWS resources like ALBs)
helm uninstall aws-load-balancer-controller -n kube-system
helm uninstall kube-prom -n monitoring

# Delete namespaces
kubectl delete namespace app monitoring

# Destroy all infrastructure
cd terraform
terraform destroy -var-file=environments/dev/terraform.tfvars
```

---

## Author

**Muhammad Rashel Mia**
- GitHub: [@mia-rashel](https://github.com/mia-rashel)
- LinkedIn: [Muhammad Rashel Mia](https://linkedin.com/in/muhammad-mia)
