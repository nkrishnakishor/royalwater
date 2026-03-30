output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  description = "ECR repository URL (use as ECR_REGISTRY in buildspecs)"
  value       = module.ecr.repository_url
}

# ── CodeBuild + CodePipeline outputs (uncomment when paid license is active) ──
# output "pipeline_name" {
#   description = "CodePipeline name"
#   value       = module.codepipeline.pipeline_name
# }
#
# output "trigger_bucket" {
#   description = "S3 bucket to upload trigger.json to start the pipeline"
#   value       = module.s3.trigger_bucket
# }
#
# output "artifact_bucket" {
#   description = "S3 artifact store bucket used by CodePipeline"
#   value       = module.s3.artifact_bucket
# }

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = module.eks.kubeconfig_command
}
