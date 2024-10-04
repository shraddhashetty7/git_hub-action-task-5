terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

# New variable to hold the public SSH key
variable "ssh_public_key" {
  type = string
}

# Create a new key pair in AWS
resource "aws_key_pair" "Githubactions_keypair" {
  key_name   = "Githubactions_keypair"
  public_key = var.ssh_public_key  # Use the public key from the GitHub secret
}

# Create a Security Group
resource "aws_security_group" "Githubactions_SG" {
  name        = "Githubactions_SG"
  description = "Allow inbound SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Ensure this is intentional (allows any IP)
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Githubactions_SG"
  }
}

# Create an EC2 Instance with Default Root Volume
resource "aws_instance" "Githubactions-EC2" {
  ami           = "ami-0866a3c8686eaeeba"  # Ensure this AMI is valid for your region
  instance_type = "t2.medium"
  key_name      = aws_key_pair.Githubactions_keypair.key_name

  root_block_device {
    volume_size = 40      # Default size (adjust if needed)
    volume_type = "gp2"   # General Purpose SSD
  }

  tags = {
    Name = "Githubactions-EC2"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update
    sudo apt upgrade -y
    sudo apt install curl -y
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
    node -v
    npm -v
    sudo apt update
    sudo npm install @medusajs/medusa-cli -g
    medusa --version
    medusa new my-medusa-store
    cd my-medusa-store
    npm install
    sudo apt install postgresql postgresql-contrib -y
    sudo service postgresql start
    sudo -u postgres psql -c "CREATE DATABASE medusa_db;"
    sudo -u postgres psql -c "CREATE USER medusa WITH PASSWORD 'medusa@123';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE medusa_db TO medusa;"
    echo "DATABASE_URL=postgres://medusa:medusa@123@localhost:5432/medusa_db" >> .env
    sudo chmod 644 .env
    npm run seed
    npx medusa user -e "dhanyak.dk@gmail.com" -p supersect
    npm run start

  EOF


  associate_public_ip_address = true

  # Define dependencies on security group
  vpc_security_group_ids = [aws_security_group.Githubactions_SG.id]
}