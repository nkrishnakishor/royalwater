terraform {
  required_version = ">= 1.5.0"

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
}

provider "aws" {
  region = var.region

  # LocalStack endpoint configuration
  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      s3             = local.ls_s3_endpoint
      sts            = local.ls_endpoint
      iam            = local.ls_endpoint
      ec2            = local.ls_endpoint
      eks            = local.ls_endpoint
      ecr            = local.ls_endpoint
      elb            = local.ls_endpoint
      elbv2          = local.ls_endpoint
      rds            = local.ls_endpoint
      dynamodb       = local.ls_endpoint
      sns            = local.ls_endpoint
      sqs            = local.ls_endpoint
      lambda         = local.ls_endpoint
      apigateway     = local.ls_endpoint
      cloudformation = local.ls_endpoint
      cloudwatch     = local.ls_endpoint
      logs           = local.ls_endpoint
      secretsmanager = local.ls_endpoint
      ssm            = local.ls_endpoint
    }
  }

  # Skip credentials validation for LocalStack
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = "k8s-debian"
    }
  }
}
