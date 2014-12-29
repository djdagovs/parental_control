#!/bin/sh

# Copyright (C) Raphaël Flores (raf64flo), 2014
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

echo
echo "########################"
echo "#Arrêt du service Squid."
echo "########################"
service squid3 stop

echo
echo "###########################################################"
echo "#Suppression et nettoyage des paquets squid3 et squidguard."
echo "###########################################################"
apt remove --purge -y squid3 squidguard
apt-get autoremove -y

echo
echo "######################################"
echo "#Suppression des répertoires restants."
echo "######################################"
rm -rf /etc/squid3 /etc/squidguard /var/lib/squidguard

echo
echo "#################################"
echo "#Suppression des règles IPTABLES."
echo "#################################"
sed -i 's/^iptables \-t nat \-A OUTPUT \-m owner \-\-gid\-owner 64600 \-p tcp \-m tcp \-\-dport 80 \-j ACCEPT$//' /etc/rc.local
sed -i 's/^iptables \-t nat \-A OUTPUT \-m owner \! \-\-uid\-owner 13 \-p tcp \-m tcp \-\-dport 80 \-j REDIRECT \-\-to\-ports 3128//' /etc/rc.local

echo
echo "###################"
echo "#Nettoyage du cron."
echo "###################"
rm /etc/cron.weekly/squidguard_blacklists

echo
echo "###################"
echo "#Nettoyage terminé."
echo "###################"
exit 0

