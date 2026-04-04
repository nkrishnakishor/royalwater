# ── SSH Key Module Outputs ────────────────────────────────────────────────────

output "key_name" {
  description = "Name of the AWS key pair"
  value       = aws_key_pair.this.key_name
}

output "key_pair_id" {
  description = "ID of the AWS key pair"
  value       = aws_key_pair.this.key_pair_id
}

output "public_key" {
  description = "SSH public key content"
  value       = tls_private_key.this.public_key_openssh
}

output "private_key" {
  description = "SSH private key content (sensitive)"
  value       = tls_private_key.this.private_key_pem
  sensitive   = true
}

output "private_key_file" {
  description = "Path to saved private key file (if enabled)"
  value       = var.save_private_key ? local_file.private_key[0].filename : null
}

output "public_key_file" {
  description = "Path to saved public key file (if enabled)"
  value       = var.save_public_key ? local_file.public_key[0].filename : null
}

output "fingerprint" {
  description = "SSH key fingerprint"
  value       = tls_private_key.this.public_key_fingerprint_md5
}