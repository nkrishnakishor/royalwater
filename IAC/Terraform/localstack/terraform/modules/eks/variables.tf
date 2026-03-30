variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "role_arn" {
  description = "IAM role ARN for the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}
