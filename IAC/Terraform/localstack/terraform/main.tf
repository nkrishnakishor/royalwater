terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  ls_endpoint    = "http://localhost:4566"
  ls_s3_endpoint = "http://s3.localhost.localstack.cloud:4566"

  # ECR registry URL differs between LocalStack and real AWS
  ecr_registry = var.use_localstack ? "${var.aws_account_id}.dkr.ecr.${var.region}.localhost.localstack.cloud:4566" : "${var.aws_account_id}.dkr.ecr.${var.region}.amazonaws.com"

  # Dummy IAM role ARNs for LocalStack (real AWS needs actual roles)
  dummy_role_arn = "arn:aws:iam::${var.aws_account_id}:role"
}

provider "aws" {
  region = var.region
}

module "networking" {
  source       = "./modules/networking"
  name_prefix  = var.app_name
  cidr_block   = "10.0.0.0/16"
  subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  azs          = ["${var.region}a", "${var.region}b"]
}

module "ecr" {
  source    = "./modules/ecr"
  repo_name = var.app_name
}

module "eks" {
  source       = "./modules/eks"
  cluster_name = "${var.app_name}-cluster"
  subnet_ids   = module.networking.subnet_ids
  k8s_version  = var.k8s_version
  role_arn     = "${local.dummy_role_arn}/eks-role"
  region       = var.region
}

module "s3" {
  source      = "./modules/s3"
  name_prefix = var.app_name
}

# ── CodeBuild + CodePipeline (requires LocalStack Base plan / paid license) ──
# Uncomment the blocks below when LOCALSTACK_AUTH_TOKEN is set with a valid license.
#
# module "codebuild" {
#   source       = "./modules/codebuild"
#   app_name     = var.app_name
#   region       = var.region
#   ecr_registry = local.ecr_registry
#   github_repo  = var.github_repo
#   cluster_name = module.eks.cluster_name
#   role_arn     = "${local.dummy_role_arn}/codebuild-role"
#
#   # AWS_ENDPOINT_URL tells aws CLI to hit LocalStack; unset in real AWS
#   aws_endpoint_url = var.use_localstack ? local.ls_endpoint : ""
# }
#
# module "codepipeline" {
#   source              = "./modules/codepipeline"
#   pipeline_name       = "${var.app_name}-pipeline"
#   artifact_bucket     = module.s3.artifact_bucket
#   trigger_bucket      = module.s3.trigger_bucket
#   build_project_name  = module.codebuild.build_project_name
#   deploy_project_name = module.codebuild.deploy_project_name
#   role_arn            = "${local.dummy_role_arn}/codepipeline-role"
# }
