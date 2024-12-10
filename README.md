# abesstp-docker

Configuration docker 🐳 pour déployer l'application [AbesStp](https://stp.abes.fr) (outil de ticketing de l'Abes)

![](https://docs.google.com/drawings/d/e/2PACX-1vT7cxu8j95PuHJ7VGMf5XxQ7C3WyHUYcPmptMQKKtkTPsSDHtSAQQ6qVNMillpRbisrN_b-gbsjuplr/pub?w=200)

Le code source (non opensource car vieux code) d'AbesSTP est accessible ici : https://git.abes.fr/depots/abesstp/

## URLs de l'application :

- https://stp-test.abes.fr : environnement de test
- https://stp.abes.fr : environnement de prod

## Installation d'AbesSTP

Pour installer AbesStp depuis zéro, un prérequis et de disposer d'un serveur ayant docker (>= 20.10.7) et docker-compose (>= 1.28.5). Ensuite il est nécessaire de dérouler les étapes suivantes : 

```bash
cd /opt/pod/
git clone https://github.com/abes-esr/abesstp-docker/

# récupération du code source d'AbesSTP (non ouvert)
# pour qu'il puisse être embarqué dans l'image d'abesstp-web
git submodule update --init --recursive

# bascule sur la branche souhaité si déploiement en test ou prod (exemple ci-dessous sur branche develop pour test)
git submodule update
git submodule foreach --recursive git checkout develop

# indiquez les mots de passes souhaités et les différents paramètres
# en personnalisant le contenu de .env (ex: mot de passes mysql et param smtp)
cp .env-dist .env

# copier le contenu de files/assistance/ depuis les dernières sauvegardes (pièces jointes des tickets AbesSTP)
rsync -rav \
  sotora:/backup_pool/diplotaxis2-prod/daily.0/racine/opt/pod/abesstp-docker/volumes/abesstp-web/files-assistance/ \
  ./volumes/abesstp-web/files-assistance/

# import du dump de la bdd depuis les dernières sauvegardes
# A noter : le temps de chargement prend environ 5 minutes
docker-compose up -d abesstp-db
rsync -ravL sotora:/backup_pool/diplotaxis2-prod/daily.0/racine/opt/pod/abesstp-docker/volumes/abesstp-db/dump/latest.svp.sql.gz .
gunzip -c latest.svp.sql.gz | docker exec -i abesstp-db bash -c 'mysql --user=root --password=$MYSQL_ROOT_PASSWORD svp'

# construction des images docker spécifiques à AbesSTP
# (facultatif car elles seront automatiquement construites au démarrage si elles ne sont pas en cache)
docker-compose build
```
### Installation d'AbesSTP en local, dev, et test

Pour déployer `abesstp-docker` en local, en dev ou en test il faut également lancer cette commande qui aura pour effet de générer un fichier `docker-compose.override.yml` qui mettra à disposition les outils phpmyadmin et mailhog dans des conteneurs dédiés (cf section plus bas) :
```bash
cd /opt/pod/abesstp-docker/
echo "
services:
  # ajout du conteneur mailhog
  # avec surcharge des autres conteneurs
  abesstp-mailhog:
    extends:
      file: docker-compose.mailhog.yml
      service: abesstp-mailhog
  abesstp-web:
    extends:
      file: docker-compose.mailhog.yml
      service: abesstp-web
  abesstp-web-clamav:
    extends:
      file: docker-compose.mailhog.yml
      service: abesstp-web-clamav
  abesstp-web-cron:
    extends:
      file: docker-compose.mailhog.yml
      service: abesstp-web-cron
  # ajout du conteneur phpmyadmin
  abesstp-phpmyadmin:
    extends:
      file: docker-compose.phpmyadmin.yml
      service: abesstp-phpmyadmin
" > docker-compose.override.yml
```

## Démarrage d'AbesSTP

Pour démarrer abesstp pour la production :
```bash
cd /opt/pod/abesstp-docker/
docker-compose up -d
```
Il est alors possible d'acceder a abesstp sur l'URL suivante :
- http://localhost:29800/ (en local)
- http://diplotaxis2-test.v202.abes.fr:29800/ (en test)
- http://diplotaxis2-prod.v102.abes.fr:29800/ (en prod)

## Arret et redémarrage d'AbesSTP

```bash
cd /opt/pod/abesstp-docker/
docker-compose stop

# si besoin de relancer abesstp
docker-compose restart
```

## Configuration de l'URL publique d'AbesSTP

Pour accéder à AbesSTP il est possible d'utiliser son URL interne (en HTTP) à des fins de tests :
- http://diplotaxis2-test.v202.abes.fr:29800/ (en test)
- http://diplotaxis2-prod.v102.abes.fr:29800/ (en prod)

Mais pour l'utilisateur final il est nécessaire de faire correspondre une URL publique en HTTPS :
- https://stp-test.abes.fr (en test)
- https://stp.abes.fr (en prod)

L'architecture mise en place pour permettre ceci est la configuration du reverse proxy de l'Abes (raiponce) qui permet d'associer l'URL publique en HTTPS avec l'URL interne d'AbesSTP. Voici un extrait de la configuration Apache permettant de paramétrer l'URL de https://stp-test.abes.fr/ sur son URL interne http://diplotaxis2-test.v202.abes.fr:29800/ :

```apache
<VirtualHost *:443>
  ServerName stp-test.abes.fr
  ServerAdmin exploit@abes.fr
  ProxyPreserveHost On

  SSLEngine on
  SSLProxyEngine on
  SSLCertificateFile /etc/pki/tls/certs/__abes_fr_cert.cer
  SSLCertificateKeyFile /etc/pki/tls/private/abes.fr.key
  SSLCertificateChainFile /etc/pki/tls/certs/__abes_fr_interm.cer

  Header add Set-Cookie "ROUTEID=.%{BALANCER_WORKER_ROUTE}e; path=/" env=BALANCER_ROUTE_CHANGED
  <Proxy balancer://cluster-stp-diplotaxis>
    BalancerMember http://diplotaxis2-test.v202.abes.fr:29800 loadfactor=1 connectiontimeout=600 timeout=600
    ProxySet stickysession=ROUTEID
  </Proxy>

  <Location / >
    ProxyPass        "balancer://cluster-stp-diplotaxis/"
    ProxyPassReverse "balancer://cluster-stp-diplotaxis/"
  </Location>
</VirtualHost>
```

Les configurations complètes et à jour se trouvent dans `/etc/httpd/conf.app/stp.conf` sur les serveurs raiponce1 (test ou prod).

## Sauvegarde d'AbesSTP

### Que faut il sauvegarder ?

Les sauvegardes doivent être paramétrées sur ces répertoires clés :
- la base de données : des dumps sont générés automatiquement toutes les nuits dans `/opt/pod/abesstp-docker/volumes/abesstp-db/dump/` 
- le répertoire `/opt/pod/abesstp-docker/volumes/abesstp-web/files-assistance/` car on y retrouve les pièces jointes (fichiers) des tickets d'AbesSTP dans le sous répertoire `files/assistance/`

Les chemins volumineux à d'exclure des sauvegardes sont les suivants :
- ``/opt/pod/abesstp-docker/volumes/abesstp-db/mysql/*`` : car il contient les données binaires de la base de données mysql

Pour mémo, si on souhaite sauvegarder ponctuellement la base de données, la commande suivante fait l'affaire :
```bash
# generation du dump de la base de donnees
docker exec -i abesstp-db bash -c 'mysqldump --user=root --password=$MYSQL_ROOT_PASSWORD svp' > dump.sql
```
### Comment restaurer AbesSTP ?

Vous pouvez soit procéder à une réinstallation complète de l'application (cf section plus haut), soit procéder à une restauration des données.

Pour restaurer uniquement les données de l'application, commencez par vous positionner sur le serveur où l'on souhaite restaurer les données de l'application (ici diplotaxis2-test est pris comme exemple) :
```bash
ssh diplotaxis2-test
cd /opt/pod/abesstp-docker/
```

Commencer par restaurer le ``.env`` depuis les sauvegardes (à noter que pour cette étape il faut demander au SIRE de lancer la commande `rsync`) :
```bash
cd /opt/pod/abesstp-docker/
rsync -av \
  sotora:/backup_pool/diplotaxis2-prod/daily.0/racine/opt/pod/abesstp-docker/.env ./
```

Pour restaurer les pièces jointes aux tickets AbesSTP depuis les sauvegardes (à noter que pour cette étape il faut demander au SIRE de lancer la commande `rsync`) :
```bash
cd /opt/pod/abesstp-docker/
rsync -rav \
  sotora:/backup_pool/diplotaxis2-prod/daily.0/racine/opt/pod/abesstp-docker/volumes/abesstp-web/files-assistance/ \
  ./volumes/abesstp-web/files-assistance/
```

Pour restaurer la base de données depuis un dump (à noter que pour cette étape il faut demander au SIRE de lancer la commande `rsync`) :
```bash
cd /opt/pod/abesstp-docker/

# récupération du dump depuis le serveur de sauvegardes
rsync -ravL sotora:/backup_pool/diplotaxis2-prod/daily.0/racine/opt/pod/abesstp-docker/volumes/abesstp-db/dump/latest.svp.sql.gz .

# s'assurer que le conteneur abesstp-db est lancé
sudo docker compose up -d abesstp-db

# lancer la commande suivante pour reinitialiser la base de donnees a partir du dump
gunzip -c latest.svp.sql.gz | sudo docker exec -i abesstp-db bash -c 'mysql --user=root --password=$MYSQL_ROOT_PASSWORD svp'
```

Il faut ensuite attendre 3 minutes avant que l'application soit denouveau UP (sinon la mire "Site off-line" de Drupal s'affiche).

## Debug d'AbesSTP

Pour lancer l'application avec tous les outils d'administration et de debug vous devez générer le fichier `docker-compose.override.yml` comme indiqué dans la procédure d'installation plus haut. Cette configuration permettra de lancer les deux conteneurs décrits ci-dessous : phpmyadmin et mailhog.

### phpmyadmin

Le conteneur `abesstp-phpmyadmin` propose l'outil phpmyadmin pour administrer la base mysql d'AbesSTP, sont URL est :
- http://localhost:29801/ : en local
- http://diplotaxis2-test.v202.abes.fr:29801/ : en test

### mailhog

Le conteneur `abesstp-mailhog` propose l'outil mailhog qui permet de simuler un serveur de mail (SMTP) fictif. Il intercepte ainsi les mails envoyés par abesstp et propose une interface web pour les consulter.

Il est alors possible d'acceder a mailhog sur l'URL suivante :
- http://localhost:29802/ : en local
- http://diplotaxis2-test.v202.abes.fr:29802/ : en test

Vous pouvez alors par exemple créer un ticket dans abesstp et le mail de notification ne sera pas réèlement envoyé car il sera intercepté par mailhog.

### logs

```bash
cd /opt/pod/abesstp-docker/
docker-compose logs
```


## Architecture d'AbesSTP

Les versions des middleware utilisés par AbesStp avant sa dockerisation (date de la mep 21/10/2021, avant les serveurs se nommaient typhon-prod et tourbillon) sont :
- apache 2.2.15 et php 5.3.3 : pour l'application en drupal6/php d'AbesStp
- mysql 5.1.73 : pour la base de donnees mysql d'AbesStp

Les images docker utilisées pour faire tourner abesstp sont les suivantes :
- [`php:5.6.40-apache`](https://hub.docker.com/_/php?tab=tags&page=1&ordering=last_updated&name=5.6.40-apache)
- [`mysql:5.5.62`](https://hub.docker.com/_/mysql?tab=tags&page=1&ordering=last_updated&name=5.5.62)

Les conteneurs docker suivants sont alors disponibles et préèconfiguré via les fichiers `docker-compose*.yml` :
- `abesstp-web` : conteneur qui contient l'application drupal/php d'abesstp
- `abesstp-web-cron` : conteneur qui 
  - appelle le fichier cron.php de drupal toutes les minutes,
  - lance la surveillance de files/ avec le script liens.sh,
  - supprime les fichiers *.php qui pourraient être uploadés dans files/assistance/,
  - supprime les vielles (datant de plus de 365 jours) pièces jointes d'AbesSTP (files/assistance/) pour faire du ménage  
- `abesstp-web-clamav` : conteneur qui va scanner files/assistance/ pour vérifier la présence d'éventuels virus uploadés par les utilisateurs en pj des tickets  
- `abesstp-db` : conteneur qui contient la base de données mysql nécessaire au drupal d'abesstp
- `abesstp-db-dumper` : conteneur qui va dumper chaques nuits la base de données en gardant un petit historique
- `abesstp-phpmyadmin` : conteneur utilisé pour administrer la base de données (utile uniquement pour le debug)
- `abesstp-mailhog` : conteneur utilisé pour intercepter et visualiser les mails envoyés à l'exterieur depuis l'application abesstp (utile uniquement pour le debug)

Les volumes docker suivants sont utilisés :
- `volumes/abesstp-web/files-assistance/` : contient les pièces jointes des tickets d'AbesSTP
- `volumes/abesstp-db/mysql/` : contient les données binaires mysql de la base de données d'abesstp
- `volumes/abesstp-db/dump/` : contient les dumps de la base de données d'abesstp (générés quotidiennement)

Le schéma permettant de résumer l'architecture est le suivant :
[![](https://docs.google.com/drawings/d/e/2PACX-1vTcrNXZNX-AmEDPb_bkBS4DKq1kgvE83bryWgF5bo89Q_tex4TcL59edePn6_ojmYkpZKjpJei70LRg/pub?w=938&h=630)](https://docs.google.com/drawings/d/1cuwHDa3bV-00rJuUSGCHuSI194eNmM_9xdVWkw80tR0/edit?usp=sharing)
