output "bucket_name" {
  description = "Documents bucket name"
  value       = aws_s3_bucket.documents.id
}

output "bucket_arn" {
  description = "Documents bucket ARN"
  value       = aws_s3_bucket.documents.arn
}

output "log_bucket_name" {
  description = "Access logs bucket name"
  value       = aws_s3_bucket.logs.id
}

output "log_bucket_arn" {
  description = "Access logs bucket ARN"
  value       = aws_s3_bucket.logs.arn
}
