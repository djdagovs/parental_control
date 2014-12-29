#! /bin/sh

# Copyright (C) Raphaël Flores (raf64flo), 2014
# Copyright (C) 2007 - ZEPALA.FREE.FR
# Copyright (C) Roozeec Linux Blog
# Contributors from french Ubuntu wiki: Roozeec, Boris Le Hachoir, Fabien26, Furious-therapy, sensouci
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

# L'essentiel des commandes de ce script proviennent des pages suivantes :
# http://doc.ubuntu-fr.org/tutoriel/comment_mettre_en_place_un_controle_parental
# http://zepala.free.fr/?q=node/64

echo
echo "####################################"
echo "#Configuration du contrôle parental..."
echo "####################################" && sleep 0

echo
echo "#########################"
echo "Création du group \"parents\""
echo "#########################" && sleep 0
groupadd -g 64000 parents

add_user_to_parent_group () {
	echo "Quel utilisateur est un parent ?"
	read parent_user
	if [ -z $parent_user ]
	then
		echo "Pas de parent."
	else
		echo "Parent: $parent_user"
	fi
	exit 0
	usermod -G parents --append $parent_user
}
#add_user_to_parent_group
usermod -G parents --append janick
usermod -G parents --append rflores
#exit 0

echo
echo "####################################"
echo "#Installation de Squid et SquidGuard..."
echo "####################################" && sleep 1

cmd="apt-get install -y squid3 squidguard" && echo "#Exécution de la commande : '$cmd'"
eval $cmd

echo
echo "###############################"
echo "#Configuration de Squid3..."
echo "###############################" && sleep 1

squid_conf_file="/etc/squid3/squid.conf"
cp ${squid_conf_file} "${squid_conf_file}.orig"

sed -ri.bak 's/^(http_access allow localhost)$/http_access allow all\n\1/p' ${squid_conf_file}
sed -ri.bak 's/^(http_port 3128)$/#\1/p' ${squid_conf_file}

(
cat <<-EOF
	#redirect_program /usr/bin/squidGuard -c /etc/squid/squidGuard.conf
	redirect_program /usr/bin/squidGuard -c /etc/squidguard/squidGuard.conf
	redirect_children 10
	 
	http_port 3128 transparent
EOF
) >> ${squid_conf_file}


echo
echo "####################################"
echo "#Configuration des listes noires..."
echo "####################################"
sleep 1
# Voir "Configuration de SquidGuard" : http://doc.ubuntu-fr.org/tutoriel/comment_mettre_en_place_un_controle_parental
cd /tmp
blacklists_file="/tmp/blacklists.tar.gz"
#rm $blacklists_file
if [ -f $blacklists_file ]
then
	echo "Fichier déjà téléchargé."
else
	wget ftp://ftp.univ-tlse1.fr/pub/reseau/cache/squidguard_contrib/blacklists.tar.gz -O $blacklists_file
