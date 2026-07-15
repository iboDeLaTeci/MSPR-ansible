#!/usr/bin/env bash
# =============================================================================
# Script de provisioning Packer : prépare l'image (AMI) commune aux 3 noeuds
# du cluster K3s (control-plane + workers).
#
# Objectif : "cuire" dans l'image tout ce qui est identique sur tous les
# noeuds (paquets, utilisateur, durcissement) pour que Terraform n'ait plus
# qu'à démarrer des instances prêtes à l'emploi, et qu'Ansible se limite au
# rôle spécifique de chaque noeud (installation de K3s en server ou agent).
# =============================================================================
set -euxo pipefail

# --- Mise à jour du système et paquets nécessaires ---------------------------
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y \
  curl \
  ca-certificates \
  apt-transport-https \
  gnupg \
  unzip \
  jq \
  open-iscsi \
  nfs-common \
  python3

# open-iscsi et nfs-common : requis par certaines classes de stockage
# Kubernetes (Longhorn, nfs-subdir-external-provisioner) même si non
# utilisées immédiatement dans ce PoC ; les avoir en image évite un
# redéploiement ultérieur.

# --- Création de l'utilisateur d'administration -----------------------------
# Utilisateur dédié (plutôt que le compte "ubuntu" par défaut) sur lequel
# Ansible se connectera en SSH par clé, avec sudo sans mot de passe.
sudo useradd --create-home --shell /bin/bash mspr || true
sudo usermod -aG sudo mspr
echo "mspr ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-mspr
sudo chmod 440 /etc/sudoers.d/90-mspr


# La clé publique à autoriser est injectée par Packer via la variable
# d'environnement MSPR_SSH_PUBLIC_KEY (voir ubuntu-k3s.pkr.hcl). On n'utilise
# volontairement PAS la clé éphémère de build de Packer (copiée sur le compte
# "ubuntu" le temps du build) : elle est révoquée après le build et ne doit
# pas se retrouver figée dans l'image.
: "${MSPR_SSH_PUBLIC_KEY:?La variable MSPR_SSH_PUBLIC_KEY doit être définie}"

sudo mkdir -p /home/mspr/.ssh
echo "${MSPR_SSH_PUBLIC_KEY}" | sudo tee /home/mspr/.ssh/authorized_keys > /dev/null
sudo chown -R mspr:mspr /home/mspr/.ssh
sudo chmod 700 /home/mspr/.ssh
sudo chmod 600 /home/mspr/.ssh/authorized_keys

# --- Durcissement SSH ---------------------------------------------------------
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# --- Pare-feu local : ports nécessaires au fonctionnement de K3s -------------
sudo apt-get install -y ufw
sudo ufw allow OpenSSH
sudo ufw allow 6443/tcp   # API server Kubernetes
sudo ufw allow 80/tcp     # Ingress HTTP
sudo ufw allow 443/tcp    # Ingress HTTPS
sudo ufw allow 8472/udp   # Flannel VXLAN (inter-noeuds)
sudo ufw allow 10250/tcp  # kubelet
sudo ufw --force enable

# --- Nettoyage avant la capture de l'image -----------------------------------
sudo apt-get autoremove -y
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*
sudo cloud-init clean --logs || true
sudo truncate -s 0 /etc/machine-id || true
