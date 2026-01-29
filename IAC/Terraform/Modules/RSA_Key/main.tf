resource "tls_private_key" "this" {
  rsa_bits  = var.rsa_bits
  algorithm = var.algorithm
}

resource "local_sensitive_file" "private_key" {
  count           = var.save_file ? 1 : 0
  filename        = "${var.output_path}/${var.key_name}.pem"
  content         = tls_private_key.this.private_key_pem
  file_permission = 0600
}

resource "local_file" "public_key" {
  count           = var.save_file ? 1 : 0
  filename        = "${var.output_path}/${var.key_name}.pub"
  content         = tls_private_key.this.public_key_pem
  file_permission = 0644
}
