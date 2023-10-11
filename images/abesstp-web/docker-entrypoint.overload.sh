#!/bin/bash


# Reglages variables php.ini pour la prod
cp -f "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
# utilisation de msmtp pour envoyer de mails depuis php
# la config est placee dans /etc/msmtprc
sed -i 's#;sendmail_path =#sendmail_path = /usr/bin/msmtp -t -i#g' $PHP_INI_DIR/php.ini

# on injecte les parametres SMTP vevnant des variable d'env
# SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, SMTP_RETURN_PATH ...
if [ "${SMTP_TLS}" = "on" ]; then
  envsubst < /etc/msmtprc.tls.tmpl > /etc/msmtprc
else
  envsubst < /etc/msmtprc.notls.tmpl > /etc/msmtprc
fi

# quelques réglages de droits d'écriure sur ces répertoires particuliers
#files/assistance/ est l'endroit où les pièces jointes des tickets abesstp sont déposées
if [ -d /var/www/html/sites/stp.abes.fr/files/assistance/ ]; then
  chmod 777 /var/www/html/sites/stp.abes.fr/files/assistance/
else
  echo "Warning : le repertoire /var/www/html/sites/stp.abes.fr/files/assistance/ n'existe pas, AbesSTP ne pourra pas fonctionner correctement !"
fi
if [ -d /var/www/html/sites/stp.abes.fr/files/ ]; then
  chmod 777 /var/www/html/sites/stp.abes.fr/files/
else
  echo "Warning : le repertoire /var/www/html/sites/stp.abes.fr/files/ n'existe pas, AbesSTP ne pourra pas fonctionner correctement !"
fi


# start the real entrypoint
exec /usr/local/bin/docker-php-entrypoint $@

