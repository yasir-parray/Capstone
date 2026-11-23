variable "iam_user_name" {
  description = "Name for the IAM user created by this project."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique name for the S3 bucket created by this project."
  type        = string
}

variable "s3_read_policy" {
  description = "Effect and actions for the S3 read policy."

  type = object({
    effect             = string
    list_bucket_action = string
    get_object_action  = string
  })

  default = {
    effect             = "Allow"
    list_bucket_action = "s3:ListBucket"
    get_object_action  = "s3:GetObject"
  }
}