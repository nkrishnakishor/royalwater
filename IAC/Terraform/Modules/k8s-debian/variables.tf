# ── Cluster Configuration ────────────────────────────────────────────────────
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
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
variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EC2 instances"
  type        = list(string)
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

  validation {
    condition     = var.control_plane_count >= 1
    error_message = "At least 1 control plane node is required."
  }
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

variable "ami_id" {
  description = "AMI ID for EC2 instances (leave empty for latest Debian 12)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
}

# ── SSH Access ────────────────────────────────────────────────────────────────
variable "key_name" {
  description = "Name of existing SSH key pair (leave empty to create new)"
  type        = string
  default     = ""
}

variable "public_key" {
  description = "SSH public key content (required if key_name is empty)"
  type        = string
  default     = ""
}

variable "private_key" {
  description = "SSH private key content for cluster initialization"
  type        = string
  sensitive   = true
  default     = ""
}

# ── Tags ──────────────────────────────────────────────────────────────────────
variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
