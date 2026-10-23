# Plan d'adressage

| Machine | Interface | Adresse | Réseau VMware | Rôle |
|---|---|---|---|---|
| gw | ens33 | DHCP (192.168.204.140) | VMnet8 (NAT) | WAN |
| gw | ens37 | 10.10.10.1/24 | VMnet2 | Passerelle DMZ |
| gw | ens38 | 10.10.20.1/24 | VMnet3 | Passerelle LAN |
| web | ens33 | 10.10.10.10/24 | VMnet2 | Serveur web (DMZ) |
| client | ens33 | 10.10.20.10/24 | VMnet3 | Poste utilisateur (LAN) |
| mon | ens33 | 10.10.20.20/24 | VMnet3 | Supervision Zabbix (LAN) |

## Correspondance interfaces / cartes VMware (gw)

| Interface Linux | Carte VMware | MAC |
|---|---|---|
| ens33 | Network Adapter | 00:0c:29:ae:76:07 |
| ens37 | Network Adapter 2 | 00:0c:29:ae:76:11 |
| ens38 | Network Adapter 3 | 00:0c:29:ae:76:1b |
