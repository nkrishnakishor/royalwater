# ── AWS Configuration ────────────────────────────────────────────────────────
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "use_localstack" {
  description = "Set true to target LocalStack; false for real AWS"
  type        = bool
  default     = true
}

variable "aws_account_id" {
  description = "AWS account ID — used for resource naming (ignored in LocalStack)"
  type        = string
  default     = "000000000000"
  sensitive   = true
}

# ── Cluster Configuration ────────────────────────────────────────────────────
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "debian-k8s"
}

variable "k8s_version" {
  description = "Kubernetes version to install (e.g., '1.31')"
  type        = string
  default     = "1.31"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ── Networking ────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "subnet_cidrs" {
  description = "List of subnet CIDR blocks"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "pod_cidr" {
  description = "CIDR for pod network"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for service network"
  type        = string
  default     = "10.96.0.0/12"
}

# ── Compute ───────────────────────────────────────────────────────────────────
variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "EC2 instance type for nodes"
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (leave empty for latest Debian 12)"
  type        = string
  default     = ""
}

# ── SSH Access ────────────────────────────────────────────────────────────────
variable "key_name" {
  description = "Name of existing SSH key pair (leave empty to auto-generate)"
  type        = string
  default     = ""
}

variable "ssh_algorithm" {
  description = "SSH key algorithm (RSA, ECDSA, or ED25519)"
  type        = string
  default     = "ED25519"
}

variable "ssh_rsa_bits" {
  description = "RSA key size in bits (only used if algorithm is RSA)"
  type        = number
  default     = 4096
}

variable "ssh_ecdsa_curve" {
  description = "ECDSA curve (only used if algorithm is ECDSA)"
  type        = string
  default     = "P256"
}

variable "save_ssh_keys" {
  description = "Save generated SSH keys to local files"
  type        = bool
  default     = true
}
