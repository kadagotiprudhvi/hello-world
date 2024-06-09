terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.46.0"  # Ensure this version works with your modules
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

#creating vpc
resource "aws_vpc" "provpc" {
  cidr_block = "10.10.0.0/16"

  tags = {
     
    Name = "provpc"
  }
}

#creating internet_gateway
resource "aws_internet_gateway" "proig" {
  vpc_id = aws_vpc.provpc.id

  tags = {
    Name = "proig"
  }
}

#creating subnet in avalibitlity zone us-east-1a
resource "aws_subnet" "aval_1a_subnet" {
  vpc_id     = aws_vpc.provpc.id
  cidr_block = "10.10.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "aval_1a_subnet"
  }
}

#creating route table for aval-1a
resource "aws_route_table" "aval_1a_rt" {
  vpc_id = aws_vpc.provpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.proig.id
  }

  tags = {
    Name = "aval_1a_rt"
  }
}

#attaching public route table to avalabitlity zone 1a subnet 
resource "aws_route_table_association" "public_attach_1a" {
  subnet_id      = aws_subnet.aval_1a_subnet.id
  route_table_id = aws_route_table.aval_1a_rt.id
}

#creating security_group for instance
resource "aws_security_group" "prosg" {
  name   = "prosg"
  vpc_id = aws_vpc.provpc.id
  description = "security_group"

  ingress {
    description = "http from all internet"
    from_port = 3000
    to_port = 3000
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http from all internet"
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "http to all internet"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"] 
  }
}


resource "aws_instance" "first_instance" {
  ami           = "ami-04b70fa74e45c3917"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.aval_1a_subnet.id
  security_groups = [aws_security_group.prosg.id]
  tags = {
    Name = "FirstInstance"
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y npm
              # Add Docker's official GPG key:
              sudo apt-get update
              sudo apt-get install ca-certificates curl
              sudo install -m 0755 -d /etc/apt/keyrings
              sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
              sudo chmod a+r /etc/apt/keyrings/docker.asc
              
              # Add the repository to Apt sources:
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt-get update
              
              EOF
    key_name = "terraformkey"
    associate_public_ip_address = true
}
