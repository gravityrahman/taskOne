terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region  = "us-east-1"
  profile = "default"

}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Project VPC"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

data "aws_availability_zones" "available_zones" {}

# private subnet
resource "aws_subnet" "private_subnet" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"

  tags = {
    Name = "private subnet"
  }
}

# public subnet
resource "aws_subnet" "public_subnet" {
  availability_zone       = data.aws_availability_zones.available_zones.names[0]
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public subnet"
  }
}

resource "aws_subnet" "public_subnet_2" {
  availability_zone       = data.aws_availability_zones.available_zones.names[1]
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public subnet 2"
  }
}

#elastic ip
resource "aws_eip" "ip" {
  depends_on = [aws_internet_gateway.gw]
}

#nat gateway
resource "aws_nat_gateway" "project" {
  allocation_id = aws_eip.ip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

#route table private
resource "aws_route_table" "private_subnet" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.project.id
  }


  tags = {
    Name = "private_route"
  }
}

#aws_route_table_association private
resource "aws_route_table_association" "private_subnet" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_subnet.id
}

#route table public
resource "aws_route_table" "public_subnet" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }


  tags = {
    Name = "public_route"
  }
}

#aws_route_table_association public
resource "aws_route_table_association" "pulic_subnet" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_subnet.id
}

# load balancer aws_security_group
resource "aws_security_group" "lb_sg" {
  name   = "allow lb"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "http access"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http access"
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#aws_lb_target_group_attachment
resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.test.arn
  target_id        = aws_instance.ec2_instance.id
}

#aws lb target group
resource "aws_lb_target_group" "test" {
  name     = "lb-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

#load balancer
resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_subnet.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection = false


  tags = {
    Name = "pSubnetLb"
  }
}


#aws aws_lb_listener
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}

# bastion security group
resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "allow  ports 22"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "http proxy access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


data "aws_ami" "ubuntu" {

  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

# bastion ec2_instance
resource "aws_instance" "bastion" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.bastion_sg.id]
  key_name        = "lampstack" #change this


  tags = {
    Name = "bastion_server"
  }
}

#web server ec2_instance security_groups
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "allow  ports 22"
  vpc_id      = aws_vpc.main.id

  # allow access on port 8080
  ingress {
    description     = "http proxy access"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  # allow access on port 22
  ingress {
    description     = "ssh access"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description     = "http access"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# web server ec2_instance
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = "lampstack" #change this
  user_data              = file("install_tomcat.sh")
  depends_on             = [aws_nat_gateway.project]

  tags = {
    Name = "tomcat"
  }
  
}
