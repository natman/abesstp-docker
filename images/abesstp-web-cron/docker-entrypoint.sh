#!/bin/bash

# Réglage de /etc/environment pour que les crontab s'exécutent avec les bonnes variables d'env
# en particulier LANG qui permet de communiquer la locale à utiliser
# à la commande "mail". Sans cela les mails envoyés auront des pièces jointes
# dès qu'un caractère non ASCII est présent dans le corps du mail ...
# cf https://git.abes.fr/depots/abesstp-docker/-/issues/38
echo "$(env)
LANG=en_US.UTF-8" > /etc/environment

# vérification de la présence de files/assistance/
if [ ! -d /var/www/html/sites/stp.abes.fr/files/assistance/ ]; then
  echo "Erreur: impossible de lancer abesstp-web-cron car /var/www/html/sites/stp.abes.fr/files/assistance/ est introuvable" 
  sleep 2 && exit 1
fi


# on injecte les parametres SMTP vevnant des variable d'env
# SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, ...
if [ "${SMTP_TLS}" = "on" ]; then
  envsubst < /etc/msmtprc.tls.tmpl > /etc/msmtprc
else
  envsubst < /etc/msmtprc.notls.tmpl > /etc/msmtprc
fi


# execute CMD (crond)
exec "$@"
