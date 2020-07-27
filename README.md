# SECRET : Secure Environment for automatic test grading

> Travail de Bachelor 2019-2020
>
> Caroline Monthoux



## Procédure d'installation de l'environnement

Ce document est une marche à suivre pour configurer le serveur LTSP.

Il est assumé que :

* Le serveur est fraîchement installé avec Ubuntu 18.04 Desktop 
* Les paramètres liés au pays et à la langue sont corrects (localisation `Europe/Zurich`, clavier `Switzerland - French`)
* La topologie réseau est prête (le serveur est branché au réseau local par une interface et à au moins un client par une autre interface)

Avant de continuer, il faut être en possession des informations suivantes :

* Un compte utilisateur capable d'administrer le serveur (faisant partie du groupe sudo)
* Le nom de l'interface connectée au réseau local englobant (réseau de l'école ou de la maison)
* Le nom de l'interface connectée au réseau local de LTSP

Il est important de ne pas se déplacer manuellement dans les répertoire entre le lancement des scripts.



#### Étape 1 : premiers paramétrages du serveur

Éditer le fichier script `01.setup_server` pour remplacer les noms des interfaces et des adresses IP pour qu'elles correspondent à votre environnement. **Une balise `# *EDIT*` se trouve avant chaque option à éditer manuellement.**

Lancer le script `01.setup_server.sh`. Il installe les paquets principaux, configure les interfaces réseau, ajoute les règles iptables, génère le chroot, ajoute les groupes du système et génère le skeleton étudiant.

* Répondre **`Yes`** deux fois lors de la configuration de `iptables-persistent`



#### Étape 2 : installation de Mitmproxy

Lancer le script `02.install_mitmproxy.sh`. Il télécharge les exécutables Mitmproxy.

Une fois l'exécution terminée, lancer l'exécutable `mitmproxy` pour générer ses certificats :

```bash
$ sudo ./mitmproxy
```

Continuer l'installation en lançant le script `03.setup_mitmproxy`

WIRESHARK ??



#### Étape 3 : installation du chroot

Lancer le script `04.install_chroot.sh`. Il entre dans le chroot, télécharge les paquets nécessaires au client, installe le certificat proxy et met en place les configurations de l'environnement.

* Garder l'encodage par défaut lors de l'upgrade des paquets
* Répondre **<Yes>** deux fois lors de la configuration de `iptables-persistent`
* Ne pas installer GRUB lors de l'installation de `ubuntu-desktop`



#### Étape 4 : installation de Logkeys dans le chroot

Lancer le script `05.install_chroot_logkeys.sh`. Il installe le keylogger Logkeys dans le chroot et le configure pour qu'il s'exécute seulement pendant une session.



#### Étape 5 : installation du serveur, agent et frontend Zabbix

Lancer le script `06.install_zabbix`. Il installe les composants nécessaires à Zabbix sur le serveur, dont la base de données PostgreSQL et Apache.

* Un mot de passe pour la base de données est demandé pendant l'installation, le garder précieusement

Une fois l'exécution du script terminée, il ne reste que quelques étapes à effectuer :

1. Éditer le fichier `/etc/zabbix/zabbix_server.conf` et donner le mot de passe de la DB :

```
DBPassword=password
```

2. Éditer le fichier `/etc/zabbix/apache.conf` et décommenter les 2 `php_value date.timezone` en mettant `Europe/Zurich`:

```xml
<Directory "/usr/share/zabbix">
    ...

    <IfModule mod_php5.c>
        ...
        php_value date.timezone Europe/Zurich
    </IfModule>
    <IfModule mod_php7.c>
        ...
        php_value date.timezone Europe/Zurich
    </IfModule>
</Directory>
```

3. Exécuter les commandes suivantes :

```bash
$ sudo systemctl enable zabbix-server zabbix-agent apache2
$ sudo systemctl start zabbix-server zabbix-agent apache2
```

4. **Redémarrer le serveur** pour terminer l'installation de Zabbix



#### Étape 6 : installation de l'agent Zabbix dans le chroot

Lancer le script `07.install_chroot_zabbix.sh`. Il installe l'agent Zabbix dans le chroot et donne les permissions nécessaires à son fonctionnement.

Une fois l'exécution terminée, ouvrir le fichier `/etc/zabbix/zabbix_agentd.conf` et modifier les valeurs des clés suivantes pour qu'elles soient exactement comme suit :

```
Server=192.168.67.1
ServerActive=192.168.67.1
#Hostname=Zabbix server
HostnameItem=system.hostname
```



#### Étape 7 : configurations manuelles

##### 7.1 Sur le serveur :

