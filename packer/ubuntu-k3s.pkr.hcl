// =============================================================================
// Packer - Mission 4 : préparation de l'image (AMI) commune aux noeuds du
// cluster K3s (control-plane + workers), à partir d'une image Ubuntu 22.04
// officielle Canonical sur AWS.
//
// Usage :
//   cd packer
//   packer init .
//   packer validate -var-file=variables.pkrvars.hcl .
//   packer build   -var-file=variables.pkrvars.hcl .
//
// L'AMI produite est ensuite référencée par Terraform (Mission 5) pour créer
// les instances EC2 du cluster.
// =============================================================================

packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type        = string
  description = "Région AWS dans laquelle construire l'AMI"
  default     = "eu-west-3"
}

variable "instance_type" {
  type        = string
  description = "Type d'instance EC2 utilisé uniquement le temps du build"
  default     = "t3.micro"
}

variable "mspr_ssh_public_key" {
  type        = string
  description = "Clé publique SSH (contenu du .pub) autorisée pour l'utilisateur 'mspr' sur les instances finales"
}

variable "ami_name_prefix" {
  type        = string
  description = "Préfixe du nom de l'AMI produite"
  default     = "mspr-k3s-node"
}

source "amazon-ebs" "k3s_node" {
  region          = var.aws_region
  instance_type   = var.instance_type
  ami_name        = "${var.ami_name_prefix}-{{timestamp}}"
  ami_description = "Image de base (Ubuntu 22.04) pour les noeuds du cluster K3s - MSPR COGIP/Odoo"

  # Image source officielle Canonical Ubuntu 22.04 LTS (amd64)
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  ssh_username = "ubuntu"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  tags = {
    Name    = "mspr-k3s-node"
    Project = "MSPR-COGIP-Odoo"
  }
}

build {
  name    = "ubuntu-k3s"
  sources = ["source.amazon-ebs.k3s_node"]

  provisioner "shell" {
    script = "scripts/provision.sh"
    environment_vars = [
      "MSPR_SSH_PUBLIC_KEY=${var.mspr_ssh_public_key}",
    ]
    execute_command = "chmod +x {{ .Path }}; sudo -E bash {{ .Path }}"
  }
}
