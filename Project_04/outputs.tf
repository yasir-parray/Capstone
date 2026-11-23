output "iam_user_name" {
  description = "Created IAM user name."
  value       = aws_iam_user.project4.name
}

output "s3_bucket_name" {
  description = "Created S3 bucket name."
  value       = aws_s3_bucket.project4.bucket
}

output "s3_read_policy_arn" {
  description = "ARN of the attached S3 read policy."
  value       = aws_iam_policy.s3_read.arn
}