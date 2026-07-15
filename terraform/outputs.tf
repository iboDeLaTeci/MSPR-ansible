# =============================================================================
# Outputs : IPs utiles + génération automatique de l'inventaire Ansible
# consommé par le playbook Mission 6 (playbooks/deploy_k3s_cluster.yml).
# =============================================================================

output "control_plane_public_ip" {
  description = "IP publique du control-plane K3s"
  value       = aws_instance.control_plane.public_ip
}

output "control_plane_private_ip" {
  description = "IP privée du control-plane K3s (utilisée pour la jonction des workers)"
  value       = aws_instance.control_plane.private_ip
}

output "worker_public_ips" {
  description = "IPs publiques des workers K3s"
  value       = aws_instance.workers[*].public_ip
}

output "odoo_kubeconfig_hint" {
  description = "Rappel : une fois le cluster déployé (mission 6), pointer group_vars/all.yml -> kubeconfig_path vers le fichier généré par le playbook deploy_k3s_cluster.yml"
  value       = "kubeconfig attendu après la mission 6 Ansible, cf. README.md"
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    control_plane_public_ip  = aws_instance.control_plane.public_ip
    control_plane_private_ip = aws_instance.control_plane.private_ip
    workers                  = aws_instance.workers
    ssh_user                 = var.ssh_user
    ssh_private_key_path     = var.ssh_private_key_path
  })
  filename = "${path.module}/../inventory/k3s_hosts.ini"
}
