resource "aws_s3_bucket" "project4" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "project4" {
  bucket                  = aws_s3_bucket.project4.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "s3_read" {
  statement {
    sid       = "ListBucket"
    effect    = var.s3_read_policy.effect
    actions   = [var.s3_read_policy.list_bucket_action]
    resources = [aws_s3_bucket.project4.arn]
  }

  statement {
    sid       = "ReadObjects"
    effect    = var.s3_read_policy.effect
    actions   = [var.s3_read_policy.get_object_action]
    resources = ["${aws_s3_bucket.project4.arn}/*"]
  }
}

resource "aws_iam_user" "project4" {
  name = var.iam_user_name
}

resource "aws_iam_policy" "s3_read" {
  name        = "${var.iam_user_name}-s3-read"
  description = "Allows read-only access to the Project 4 S3 bucket."
  policy      = data.aws_iam_policy_document.s3_read.json
}

resource "aws_iam_user_policy_attachment" "s3_read" {
  user       = aws_iam_user.project4.name
  policy_arn = aws_iam_policy.s3_read.arn
}