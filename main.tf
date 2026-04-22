data "aws_vpc" "default" {
  default = true
}

# This 'creates' the firewall to monitor
resource "aws_security_group" "remediation_lab_sg" {
  name        = "remediation-lab-sg"
  description = "SG for testing our automated bot"
  vpc_id      = data.aws_vpc.default.id
}