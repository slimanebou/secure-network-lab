# Phase 3 : serveur web et DNS interne

## Objectif
Publier un site Nginx en DMZ, accessible depuis le LAN et depuis l'extérieur (DNAT), et donner un nom à chaque machine avec un DNS interne sur gw.

## Fichiers
- [`web/var/www/html/index.html`](../web/var/www/html/index.html) : page du site
- [`web/etc/nginx/nginx.conf`](../web/etc/nginx/nginx.conf) : `server_tokens off` (version masquée)
- [`gw/etc/dnsmasq.d/lab.conf`](../gw/etc/dnsmasq.d/lab.conf) : DNS interne `lab.internal`
- [`gw/usr/local/sbin/firewall.sh`](../gw/usr/local/sbin/firewall.sh) : port 53 ouvert vers gw, DNS direct de la DMZ fermé
- `*/etc/resolv.conf` : chaque VM interroge gw

## Choix techniques
- Domaine `lab.internal` plutôt que `.local` (réservé au mDNS)
- dnsmasq n'écoute que sur la DMZ et le LAN (`bind-interfaces`) : pas de résolveur ouvert sur le WAN
- La DMZ ne peut plus interroger de DNS extérieur : tout passe par gw (journalisé, protection contre le tunnel DNS)
- Service `avahi-daemon` (mDNS) désactivé sur toutes les VMs : surface d'attaque réduite

## Preuves
| Test | Résultat |
|---|---|
| client → web:80 | `refused` (phase 2) → `200 OK` |
| Windows → `192.168.204.140:80` (DNAT) | Page affichée, IP réelle du visiteur dans `access.log` |
| `dig web.lab.internal` depuis client | `10.10.10.10` |
| DNS direct depuis web | Fonctionne avant la modification du pare-feu → bloqué après (`timed out` + log `DPT=53`) |
| `apt update` sur web | OK, en passant par le DNS de gw |

Fichiers : [`preuves/phase-3/`](preuves/phase-3/)

## Difficultés rencontrées
- Fichier de preuve « avant » capturé après le changement prévu → renommé, et le blocage prouvé par un second test et par les logs du pare-feu
- Service avahi découvert en écoute sur toutes les interfaces → désactivé