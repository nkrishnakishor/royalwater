variable "app_name" {
  description = "Application name — used as prefix for all resource names"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "github_repo" {
  description = "GitHub repo URL for CodeBuild to clone (e.g. https://github.com/org/repo.git)"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "use_localstack" {
  description = "Set true to target LocalStack; false for real AWS"
  type        = bool
  default     = true
}

variable "aws_account_id" {
  description = "AWS account ID — used to build ECR URL (ignored in LocalStack)"
  type        = string
  default     = "000000000000"
}
