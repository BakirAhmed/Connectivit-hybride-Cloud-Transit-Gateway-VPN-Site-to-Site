# Détails de conception — Connectivité hybride

## 1. Plan d'adressage IP

| Environnement | CIDR | Usage |
|---|---|---|
| On-premise | 10.0.0.0/16 | Datacenter physique (simulé) |
| Dev | 10.10.0.0/16 | Environnement de développement |
| Staging | 10.20.0.0/16 | Pré-production |
| Prod | 10.30.0.0/16 | Production |

Choix : préfixes /16 espacés (10.0/10.10/10.20/10.30) pour permettre une croissance
ultérieure de chaque environnement sans risque de chevauchement, et pour simplifier
les règles de pare-feu (résumé de route par dizaine).

## 2. Routage BGP sur le tunnel VPN

- ASN on-premise (Customer Gateway) : **65000** (plage privée 64512–65534)
- ASN côté Amazon (Transit Gateway) : **64512**
- Le tunnel IPsec IKEv2 encapsule une session BGP qui annonce dynamiquement :
  - Depuis l'on-premise → les routes internes du datacenter
  - Depuis AWS → les CIDR des VPC Dev/Staging/Prod (via propagation TGW)
- Avantage vs routes statiques : bascule automatique en cas de changement de topologie
  côté on-premise, sans intervention manuelle sur les tables de routage AWS.

## 3. Table de routage Transit Gateway

Une table de routage unique (`spokes`) associe et propage les 3 attachements VPC et
l'attachement VPN, ce qui permet une communication complète on-prem ↔ VPC et VPC ↔ VPC
(hub-and-spoke). Pour une isolation stricte (ex. Dev ne doit pas joindre Prod), on
créerait des tables de routage séparées par segment — piste d'amélioration documentée
dans le README.

## 4. Résolution DNS hybride

- **Resolver Outbound Endpoint** (côté AWS) : transfère les requêtes du domaine
  `corp.local` vers le serveur DNS on-premise.
- **Resolver Inbound Endpoint** : permet aux hôtes on-premise de résoudre les zones
  privées Route 53 hébergées dans le VPC Prod.
- Un `aws_route53_resolver_rule` de type `FORWARD` associe le domaine `corp.local` à
  l'IP du DNS on-premise simulé.

## 5. Inspection est-ouest

AWS Network Firewall est déployé dans le VPC Prod avec un groupe de règles stateful.
En production, les tables de routage des subnets seraient modifiées pour forcer le
trafic inter-VPC à transiter par les endpoints du firewall (inspection VPC pattern).

## 6. Partage multi-comptes (AWS RAM)

Le Transit Gateway est partagé via AWS Resource Access Manager, ce qui permettrait à
d'autres comptes AWS (organisation) d'y attacher leurs propres VPC sans dupliquer
l'infrastructure réseau centrale.
