AWS Automated Security Remediation Bot
A Cloud-Native Security Project

Overview
This project automates the detection and remediation of insecure AWS Security Group configurations. Using Infrastructure as Code (Terraform), it deploys a monitoring system that watches for "Open to the World" (0.0.0.0/0) rules on sensitive ports (like SSH 22) and automatically deletes them to maintain a "Least Privilege" security posture.

Tech Stack
IaC: Terraform

Cloud: AWS (VPC, Security Groups, EventBridge, Lambda)

Language: Python (for the Lambda remediation logic)

Version Control: Git & GitHub
