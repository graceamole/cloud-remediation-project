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


# This creates the 'Security Camera' (EventBridge Rule)
resource "aws_cloudwatch_event_rule" "remediation_rule" {
  name        = "detect-security-group-change"
  description = "Fires when a Security Group rule is created or modified"

  # This 'Pattern' tells AWS exactly what event to look for
  event_pattern = jsonencode({
    "source": ["aws.ec2"],
    "detail-type": ["AWS API Call via CloudTrail"],
    "detail": {
      "eventSource": ["ec2.amazonaws.com"],
      "eventName": [
        "AuthorizeSecurityGroupIngress"
      ]
    }
  })
}

# --- lamda function
resource "aws_iam_role" "iam_for_lambda" {
  name = "remediation_lambda_role"

  # This tells AWS: "Who is allowed to wear this badge?"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# ---lambda roles
resource "aws_iam_role_policy" "lambda_network_policy" {
  name = "lambda_network_remediation_policy"
  role = aws_iam_role.iam_for_lambda.id

  # This lists exactly what the robot can touch
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ec2:DescribeSecurityGroups",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}


# 1. This zips up your Python code into a gift box
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "remediate.py"
  output_path = "lambda_function_payload.zip"
}

# 2. This creates the actual Robot (Lambda Function)
resource "aws_lambda_function" "remediation_lambda" {
  filename      = "lambda_function_payload.zip"
  function_name = "security_remediation_bot"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "remediate.lambda_handler"
  timeout = 15 
  runtime       = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  # 3. Update the Lambda to know about the SNS Topic
# Find your existing aws_lambda_function block and ADD the environment section:
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.remediation_alerts.arn
    }
  }

}


# --- STEP 10: THE PERMISSION ---
# This tells AWS: "It is okay for the Alarm to wake up the Robot"
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediation_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.remediation_rule.arn
}

# --- STEP 11: THE TARGET (The Wire) ---
# This connects the "Motion Sensor" to the "Robot"
resource "aws_cloudwatch_event_target" "remediate_lambda_target" {
  rule      = aws_cloudwatch_event_rule.remediation_rule.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.remediation_lambda.arn
}


# 1. The "Post Office" (SNS Topic)
resource "aws_sns_topic" "remediation_alerts" {
  name = "security-remediation-alerts"
}

# 2. The "Subscriber" (Your Email)
resource "aws_sns_topic_subscription" "email_target" {
  topic_arn = aws_sns_topic.remediation_alerts.arn
  protocol  = "email"
  endpoint  = "graceamole30@gmail.com" # <---you can change THIS to your real email!
}



# 4. Give the Lambda permission to "Send Mail"

resource "aws_iam_role_policy" "lambda_sns_policy" {
  name = "lambda_sns_policy"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.remediation_alerts.arn
      }
    ]
  })
}

# This helper finds your AWS Account ID automatically
data "aws_caller_identity" "current" {}