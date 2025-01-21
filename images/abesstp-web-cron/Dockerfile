FROM rockylinux:8.9

# vim: pour debug de l'image plus facile
RUN yum install -y vim

# system pour appeler periodiquement cron.php (via wget)
RUN yum install -y wget

# system pour nettoyer periodiquement les vielles pieces jointes d'abesstp
RUN yum install -y tmpwatch

# systeme pour les crontab
# cronie: pour la crontab qui gère bien les signaux CTRL+C
# gettext: pour avoir envsubst qui permet de gérer les template pour la crontab
RUN yum install -y cronie gettext && \
    crond -V && rm -rf /etc/cron.*/*

# system pour envoyer les mails
# epel-release: pour que msmtp puisse être installé
# langpacks-en glibc-all-langpacks : pour envoyer des mails en UTF8 (ex: lien.sh)
RUN yum -y install epel-release && yum makecache
RUN yum install -y msmtp mailx
RUN yum install -y langpacks-en glibc-all-langpacks

# configuration pour les crontab
COPY ./crontab-tasks /etc/local/etc/cron.d/crontab-tasks
RUN crontab /etc/local/etc/cron.d/crontab-tasks
# configuration pour envoyer les mail
COPY ./msmtprc.tls.tmpl /etc/
COPY ./msmtprc.notls.tmpl /etc/

# script de comparaison de files/assistance/
COPY ./lien.sh /usr/local/bin/lien.sh

RUN yum install -y \
    rsync \
 && yum clean all

RUN chgrp -R root /etc /var/run
RUN chmod -R g+rwX /etc /var/run
RUN chmod gu+rw /var/run /etc
RUN chmod gu+s /usr/sbin/crond /etc

# gestion des cron dans docker inspirée de
# https://sudonull.com/post/80071-Running-cron-inside-a-docker-container-Redmadrobots-blog
COPY ./docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["crond", "-n"]
