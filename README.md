# MSPR-ansible — Déploiement Odoo + HTTPS/SSL sur Kubernetes

Ce dépôt contient la partie Ansible de la MSPR "Gérer un projet d'infrastructures
virtualisées" (Mission 7 du cahier des charges) :

- **Installation et configuration d'Odoo** via le module `kubernetes.core.helm`
  (chart Helm Bitnami, avec PostgreSQL embarqué).
- **Configuration HTTPS + certificat SSL** via `cert-manager` (certificat
  autosigné, accepté par le sujet) et un `Ingress` NGINX.

## Prérequis

- Un cluster Kubernetes déjà opérationnel (control-plane + 2 workers, cf.
  Mission 6 du sujet), avec un fichier **kubeconfig** valide.
- Sur le control node Ansible :
  - Python 3 + le paquet `kubernetes` (`pip install kubernetes`)
  - Le binaire **`helm`** installé et dans le `PATH`
  - Ansible + la collection `kubernetes.core` :
    ```bash
    ansible-galaxy collection install -r requirements.yml
    ```

## Structure du dépôt

```
ansible.cfg
requirements.yml          # collection kubernetes.core
inventory/hosts.ini        # un seul hôte "localhost" (pilotage via API k8s)
group_vars/all.yml          # toutes les variables à adapter au contexte
roles/
  odoo/                    # installation Odoo + PostgreSQL (Helm)
  ingress_nginx/           # contrôleur Ingress NGINX (Helm)
  cert_manager/             # cert-manager + ClusterIssuer autosigné (Helm)
  odoo_ingress/             # Certificate + Ingress HTTPS pour Odoo
playbooks/
  deploy_odoo.yml            # installation/config d'Odoo
  configure_https.yml         # ingress-nginx + cert-manager + HTTPS Odoo
  site.yml                    # les deux playbooks ci-dessus, dans l'ordre
```

## Utilisation

```bash
# 1) Installer et configurer Odoo sur le cluster
ansible-playbook playbooks/deploy_odoo.yml

# 2) Mettre en place l'accès HTTPS (ingress-nginx + cert-manager + certificat)
ansible-playbook playbooks/configure_https.yml

# Ou les deux d'un coup :
ansible-playbook playbooks/site.yml
```

Une fois `configure_https.yml` terminé, ajoutez une entrée dans `/etc/hosts`
(ou dans votre DNS) pointant `odoo_domain` (par défaut `odoo.mspr.local`)
vers l'IP externe du `Service` `ingress-nginx-controller` :

```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller
# puis, en local :
echo "<IP_EXTERNE>  odoo.mspr.local" | sudo tee -a /etc/hosts
```

Odoo sera alors accessible sur `https://odoo.mspr.local`. Le certificat étant
**autosigné** (conforme au sujet), le navigateur affichera un avertissement de
sécurité qu'il faudra accepter manuellement.

## Ce qu'il faut changer avant de lancer / pour que tout fonctionne

Tout est centralisé dans **`group_vars/all.yml`**, mais voici concrètement ce
qui doit être adapté à votre environnement :

1. **`kubeconfig_path`** : chemin vers le kubeconfig de votre cluster réel
   (celui généré à la Mission 6, ou celui de votre cluster managé cloud).
2. **Mots de passe** : `odoo_admin_password` et `postgresql_admin_password`
   sont des valeurs de démo (`ChangeMe...`) — à remplacer par des valeurs
   fortes. Idéalement, chiffrez-les avec **Ansible Vault** plutôt que de les
   laisser en clair dans `group_vars/all.yml` :
   ```bash
   ansible-vault encrypt_string 'MonMotDePasseFort' --name 'odoo_admin_password'
   ```
3. **`odoo_domain`** : remplacez `odoo.mspr.local` par le nom de domaine (ou
   sous-domaine) réellement utilisé, et assurez-vous qu'il résout vers l'IP
   de l'Ingress (DNS réel, ou `/etc/hosts` pour un test local).
4. **`ingress_nginx_service_type`** :
   - `LoadBalancer` si vous êtes sur un cloud managé (GKE/AKS/EKS) ou si
     **MetalLB** est déjà déployé sur votre cluster bare-metal (K0S/RKE2).
   - `NodePort` si vous n'avez pas de LoadBalancer disponible en bare-metal.
5. **`odoo_storage_class`** : laissez vide (`""`) pour utiliser la
   StorageClass par défaut du cluster. Si vous utilisez
   `nfs-subdir-external-provisioner` (recommandation du sujet pour le
   bare-metal), renseignez le nom de la StorageClass qu'il expose (souvent
   `nfs-client`), sauf si vous l'avez définie comme classe par défaut.
6. **Versions des charts** (`odoo_chart_version`, `ingress_nginx_chart_version`,
   `cert_manager_chart_version`) : les valeurs par défaut fonctionnent, mais
   pour un rendu reproductible (demandé par le sujet), il est recommandé
   d'épingler des versions précises testées dans votre environnement.
7. **Dimensionnement** (`odoo_resources`, `odoo_persistence_size`,
   `postgresql_persistence_size`) : à ajuster selon les ressources réelles de
   vos workers (le sujet recommande 2 vCPU / 4 Go RAM par worker minimum).

### Vérifications après déploiement

```bash
kubectl -n odoo get pods,svc,ingress
kubectl -n odoo get certificate
kubectl -n cert-manager get pods
kubectl -n ingress-nginx get pods,svc
```

Si le `Certificate` reste à `Ready: False`, vérifiez les logs de cert-manager
(`kubectl -n cert-manager logs deploy/cert-manager`) et que le
`ClusterIssuer` `selfsigned-issuer` est bien `Ready`
(`kubectl get clusterissuer selfsigned-issuer -o yaml`).
