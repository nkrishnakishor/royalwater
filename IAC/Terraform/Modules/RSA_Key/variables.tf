variable "key_name" {
  type        = string
  description = "Name of the RSA key being created"
}

variable "rsa_bits" {
  description = "size of the generated RSA key, default values available are 2048, 4096"
  default     = 4096
  type        = number
}

variable "algorithm" {
  description = "Name of the algorithm to use, ED25519 or RSA or ECDSA"
  type        = string
  default     = "RSA"
}

variable "save_file" {
  description = "Do need to save the file ?"
  type        = bool
  default     = false
}

variable "output_path" {
  description = "Path to save the file"
  type        = string
  default     = "."
}
