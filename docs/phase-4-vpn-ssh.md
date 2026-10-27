# Phase 4 : VPN WireGuard et durcissement SSH

## Objectif
Faire de l'administration un accès unique, chiffré et authentifié par clé : tunnel WireGuard vers gw, SSH fermé sur le WAN, mots de passe interdits, rebond obligatoire par gw.

## Fichiers
- [`gw/etc/wireguard/wg0.conf.example`](../gw/etc/wireguard/wg0.conf.example) : tunnel côté gw (sans clé)
- [`wireguard-admin.conf.example`](wireguard-admin.conf.example) : tunnel côté admin (sans clé)
- [`gw/usr/local/sbin/firewall.sh`](../gw/usr/local/sbin/firewall.sh) : UDP 51820 ouvert, SSH uniquement sur `wg0`
- `*/etc/ssh/sshd_config.d/10-durcissement.conf` : clés uniquement, pas de root, `AllowUsers` par source

## Politique d'accès SSH
| Machine | Autorisé |
|---|---|
| gw | `bouaroua` depuis le VPN `10.8.0.0/24` |
| web | `bouaroua` depuis gw (`10.10.10.1`) |
| client, mon | `bouaroua` depuis gw (`10.10.20.1`) |

## Preuves clés
SSH direct sur le WAN, tunnel actif ou non :
```
ssh: connect to host 192.168.204.140 port 22: Connection timed out
```
Connexion par mot de passe :
```
bouaroua@10.8.0.1: Permission denied (publickey).
```
Déplacement latéral client → mon (log de mon) :
```
User bouaroua from 10.10.20.10 not allowed because not listed in AllowUsers
```

## Difficultés rencontrées
- Git Bash n'utilisait pas l'agent SSH de Windows → alias vers le `ssh` de Windows
- Bascule de l'accès admin sans se bloquer : nouvel accès testé avant de fermer l'ancien, console VMware en secours