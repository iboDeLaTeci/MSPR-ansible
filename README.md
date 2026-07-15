# MSPR-ansible — Infrastructure as Code : cluster K3s + Odoo + HTTPS/SSL

Ce dépôt contient l'ensemble de l'Infrastructure as Code de la MSPR "Gérer un
projet d'infrastructures virtualisées" pour la société fictive COGIP :

| Mission du sujet | Outil | Dossier |
|---|---|---|
| Mission 4 — Préparation de l'image | Packer | `packer/` |
| Mission 5 — Provisionnement de l'infra | Terraform | `terraform/` |
| Mission 6 — Déploiement du cluster K3s | Ansible | `roles/k3s_cluster/`, `playbooks/deploy_k3s_cluster.yml` |
| Mission 7 — Déploiement d'Odoo + Ingress HTTPS | Ansible | `roles/odoo*`, `roles/ingress_nginx`, `roles/cert_manager`, `playbooks/deploy_odoo.yml`, `playbooks/configure_https.yml` |

## Mission 1 — Choix des technologies et justification

- **Infrastructure d'hébergement : AWS (EC2)**. Choix retenu pour ce PoC afin
  de garantir un accès public reproductible sans dépendre du matériel du
  campus ; les instances utilisées (`t3.small`/`t3.medium`) restent proches
  du seuil gratuit/faible coût. Le code Terraform reste isolé dans son propre
  provider (`terraform/versions.tf`) : basculer vers un autre cloud ou un
  hyperviseur (Proxmox, VMware) ne nécessiterait de réécrire que ce dossier.
- **Distribution Kubernetes : K3s**. C'est la distribution recommandée en
  premier par le sujet : elle embarque un LoadBalancer (ServiceLB/Klipper) et
  un Ingress (Traefik, ici désactivé) directement intégrés, ce qui simplifie
  fortement la Mission 6 — un simple script d'installation officiel suffit,
  pas besoin de déployer CNI/LoadBalancer séparément comme avec RKE2/K0S.
- **Packer** : construit une AMI Ubuntu 22.04 unique, commune au
  control-plane et aux workers (paquets, utilisateur `mspr`, durcissement
  SSH, règles de pare-feu locales). Cela évite de reconfigurer chaque
  instance individuellement et rend les déploiements reproductibles.
- **Terraform (provider AWS)** : provisionne le réseau (VPC dédié, subnet
  public, IGW), les security groups, et les 3 instances EC2 à partir de
  l'AMI Packer. Génère automatiquement l'inventaire Ansible en sortie
  (`local_file` + `templatefile`), pour enchaîner directement avec Ansible.
- **Ansible + module `kubernetes.core`** : pilote l'installation de K3s par
  SSH (Mission 6), puis le déploiement applicatif via l'API Kubernetes
  (Mission 7), sans jamais utiliser `kubectl`/`helm` en ligne de commande
  manuelle — tout est déclaratif et rejouable.
- **Helm (charts Bitnami/ingress-nginx/Jetstack) piloté par
  `kubernetes.core.helm`** : réutilise des charts communautaires maintenus
  plutôt que de réécrire des manifests Kubernetes bruts pour des briques
  standards (Odoo+PostgreSQL, contrôleur Ingress, cert-manager).
- **cert-manager + `ClusterIssuer` autosigné** : le sujet accepte
  explicitement les certificats autosignés pour ce PoC ; pas besoin de
  Let's Encrypt (qui exigerait un nom de domaine public résolu et le port 80
  ouvert à Internet pour le challenge HTTP-01).

## Prérequis généraux

