variable "repo_name" {
  description = "ECR repository name"
  type        = string
}

variable "image_tag_mutability" {
  description = "MUTABLE or IMMUTABLE image tags"
  type        = string
  default     = "MUTABLE"
}
