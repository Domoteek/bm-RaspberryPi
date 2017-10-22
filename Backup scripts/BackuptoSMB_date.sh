#!/bin/bash
###########################################
# Backup a Raspberry Pi to CIFS share
###########################################
# auteur : Mr Xhark (blogmotion.fr)
# source : http://blogmotion.fr/systeme/script-backup-rpi-partage-15977
VERSION="2017.10.22"
# licence type	: Creative Commons Attribution-NoDerivatives 4.0 (International)
# licence info	: http://creativecommons.org/licenses/by-nd/4.0/
###########################################

### VARIABLES ###
PARTAGE="//192.168.1.6/SD-Raspberry"
PARTAGEMNT="/mnt/SD-raspberry"
PARTAGENAME="CIFS sur PC" # commentaire pour l'affichage
USERNAME="USERNAME"
PASSWORD="PASSWORD"
NBJ="21" #Nombre de jours de sauvegardes à laisser
### FIN DES VARIABLES ###

# __________________ NE RIEN MODIFIER SOUS CETTE LIGNE __________________ #

DATE=$(date +%d-%m-%Y)
TAR=$(hostname -s)"-${DATE}.tar.gz"

ipserver=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
locpath=`dirname "${BASH_SOURCE[0]}"` 	# chemin vers le script
scriptpath=`basename $0`				# script.sh

bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

rouge=$(	tput setaf 1)
vert=$(		tput setaf 2)
jaune=$(	tput setaf 3)
bleu=$(		tput setaf 4)
violet=$(	tput setaf 5)
cyan=$(		tput setaf 6)
gris=$(		tput setaf 7)

# Fonctions
shw_norm () { echo -en "${bold}$(tput setaf 9)${@}${reset}";	}
shw_info () { echo -en "${bold}${cyan}${@}${reset}";		}
shw_OK ()   { echo -en "${bold}${vert}OK!${@}${reset}";		}
shw_warn () { echo -en "${bold}${violet}${@}${reset}";		}
shw_err ()  { echo -en "${bold}${rouge}${@}${reset}";		}
gris() 	    { echo -en "${bold}${gris}${@}${reset}";		}
header()    { echo -e "${bold}${jaune}$*${reset}";		}
headerU()   { echo -e "${underline}${bold}${jaune}$*${reset}";  }

# debut du script
clear && echo -e "\n\n"
header  "****************************************************************************"
header  "***   bm-PiBackup by @xhark - Creative Commons BY-ND 4.0 (v${VERSION})   ***"
headerU "****************************************************************************"

shw_info "\n\n=== Demarrage sauvegarde Raspberry Pi le $(date +'%d/%m/%Y a %Hh%M'):\n\n"

# Vérification execution en tant que 'root'
shw_norm "\t::: execution en tant que root... " 
if [[ $EUID -ne 0 ]]; then
	sudo "$0" "$@" || (shw_err "Ce script doit être executé avec les droits 'root'. Arrêt du script.\n" ; exit 1)
else
	shw_OK
fi

# controle montage
shw_norm "\n\t::: verification du partage ($PARTAGENAME)... "
if grep -qs $PARTAGEMNT /proc/mounts; then
	shw_OK
else
	# creation point montage si non present
	[ -d $PARTAGEMNT ] || mkdir -p $PARTAGEMNT
	# montage du partage syno
	mount.cifs $PARTAGE $PARTAGEMNT -o user=${USERNAME},pass="${PASSWORD}" && shw_OK
	if [[ $? -ne 0 ]]; then
		shw_err "\n\t ERREUR: montage impossible de $PARTAGE -- Arrêt du script \n"
		exit 1
	fi
fi

# Sauvegarde listing cron
/usr/bin/crontab -l > /tmp/crontab

cd $PARTAGEMNT || (shw_err "\n\t ERREUR: cd impossible"; exit 1)

# On test si il existe un fichier de plus de 3 semaines pour le supprimer
shw_norm "\n\t::: suppression archive de plus de 3 semaines ... "
find /mnt/SD-raspberry/ -type f -mtime +"$NBJ" -iname "jeedom*" -exec rm -rf {} \;
#if [ -f /mnt/SD-Raspberry/$(hostname -s)$(date --date '28 days ago' "+%d.%m.%Y").tar.gz ]; then

#   rm "/mnt/SD-Raspberry/$(hostname -s)$(date --date '28 days ago' "+%d.%m.%Y").tar.gz"
#fi
shw_OK

# creation archive
shw_norm "\n\t::: creation de l'archive ${TAR}... "
# une ligne par fichier ou dossier à sauvegarder, sans oublier les exclusions
tar zcf "$TAR" \
	/*		\
	--exclude '/dev/*'	\
	--exclude '/proc/*'	\
	--exclude '/sys/*'	\
	--exclude '/tmp/*'	\
	--exclude '/run/*'	\
	--exclude '/mnt/*' \
	--exclude '/media/*' \
	--exclude '/lost+found' \
	> /dev/null 2>&1

tarsize=$(du -sh "$TAR")

if [[ $? -ne 0 ]]; then
	shw_err "\n\t ERREUR: impossible de creer l'archive $TAR \n"
	umount -l $PARTAGEMNT && shw_warn "\n\t demontage du partage et stop du script!"
	exit 1
fi
shw_OK

# démontage
shw_norm "\n\t::: demontage partage... "
if umount -l $PARTAGEMNT; then
        shw_OK
else
	shw_err "IMPOSSIBLE!"
fi

gris "\n\n\t=> Taille du backup: $tarsize"

shw_info "\n\n=== Fin du Backup le $(date +'%d/%m/%Y a %Hh%M')"
shw_info "\n=== ce script tourne depuis ${ipserver}:${locpath}/${scriptpath}\n\n"

# Nettoyage des fichiers temporaires
rm -f /tmp/crontab

exit 0
