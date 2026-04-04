output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "kubeconfig_command" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.region}"
}
