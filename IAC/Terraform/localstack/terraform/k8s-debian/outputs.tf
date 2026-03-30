# ── Cluster Connection ────────────────────────────────────────────────────────
output "api_server_url" {
  description = "Kubernetes API server URL via NLB"
  value       = module.k8s_debian.api_server_url
}

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = module.k8s_debian.cluster_name
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = module.k8s_debian.kubeconfig_path
}

# ── Load Balancer ─────────────────────────────────────────────────────────────
output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = module.k8s_debian.nlb_dns_name
}

# ── Control Plane ─────────────────────────────────────────────────────────────
output "control_plane_private_ips" {
  description = "List of control plane private IPs"
  value       = module.k8s_debian.control_plane_private_ips
}

output "control_plane_public_ips" {
  description = "List of control plane public IPs"
  value       = module.k8s_debian.control_plane_public_ips
}

# ── Workers ───────────────────────────────────────────────────────────────────
output "worker_private_ips" {
  description = "List of worker private IPs"
  value       = module.k8s_debian.worker_private_ips
}

output "worker_public_ips" {
  description = "List of worker public IPs"
  value       = module.k8s_debian.worker_public_ips
}

# ── Networking ────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = module.networking.subnet_ids
}

# ── SSH Key ──────────────────────────────────────────────────────────────────
output "ssh_key_name" {
  description = "Name of the SSH key pair"
  value       = module.ssh_key.key_name
}

output "ssh_public_key" {
  description = "SSH public key content"
  value       = module.ssh_key.public_key
}

output "ssh_private_key_file" {
  description = "Path to saved SSH private key file"
  value       = module.ssh_key.private_key_file
}

output "ssh_public_key_file" {
  description = "Path to saved SSH public key file"
  value       = module.ssh_key.public_key_file
}

output "ssh_key_fingerprint" {
  description = "SSH key fingerprint"
  value       = module.ssh_key.fingerprint
}

# ── Commands ──────────────────────────────────────────────────────────────────
output "ssh_command_master" {
  description = "SSH command to connect to first master node"
  value       = module.k8s_debian.ssh_command_master
}

output "kubectl_command" {
  description = "kubectl command to access the cluster"
  value       = module.k8s_debian.kubectl_command
}
