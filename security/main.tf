#   _____________________________  ____ _____________.___________________.___.
#  /   _____/\_   _____/\_   ___ \|    |   \______   \   \__    ___/\__  |   |
#  \_____  \  |    __)_ /    \  \/|    |   /|       _/   | |    |    /   |   |
#  /        \ |        \\     \___|    |  / |    |   \   | |    |    \____   |
# /_______  //_______  / \______  /______/  |____|_  /___| |____|    / ______|
#         \/         \/         \/                 \/                \/       
variable "local_ip" {
  type    = string
  default = "0.0.0.0/0"
}
variable "aws_account_id" {
  type = string
}
variable "aws_role_arn" {
  type = string
}
variable "vpc_id" {
  type = string
}

resource "aws_iam_policy" "sandcastle_consul_auto_join" {
  name        = "sandcastle_consul_auto_join"
  description = "My auto join policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "sandcastle_consul" {
  name               = "sandcastle_consul"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${var.aws_account_id}:role/${var.aws_role_arn}",
                "Service": "ec2.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:SetSourceIdentity"
            ]
        }
    ]
}
EOF
  managed_policy_arns = [
    resource.aws_iam_policy.sandcastle_consul_auto_join.arn
  ]
}

resource "aws_iam_instance_profile" "sandcastle_consul" {
  name = "sandcastle_consul"
  role = aws_iam_role.sandcastle_consul.name

  provisioner "local-exec" {
    command = "echo iam_instance_profile_name = \\\"${aws_iam_instance_profile.sandcastle_consul.name}\\\" | tee -a ../servers/main.tfvars"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "find ../servers -name \"main.tfvars\" -exec sed -i '' -e '/^iam_instance_profile_name/d' {} \\;"
  }
}

resource "aws_security_group" "sandcastle_consul" {
  name        = "sandcastles-consul-sg"
  description = "Allow SSH inbound traffic from local machine"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.local_ip]
  }

  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    self        = true
    description = "DNS queries to consul on TCP"
  }

  ingress {
    from_port = 8600
    to_port   = 8600
    protocol  = "udp"
    self      = true
  }

  ingress {
    from_port   = 8300
    to_port     = 8302
    protocol    = "tcp"
    self        = true
    description = "Intra cluster RPC and LAN, inter cluster WAN on TCP"
  }

  ingress {
    from_port   = 8301
    to_port     = 8302
    protocol    = "udp"
    self        = true
    description = "Intra cluster, inter cluster WAN on UDP"
  }

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    self        = true
    description = "HTTP API access on 8500 within the security group"
  }

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = [var.local_ip]
    description = "Access Consul UI from local"
  }


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.local_ip]
    description = "Access Apache Servers via local IP"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.local_ip]
    description = "Access Express Servers via local IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sandcastle_consul"
  }

  provisioner "local-exec" {
    command = "echo security_group_id = \\\"${aws_security_group.sandcastle_consul.id}\\\" | tee -a ../servers/main.tfvars"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "find ../servers -name \"main.tfvars\" -exec sed -i '' -e '/^security_group_id/d' {} \\;"
  }
}

output "security_group_id" {
  value = aws_security_group.sandcastle_consul.id
}
output "iam_instance_profile_name" {
  value = aws_iam_instance_profile.sandcastle_consul.name
}