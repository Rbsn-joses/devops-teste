terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"
  shared_config_files      = ["${var.HOME}/.aws/config"]
  shared_credentials_files = ["${var.HOME}/.aws/credentials"]
}
data "aws_vpc" "default" {
 default = true
}


resource "aws_security_group" "http_access" {
  name        = "http_access"
  description = "teste devops"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "devops-teste"
  public_key = tls_private_key.ssh_key.public_key_openssh

  provisioner "local-exec" {    
    command = <<-EOT
      echo '${tls_private_key.ssh_key.private_key_pem}' > ./'${var.generated_key_name}'.pem
      chmod 400 ./'${var.generated_key_name}'.pem
    EOT
  }

}

resource "aws_instance" "app_server" {
  ami           = "ami-0b72821e2f351e396"
  instance_type = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.http_access.id]
  key_name      = "devops-teste"
  user_data = <<-EOF
        #!/bin/bash
        sudo yum update -y
        sudo yum install -y docker
        sudo service docker start
        sudo usermod -aG docker ec2-user
              EOF

  tags = {
    Name = "app-teste-devops"
  }
}
