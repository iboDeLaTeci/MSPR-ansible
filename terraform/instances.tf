# =============================================================================
# Instances EC2 : 1 control-plane + N workers (2 par défaut), construites à
# partir de l'AMI préparée par Packer (Mission 4).
# =============================================================================

resource "aws_instance" "control_plane" {
  ami                    = var.ami_id
  instance_type          = var.control_plane_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k3s_nodes.id]
  key_name               = var.key_name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.control_plane_root_volume_size
  }

  tags = {
    Name = "${var.project_name}-control-plane"
    Role = "k3s-control-plane"
  }
}

resource "aws_instance" "workers" {
  count                  = var.worker_count
  ami                    = var.ami_id
  instance_type          = var.worker_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k3s_nodes.id]
  key_name               = var.key_name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.worker_root_volume_size
  }

  tags = {
    Name = "${var.project_name}-worker-${count.index + 1}"
    Role = "k3s-worker"
  }
}
