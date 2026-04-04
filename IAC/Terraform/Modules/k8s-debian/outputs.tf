# ── Cluster Connection ────────────────────────────────────────────────────────
output "api_server_url" {
  description = "Kubernetes API server URL via NLB"
  value       = "https://${aws_lb.k8s_api.dns_name}:6443"
}

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = "${path.module}/kubeconfig-${var.cluster_name}.yaml"
}

# ── Load Balancer ─────────────────────────────────────────────────────────────
output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.k8s_api.dns_name
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = aws_lb.k8s_api.arn
}

# ── Control Plane ─────────────────────────────────────────────────────────────
output "control_plane_instance_ids" {
  description = "List of control plane instance IDs"
  value       = aws_instance.control_plane[*].id
}

output "control_plane_private_ips" {
  description = "List of control plane private IPs"
  value       = aws_instance.control_plane[*].private_ip
}

output "control_plane_public_ips" {
  description = "List of control plane public IPs"
  value       = aws_instance.control_plane[*].public_ip
}

# ── Workers ───────────────────────────────────────────────────────────────────
output "worker_instance_ids" {
  description = "List of worker instance IDs"
  value       = aws_instance.worker[*].id
}

output "worker_private_ips" {
  description = "List of worker private IPs"
  value       = aws_instance.worker[*].private_ip
}

output "worker_public_ips" {
  description = "List of worker public IPs"
  value       = aws_instance.worker[*].public_ip
}

# ── Security Groups ───────────────────────────────────────────────────────────
output "control_plane_security_group_id" {
  description = "Security group ID for control plane nodes"
  value       = aws_security_group.control_plane.id
}

output "worker_security_group_id" {
  description = "Security group ID for worker nodes"
  value       = aws_security_group.worker.id
}

# ── SSH Commands ──────────────────────────────────────────────────────────────
output "ssh_command_master" {
  description = "SSH command to connect to first master node"
  value       = "ssh -i <key> admin@${aws_instance.control_plane[0].public_ip}"
}

output "kubectl_command" {
  description = "kubectl command to access the cluster"
  value       = "export KUBECONFIG=${path.module}/kubeconfig-${var.cluster_name}.yaml && kubectl get nodes"
}
