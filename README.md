# s3-objects-viewer-eks-deployment
A production-style DevOps project that provisions a complete AWS EKS cluster using Terraform and deploys a containerized S3 browser application. The app runs as a Python Flask service inside Kubernetes, uses IRSA for pod-level AWS credentials, and is exposed publicly via an AWS Network Load Balancer.

---

## What It Does

The S3 Explorer is a web application that lets you browse your AWS S3 buckets directly from a browser — navigating into folders, viewing objects, and opening files via presigned URLs — all served from inside a Kubernetes pod with no hardcoded credentials anywhere.

---
live pics
<img width="1364" height="627" alt="Screenshot from 2026-06-20 01-30-52" src="https://github.com/user-attachments/assets/a19983d8-8af3-4cf6-bbc5-821e15b894a3" />

<img width="1364" height="627" alt="Screenshot from 2026-06-20 01-30-39" src="https://github.com/user-attachments/assets/5f4e858e-6463-478e-a805-d93ca11246f1" />

## Architecture

```
User
  │
  ▼ (public internet)
Internet Gateway
  │
  ▼
Network Load Balancer  (public subnet)
  │
  ▼
Flask Pod  (private subnet)
  │  IRSA — pod assumes IAM role via OIDC token
  ├──► S3 API (via VPC Gateway Endpoint — never leaves AWS)
  └──► Returns bucket/object data to browser
```

---

## Infrastructure (Terraform)
<img width="641" height="319" alt="WhatsApp Image 2026-06-13 at 2 15 29 PM" src="https://github.com/user-attachments/assets/81164b30-d158-4bdc-8f38-73e1576b383e" />


Everything is provisioned with Terraform:

**Networking**
- VPC with public and private subnets across two Availability Zones
- Internet Gateway for public subnets
- NAT Gateway per AZ for private subnet outbound traffic
- VPC Gateway Endpoint for S3 — pod-to-S3 traffic never hits the public internet
- Route tables and subnet tags for EKS and Load Balancer discovery

**Compute**
- EKS cluster (Kubernetes 1.30) with authentication mode set to `API`
- Managed Node Group (t3.small, on-demand) in private subnets
- EKS managed add-ons: VPC CNI, CoreDNS, kube-proxy, EBS CSI Driver

**IAM**
- Cluster IAM Role — allows EKS to manage VPC resources
- Node IAM Role — allows nodes to join the cluster, pull from ECR, manage pod networking
- OIDC Provider — enables IRSA (pod-level IAM credentials)
- IRSA Role for the S3 Explorer pod (scoped to `s3:ListAllMyBuckets`, `s3:ListBucket`, `s3:GetObject`)
- IRSA Role for AWS Load Balancer Controller

**Load Balancing**
- AWS Load Balancer Controller installed via Helm
- NLB created automatically from a Kubernetes Service manifest

**Storage**
- S3 bucket with server-side encryption, public access blocked, and versioning enabled

---

## Application

The S3 Explorer is a Python Flask app containerized with Docker and deployed on EKS.

**Features**
- Browse all S3 buckets in the AWS account
- Navigate into folders (S3 prefixes) with breadcrumb navigation
- Filter objects by name
- Open any file in a new tab via a presigned URL (1-hour expiry)
- Auto-refresh every 30 seconds — detects new objects and highlights them
- Manual refresh button with live countdown

**How credentials work**

The pod never has hardcoded AWS credentials. Instead:

1. Kubernetes injects a short-lived JWT token into the pod at `/var/run/secrets/eks.amazonaws.com/serviceaccount/token`
2. The AWS SDK finds this token automatically
3. It calls `sts:AssumeRoleWithWebIdentity` to exchange the token for temporary IAM credentials
4. STS validates the token against the cluster's OIDC provider and checks that the token's `sub` claim matches the trusted service account
5. Temporary credentials are issued — scoped only to S3 list/read operations

---

## Project Structure

```
.
├── terraform/
│   ├── versions.tf          # provider versions and terraform block
│   ├── providers.tf         # AWS, Kubernetes, Helm, TLS providers
│   ├── variables.tf         # input variables
│   ├── locals.tf            # computed values and common tags
│   ├── vpc.tf               # VPC, subnets, IGW, NAT, route tables
│   ├── security_groups.tf   # cluster and node security groups
│   ├── iam.tf               # cluster role, node role, OIDC, IRSA roles
│   ├── eks.tf               # EKS cluster
│   ├── node_group.tf        # managed node group
│   ├── addons.tf            # VPC CNI, CoreDNS, kube-proxy, EBS CSI
│   ├── lb_controller.tf     # AWS Load Balancer Controller (Helm)
│   ├── vpc_endpoint.tf      # S3 gateway endpoint
│   ├── s3.tf                # S3 bucket
│   ├── access.tf            # EKS access entries
│   └── outputs.tf           # cluster endpoint, OIDC ARN, bucket name
│
└── k8s/
|    ├── Dockerfile           # Python alpine image
|    ├── deployment.yaml      # Kubernetes Deployment
|    └── service.yaml         # Kubernetes Service (cluster ip)
|    └── elb.yaml             # Kubernetes Service (NLB)
|    └── sa.yaml             # Service Account used in IRSA
└── python/
    ├── app.py               # Flask backend
    ├── static/
        └── index.html  
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Infrastructure as Code | Terraform |
| Cloud Provider | AWS |
| Container Orchestration | Kubernetes (EKS) |
| Application | Python / Flask |
| AWS SDK | boto3 |
| Container Registry | Docker Hub |
| Package Management | Helm |
| Load Balancing | AWS NLB via AWS Load Balancer Controller |
| Pod IAM Credentials | IRSA (IAM Roles for Service Accounts) |
| Private S3 Access | VPC Gateway Endpoint |

---

## Prerequisites

- AWS CLI configured with sufficient IAM permissions 'aws login'
- Terraform >= 1.15
- kubectl
- Docker
- Helm

---

## Deploy

**1. Provision infrastructure**

```bash
cd terraform
terraform init
terraform apply
```

**2. Configure kubectl**

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name my-eks-cluster
```

**3. Build and push the application image**

```bash
cd k8s
docker build -t your-dockerhub/s3-explorer:latest .
docker push your-dockerhub/s3-explorer:latest
```

**4. Deploy to Kubernetes**

```bash
cd k8s/
kubectl apply -f .
```

**5. Get the NLB DNS**

```bash
kubectl get svc 

# open the EXTERNAL-IP in your browser
```

---

## Destroy

Always clean up Kubernetes resources before destroying infrastructure to avoid ENI dependency errors:

```bash
# 1. delete the service (removes the NLB from AWS)
kubectl delete -f k8s/elb.yaml

# 2. destroy node group first (removes VPC CNI ENIs)
terraform destroy -target=aws_eks_node_group.main

# 3. destroy everything else
terraform destroy
```
