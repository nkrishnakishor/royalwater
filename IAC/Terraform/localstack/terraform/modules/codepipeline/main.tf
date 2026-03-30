resource "aws_codepipeline" "main" {
  name     = var.pipeline_name
  role_arn = var.role_arn

  artifact_store {
    type     = "S3"
    location = var.artifact_bucket
  }

  # ── Stage 1: Source ──────────────────────────────────────────────────────────
  # Watches an S3 object; upload trigger.json to start the pipeline.
  # PollForSourceChanges=false — we start via start-pipeline-execution API call.
  stage {
    name = "Source"

    action {
      name             = "S3Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        S3Bucket             = var.trigger_bucket
        S3ObjectKey          = "trigger.json"
        PollForSourceChanges = "false"
      }
    }
  }

  # ── Stage 2: Build ───────────────────────────────────────────────────────────
  # Runs build CodeBuild project: git clone → docker build → ECR push
  # Outputs BuildArtifact containing the image digest.
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = var.build_project_name
      }
    }
  }

  # ── Stage 3: Deploy ──────────────────────────────────────────────────────────
  # Runs deploy CodeBuild project: reads digest → kubectl set image → rollout status
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Build" # CodeBuild used as the deploy executor
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = var.deploy_project_name
      }
    }
  }

  tags = {
    Name = var.pipeline_name
  }
}