fi
mkdir -p /var/lib/squidguard/db/
tar zxvf $blacklists_file -C /var/lib/squidguard/db/
cd /var/lib/squidguard/db
mv blacklists/* .
rm -rf blacklists


echo
echo "###############################"
echo "#Configuration de SquidGuard..."
echo "###############################" && sleep 1

squidguard_conf_file="/etc/squidguard/squidGuard.conf"
cp ${squidguard_conf_file} ${squidguard_conf_file}.orig
(
cat <<-EOF
	#
	# CONFIG FILE FOR SQUIDGUARD
	#

	dbhome /var/lib/squidguard/db
	logdir /var/log/squid3

	# ------------------------------------------------------------
	# Définition de la base de données de filtrage utilisée
	# ------------------------------------------------------------
	dest adult {
		domainlist adult/domains
		urllist adult/urls
	}

	dest publicite {
		domainlist publicite/domains
		urllist publicite/urls
	}

	dest warez {
		domainlist warez/domains
		urllist warez/urls
	}

	dest porn {
		domainlist porn/domains
		urllist porn/urls
	}

	dest violence {
		domainlist violence/domains
		urllist violence/urls
	}

	# ajoutez ici les thèmes supplémentaires de votre choix présents dans la blacklist de la façon suivante :
	# dest <nom du thème> {
	#        domainlist <nom du thème>/domains
	#        urllist <nom du thème>/urls
	# }

	# ------------------------------------------------------------
	# Définition des ACL
	# ------------------------------------------------------------

	acl {
	  default {
	# les thèmes supplémentaires sont à ajouter avant le mot-clé all par !<nom du thème>
		pass !porn !adult !publicite !warez !violence all
		redirect  http://www.ovh.com/fr/images/hosting/astuce_htaccess/interdit.jpg
	  }
	}
	# ------------------------------------------------------------
EOF
) > ${squidguard_conf_file}


echo
echo "##############################################################"
echo "#Création de la base de données SquidGuard (peut être long)..."
echo "##############################################################" && sleep 1

cmd="squidGuard -C all" && echo "#Exécution de la commande : '$cmd'"
eval $cmd


echo
echo "######################################################################################################"
echo "#Configuration du pare-feu IPTABLES (pour rediriger les requêtes du navigateur vers le proxy Squid)..."
echo "######################################################################################################" && sleep 1

# On autorise le groupe parents (64000) a surfer directement :
iptables -t nat -A OUTPUT -m owner --gid-owner 64000 -p tcp -m tcp --dport 80 -j ACCEPT
# On redirige dans le proxy tout le reste du monde, excepté l'utilisateur 'proxy' (13)
iptables -t nat -A OUTPUT -m owner ! --uid-owner 13 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 3128

# Ajoute la règle IPTABLE à chaque démarrage du PC 
sed -i 's/exit 0$/iptables \-t nat \-A OUTPUT \-m owner \-\-gid\-owner 64600 \-p tcp \-m tcp \-\-dport 80 \-j ACCEPT\nexit 0/' /etc/rc.local
sed -i 's/exit 0$/iptables \-t nat \-A OUTPUT \-m owner \! \-\-uid\-owner 13 \-p tcp \-m tcp \-\-dport 80 \-j REDIRECT \-\-to\-ports 3128\nexit 0/' /etc/rc.local

echo
echo "######################"
echo "#Démarrage de Squid..."
echo "######################" && sleep 1
chown -R proxy:proxy /etc/squid3 /var/log/squid3 /var/spool/squid3 /usr/lib/squid3 /usr/sbin/squid3 /var/lib/squidguard
cmd="squid3 -z" && echo "#Exécution de la commande : '$cmd'"
eval $cmd
cmd="/etc/init.d/squid3 restart" && echo "#Exécution de la commande : '$cmd'"
eval $cmd


echo
echo "#####################################################"
echo "#Configuration de la mise à jour des listes noires..."
echo "#####################################################" && sleep 1
(
cat <<-EOF
	#!/bin/sh
	#
	# Fichier /etc/cron.weekly/squidguard_blacklists
	#
	# Télécharge chaque semaine les listes noires pour SquidGuard
	# et met à jour les bases de ce dernier.

	if [ -d /var/lib/squidguard ]; then
		wget ftp://ftp.univ-tlse1.fr/pub/reseau/cache/squidguard_contrib/blacklists.tar.gz -O /var/lib/squidguard/blacklists.tar.gz
		tar zxvf /var/lib/squidguard/blacklists.tar.gz -C /var/lib/squidguard/
		rm -rf /var/lib/squidguard/db
		mkdir /var/lib/squidguard/db || true
		mv -f /var/lib/squidguard/blacklists/* /var/lib/squidguard/db/
		chmod 2770 /var/lib/squidguard/db
		rm -rf /var/lib/squidguard/blacklists /var/lib/squidguard/blacklists.tar.gz
		/usr/bin/squidGuard -C all
		chown -R proxy:proxy /etc/squid3 /var/log/squid3 /var/spool/squid3 /usr/lib/squid3 /usr/sbin/squid3 /var/lib/squidguard
		service squid3 restart
	fi
EOF
) > /etc/cron.weekly/squidguard_blacklists
chmod +x /etc/cron.weekly/squidguard_blacklists


echo
echo "#######################"
echo "#Installation terminée."
echo "#######################"
exit 0

