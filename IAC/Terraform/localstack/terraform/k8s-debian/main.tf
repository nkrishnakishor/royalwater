# ── SSH Key Module ──────────────────────────────────────────────────────────
module "ssh_key" {
  source = "./modules/ssh-key"

  name_prefix      = var.cluster_name
  key_name         = var.key_name != "" ? var.key_name : ""
  algorithm        = var.ssh_algorithm
  rsa_bits         = var.ssh_rsa_bits
  ecdsa_curve      = var.ssh_ecdsa_curve
  save_private_key = var.save_ssh_keys
  save_public_key  = var.save_ssh_keys

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Cluster     = var.cluster_name
  }
}

# ── Networking Module ─────────────────────────────────────────────────────────
module "networking" {
  source = "./modules/networking"

  name_prefix  = var.cluster_name
  cidr_block   = var.vpc_cidr
  subnet_cidrs = var.subnet_cidrs
  azs          = var.azs
}

# ── Kubernetes Module ─────────────────────────────────────────────────────────
module "k8s_debian" {
  source = "./modules/k8s-debian"

  cluster_name        = var.cluster_name
  k8s_version         = var.k8s_version
  environment         = var.environment
  vpc_id              = module.networking.vpc_id
  subnet_ids          = module.networking.subnet_ids
  pod_cidr            = var.pod_cidr
  service_cidr        = var.service_cidr
  control_plane_count = var.control_plane_count
  worker_count        = var.worker_count
  instance_type       = var.instance_type
  ami_id              = var.ami_id
  key_name            = module.ssh_key.key_name
  public_key          = module.ssh_key.public_key
  private_key         = module.ssh_key.private_key
  root_volume_size    = var.root_volume_size

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Cluster     = var.cluster_name
  }
}
