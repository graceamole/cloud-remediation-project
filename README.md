AWS Automated Security Remediation Bot
A Cloud-Native Security Project

Overview
This project automates the detection and remediation of insecure AWS Security Group configurations. Using Infrastructure as Code (Terraform), it deploys a monitoring system that watches for "Open to the World" (0.0.0.0/0) rules on sensitive ports (like SSH 22) and automatically deletes them to maintain a "Least Privilege" security posture.

# 🛡️ AWS Auto-Remediation Bot

**A Self-Healing Security Infrastructure using Terraform, Lambda, and EventBridge.**

This project automatically detects and closes security vulnerabilities in real-time. If a user opens a "forbidden" port (like SSH or RDP) to the entire world (0.0.0.0/0), this bot immediately revokes the rule and notifies the administrator via email.

## 🚀 How It Works

1. **The Trigger:** A user modifies an AWS Security Group (logged by CloudTrail).
2. **The Alarm:** An EventBridge Rule filters for AuthorizeSecurityGroupIngress events.
3. **The Brain:** A Python Lambda Function analyzes the event to see if the port is 22 or 3389 and if the source is 0.0.0.0/0.
4. **The Cure:** If the rule is dangerous, the Lambda calls the EC2 API to delete the rule.
5. **The Notification:** SNS sends an email alert to the security team with the details.

## 🛠️ Tech Stack

- **Infrastructure as Code:** Terraform
- **Compute:** AWS Lambda (Python 3.9)
- **Monitoring:** AWS CloudTrail & EventBridge
- **Messaging:** AWS SNS
- **Cloud Provider:** AWS

## 📦 Prerequisites

- Terraform installed.
- AWS CLI configured with administrator permissions.
- An active AWS Account.

## 🔧 Deployment

1. **Clone the repository:**
   `git clone <your-repo-link>`
   `cd cloud-remediation-project`
2. **Initialize Terraform:**
   `terraform init`
3. **Update your email:**
   Open main.tf and change the endpoint in the aws_sns_topic_subscription block to your actual email address.
4. **Deploy:**
   `terraform apply`
5. **Confirm Subscription:** Check your email and click the Confirm Subscription link from AWS SNS.

## 🧪 Testing the Bot

1. Navigate to the EC2 Console -> Security Groups.
2. Select the remediation-lab-sg created by this project.
3. Add an Inbound Rule: SSH (Port 22) with Source Anywhere (0.0.0.0/0).
4. **Wait ~2 minutes.**
5. Refresh the page; the rule will be gone, and you will receive an email alert!

## ⚠️ Lessons Learned

- **Infinite Loops:** Learned to filter out Revoke events so the bot doesn't trigger itself.
- **Idempotency:** Handled NotFound errors in Python to ensure the bot doesn't crash if a rule is deleted twice.
- **CloudTrail Latency:** CloudTrail logs are not instant (1-2 minute delay), which is critical for setting expectations in automated remediation.
