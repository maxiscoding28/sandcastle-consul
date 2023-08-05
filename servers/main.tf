#   __________________________________   _________________________  _________
#  /   _____/\_   _____/\______   \   \ /   /\_   _____/\______   \/   _____/
#  \_____  \  |    __)_  |       _/\   Y   /  |    __)_  |       _/\_____  \ 
#  /        \ |        \ |    |   \ \     /   |        \ |    |   \/        \
# /_______  //_______  / |____|_  /  \___/   /_______  / |____|_  /_______  /
#         \/         \/         \/                   \/         \/        \/ 
variable "region" {
  type    = string
  default = "us-west-2"
}
variable "instance_type" {
  type    = string
  default = "t2.micro"
}
variable "consul_version" {
  type    = string
  default = "1.16.0+ent"
}
variable "ami_id" {
  type    = string
  default = "ami-0ab193018f3e9351b"
}
variable "client_ami" {
  type    = string
  default = "ami-0507f77897697c4ba"
}
variable "comsul_servers_count" {
  type    = number
  default = 1
}
variable "apache_servers_count" {
  type    = number
  default = 1
}
variable "express_servers_count" {
  type    = number
  default = 1
}
variable "consul_license" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_id_a" {
  type = string
}
variable "subnet_id_b" {
  type = string
}
variable "security_group_id" {
  type = string
}
variable "iam_instance_profile_name" {
  type = string
}
# You will need to create this through AWS console or CLI
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html
variable "ssh_key_name" {
  type = string
}

resource "aws_launch_template" "sandcastle_consul" {
  name_prefix            = "sandcastle_consul"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [var.security_group_id]

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  metadata_options {
    http_tokens = "optional"
  }

  user_data = base64encode(templatefile("./startup.sh", {
    consul_license = var.consul_license
    consul_version = var.consul_version,
    servers_count  = var.comsul_servers_count
  }))
}

resource "aws_autoscaling_group" "sandcastle_consul" {
  name                = "sandcastle_consul"
  vpc_zone_identifier = [var.subnet_id_a, var.subnet_id_b]
  desired_capacity    = var.comsul_servers_count
  max_size            = 5
  min_size            = 0

  launch_template {
    id      = aws_launch_template.sandcastle_consul.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "sandcastle_consul"
    propagate_at_launch = true
  }

  tag {
    key                 = "consul"
    value               = "join"
    propagate_at_launch = true
  }
}

resource "aws_launch_template" "apache_servers" {
  name_prefix            = "apache_servers"
  image_id               = var.client_ami
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [var.security_group_id]

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  metadata_options {
    http_tokens = "optional"
  }

  user_data = base64encode(templatefile("./startup-apache.sh", {
    consul_version = var.consul_version,
    consul_license = var.consul_license
  }))
}

resource "aws_autoscaling_group" "apache_servers" {
  name                = "apache_servers"
  vpc_zone_identifier = [var.subnet_id_a, var.subnet_id_b]
  desired_capacity    = var.apache_servers_count
  max_size            = 5
  min_size            = 0

  launch_template {
    id      = aws_launch_template.apache_servers.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "apache_server"
    propagate_at_launch = true
  }
}

resource "aws_launch_template" "express_servers" {
  name_prefix            = "express_servers"
  image_id               = var.client_ami
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [var.security_group_id]

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  metadata_options {
    http_tokens = "optional"
  }

  user_data = base64encode(templatefile("./startup-express.sh", {
    consul_version = var.consul_version,
    consul_license = var.consul_license
  }))
}

resource "aws_autoscaling_group" "express_servers" {
  name                = "express_servers"
  vpc_zone_identifier = [var.subnet_id_a, var.subnet_id_b]
  desired_capacity    = var.express_servers_count
  max_size            = 5
  min_size            = 0

  launch_template {
    id      = aws_launch_template.express_servers.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "express_server"
    propagate_at_launch = true
  }
}