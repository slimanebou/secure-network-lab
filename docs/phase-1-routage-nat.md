# Phase 1 : routage et NAT

## Objectif

Transformer `gw` en routeur :
1. faire communiquer la DMZ (`10.10.10.0/24`) et le LAN (`10.10.20.0/24`) ;
2. donner accès à Internet à ces deux réseaux privés grâce au NAT.

## Configuration

### Routage IPv4

Fichier [`gw/etc/sysctl.d/99-routage.conf`](../gw/etc/sysctl.d/99-routage.conf) :

```
net.ipv4.ip_forward = 1
```

Appliqué avec `sudo sysctl --system`, et vérifié après redémarrage (`cat /proc/sys/net/ipv4/ip_forward` → `1`).

### NAT MASQUERADE

```bash
iptables -t nat -A POSTROUTING -s 10.10.0.0/16 -o ens33 -j MASQUERADE
```

| Élément | Rôle |
|---|---|
| `-t nat -A POSTROUTING` | Règle appliquée juste avant la sortie du paquet |
| `-s 10.10.0.0/16` | Concerne la DMZ et le LAN |
| `-o ens33` | Uniquement vers la carte WAN |
| `-j MASQUERADE` | Remplace l'adresse source par l'IP actuelle de `ens33` |

> La règle n'est pas encore persistante : elle sera intégrée au script `firewall.sh` en phase 2.

## Preuves

### 1. Routage DMZ → LAN (ping `web` → `client`)

**Avant** (`ip_forward = 0`) : `gw` jette les paquets qui ne lui sont pas destinés.

```
bouaroua@web:~$ ping -c2 10.10.20.10
PING 10.10.20.10 (10.10.20.10) 56(84) bytes of data.

--- 10.10.20.10 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 1020ms
```

**Après** (`ip_forward = 1`) : les paquets traversent `gw`.

```
bouaroua@web:~$ ping -c2 10.10.20.10
PING 10.10.20.10 (10.10.20.10) 56(84) bytes of data.
64 bytes from 10.10.20.10: icmp_seq=1 ttl=63 time=2.71 ms
64 bytes from 10.10.20.10: icmp_seq=2 ttl=63 time=2.81 ms

--- 10.10.20.10 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 2.714/2.763/2.813/0.049 ms
```

Le `ttl=63` confirme le passage par un routeur : `client` envoie sa réponse avec un TTL de 64, que `gw` décrémente de 1 en la transmettant.

### 2. NAT (capture `tcpdump` sur `ens33` pendant un ping `web` → `8.8.8.8`)

Commande de capture sur `gw` :

```bash
sudo tcpdump -lni ens33 icmp -c6
```

**Avant** (sans règle NAT) : la source privée `10.10.10.10` sort telle quelle, aucune réponse ne revient.

```
15:28:03.447476 IP 10.10.10.10 > 8.8.8.8: ICMP echo request, id 10, seq 1, length 64
15:28:04.464833 IP 10.10.10.10 > 8.8.8.8: ICMP echo request, id 10, seq 2, length 64
15:28:05.489106 IP 10.10.10.10 > 8.8.8.8: ICMP echo request, id 10, seq 3, length 64
```

```
bouaroua@web:~$ ping -c3 8.8.8.8
3 packets transmitted, 0 received, 100% packet loss, time 2041ms
```

**Après** (avec MASQUERADE) : la source est traduite en `192.168.204.140` (IP de `ens33`) et les réponses reviennent.

```
15:28:27.155392 IP 192.168.204.140 > 8.8.8.8: ICMP echo request, id 11, seq 1, length 64
15:28:27.160589 IP 8.8.8.8 > 192.168.204.140: ICMP echo reply, id 11, seq 1, length 64
15:28:28.156970 IP 192.168.204.140 > 8.8.8.8: ICMP echo request, id 11, seq 2, length 64
15:28:28.176892 IP 8.8.8.8 > 192.168.204.140: ICMP echo reply, id 11, seq 2, length 64
15:28:29.159259 IP 192.168.204.140 > 8.8.8.8: ICMP echo request, id 11, seq 3, length 64
15:28:29.175219 IP 8.8.8.8 > 192.168.204.140: ICMP echo reply, id 11, seq 3, length 64
```

```
bouaroua@web:~$ ping -c3 8.8.8.8
64 bytes from 8.8.8.8: icmp_seq=1 ttl=127 time=6.40 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=127 time=20.7 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=127 time=16.8 ms

3 packets transmitted, 3 received, 0% packet loss, time 2004ms
```

## Résumé

| Test | Avant | Après |
|---|---|---|
| `web` → `client` | 100 % de perte | 0 % de perte |
| `web` → `8.8.8.8` | 100 % de perte, source `10.10.10.10` | 0 % de perte, source traduite en `192.168.204.140` |

## Difficultés rencontrées

- Aucune difficulté bloquante sur cette phase.
