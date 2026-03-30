locals {
  # When aws_endpoint_url is set, inject it so aws CLI hits LocalStack
  common_env = var.aws_endpoint_url != "" ? [
    { name = "AWS_ENDPOINT_URL", value = var.aws_endpoint_url, type = "PLAINTEXT" }
  ] : []
}

# ── Build project — clones GitHub, builds image, pushes to ECR ────────────────
resource "aws_codebuild_project" "build" {
  name         = "${var.app_name}-build"
  service_role = var.role_arn

  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.root}/../buildspec-build.yml")
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true # required for docker build inside container

    dynamic "environment_variable" {
      for_each = concat(local.common_env, [
        { name = "APP_NAME", value = var.app_name, type = "PLAINTEXT" },
        { name = "ECR_REGISTRY", value = var.ecr_registry, type = "PLAINTEXT" },
        { name = "GITHUB_REPO", value = var.github_repo, type = "PLAINTEXT" },
        { name = "AWS_DEFAULT_REGION", value = var.region, type = "PLAINTEXT" },
      ])
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
        type  = environment_variable.value.type
      }
    }
  }

  tags = {
    Name = "${var.app_name}-build"
  }
}

# ── Deploy project — reads digest artifact, runs kubectl ──────────────────────
resource "aws_codebuild_project" "deploy" {
  name         = "${var.app_name}-deploy"
  service_role = var.role_arn

  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.root}/../buildspec-deploy.yml")
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    dynamic "environment_variable" {
      for_each = concat(local.common_env, [
        { name = "APP_NAME", value = var.app_name, type = "PLAINTEXT" },
        { name = "ECR_REGISTRY", value = var.ecr_registry, type = "PLAINTEXT" },
        { name = "CLUSTER_NAME", value = var.cluster_name, type = "PLAINTEXT" },
        { name = "AWS_DEFAULT_REGION", value = var.region, type = "PLAINTEXT" },
      ])
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
        type  = environment_variable.value.type
      }
    }
  }

  tags = {
    Name = "${var.app_name}-deploy"
  }
}
