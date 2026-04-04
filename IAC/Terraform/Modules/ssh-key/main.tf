# ── SSH Key Generation Module ────────────────────────────────────────────────
# This module generates SSH key pairs for secure access to EC2 instances

# Generate SSH private key
resource "tls_private_key" "this" {
  algorithm   = var.algorithm
  rsa_bits    = var.rsa_bits
  ecdsa_curve = var.ecdsa_curve
}

# Create AWS key pair with generated public key
resource "aws_key_pair" "this" {
  key_name   = var.key_name != "" ? var.key_name : "${var.name_prefix}-key"
  public_key = tls_private_key.this.public_key_openssh

  tags = merge(var.tags, {
    Name = var.key_name != "" ? var.key_name : "${var.name_prefix}-key"
  })
}

# Store private key locally for reference (optional)
resource "local_file" "private_key" {
  count           = var.save_private_key ? 1 : 0
  content         = tls_private_key.this.private_key_pem
  filename        = "${path.module}/${var.key_name != "" ? var.key_name : "${var.name_prefix}-key"}-private.pem"
  file_permission = "0600"
}

# Store public key locally for reference (optional)
resource "local_file" "public_key" {
  count           = var.save_public_key ? 1 : 0
  content         = tls_private_key.this.public_key_openssh
  filename        = "${path.module}/${var.key_name != "" ? var.key_name : "${var.name_prefix}-key"}-public.pub"
  file_permission = "0644"
}