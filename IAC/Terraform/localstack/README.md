# LocalStack EKS App Deployment Pipeline

A local end-to-end CI/CD pipeline that simulates the full AWS deployment workflow using LocalStack. Provisions an EKS cluster, ECR registry, CodeBuild projects, and CodePipeline — all running locally via Docker.

> **Current Status**: Infrastructure is provisioned and EKS cluster is ACTIVE. CodeBuild and CodePipeline modules are commented out in Terraform (require paid LocalStack license).

---

## Architecture

```
Git repo (GitHub)
      │
      │  make trigger
      ▼
┌─────────────────────────────────────────────────────┐
│  AWS CodePipeline  (LocalStack)                     │
│                                                     │
│  Stage 1 ─ Source                                   │
│    S3 trigger object → SourceArtifact               │
│              │                                      │
│  Stage 2 ─ Build  (CodeBuild: NO_SOURCE)            │
│    git clone GitHub repo                            │
│    docker build → extract sha256 digest tag         │
│    docker push ECR:<IMAGE_DIGEST>                   │
│    output → BuildArtifact (digest.env)              │
│              │                                      │
│  Stage 3 ─ Deploy  (CodeBuild: NO_SOURCE)           │
│    read IMAGE_DIGEST from artifact                  │
│    kubectl set image deployment/myapp               │
│    kubectl rollout status                           │
└─────────────────────────────────────────────────────┘
      │
      ▼
EKS Cluster (k3s via LocalStack)
  └─ Pod: myapp:<IMAGE_DIGEST>
  └─ Service: ClusterIP
  └─ Ingress: Traefik → http://localhost:8081/app
```

---

## Deploying a Docker Image to LocalStack EKS

This section covers building and deploying your Docker image directly to the LocalStack EKS cluster.

### Step 1: Build the Docker Image

```bash
docker build -t myapp:latest .
```

### Step 2: Push to LocalStack ECR

```bash
# Login to LocalStack ECR
awslocal ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566

# Tag the image for ECR
docker tag myapp:latest 000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566/myapp:latest

# Push to ECR
docker push 000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566/myapp:latest
```

### Step 3: Update Kubernetes Deployment

Update `k8s/deployment.yaml` to reference the ECR image:

```yaml
spec:
  containers:
    - name: myapp
      image: 000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566/myapp:latest
      imagePullPolicy: Always
      ports:
        - containerPort: 80
```

> **Note**: Change `imagePullPolicy` from `Never` to `Always` when pulling from ECR.

### Step 4: Apply Manifests

```bash
kubectl apply -f k8s/
```

### Step 5: Verify Deployment

```bash
kubectl get pods -l app=myapp
kubectl get svc myapp
kubectl get ingress myapp
```

### Adding k3d Cluster to Kubeconfig (without overwriting)

To merge a k3d cluster config into your existing `~/.kube/config`:

```bash
k3d kubeconfig merge <cluster-name> --kubeconfig-merge-default
```

For example, to add a cluster named `my-new-cluster`:

```bash
k3d cluster create my-new-cluster
k3d kubeconfig merge my-new-cluster --kubeconfig-merge-default
```

This preserves all existing contexts (k3d-cilium-cluster, kubernetes-admin, LocalStack EKS) while adding the new k3d cluster context.

Verify with:
```bash
kubectl config get-contexts
```

---

## Current Infrastructure Status

The following resources are currently provisioned and running:

| Resource | Status | Details |
|----------|--------|---------|
| LocalStack | ✅ Running (healthy) | Port 4566, services: ec2, eks, ecr, iam, sts, s3, codebuild, codepipeline |
| EKS Cluster | ✅ ACTIVE | `myapp-cluster`, Kubernetes v1.34, endpoint: `https://localhost.localstack.cloud:4510` |
| ECR Repository | ✅ Created | `000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566/myapp` |
| S3 Buckets | ✅ Created | `myapp-pipeline-artifacts`, `myapp-pipeline-trigger` |
| VPC + Networking | ✅ Created | VPC with 2 subnets, internet gateway |
| CodeBuild | ❌ Not provisioned | Requires paid LocalStack license (commented in `terraform/main.tf`) |
| CodePipeline | ❌ Not provisioned | Requires paid LocalStack license (commented in `terraform/main.tf`) |
| Traefik Ingress | ❌ Not deployed | Required for HTTP access on port 8081 |

