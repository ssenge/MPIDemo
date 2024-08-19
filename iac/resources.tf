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
  region     = var.region
  access_key = var.access_key_id
  secret_key = var.secret_access_key
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "my-key"
  public_key = file(var.public_key)
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow ephemeral ports for MPI connections
  # Note that this is a potential security risk for PROD systems, and should be locked down to specific IP ranges
  ingress {
    from_port   = 1024
    to_port     = 65535
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

data "aws_vpc" "default" {
  default = true
}

resource "aws_instance" "node" {
  ami                    = var.image_id
  instance_type          = var.instance_type
  count                  = var.instance_count
  key_name               = aws_key_pair.ssh_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  user_data = <<-EOF
            #!/bin/bash
            echo "${base64encode(file(var.private_key))}" | base64 -d > /home/ec2-user/.ssh/id_rsa
            chmod 400 /home/ec2-user/.ssh/id_rsa
            EOF

  connection {
    type        = "ssh"
    user        = var.user
    host        = self.public_ip
    private_key = file(var.private_key)
    agent       = false
    timeout     = "2m"
  }

  tags = {
    name = "MPI Test"
  }
}

resource "null_resource" "ansible_provision" {
  provisioner "local-exec" {
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }

    # Note this "join"-approach will likely fail for many instances (too long cmd line), then write to an inventory file first
    command = <<EOT
      ansible-playbook -i '${join(",", aws_instance.node[*].public_ip)},' -u ec2-user --private-key ${var.private_key} playbook.yml
    EOT
  }

  depends_on = [aws_instance.node]
}


