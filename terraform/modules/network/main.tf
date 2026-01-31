//Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = var.env_prod ? "prod" : "dev",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_availability_zones)
  vpc_id = aws_vpc.vpc.id
  cidr_block = var.private_cidr_blocks[count.index]
  availability_zone = var.private_availability_zones[count.index]
  tags = {
    Name = "private-${count.index}",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_availability_zones)
  vpc_id = aws_vpc.vpc.id
  cidr_block = var.public_cidr_blocks[count.index]
  availability_zone = var.public_availability_zones[count.index]
  tags = {
    Name = "public-${count.index}",
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
    Name = "public-rt",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_route_table_association" "public" {
  count = 2
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = 2
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "private-rt-${count.index}",
    Env = var.env_prod ? "prod" : "dev"
  }
}

resource "aws_route_table_association" "private" {
  count = 2
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
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

resource "aws_instance" "nat" {
  count = var.env_prod ? 0 : 1
  instance_type = var.nat_instance_type
  ami = var.nat_ami
  subnet_id = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.nat.id]
  source_dest_check = false
  tags = {
    Name = "nat-ec2",
    Env = var.env_prod ? "prod" : "dev"
  }
  user_data_base64 = base64encode(file("user_data.sh"))
}

resource "aws_eip_association" "nat-instance" {
  count = var.env_prod ? 0:1
  instance_id = aws_instance.nat[0].id
  allocation_id = aws_eip.nat[0].id
}

resource "aws_nat_gateway_eip_association" "nat-gateway" {
  count = var.env_prod ? 2:0
  allocation_id = aws_eip.nat[count.index].id
  nat_gateway_id = aws_nat_gateway.nat[count.index].id
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
    protocol = "4"
    from_port = 0
    to_port = 0
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
    protocol = "4"
    from_port = 0
    to_port = 0
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