* Éditer le fichier `/etc/ltsp/ltsp.conf` et ajouter les lignes suivantes **sous les balises correspondantes** :

```bash
[server]
# Hide iPXE shell
POST_IPXE_HIDE_CONFIG="sed '/--key c/d' -i /srv/tftp/ltsp/ltsp.ipxe"
POST_IPXE_HIDE_SHELL="sed '/--key s/d' -i /srv/tftp/ltsp/ltsp.ipxe"

[clients]
# Hide process information for other users
FSTAB_PROC="proc /proc proc defaults,hidepid=2 0 0"

# Allow specific services
KEEP_SYSTEM_SERVICES="ssh"

# Copy the server SSH keys into clients. Required for SSH communication
POST_INIT_CP_KEYS="cp /etc/ltsp/ssh_host_* /etc/ssh/"

# Filter which users accounts are copied on the clients
PWMERGE_SGR="^student$"
```

* Éditer le fichier `/etc/zabbix/zabbix_agentd.conf` et modifier les lignes suivantes :

```
Server=127.0.0.1
ServerActive=127.0.0.1
Hostname=Zabbix server
```

* Éditer le fichier `/etc/gdm3/greeter.dconf-defaults` comme suit pour cacher la liste d'utilisateurs de la fenêtre de login :

```bash
# Décommenter les lignes suivantes
[org/gnome/login-screen]
disable-user-list=true
```



##### 7.2 Dans le chroot :

Entrer dans le schroot avec la commande :

```bash
$ schroot -c bionic -u root
```

* Éditer le fichier `/etc/default/keyboard` comme suit pour paramétrer le clavier en français :

```bash
XKBLAYOUT="ch"
XKBVARIANT="fr"
```

* Éditer le fichier `/etc/gdm3/greeter.dconf-defaults` comme suit pour cacher la liste d'utilisateurs de la fenêtre de login :

```bash
# Décommenter les lignes suivantes
[org/gnome/login-screen]
disable-user-list=true
```



#### Étape 8 : création de l'image cliente LTSP

Créer quelques utilisateurs étudiants en utilisant le script `create-users.sh` :

```bash
# Create script create-users.sh (owned by the current user)
$ sudo chmod u+x create-users.sh
$ printf "luke_skywalker\nhan_solo\n" > users
$ sudo ./create-users.sh users
$ cat users-output.txt
```

Lancer le script `08.image.sh`. Il génère l'image, le menu iPXE et le fichier initrd, et partage le chroot en NFS.



#### Étape 9 : configuration de Zabbix Frontend & Server

Suivre la procédure `Importation de la configuration Zabbix.pdf` pour terminer l'installation de Zabbix sur le serveur.



#### Étape 10 : tester l'environnement

Dès à présent, il devrait être possible de démarrer des clients LTSP.

Démarrer le proxy en naviguant dans `/opt/mitmproxy` et en lançant la commande :

```bash
# Start capture
$ sudo ./mitmdump -s redirect_requests.py -w output
# Read capture
$ sudo ./mitmdump -s pretty_print.py -r output
```

Une fois un client démarré, son agent devrait s'inscrire tout seul dans les Hosts Zabbix et être monitoré.

**Un compte `ltsp_monitoring` possédant les droits sudo existe expressément pour pouvoir se connecter aux clients et y effectuer des actions privilégiées.** N'hésitez pas à l'utiliser (avec ssh ou en se connectant directement sur le client).

#### Troubleshooting

Il est possible que certains problèmes apparaîssent malgré le suivi scrupuleux de la procédure :

* Si les clients ne parviennent pas à obtenir une adresse IP, voir si les règles IPtables sont OK. Il suffit qu'on ait oublié de modifier le nom de l'interface dans une règle pour que cela pose problème.
* Si les clients ne parviennent pas à se connecter au serveur TFTP, voir les logs de dnsmasq. Il suffit parfois de redémarrer le service.
* Si une interface semble DOWN, vérifier les configurations netplan et réappliquer si nécessaire.
* Si le serveur Zabbix apparaît "Down" dans la console, vérifier les logs dans `/var/log/zabbix/zabbix_agentd.log` et `/var/log/zabbix/zabbix_server.log`. Il peut arriver que le serveur communique avec son propre agent non pas avec l'adresse 127.0.0.1 mais avec l'adresse d'une autre interface. Si c'est le cas, il faut modifier les clés `Server` et `ServerActive` dans la configuration de l'agent pour les faire correspondre avec l'IP utilisée.
* Si l'agent Zabbix sur les clients ne démarre pas, vérifier le owner du dossier `/var/log/zabbix`. Il arrive que ce fichier change de propriétaire sans raison. Cela devrait être `zabbix:zabbix`.