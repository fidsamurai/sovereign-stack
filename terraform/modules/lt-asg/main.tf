data "aws_ami" "ubuntu" {
  most_recent = true
  # Official Canonical owner ID
  owner_id    = "099720109477" 

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
    name = cplane
    public_key = file("~/.ssh/cplane.pem.pub")
}

resource "aws_launch_template" "cplane" {
  name = cplane
  image_id = aws_ami.ubuntu.id
  iam_instance_profile = var.lt_cplane_iam_instance_profile
  key_name = cplane
  vpc_security_group_ids = [aws_security_group.cplane.id]  
}

resource "aws_autoscaling_group" "cplane" {
    name = cplane
 
    min_size = 1
    max_size = var.env_prod ? 3 : 1
    desired_capacity = 1
    vpc_zone_identifier = [aws_subnet.private1.id, aws_subnet.private2.id]

    mixed_instances_policy {
      launch_template {
        id = aws_launch_template.cplane.id
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

resource "aws_key_pair" "workers" {
  name = workers
  public_key = file("~/.ssh/workers.pem.pub")
}

resource "aws_launch_template" "workers" {
  name = workers
  image_id = aws_ami.ubuntu.id
  iam_instance_profile = var.lt_workers_iam_instance_profile
  key_name = workers
  vpc_security_group_ids = [aws_security_group.workers.id]
  user_data = base64encode(file("${path.module}/cluster_join.sh"))
}

resource "aws_autoscaling_group" "workers" {
    name = workers
 
    min_size = 1
    max_size = 3
    desired_capacity = 1
    vpc_zone_identifier = [aws_subnet.private1.id, aws_subnet.private2.id]

    mixed_instances_policy {
      launch_template {
        id = aws_launch_template.workers.id
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
}