data "aws_ami" "ubuntu" {
  most_recent = true
  # Official Canonical owner ID
  owners = ["099720109477"]

  filter {
    name   = "name"
    # Matches the standard naming convention for Ubuntu 24.04 LTS server images with hvm-ssd-gp3
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"] 
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_key_pair" "cplane" {
    key_name = "cplane"
    public_key = file(pathexpand("~/.ssh/${var.env_prod ? "prod" : "dev"}_cplane_${var.is_dr ? "dr" : "pri"}.pem.pub"))
}

resource aws_iam_policy "cplane" {
  name = "cplane"
  description = "Policy for cplane instances"
  policy = jsonencode({ 
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "InfrastructureDiscovery",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeRegions",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVolumes",
                "ec2:DescribeVpcs",
                "ec2:DescribeAvailabilityZones"
            ],
            "Resource": "*"
        },
        {
            "Sid": "NetworkAndVolumeManagement",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateRoute",
                "ec2:DeleteRoute",
                "ec2:ModifyInstanceAttribute",
                "ec2:AttachVolume",
                "ec2:DetachVolume"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:instance/*",
                "arn:aws:ec2:*:*:volume/*",
                "arn:aws:ec2:*:*:route-table/*"
            ]
        },
        {
            "Sid": "BasicNodeHealth",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ssm:UpdateInstanceInformation",
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
  })
}

resource "aws_iam_role" "cplane" {
  name = "cplane"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "cplane" {
  name = "cplane"
  role = aws_iam_role.cplane.name
}

resource "aws_launch_template" "cplane" {
  name = "cplane"
  image_id = data.aws_ami.ubuntu.id
  iam_instance_profile {name = aws_iam_instance_profile.cplane.name}
  key_name = aws_key_pair.cplane.key_name
  vpc_security_group_ids = [var.cplane-sg-id]
  user_data = base64encode(file("${path.module}/cluster_join.tftpl"))
}

resource "aws_autoscaling_group" "cplane" {
  name = "cplane"
 
  min_size = 1
  max_size = var.env_prod ? 3 : 1
  desired_capacity = 1
  vpc_zone_identifier = var.private_subnet_ids

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.cplane.id
        version = "$Latest"
      }
      override {
        instance_requirements {
          memory_mib {
            min = var.asg-cplane-min-memory-mib
            max = var.asg-cplane-max-memory-mib
          }
          vcpu_count {
            min = var.asg-cplane-min-vcpu-count
            max = var.asg-cplane-max-vcpu-count
          }
        }
      }
    }    
  }

  lifecycle {
    ignore_changes = [desired_capacity, max_size]
  }
}

resource "aws_key_pair" "workers" {
  key_name = "workers"
  public_key = file(pathexpand("~/.ssh/${var.env_prod ? "prod" : "dev"}_worker_${var.is_dr ? "dr" : "pri"}.pem.pub"))
}

resource "aws_launch_template" "workers" {
  name = "workers"
  image_id = data.aws_ami.ubuntu.id
  key_name = aws_key_pair.workers.key_name
  vpc_security_group_ids = [var.workers-sg-id]
  user_data = base64encode(file("${path.module}/cluster_join.tftpl"))
}

resource "aws_autoscaling_group" "workers" {
  name = "workers"
 
  min_size = 1
  max_size = 3
  desired_capacity = 1
  vpc_zone_identifier = var.private_subnet_ids

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.workers.id
        version = "$Latest"
      }
      override {
        instance_requirements {
          memory_mib {
            min = var.asg-workers-min-memory-mib
            max = var.asg-workers-max-memory-mib
          }
          vcpu_count {
            min = var.asg-workers-min-vcpu-count
            max = var.asg-workers-max-vcpu-count
          }
        }

      }
    }
    instances_distribution {
      on_demand_base_capacity = 0
      spot_allocation_strategy = "price-capacity-optimized"
    } 
  }  

  lifecycle {
    ignore_changes = [desired_capacity, max_size]
  }
}

resource "aws_key_pair" "jump" {
  key_name = "jump"
  public_key = file(pathexpand("~/.ssh/${var.env_prod ? "prod" : "dev"}_jump_${var.is_dr ? "dr" : "pri"}.pem.pub"))
}

resource "aws_eip" "jump" {
  domain = "vpc"
}

resource "aws_launch_template" "jump" {
  name = "jump-server"
  image_id = data.aws_ami.ubuntu.id
  key_name = aws_key_pair.jump.key_name
  vpc_security_group_ids = [var.jump-sg-id]
  user_data = base64encode(templatefile("jump.tftpl", {
    allocation_id = aws_eip.jump.id
    jump_ip = aws_eip.jump.public_ip
    jump_pem_name = aws_key_pair.jump.key_name
    jump_pem = file(pathexpand("~/.ssh/${var.env_prod ? "prod" : "dev"}_jump_${var.is_dr ? "dr" : "pri"}.pem"))
  }))
}


resource "aws_autoscaling_group" "jump" {
  name = "jump-server"
 
  min_size = 1
  max_size = 1
  desired_capacity = 1
  vpc_zone_identifier = var.public_subnet_ids

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.jump.id
        version = "$Latest"
      }
      override {
        instance_requirements {
          cpu_manufacturers = ["amazon-web-services"]
          memory_mib {
            min = 4096
            max = 4096
          }
          vcpu_count {
            min = 2
            max = 2
          }
        }
      }
    }
    instances_distribution {
      on_demand_base_capacity = 0
      spot_allocation_strategy = "price-capacity-optimized"
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity, max_size]
  }
}