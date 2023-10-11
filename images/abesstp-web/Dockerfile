FROM php:5.6.40-apache

# pour avoir un client SMTP dans le conteneur (msmtp)
# gettext-base: pour disposer de la commande envsubst (systeme de template)
# libldap2-dev libldb-dev: pour l'extension php LDAP
# libpng-dev : pour l'extension php GD
RUN set -x \
    && DEBIAN_FRONTEND=noninteractive \
    && apt-get update && apt-get install -y vim msmtp gettext-base libldap2-dev libldb-dev libpng-dev
COPY ./msmtprc.tls.tmpl /etc/
COPY ./msmtprc.notls.tmpl /etc/

RUN docker-php-ext-install gd
RUN docker-php-ext-install mysqli
RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/
RUN docker-php-ext-install ldap
RUN a2enmod rewrite expires

COPY ./php-abesstp.ini /usr/local/etc/php/conf.d/php-abesstp.ini

COPY ./docker-entrypoint.overload.sh /
ENTRYPOINT ["/docker-entrypoint.overload.sh"]
CMD ["apache2-foreground"]
