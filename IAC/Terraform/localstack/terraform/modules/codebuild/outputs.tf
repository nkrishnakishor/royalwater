output "build_project_name" {
  description = "CodeBuild build project name"
  value       = aws_codebuild_project.build.name
}

output "deploy_project_name" {
  description = "CodeBuild deploy project name"
  value       = aws_codebuild_project.deploy.name
}

output "build_project_arn" {
  description = "CodeBuild build project ARN"
  value       = aws_codebuild_project.build.arn
}

output "deploy_project_arn" {
  description = "CodeBuild deploy project ARN"
  value       = aws_codebuild_project.deploy.arn
}
