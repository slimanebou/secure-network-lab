# Phase 2 : pare-feu iptables

## Objectif
Passer gw en politique « tout refuser sauf ce qui est autorisé » (Default Deny), journaliser les paquets bloqués et appliquer le pare-feu automatiquement au démarrage.

## Fichiers
- [`gw/usr/local/sbin/firewall.sh`](../gw/usr/local/sbin/firewall.sh) : la politique complète (modes `start`, `stop`, `status`)
- [`gw/etc/systemd/system/firewall.service`](../gw/etc/systemd/system/firewall.service) : lancement au démarrage, avant le réseau

## Politique appliquée
| Source | Destination | Ports | Décision |
|---|---|---|---|
| LAN | Internet | tout | ✅ |
| DMZ | Internet | 53, 80, 443, 123 + ping | ✅ (filtrage en sortie) |
| LAN | web | 80, 443 + ping | ✅ |
| Internet | web (DNAT) | 80, 443 | ✅ |
| Hôte (NAT VMware) | gw | 22 | ✅ temporaire, remplacé par le VPN en phase 4 |
| DMZ | LAN | tout | ❌ DROP + LOG |
| LAN | web, gw | 22 | ❌ DROP + LOG |

## Preuves
| Test | Avant | Après |
|---|---|---|
| web → client (SSH, ping) | joignable | bloqué (timeout) |
| client → web:22 | joignable | bloqué (timeout) |
| client → web:80 | refused | refused (autorisé, pas encore de service) |
| client → gw:22 | joignable | bloqué (timeout) |

Fichiers : [`preuves/phase-2/`](preuves/phase-2/) (avant / après, logs, état après redémarrage)

## Difficultés rencontrées
- Preuve « avant » de client oubliée → recréée en désactivant temporairement le pare-feu (`firewall.sh stop`)
- Horodatage des logs faux → fuseau horaire des VMs corrigé en `Europe/Paris`