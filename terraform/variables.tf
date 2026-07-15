# =============================================================================
# Variables Terraform - Mission 5 (provisionnement de l'infrastructure AWS)
# =============================================================================

variable "aws_region" {
  type        = string
  description = "Région AWS où déployer l'infrastructure"
  default     = "eu-west-1"
}

variable "project_name" {
  type        = string
  description = "Préfixe utilisé pour nommer/tagger toutes les ressources"
  default     = "mspr-cogip"
}

variable "ami_id" {
  type        = string
  description = "ID de l'AMI construite par Packer (mission 4), ex: ami-0123456789abcdef0"
}

variable "key_name" {
  type        = string
  description = "Nom de la paire de clés EC2 (Key Pair) existante dans AWS, utilisée pour l'accès SSH de secours"
}

variable "vpc_cidr" {
  type        = string
  description = "Plage d'adresses du VPC"
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "Plage d'adresses du sous-réseau public hébergeant le cluster"
  default     = "10.42.1.0/24"
}

variable "availability_zone" {
  type        = string
  description = "Zone de disponibilité du sous-réseau public"
  default     = "eu-west-1a"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "Plage IP autorisée à se connecter en SSH (mettre VOTRE IP publique en /32, jamais 0.0.0.0/0 en usage réel)"
  default     = "0.0.0.0/0"
}

variable "allowed_https_cidr" {
  type        = string
  description = "Plage IP autorisée à accéder à Odoo en HTTP/HTTPS (80/443)"
  default     = "0.0.0.0/0"
}

variable "control_plane_instance_type" {
  type        = string
  description = "Type d'instance EC2 du control-plane K3s (min. cahier des charges : 2 vCPU / 2 Go RAM)"
  default     = "t3.small"
}

variable "worker_instance_type" {
  type        = string
  description = "Type d'instance EC2 des workers K3s (min. cahier des charges : 2 vCPU / 4 Go RAM recommandé, Odoo est gourmand)"
  default     = "t3.medium"
}

variable "worker_count" {
  type        = number
  description = "Nombre de workers K3s à provisionner"
  default     = 2
}

variable "control_plane_root_volume_size" {
  type        = number
  description = "Taille du disque racine du control-plane (Go)"
  default     = 20
}

variable "worker_root_volume_size" {
  type        = number
  description = "Taille du disque racine de chaque worker (Go)"
  default     = 30
}

variable "ssh_user" {
  type        = string
  description = "Utilisateur SSH créé par Packer dans l'AMI"
  default     = "mspr"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Chemin local vers la clé privée SSH correspondant à mspr_ssh_public_key utilisée dans Packer, pour générer l'inventaire Ansible"
  default     = "~/.ssh/id_ed25519"
}
