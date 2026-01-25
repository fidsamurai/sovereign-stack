//Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "private1" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = var.private1_cidr_block
  availability_zone = var.availability_zone_pri1
  tags = {
    Name = "private1",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_subnet" "private2" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = var.private2_cidr_block
  availability_zone = var.availability_zone_pri2
  tags = {
    Name = "private2",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_subnet" "public1" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = var.public1_cidr_block
  availability_zone = var.availability_zone_pub1
  tags = {
    Name = "public1",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_subnet" "public2" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = var.public2_cidr_block
  availability_zone = var.availability_zone_pub2
  tags = {
    Name = "public2",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "igw",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_eip" "nat" {
  count = var.env_prod ? 2 : 1
  domain = "vpc"
  tags = {
    Name = "nat-eip-${count.index}",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = 2
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
  tags = {
    Name = "public-rt-association-${count.index}",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_route_table" "private" {
  count = 2
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "private-rt-${count.index}"
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_route_table_association" "private" {
  count = 2
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
  tags = {
    Name = "private-rt-association-${count.index}",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_nat_gateway" "nat" {
  count = var.env_prod ? 2 : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id   = aws_subnet.public[count.index].id
  tags = {
    Name = "nat-${count.index}",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_ec2" "nat" {
  count = var.env_prod ? 1 : 0
  instance_type = var.nat_instance_type
  ami = var.nat_ami
  subnet_id = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.nat.id]
  source_dest_check = false
  tags = {
    Name = "nat-ec2",
    Env = var.env_prod ? "prod" : "dev"
  }
  user_data = base64encode(file("user_data.sh"))
}

resource "aws_eip_association" "nat" {
  count = var.env_prod ? 1:0
  instance_id = aws_ec2.nat.id
  allocation_id = aws_eip.nat.id
}

resource "aws_security_group" "nat" {
  name = "nat-sg"
  description = "Security group for NAT instance"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nat-sg",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_security_group" "ALB" {
  name = "alb-sg"
  description = "Security group for ALB"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_security_group" "RDS" {
  name = "rds-sg"
  description = "Security group for RDS"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_security_group" "Cplane" {
  name = "cplane-sg"
  description = "Security group for Cplane"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    from_port = 53
    to_port = 53
    protocol = "udp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    from_port = 53
    to_port = 53
    protocol = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    from_port = 179
    to_port = 179
    protocol = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    cidr_blocks = [var.cidr_block]
    ip_protocol = "4"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [var.cidr_block]
  }

  tags = {
    Name = "cplane-sg",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_security_group" "workers" {
  name = "workers-sg"
  description = "Security group for workers"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    from_port = 53
    to_port = 53
    protocol = "udp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    from_port = 53
    to_port = 53
    protocol = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    from_port = 179
    to_port = 179
    protocol = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    cidr_blocks = [var.cidr_block]
    ip_protocol = "4"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [var.cidr_block]
  }

  tags = {
    Name = "workers-sg",
    Env = var.env_prod ? "prod" : "dev"
  }
}
