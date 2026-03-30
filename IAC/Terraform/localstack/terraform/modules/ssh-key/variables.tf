# ── SSH Key Module Variables ──────────────────────────────────────────────────

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "k8s"
}

variable "key_name" {
  description = "Name of the SSH key pair (if empty, will be generated from name_prefix)"
  type        = string
  default     = ""
}

variable "algorithm" {
  description = "SSH key algorithm (RSA, ECDSA, or ED25519)"
  type        = string
  default     = "ED25519"

  validation {
    condition     = contains(["RSA", "ECDSA", "ED25519"], var.algorithm)
    error_message = "Algorithm must be one of: RSA, ECDSA, ED25519"
  }
}

variable "rsa_bits" {
  description = "RSA key size in bits (only used if algorithm is RSA)"
  type        = number
  default     = 4096
}

variable "ecdsa_curve" {
  description = "ECDSA curve (only used if algorithm is ECDSA)"
  type        = string
  default     = "P256"

  validation {
    condition     = contains(["P256", "P384", "P521"], var.ecdsa_curve)
    error_message = "ECDSA curve must be one of: P256, P384, P521"
  }
}

variable "save_private_key" {
  description = "Save private key to local file"
  type        = bool
  default     = true
}

variable "save_public_key" {
  description = "Save public key to local file"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}