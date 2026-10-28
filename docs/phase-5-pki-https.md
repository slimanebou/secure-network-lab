# Phase 5 : PKI interne et HTTPS

## Objectif
Créer une autorité de certification interne, signer le certificat du serveur web, forcer HTTPS sur Nginx et faire confiance à la CA sur les postes.

## Fichiers
- [`pki/ca.cnf`](../pki/ca.cnf), [`pki/ca.crt`](../pki/ca.crt) : la CA racine (la clé privée reste hors ligne, hors du dépôt)
- [`pki/web.cnf`](../pki/web.cnf), [`pki/web-ext.cnf`](../pki/web-ext.cnf), [`pki/web.crt`](../pki/web.crt) : demande et certificat de web
- [`web/etc/nginx/sites-available/secure-network-lab`](../web/etc/nginx/sites-available/secure-network-lab) : HTTPS, redirection 301, TLS 1.2/1.3

## Chaîne de confiance
`Secure Network Lab Root CA` (RSA 4096, 10 ans, `CA:TRUE, pathlen:0`) → `web.lab.internal` (RSA 2048, 397 jours, `serverAuth`, SAN : 2 noms + 2 IP)

## Preuves clés
Avant d'installer la CA sur client :
```
bouaroua@client:~$ curl https://web.lab.internal
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the webpage mentioned above.
```
Après :
```
bouaroua@client:~$ curl -sIL http://web.lab.internal | grep -E "^HTTP|^Location"
HTTP/1.1 301 Moved Permanently
Location: https://web.lab.internal/
HTTP/2 200
bouaroua@client:~$ openssl s_client -connect web.lab.internal:443 -servername web.lab.internal </dev/null 2>/dev/null | grep "Verify return code"
Verify return code: 0 (ok)
```

## Limites et améliorations
- Pas de révocation (CRL/OCSP)
- Pas de `nameConstraints` : la CA pourrait signer n'importe quel nom
- Renouvellement du certificat manuel (pas d'ACME)