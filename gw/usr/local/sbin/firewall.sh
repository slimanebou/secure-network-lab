#!/usr/bin/env bash
# =====================================================================
# firewall.sh - Pare-feu de gw (Secure Network Lab)
# Politique : tout refuser par défaut, n'autoriser que le nécessaire
# Usage     : firewall.sh start | stop | status
# =====================================================================
set -euo pipefail

# ---------- Variables : interfaces et adresses ----------
WAN=ens33                    # Carte NAT VMware (Internet)
DMZ=ens37                    # Carte DMZ  (vmnet2)
LAN=ens38                    # Carte LAN  (vmnet3)
MON=10.10.20.20              # Serveur de supervision (Zabbix)

VPN=wg0                      # Carte du tunnel WireGuard
VPN_PORT=51820               # Port UDP de WireGuard

INT_NETS=10.10.0.0/16        # DMZ + LAN
WEB=10.10.10.10              # Serveur web en DMZ

LOG_LIMIT="5/min"            # nombre max de lignes de log par minute

# ---------- Mode start : appliquer la politique ----------
start() {
  # 1. Repartir de zéro
  iptables -F                # vide les règles de la table filter
  iptables -X                # supprime les chaînes personnalisées
  iptables -t nat -F         # vide les règles de la table nat

  # 2. Politiques par défaut
  iptables -P INPUT   DROP
  iptables -P FORWARD DROP
  iptables -P OUTPUT  ACCEPT

  # 3. INPUT : ce qui arrive SUR gw
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

  # WireGuard : le tunnel peut être joint depuis le WAN
  iptables -A INPUT -i "$WAN" -p udp --dport "$VPN_PORT" -j ACCEPT
  # Dans le tunnel : SSH et ping vers gw
  iptables -A INPUT -i "$VPN" -p tcp --dport 22 -j ACCEPT
  iptables -A INPUT -i "$VPN" -p icmp --icmp-type echo-request -j ACCEPT

  iptables -A INPUT -i "$DMZ" -p icmp --icmp-type echo-request -j ACCEPT
  iptables -A INPUT -i "$LAN" -p icmp --icmp-type echo-request -j ACCEPT

  # DNS (dnsmasq) pour la DMZ et le LAN
  iptables -A INPUT -i "$DMZ" -p udp --dport 53 -j ACCEPT
  iptables -A INPUT -i "$DMZ" -p tcp --dport 53 -j ACCEPT
  iptables -A INPUT -i "$LAN" -p udp --dport 53 -j ACCEPT
  iptables -A INPUT -i "$LAN" -p tcp --dport 53 -j ACCEPT

  # Supervision : mon interroge l'agent de gw
  iptables -A INPUT -i "$LAN" -s "$MON" -p tcp --dport 10050 -j ACCEPT

  # 4. FORWARD : ce qui TRAVERSE gw
  iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP

  # LAN -> Internet : tout
  iptables -A FORWARD -i "$LAN" -o "$WAN" -j ACCEPT

  # DMZ -> Internet : uniquement HTTP/HTTPS, NTP et ping (le DNS passe par gw)
  iptables -A FORWARD -i "$DMZ" -o "$WAN" -p udp --dport 123 -j ACCEPT
  iptables -A FORWARD -i "$DMZ" -o "$WAN" -p tcp -m multiport --dports 80,443 -j ACCEPT
  iptables -A FORWARD -i "$DMZ" -o "$WAN" -p icmp --icmp-type echo-request -j ACCEPT

  # LAN -> serveur web : HTTP/HTTPS et ping
  iptables -A FORWARD -i "$LAN" -o "$DMZ" -d "$WEB" -p tcp -m multiport --dports 80,443 -j ACCEPT
  iptables -A FORWARD -i "$LAN" -o "$DMZ" -p icmp --icmp-type echo-request -j ACCEPT

  # VPN admin -> interface web de Zabbix
  iptables -A FORWARD -i "$VPN" -o "$LAN" -d "$MON" -p tcp --dport 80 -j ACCEPT

  # Supervision : mon interroge l'agent de web
  iptables -A FORWARD -i "$LAN" -o "$DMZ" -s "$MON" -d "$WEB" -p tcp --dport 10050 -j ACCEPT

  # Internet -> serveur web : HTTP/HTTPS (redirigé par le DNAT ci-dessous)
  iptables -A FORWARD -i "$WAN" -o "$DMZ" -d "$WEB" -p tcp -m multiport --dports 80,443 -j ACCEPT

  # DMZ -> LAN : AUCUNE règle, donc bloqué par la politique DROP
  
  # 4bis. Journaliser ce qui va être jeté (dernières règles des chaînes)
  iptables -A INPUT   -m limit --limit "$LOG_LIMIT" --limit-burst 10 \
           -j LOG --log-prefix "FW-DROP-IN: "  --log-level 4
  iptables -A FORWARD -m limit --limit "$LOG_LIMIT" --limit-burst 10 \
           -j LOG --log-prefix "FW-DROP-FWD: " --log-level 4

  # 5. NAT
  iptables -t nat -A PREROUTING  -i "$WAN" -p tcp -m multiport --dports 80,443 -j DNAT --to-destination "$WEB"
  iptables -t nat -A POSTROUTING -s "$INT_NETS" -o "$WAN" -j MASQUERADE

  echo "Pare-feu appliqué."
}

# ---------- Mode stop : tout ouvrir (secours) ----------
stop() {
  iptables -P INPUT   ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT  ACCEPT
  iptables -F
  iptables -X
  iptables -t nat -F
  iptables -t nat -A POSTROUTING -s "$INT_NETS" -o "$WAN" -j MASQUERADE
  echo "ATTENTION : pare-feu désactivé (tout est autorisé, NAT conservé)."
}

# ---------- Mode status : afficher l'état ----------
status() {
  echo "===== Table filter ====="
  iptables -L -n -v --line-numbers
  echo
  echo "===== Table nat ====="
  iptables -t nat -L -n -v --line-numbers
}

# ---------- Point d'entrée ----------
[[ $EUID -eq 0 ]] || { echo "Erreur : lancer avec sudo." >&2; exit 1; }

case "${1:-}" in
  start)  start  ;;
  stop)   stop   ;;
  status) status ;;
  *) echo "Usage : $0 {start|stop|status}" >&2; exit 1 ;;
esac