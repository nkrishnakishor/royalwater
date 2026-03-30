variable "app_name" {
  description = "Application name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "ecr_registry" {
  description = "ECR registry URL (e.g. 000000000000.dkr.ecr.us-east-1...)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository URL to clone in buildspec"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name used in deploy buildspec"
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN for CodeBuild projects"
  type        = string
}

variable "aws_endpoint_url" {
  description = "AWS endpoint URL override (set to LocalStack URL for local; empty for real AWS)"
  type        = string
  default     = ""
}
