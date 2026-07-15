# Copier ce fichier en "variables.pkrvars.hcl" (ignoré par git) et
# renseigner vos propres valeurs avant de lancer "packer build".
aws_region    = "eu-west-1"
instance_type = "t3.micro"

# Contenu de VOTRE clé publique SSH (ex: cat ~/.ssh/id_ed25519.pub)
mspr_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILcm+o/3BNuWQyaR8o3G25FeOafNCNePwTT5wI8StFUB mspr-ansible"
