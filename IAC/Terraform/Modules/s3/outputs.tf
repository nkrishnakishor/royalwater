output "artifact_bucket" {
  description = "S3 artifact store bucket name"
  value       = aws_s3_bucket.artifacts.bucket
}

output "trigger_bucket" {
  description = "S3 trigger bucket name — upload trigger.json here to start pipeline"
  value       = aws_s3_bucket.trigger.bucket
}