- Un compte AWS avec des credentials configurés (`aws configure` ou
  variables d'environnement `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`).
- Une paire de clés SSH (`ssh-keygen`) dédiée au projet.
- `packer`, `terraform`, `ansible` installés en local.
- Sur le control node Ansible : Python 3 + le paquet `kubernetes`
  (`pip install kubernetes`), le binaire `helm`, et la collection
  `kubernetes.core` :
  ```bash
  ansible-galaxy collection install -r requirements.yml
  ```

## Structure du dépôt

```
packer/
  ubuntu-k3s.pkr.hcl              # Mission 4 : AMI Ubuntu 22.04 pour les noeuds K3s
  scripts/provision.sh              # paquets, user mspr, durcissement SSH, pare-feu
  variables.pkrvars.hcl.example      # à copier en variables.pkrvars.hcl

terraform/
  network.tf, security_groups.tf, instances.tf, variables.tf, outputs.tf
  templates/inventory.tpl            # génère inventory/k3s_hosts.ini
  terraform.tfvars.example            # à copier en terraform.tfvars

ansible.cfg
requirements.yml                       # collection kubernetes.core
inventory/
  hosts.ini                            # hôte "localhost" (missions 7, pilotage via API k8s)
  k3s_hosts.ini                        # généré par "terraform apply" (missions 6, SSH) - non versionné
group_vars/all.yml                      # toutes les variables à adapter au contexte
roles/
  k3s_cluster/                         # installation K3s server/agent (mission 6)
  odoo/                                # installation Odoo + PostgreSQL (Helm, mission 7)
  ingress_nginx/                       # contrôleur Ingress NGINX (Helm, mission 7)
  cert_manager/                        # cert-manager + ClusterIssuer autosigné (Helm, mission 7)
  odoo_ingress/                        # Certificate + Ingress HTTPS pour Odoo (mission 7)
playbooks/
  deploy_k3s_cluster.yml                # mission 6
  deploy_odoo.yml                       # mission 7 (a)
  configure_https.yml                    # mission 7 (b)
  site.yml                               # les 3 playbooks ci-dessus, dans l'ordre
```

## Utilisation — pipeline complet

### 1. Packer — construire l'image des noeuds (Mission 4)

```bash
cd packer
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
# éditer variables.pkrvars.hcl : région AWS + VOTRE clé publique SSH
packer init .
packer build -var-file=variables.pkrvars.hcl .
# noter l'ID de l'AMI affiché en fin de build (ami-xxxxxxxxxxxxxxxxx)
```

### 2. Terraform — provisionner l'infrastructure (Mission 5)

```bash
cd ../terraform
cp terraform.tfvars.example terraform.tfvars
# éditer terraform.tfvars : ami_id (sortie de Packer), key_name (Key Pair AWS existante),
# allowed_ssh_cidr (VOTRE IP publique en /32), ssh_private_key_path
terraform init
terraform apply
```

Cela crée le VPC, les security groups, les 3 instances EC2, et génère
automatiquement `../inventory/k3s_hosts.ini` avec les IPs des 3 machines.

### 3. Ansible — déployer le cluster K3s (Mission 6)

```bash
cd ..
ansible-playbook playbooks/deploy_k3s_cluster.yml
```

À la fin de ce playbook, le kubeconfig du cluster est rapatrié localement
vers le chemin défini par `kubeconfig_path` (`group_vars/all.yml`).

### 4. Ansible — déployer Odoo et configurer HTTPS (Mission 7)

```bash
ansible-playbook playbooks/deploy_odoo.yml
ansible-playbook playbooks/configure_https.yml
```

### Ou tout enchaîner d'un coup (missions 6 et 7)

```bash
ansible-playbook playbooks/site.yml
```

Une fois `configure_https.yml` terminé, ajoutez une entrée dans `/etc/hosts`
(ou dans votre DNS) pointant `odoo_domain` (par défaut `odoo.mspr.local`)
vers l'IP publique du control-plane K3s (le LoadBalancer de K3s expose
l'Ingress directement sur les IPs des noeuds) :

```bash
terraform -chdir=terraform output control_plane_public_ip
echo "<IP_PUBLIQUE>  odoo.mspr.local" | sudo tee -a /etc/hosts
```

Odoo sera alors accessible sur `https://odoo.mspr.local`. Le certificat étant
**autosigné** (conforme au sujet), le navigateur affichera un avertissement de
sécurité qu'il faudra accepter manuellement.

## Ce qu'il faut changer avant de lancer / pour que tout fonctionne

### Packer / Terraform (Missions 4-5)

1. **`packer/variables.pkrvars.hcl`** : `mspr_ssh_public_key` doit contenir
   VOTRE clé publique SSH (pas celle d'exemple).
2. **`terraform/terraform.tfvars`** :
   - `ami_id` : l'AMI réellement construite par Packer (elle change à
     chaque build, pensez à la mettre à jour).
   - `key_name` : le nom d'une **Key Pair EC2 déjà créée** dans la région
     ciblée (console AWS ou `aws ec2 create-key-pair`).
   - `allowed_ssh_cidr` : restreignez à votre IP publique en `/32` — la
     valeur par défaut `0.0.0.0/0` ouvre le SSH et l'API Kubernetes (port
     6443) à tout Internet.
   - `ssh_private_key_path` : chemin vers la clé privée correspondant à
     `mspr_ssh_public_key`, utilisée pour générer l'inventaire Ansible.
