#!/usr/bin/env bash
# =====================================================================
# check-lab.sh - Vérifie l'état du Secure Network Lab en une commande
# Usage : ./scripts/check-lab.sh   (depuis Git Bash, tunnel WireGuard actif)
# Code retour : 0 si tout est OK, 1 si au moins un test échoue
# =====================================================================
set -u

# Utiliser le SSH de Windows (il connaît l'agent SSH, donc pas de phrase de passe)
if [ -x /c/Windows/System32/OpenSSH/ssh.exe ]; then
  SSH=/c/Windows/System32/OpenSSH/ssh.exe
else
  SSH=ssh
fi
export SSH

# Couleurs
VERT=$'\e[32m'; ROUGE=$'\e[31m'; JAUNE=$'\e[33m'; FIN=$'\e[0m'

# Compteurs
OK=0; KO=0


# check "description" machine attendu "commande"
#   machine : gw | web | client | mon | local
#   attendu : ok (doit réussir) | ko (doit échouer)
check() {
  local desc="$1" ou="$2" attendu="$3" cmd="$4" rc

  if [ "$ou" = "local" ]; then
    bash -c "$cmd" >/dev/null 2>&1
    rc=$?
  else
    "$SSH" -o BatchMode=yes -o ConnectTimeout=5 "$ou" "$cmd" >/dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 255 ]; then
      echo "  ${JAUNE}⚠️  $desc (SSH vers $ou impossible)${FIN}"
      KO=$((KO + 1))
      return
    fi
  fi

  if { [ "$attendu" = "ok" ] && [ "$rc" -eq 0 ]; } ||
     { [ "$attendu" = "ko" ] && [ "$rc" -ne 0 ]; }; then
    echo "  ${VERT}✅ $desc${FIN}"
    OK=$((OK + 1))
  else
    echo "  ${ROUGE}❌ $desc (code retour : $rc)${FIN}"
    KO=$((KO + 1))
  fi
}

section() { echo; echo "== $1 =="; }


echo "Secure Network Lab - vérification du $(date '+%d/%m/%Y %H:%M')"

section "Accès d'administration"
check "SSH direct sur le WAN fermé"               local ko '"$SSH" -o BatchMode=yes -o ConnectTimeout=3 bouaroua@192.168.204.140 true'
check "Authentification par mot de passe refusée" local ko '"$SSH" -o BatchMode=yes -o PubkeyAuthentication=no gw true'
check "Rebond SSH gw -> web"                      web   ok 'true'

section "Services"
check "gw : pare-feu, VPN, DNS, SNMP, agent"      gw     ok 'systemctl is-active --quiet firewall wg-quick@wg0 dnsmasq snmpd zabbix-agent2'
check "web : Nginx, agent"                        web    ok 'systemctl is-active --quiet nginx zabbix-agent2'
check "mon : Zabbix, PostgreSQL, Nginx"           mon    ok 'systemctl is-active --quiet zabbix-server postgresql nginx'

section "Routage et NAT"
check "web -> Internet (ping)"                    web    ok 'ping -c3 -W2 8.8.8.8'
check "client -> Internet (ping)"                 client ok 'ping -c3 -W2 8.8.8.8'

section "Pare-feu"
check "web -> client:22 bloqué (DMZ -> LAN)"      web    ko 'nc -z -w3 10.10.20.10 22'
check "client -> web:22 bloqué"                   client ko 'nc -z -w3 10.10.10.10 22'
check "client -> gw:22 bloqué"                    client ko 'nc -z -w3 10.10.20.1 22'
check "client -> web:443 autorisé"                client ok 'nc -z -w3 10.10.10.10 443'
check "client -> agent de web bloqué"             client ko 'nc -z -w3 10.10.10.10 10050'
check "web : DNS direct vers l'extérieur bloqué"  web    ko 'dig +time=2 +tries=1 @192.168.204.2 deb.debian.org'

section "DNS interne"
check "client résout web.lab.internal"            client ok 'test "$(dig +short web.lab.internal)" = 10.10.10.10'
check "web résout un nom Internet via gw"         web    ok 'test -n "$(dig +short deb.debian.org)"'

section "Web et PKI"
check "HTTP redirige vers HTTPS (301)"            client ok 'test "$(curl -s -o /dev/null -w "%{http_code}" http://web.lab.internal)" = 301'
check "HTTPS valide (certificat de la CA)"        client ok 'curl -sf -o /dev/null https://web.lab.internal'
check "Site public via DNAT (301)"                local  ok 'test "$(curl -s -o /dev/null -w "%{http_code}" http://192.168.204.140)" = 301'

section "Supervision"
check "mon interroge l'agent de web"              mon    ok 'test "$(zabbix_get -s 10.10.10.10 -k agent.ping)" = 1'
check "mon interroge l'agent de gw"               mon    ok 'test "$(zabbix_get -s 10.10.20.1 -k agent.ping)" = 1'



echo
TOTAL=$((OK + KO))
if [ "$KO" -eq 0 ]; then
  echo "${VERT}Bilan : $OK/$TOTAL tests OK${FIN}"
  exit 0
else
  echo "${ROUGE}Bilan : $KO/$TOTAL test(s) en échec${FIN}"
  exit 1
fi