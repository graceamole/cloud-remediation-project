data "aws_vpc" "default" {
  default = true
}

# This 'creates' the firewall to monitor
resource "aws_security_group" "remediation_lab_sg" {
  name        = "remediation-lab-sg"
  description = "SG for testing our automated bot"
  vpc_id      = data.aws_vpc.default.id
}

# 1. Create a "Bucket" to store the logs
resource "aws_s3_bucket" "trail_bucket" {
  bucket        = "my-remediation-bot-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # Allows us to delete the bucket easily later
}

# 2. Add a policy so CloudTrail has permission to save files in that bucket
resource "aws_s3_bucket_policy" "trail_policy" {
  bucket = aws_s3_bucket.trail_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = "${aws_s3_bucket.trail_bucket.arn}"
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.trail_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# 3. Finally, turn on the Trail itself
resource "aws_cloudtrail" "main_trail" {
  name                          = "remediation-bot-trail"
  s3_bucket_name                = aws_s3_bucket.trail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = false # Keeps it simple and cheap
  depends_on                    = [aws_s3_bucket_policy.trail_policy]
}

# This helper finds your AWS Account ID automatically
data "aws_caller_identity" "current" {}