3. Ces deux fichiers (`variables.pkrvars.hcl`, `terraform.tfvars`) sont
   volontairement **exclus du dépôt** (`.gitignore`) car ils référencent des
   éléments spécifiques à votre environnement/compte AWS.

### Ansible (Missions 6-7)

Tout est centralisé dans **`group_vars/all.yml`** :

1. **Mots de passe** : `odoo_admin_password` et `postgresql_admin_password`
   sont des valeurs de démo (`ChangeMe...`) — à remplacer par des valeurs
   fortes. Idéalement, chiffrez-les avec **Ansible Vault** plutôt que de les
   laisser en clair :
   ```bash
   ansible-vault encrypt_string 'MonMotDePasseFort' --name 'odoo_admin_password'
   ```
2. **`odoo_domain`** : remplacez `odoo.mspr.local` par le nom de domaine
   réellement utilisé, et assurez-vous qu'il résout vers l'IP publique du
   control-plane (DNS réel, ou `/etc/hosts` pour un test local).
3. **`odoo_storage_class`** : laissez vide (`""`) pour utiliser la
   StorageClass par défaut du cluster (EBS via le driver par défaut de K3s
   n'existe pas nativement : par défaut K3s utilise le stockage local du
   noeud via `local-path-provisioner`, suffisant pour ce PoC).
4. **Versions des charts** (`odoo_chart_version`, `ingress_nginx_chart_version`,
   `cert_manager_chart_version`) : les valeurs par défaut fonctionnent, mais
   pour un rendu reproductible, il est recommandé d'épingler des versions
   précises testées dans votre environnement.
5. **Dimensionnement** (`odoo_resources`, `odoo_persistence_size`,
   `postgresql_persistence_size`, types d'instances Terraform) : à ajuster
   selon vos besoins réels.
6. **`kubeconfig_path`** : rempli automatiquement par
   `deploy_k3s_cluster.yml` — à ne modifier que si vous réutilisez un
   cluster existant (non créé par ce dépôt).

### Vérifications après déploiement

```bash
export KUBECONFIG=~/.kube/mspr-k3s-config
kubectl get nodes
kubectl -n odoo get pods,svc,ingress
kubectl -n odoo get certificate
kubectl -n cert-manager get pods
kubectl -n ingress-nginx get pods,svc
```

Si le `Certificate` reste à `Ready: False`, vérifiez les logs de cert-manager
(`kubectl -n cert-manager logs deploy/cert-manager`) et que le
`ClusterIssuer` `selfsigned-issuer` est bien `Ready`
(`kubectl get clusterissuer selfsigned-issuer -o yaml`).

## Nettoyage

Pour détruire l'infrastructure AWS et éviter des frais inutiles :

```bash
cd terraform
terraform destroy
```

## Limites connues / non couvert par ce dépôt

- Pas de haute disponibilité (1 seul control-plane), conforme au minimum
  demandé par le sujet pour cette MSPR.
- Pas de sauvegarde/PRA automatisé (mentionné dans le sujet comme axe
  d'amélioration possible, non implémenté ici).
- Le stockage persistant utilise le `local-path-provisioner` intégré à K3s
  (stockage local au noeud, non répliqué) — suffisant pour un PoC, à
  remplacer par une solution répliquée (Longhorn, EBS CSI driver) en
  production.
