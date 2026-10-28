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
[colle ici l'erreur curl (60)]
```
Après :
```
[colle ici « Verify return code: 0 (ok) » et le HTTP/2 200]
```

## Limites et améliorations
- Pas de révocation (CRL/OCSP)
- Pas de `nameConstraints` : la CA pourrait signer n'importe quel nom
- Renouvellement du certificat manuel (pas d'ACME)