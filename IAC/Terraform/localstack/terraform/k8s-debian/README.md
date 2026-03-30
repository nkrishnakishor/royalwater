# Kubernetes on Debian EC2 - Terraform

This Terraform project provisions a self-managed Kubernetes cluster on Debian 12 EC2 instances with automatic configuration.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS VPC                              │
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │    Subnet (AZ-a)    │    │    Subnet (AZ-b)    │        │
│  │  ┌───────────────┐  │    │  ┌───────────────┐  │        │
│  │  │ Master Node 1 │  │    │  │  Worker Node 1│  │        │
│  │  │  (kubeadm)    │  │    │  │  (kubeadm)    │  │        │
│  │  └───────────────┘  │    │  └───────────────┘  │        │
│  └─────────────────────┘    └─────────────────────┘        │
│           │                          │                      │
│  ┌────────┴──────────────────────────┴───────────┐         │
│  │         Network Load Balancer (NLB)           │         │
│  │              Port 6443 (API)                  │         │
│  └───────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────┘

Components:
- Cilium CNI (eBPF-based networking)
- AWS Load Balancer Controller (Service type: LoadBalancer)
- containerd runtime
- kubeadm cluster bootstrapping
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- SSH key pair (or provide public key)

## AWS Credentials

AWS credentials are **NOT** stored in `terraform.tfvars.json` for security reasons. Instead, use one of these methods:

### Option 1: AWS CLI Configuration (Recommended)
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, region, and output format
```

### Option 2: Environment Variables
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Option 3: AWS Profiles
```bash
# Configure named profile
aws configure --profile myprofile
export AWS_PROFILE=myprofile
```

### Option 4: IAM Roles (EC2/ECS)
If running Terraform from EC2 or ECS, use IAM roles instead of access keys.

**Important**: Never commit AWS credentials to version control!

## Quick Start

### 1. Configure Variables

Edit `terraform.tfvars`:

```hcl
# AWS Configuration
region = "us-east-1"

# Cluster Configuration
cluster_name = "my-k8s-cluster"
k8s_version  = "1.31"
environment  = "dev"

# Compute Nodes
control_plane_count = 1
worker_count        = 2
instance_type       = "t3.medium"

# SSH Access - Option 1: Existing key pair
key_name = "my-existing-key"

# SSH Access - Option 2: New key pair
# public_key  = "ssh-rsa AAAA..."
# private_key = file("~/.ssh/id_rsa")
```

### 2. Deploy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy cluster
terraform apply
```

### 3. Access the Cluster

After deployment, use the kubeconfig:

```bash
# Set kubeconfig
export KUBECONFIG=./terraform/modules/k8s-debian/kubeconfig-${CLUSTER_NAME}.yaml

# Verify cluster
kubectl get nodes
kubectl get pods -A
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `region` | AWS region | `us-east-1` |
| `cluster_name` | Cluster name | `debian-k8s` |
| `k8s_version` | Kubernetes version | `1.31` |
| `environment` | Environment tag | `dev` |
| `vpc_cidr` | VPC CIDR block | `10.1.0.0/16` |
| `subnet_cidrs` | Subnet CIDRs | `["10.1.1.0/24", "10.1.2.0/24"]` |
| `azs` | Availability zones | `["us-east-1a", "us-east-1b"]` |
| `pod_cidr` | Pod network CIDR | `10.244.0.0/16` |
| `service_cidr` | Service network CIDR | `10.96.0.0/12` |
| `control_plane_count` | Master nodes | `1` |
| `worker_count` | Worker nodes | `2` |
| `instance_type` | EC2 instance type | `t3.medium` |
| `root_volume_size` | Root disk size (GB) | `50` |
| `key_name` | Existing key pair name | `""` |
| `public_key` | SSH public key content | `""` |
| `private_key` | SSH private key content | `""` |

## Outputs

| Output | Description |
|--------|-------------|
| `api_server_url` | Kubernetes API endpoint |
| `cluster_name` | Cluster name |
| `kubeconfig_path` | Path to kubeconfig file |
| `nlb_dns_name` | NLB DNS name |
| `control_plane_private_ips` | Master node IPs |
| `worker_private_ips` | Worker node IPs |
| `ssh_command_master` | SSH command for master |
| `kubectl_command` | kubectl access command |

## Components Installed

### On All Nodes
- containerd (container runtime)
- kubeadm, kubelet, kubectl
- Cilium prerequisites (kernel modules, sysctl)

### On First Master
- `kubeadm init` cluster initialization
- Cilium CNI installation
- Helm 3
- AWS Load Balancer Controller (via Helm)

### On Workers
- `kubeadm join` to cluster

## Using LoadBalancer Services

After deployment, create services with `type: LoadBalancer`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
```

## Cleanup

```bash
terraform destroy
```

## Module Structure

```
terraform-k8s-debian/
├── main.tf              # Root module calling submodules
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── providers.tf         # AWS provider config
├── terraform.tfvars     # Variable values
└── README.md            # This file

terraform/modules/k8s-debian/
├── main.tf              # EC2, SGs, NLB, cluster init
├── variables.tf         # Module input variables
├── outputs.tf           # Module outputs
└── templates/
    ├── user-data-master.sh.tpl
    └── user-data-worker.sh.tpl
```

## Troubleshooting

### Check user-data logs
```bash
ssh -i key.pem admin@<master-ip>
sudo cat /var/log/cloud-init-output.log
```

### Verify cluster status
```bash
ssh -i key.pem admin@<master-ip>
sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes
```

### Check Cilium status
```bash
ssh -i key.pem admin@<master-ip>
sudo cilium status
```
</write_to_file>
<attempt_completion>
<result>
I've created a comprehensive README.md file for the terraform-k8s-debian folder with full documentation including:

- Architecture diagram
- Prerequisites
- Quick start guide
- All variables with defaults
- All outputs
- Components installed
- LoadBalancer service examples
- Cleanup instructions
- Module structure
- Troubleshooting guide

The Terraform project is now complete with all files:
- `terraform/modules/k8s-debian/` - New module for Debian K8s
- `terraform-k8s-debian/` - Separate root folder
- `terraform-k8s-debian/README.md` - Documentation
</result>
</attempt_completion>