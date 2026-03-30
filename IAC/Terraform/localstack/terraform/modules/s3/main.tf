# Artifact store — CodePipeline passes artifacts between stages via this bucket
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.name_prefix}-pipeline-artifacts"
  force_destroy = true

  tags = {
    Name    = "${var.name_prefix}-pipeline-artifacts"
    Purpose = "codepipeline-artifact-store"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Trigger bucket — upload trigger.json here to start the pipeline
resource "aws_s3_bucket" "trigger" {
  bucket        = "${var.name_prefix}-pipeline-trigger"
  force_destroy = true

  tags = {
    Name    = "${var.name_prefix}-pipeline-trigger"
    Purpose = "codepipeline-source-trigger"
  }
}

resource "aws_s3_bucket_versioning" "trigger" {
  bucket = aws_s3_bucket.trigger.id
  versioning_configuration {
    status = "Enabled" # Required for S3 source action in CodePipeline
  }
}
