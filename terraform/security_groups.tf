# =============================================================================
# Security Groups : accès SSH restreint, accès HTTP/HTTPS public (Ingress
# Odoo), API Kubernetes accessible depuis l'extérieur (pour piloter le
# cluster avec kubectl/Ansible), et tout le trafic ouvert entre les noeuds du
# cluster (Flannel VXLAN, kubelet, etc.).
# =============================================================================

resource "aws_security_group" "k3s_nodes" {
  name        = "${var.project_name}-k3s-nodes"
  description = "SG commun aux noeuds du cluster K3s (control-plane + workers)"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-k3s-nodes"
  }
}

# Accès SSH (Packer + Ansible)
resource "aws_security_group_rule" "ssh_in" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_ssh_cidr]
  security_group_id = aws_security_group.k3s_nodes.id
}

# API Kubernetes (kubectl / Ansible kubernetes.core depuis l'extérieur)
resource "aws_security_group_rule" "k8s_api_in" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_ssh_cidr]
  security_group_id = aws_security_group.k3s_nodes.id
}

# Ingress HTTP/HTTPS (accès à Odoo depuis l'extérieur)
resource "aws_security_group_rule" "http_in" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_https_cidr]
  security_group_id = aws_security_group.k3s_nodes.id
}

resource "aws_security_group_rule" "https_in" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_https_cidr]
  security_group_id = aws_security_group.k3s_nodes.id
}

# Tout le trafic entre les noeuds du cluster eux-mêmes (Flannel VXLAN 8472/udp,
# kubelet 10250, etc.) : on autorise l'ensemble du SG entre ses propres membres
# plutôt que de lister port par port chaque composant interne de K3s.
resource "aws_security_group_rule" "intra_cluster_all" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.k3s_nodes.id
  security_group_id        = aws_security_group.k3s_nodes.id
}

# Sortie libre (mises à jour de paquets, pull d'images de conteneurs, appels
# à l'API Helm/registries, etc.)
resource "aws_security_group_rule" "all_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s_nodes.id
}
