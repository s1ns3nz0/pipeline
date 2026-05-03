variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 documents bucket"
  type        = string
}

variable "ecr_repo_arn" {
  description = "ARN of the ECR repository"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
