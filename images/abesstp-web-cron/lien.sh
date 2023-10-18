#/bin/sh

##23/12/13
## Scan du répertoire drupal afin de détecter les nouveaux fichiers déposés et d'en avertir les modérateurs
## de abesstp qui jugeront de leur pertinence
## Script prenant en paramètre la période de temps à analyser depuis la date actuelle en secondes.

#on enregistre l'IFS actuel :
R=$IFS
#on change l'IFS$SEP pour être un retour à la ligne
if [ ! -z $1 ]
	then 
IFS='
'
DRUPAL="/var/www/html/sites/stp.abes.fr/"
SUFFIX="files"
DIR="$DRUPAL/$SUFFIX"
cd $DIR
TIME=$(date +%s)
#le temps par défaut est 1 journée=86400 secondes
TIME24=$(( $TIME - $1))
SEP=ù

make_timestamp()
{
for i in $(ls $DIR)
	do 
	if [ ! -d $i ]
          then
		echo "$i$SEP$(stat -c %Y "$DIR/$i")" >> /tmp/lien.txt
	fi
	done
}

nom()
{
echo $i |awk -F "$SEP" '{print $1}'
}

timestamp()
{
echo $i |awk -F "$SEP" '{print $2}'
}

suffix()
{
echo $i |awk -F "$SEP" '{print $3}'
}

rm_file()
{
if [ -f $1 ]
then rm -f $1
fi
}

ins()
{
echo $TIME24
for i in $(cat /tmp/lien.txt)
	do 
	   if [ $(timestamp $i) -ge $TIME24 ] 
		then
		     echo "$(nom $i)$SEP$(timestamp $i)$SEP$SUFFIX">> /tmp/new.txt
	   fi
done
}
# https://gist.github.com/cdown/1163649
urlencode() {
  local length="${#1}"
  for (( i = 0; i < length; i++ )); do
    local c="${1:i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf "$c" ;;
    *) printf "$c" | xxd -p -c1 | while read x;do printf "%%%s" "$x";done
  esac
done
}

rm_file /tmp/lien.txt
rm_file /tmp/new.txt
rm_file /tmp/urls.txt

make_timestamp
ins

rm_file /tmp/lien.txt
SUFFIX="files/assistance"
DIR="$DRUPAL/$SUFFIX"
cd $DIR
make_timestamp
ins

#nom lien.txt

if [ ! -f /tmp/new.txt ] 
	then
		echo "pas de nouveau fichier"
	else
		for i in $(cat /tmp/new.txt)
			do
	  			echo " https://stp.abes.fr/sites/stp.abes.fr/$(suffix $i)/$(urlencode "$(nom $i)") déposé le $(date -d @$(timestamp $i))" >> /tmp/urls.txt
			done
		cat /tmp/urls.txt 
		echo -e "fichiers à analyser :\n$(cat /tmp/urls.txt) " | mail -s "[STP] Nouveau fichier depose a analyser" exploit@abes.fr,svp@abes.fr
fi

else

echo "usage : lien.sh [temps en sec]"
fi
#on rétablit l'IFS
		IFS=$R

