variable "pipeline_name" {
  description = "CodePipeline pipeline name"
  type        = string
}

variable "artifact_bucket" {
  description = "S3 artifact store bucket name"
  type        = string
}

variable "trigger_bucket" {
  description = "S3 source trigger bucket name"
  type        = string
}

variable "build_project_name" {
  description = "CodeBuild build project name"
  type        = string
}

variable "deploy_project_name" {
  description = "CodeBuild deploy project name"
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN for CodePipeline"
  type        = string
}
