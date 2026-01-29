output "public_key" {
  description = "Public key in PEM format"
  value       = tls_private_key.this.public_key_pem
}

output "private_key" {
  description = "Private key in PEM format"
  value       = tls_private_key.this.private_key_pem
  sensitive   = true
}

output "openssh_key" {
  description = "OpenSSH key"
  value       = tls_private_key.this.public_key_pem
}
