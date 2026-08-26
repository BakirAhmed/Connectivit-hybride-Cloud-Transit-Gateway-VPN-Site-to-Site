# 🔗 Connectivité Hybride Cloud — AWS Transit Gateway & Site-to-Site VPN

[![Terraform](https://img.shields.io/badge/IaC-Terraform-844FBA?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?logo=amazonaws)](https://aws.amazon.com/)
[![Status](https://img.shields.io/badge/status-en%20cours-yellow)]()

## 🎯 Objectif du projet

Concevoir et déployer une architecture réseau **hub-and-spoke** connectant un datacenter
on-premise à trois environnements AWS (**Dev / Staging / Prod**) via **AWS Transit Gateway**,
avec une connectivité VPN chiffrée, un routage dynamique **BGP**, une résolution **DNS hybride**
et une inspection du trafic **est-ouest**.

Ce projet illustre des compétences réseau (BGP, VPN IPsec, plan d'adressage) appliquées à une
infrastructure cloud AWS, dans une logique d'architecte réseaux & cloud.

## 🏗️ Architecture

```mermaid
flowchart LR
    subgraph OnPrem["🏢 Datacenter On-Premise (10.0.0.0/16)"]
        CGW["Customer Gateway<br/>ASN 65000"]
        DNSonprem["Serveur DNS interne<br/>corp.local"]
    end

    subgraph AWS["☁️ AWS Cloud"]
        VPN["Site-to-Site VPN<br/>IKEv2 + BGP"]
        TGW["Transit Gateway<br/>ASN 64512<br/>(hub central)"]

        subgraph DevVPC["VPC Dev — 10.10.0.0/16"]
            DevSub["Subnet privé"]
        end
        subgraph StagingVPC["VPC Staging — 10.20.0.0/16"]
            StagSub["Subnet privé"]
        end
        subgraph ProdVPC["VPC Prod — 10.30.0.0/16"]
            ProdSub["Subnet privé"]
            NFW["AWS Network Firewall<br/>(inspection est-ouest)"]
            R53R["Route 53 Resolver<br/>Inbound / Outbound"]
        end

        RAM["AWS RAM<br/>(partage multi-comptes)"]
    end

    CGW <-->|"Tunnel IPsec IKEv2<br/>BGP dynamique"| VPN
    VPN --> TGW
    TGW --> DevSub
    TGW --> StagSub
    TGW --> ProdSub
    ProdSub --- NFW
    R53R -.->|forward corp.local| DNSonprem
    TGW -.-> RAM
```

### Composants clés

| Composant | Rôle |
|---|---|
| **AWS Transit Gateway** | Hub central reliant les 3 VPC et le VPN on-premise (topologie hub-and-spoke) |
| **Site-to-Site VPN (IKEv2)** | Tunnel chiffré vers le datacenter, routage dynamique **BGP** (ASN 65000 ↔ 64512) |
| **Plan d'adressage CIDR** | `10.0.0.0/16` (on-prem), `10.10.0.0/16` (Dev), `10.20.0.0/16` (Staging), `10.30.0.0/16` (Prod) — sans chevauchement |
| **Route 53 Resolver** | Endpoints Inbound/Outbound pour résolution DNS hybride (`corp.local` ↔ zones privées AWS) |
| **AWS Network Firewall** | Inspection stateful du trafic est-ouest entre VPC |
| **AWS RAM** | Partage du Transit Gateway entre comptes AWS (organisation multi-comptes) |

## 📁 Structure du dépôt

```
.
├── terraform/
│   ├── versions.tf       # Provider AWS + contraintes de version
│   ├── variables.tf      # Plan d'adressage, ASN, région
│   ├── main.tf           # VPCs, TGW, VPN, Resolver, Network Firewall, RAM
│   └── outputs.tf        # IDs et informations de sortie
├── docs/
│   └── architecture.md   # Détails de conception (routage, BGP, DNS)
└── README.md
```

## 🚀 Déploiement

### Prérequis
- Un compte AWS avec les droits nécessaires (VPC, EC2, Transit Gateway, Route 53, Network Firewall, RAM)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.6
- AWS CLI configuré (`aws configure`)

### Étapes

```bash
git clone https://github.com/BakirAhmed/hybrid-cloud-transit-gateway-vpn.git
cd hybrid-cloud-transit-gateway-vpn/terraform

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

> ⚠️ Ce projet crée des ressources facturées (Transit Gateway, VPN, Network Firewall).
> Pensez à faire `terraform destroy` après démonstration.

### Destruction de l'environnement

```bash
terraform destroy
```

## 🧠 Points techniques abordés

- Conception d'un **plan d'adressage CIDR** multi-environnements sans chevauchement
- Topologie **hub-and-spoke** avec Transit Gateway et tables de routage dédiées
- **BGP** sur tunnel VPN IPsec (annonce dynamique des routes, ASN on-prem vs Amazon)
- **DNS hybride** via Route 53 Resolver (forwarding conditionnel de zone)
- Inspection **est-ouest** avec Network Firewall (stateful rule groups)
- Partage de ressources réseau entre comptes via **AWS RAM**

## 🔮 Améliorations futures

- [ ] Ajouter une deuxième connexion VPN pour la redondance (tunnel actif/actif)
- [ ] Comparer avec une implémentation Direct Connect
- [ ] Ajouter des tests automatisés (Terratest) et un pipeline CI/CD
- [ ] Diagramme d'architecture exporté en image (draw.io) dans `docs/`

## 👤 Auteur

**Ahmed Bakir** — Étudiant Ingénieur Réseaux & Cloud (EPSI Lyon / ENIG)
[LinkedIn](https://linkedin.com/in/ahmed-bk) · [GitHub](https://github.com/BakirAhmed)