### Verify Current Status

```bash
# Check LocalStack status
docker ps --filter "name=localstack" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check EKS cluster status
awslocal eks describe-cluster --name myapp-cluster --query 'cluster.{Name:name,Status:status,Version:version}' --output table

# Check ECR repository
awslocal ecr describe-repositories --repository-names myapp --query 'repositories[0].{Name:repositoryName,Uri:repositoryUri}' --output table

# Check S3 buckets
awslocal s3 ls | grep myapp

# Check Terraform state
cd terraform && tflocal state list
```

### Configure kubectl

The kubeconfig needs to be updated to use `awslocal` instead of `aws` for authentication:

```bash
# Update kubeconfig for LocalStack EKS cluster
awslocal eks update-kubeconfig --name myapp-cluster --region us-east-1

# Fix authentication to use awslocal instead of aws
sed -i '' 's/command: aws/command: awslocal/' ~/.kube/config

# Verify connection
kubectl get nodes
kubectl get pods -A
```

### Enable Full CI/CD Pipeline (Requires Paid License)

To enable CodeBuild and CodePipeline, you need a LocalStack Base plan license:

1. Get your license token from [localstack.cloud](https://localstack.cloud)
2. Set the environment variable: `export LOCALSTACK_AUTH_TOKEN=<your-token>`
3. Uncomment the CodeBuild and CodePipeline modules in `terraform/main.tf`:
   ```hcl
   module "codebuild" {
     source       = "./modules/codebuild"
     app_name     = var.app_name
     region       = var.region
     ecr_registry = local.ecr_registry
     github_repo  = var.github_repo
     cluster_name = module.eks.cluster_name
     role_arn     = "${local.dummy_role_arn}/codebuild-role"
     aws_endpoint_url = var.use_localstack ? local.ls_endpoint : ""
   }

   module "codepipeline" {
     source              = "./modules/codepipeline"
     pipeline_name       = "${var.app_name}-pipeline"
     artifact_bucket     = module.s3.artifact_bucket
     trigger_bucket      = module.s3.trigger_bucket
     build_project_name  = module.codebuild.build_project_name
     deploy_project_name = module.codebuild.deploy_project_name
     role_arn            = "${local.dummy_role_arn}/codepipeline-role"
   }
   ```
4. Uncomment the outputs in `terraform/outputs.tf`
5. Re-apply Terraform: `cd terraform && tflocal apply -auto-approve`
6. Deploy the application: `make trigger`

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| Docker Desktop | Runs LocalStack + k3s containers | [docker.com](https://www.docker.com/products/docker-desktop/) |
| `terraform` | Infrastructure provisioning | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| `tflocal` | Terraform wrapper for LocalStack | `pip install terraform-local` |
| `awslocal` | AWS CLI wrapper for LocalStack | `pip install awscli-local` |
| `kubectl` | Kubernetes CLI | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| LocalStack auth token | Required for CodeBuild + CodePipeline | [localstack.cloud](https://localstack.cloud) |

### LocalStack License

| Feature | Tier Required |
|---------|--------------|
| EKS (basic cluster) | Free (Hobby) |
| ECR, S3, VPC, IAM | Free (Hobby) |
| **CodeBuild** | **Base plan (paid)** |
| **CodePipeline** | **Base plan (paid)** |

Set your auth token before starting:
```bash
export LOCALSTACK_AUTH_TOKEN=<your-token>
```

### Docker — Allow Insecure ECR Registry

LocalStack ECR runs over HTTP. Add the following to Docker Desktop → Settings → Docker Engine:

```json
{
  "insecure-registries": [
    "000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566"
  ]
}
```

Apply and restart Docker Desktop.

---

## File Structure

```
localstack/
├── docker-compose.yml          # Runs LocalStack (EKS, ECR, CodeBuild, CodePipeline, S3)
├── Makefile                    # Pipeline orchestration commands
├── trigger.json                # S3 artifact uploaded to start CodePipeline
├── buildspec-build.yml         # CodeBuild Stage 2: git clone → build → ECR push
├── buildspec-deploy.yml        # CodeBuild Stage 3: read digest → kubectl deploy
├── k8s/
│   ├── deployment.yaml         # Kubernetes Deployment (image updated per pipeline run)
│   ├── service.yaml            # ClusterIP Service
│   └── ingress.yaml            # Traefik Ingress on /app path
└── terraform/
    ├── main.tf                 # Root module: provider config + module wiring
    ├── variables.tf            # Input variables
    ├── outputs.tf              # Output values (ECR URL, cluster name, etc.)
    ├── terraform.tfvars        # Per-environment values (edit this file)
    └── modules/
        ├── networking/         # VPC + subnets + internet gateway
        ├── ecr/                # ECR repository + lifecycle policy
        ├── eks/                # EKS cluster (k3s embedded, no nodegroups)
        ├── s3/                 # Artifact store + pipeline trigger buckets
        ├── codebuild/          # Build + Deploy CodeBuild projects (both NO_SOURCE)
        └── codepipeline/       # CodePipeline: Source → Build → Deploy
```

---

## Configuration

Edit `terraform/terraform.tfvars` before provisioning:

```hcl
use_localstack = true                                    # false for real AWS
app_name       = "myapp"                                 # used as prefix for all resources
region         = "us-east-1"
github_repo    = "https://github.com/<org>/<repo>.git"  # repo to clone in buildspec
k8s_version    = "1.34"
aws_account_id = "000000000000"                          # LocalStack dummy account ID
```

---

## Usage

### Phase 1 — Cluster Setup (once per session)

```bash
make cluster-up
```

This will:
1. Start LocalStack via Docker Compose
2. Wait for LocalStack to be healthy
3. Run `tflocal apply` to provision VPC, ECR, EKS, S3, CodeBuild, CodePipeline
4. Wait until the EKS cluster status is `ACTIVE`
5. Write the kubectl context via `aws eks update-kubeconfig`

Then apply the Kubernetes manifests (first time only):
```bash
kubectl apply -f k8s/
```

### Phase 2 — Deploy the App (per commit)

```bash
make trigger
```

This will:
1. Upload `trigger.json` to the S3 trigger bucket
2. Call `start-pipeline-execution` on the CodePipeline
3. Poll the pipeline status until `Succeeded` or `Failed`

The pipeline stages run automatically:
- **Stage 1 (Source)**: reads `trigger.json` from S3
- **Stage 2 (Build)**: clones your GitHub repo, builds the Docker image, pushes to ECR with a digest tag
- **Stage 3 (Deploy)**: reads the digest, runs `kubectl set image`, waits for rollout

### Verify the Deployment

```bash
make verify
```

Output shows pod status, service, ingress, and an HTTP check against `http://localhost:8081/app`.

### Tear Down

```bash
make cluster-down
```

Destroys all Terraform-managed resources and stops LocalStack.

---

## Makefile Reference

```
make cluster-up    Start LocalStack + provision all infra + configure kubectl
make cluster-down  Destroy infra + stop LocalStack
make trigger       Upload trigger + start pipeline + poll until complete
make verify        Check pods/services/ingress + HTTP curl test
make status        Show EKS cluster info + latest pipeline execution + all pods
make kubeconfig    Re-run update-kubeconfig (use if kubectl context is lost)
```

---

## How the Image Digest Tag Works

Instead of tagging images as `latest`, each build produces a unique, content-addressed tag:

```bash
IMAGE_DIGEST=$(docker images --no-trunc --quiet myapp | cut -d':' -f2 | cut -c1-12)
# Example: a3f7b1c2d9e4
```

This is the first 12 characters of the sha256 content hash of the image. Properties:
- Two builds from identical code produce the **same tag** (idempotent)
- Any code change produces a **different tag** (content-addressed)
- Every running pod can be traced back to its exact image content
- No risk of silent image replacement (unlike `latest`)

The deploy stage uses `kubectl set image` with this digest tag, triggering a rolling update only when the image actually changed.

---

## Switching to Real AWS

The entire stack is designed for a single-flag switch. Only `terraform.tfvars` changes:

```hcl
# Switch to real AWS
use_localstack = false
app_name       = "myapp"
region         = "us-east-1"
github_repo    = "https://github.com/<org>/<repo>.git"
k8s_version    = "1.34"  # or your desired version
aws_account_id = "123456789012"    # your real AWS account ID
```

| What changes | LocalStack | Real AWS |
|---|---|---|
| `use_localstack` in tfvars | `true` | `false` |
| AWS provider endpoints | Points to `localhost:4566` | Default (AWS endpoints) |
| Credentials | Dummy (`test`/`test`) | Real credentials via env/profile |
| ECR registry URL | `000000000000.dkr.ecr...localstack.cloud:4566` | `<account>.dkr.ecr.<region>.amazonaws.com` |
| IAM role ARNs | Dummy (mocked by LocalStack) | Real IAM roles with policies |
| Docker insecure registry | Required | Not needed |
| `docker-compose.yml` | Required | Not used |
| Terraform modules | **Unchanged** | **Unchanged** |
| Buildspec files | **Unchanged** | **Unchanged** |
| Kubernetes manifests | **Unchanged** | **Unchanged** |

Additional steps for real AWS:
1. Create real IAM roles for EKS, CodeBuild, and CodePipeline with appropriate policies
2. Set `aws_account_id` to your real account ID
3. Configure AWS credentials (`aws configure` or env vars)
4. Remove the insecure Docker registry entry
5. Run `terraform init && terraform apply` (without `tflocal`)

---

## Terraform Modules

Each module is self-contained and reusable independently.

### `networking`
Creates a VPC with subnets across multiple availability zones.

| Variable | Description | Default |
|---|---|---|
| `name_prefix` | Resource name prefix | required |
| `cidr_block` | VPC CIDR | `10.0.0.0/16` |
| `subnet_cidrs` | List of subnet CIDRs | `["10.0.1.0/24", "10.0.2.0/24"]` |
| `azs` | Availability zones | required |

### `ecr`
Creates an ECR repository with a lifecycle policy (keeps last 10 images).

| Variable | Description | Default |
|---|---|---|
| `repo_name` | Repository name | required |
| `image_tag_mutability` | `MUTABLE` or `IMMUTABLE` | `MUTABLE` |

### `eks`
Creates an EKS cluster using LocalStack's embedded k3s. No managed nodegroups (the k3s node acts as both control plane and worker).

| Variable | Description | Default |
|---|---|---|
| `cluster_name` | Cluster name | required |
| `subnet_ids` | VPC subnet IDs | required |
| `k8s_version` | Kubernetes version | `1.34` |
| `role_arn` | IAM role ARN | required |
| `region` | AWS region | required |

### `s3`
Creates two S3 buckets with versioning enabled:
- **Artifact bucket** — CodePipeline inter-stage artifact store
- **Trigger bucket** — upload `trigger.json` here to start the pipeline

### `codebuild`
Creates two CodeBuild projects (both `NO_SOURCE`):
- **`<app>-build`** — runs `buildspec-build.yml`, clones GitHub, builds and pushes image
- **`<app>-deploy`** — runs `buildspec-deploy.yml`, reads digest, deploys to EKS

`AWS_ENDPOINT_URL` is injected as an env var when `aws_endpoint_url` is set (LocalStack mode), letting the `aws` CLI hit LocalStack without using `awslocal`.

### `codepipeline`
Creates a 3-stage CodePipeline:
- **Source** — S3 source action watching `trigger.json`
- **Build** — CodeBuild action (`<app>-build` project)
- **Deploy** — CodeBuild action (`<app>-deploy` project)

---

## Troubleshooting

**EKS cluster stuck in `CREATING`**
```bash
# Check LocalStack logs
docker logs localstack

# Verify Docker socket is mounted (k3s needs it)
docker inspect localstack | grep -i sock
```

**kubectl: no context / connection refused**
```bash
make kubeconfig
```

**CodeBuild/CodePipeline not available**
These require a LocalStack Base plan license. Verify your token:
```bash
docker logs localstack | grep -i auth
```

**ECR push: `http: server gave HTTP response to HTTPS client`**
Add the ECR endpoint to Docker's insecure registries (see Prerequisites section).

**Pipeline stuck / not progressing**
LocalStack CodePipeline triggers are not automatic — always start via `make trigger` (which calls `start-pipeline-execution`).
