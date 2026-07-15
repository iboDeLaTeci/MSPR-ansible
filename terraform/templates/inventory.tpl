## Fichier généré automatiquement par Terraform (terraform apply) -- NE PAS
## éditer à la main, vos modifications seraient écrasées au prochain apply.
[k3s_control_plane]
${control_plane_public_ip} ansible_host=${control_plane_public_ip} private_ip=${control_plane_private_ip} ansible_user=${ssh_user} ansible_ssh_private_key_file=${ssh_private_key_path}

[k3s_workers]
%{ for w in workers ~}
${w.public_ip} ansible_host=${w.public_ip} private_ip=${w.private_ip} ansible_user=${ssh_user} ansible_ssh_private_key_file=${ssh_private_key_path}
%{ endfor ~}

[k3s_cluster:children]
k3s_control_plane
k3s_workers

[k3s_cluster:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
