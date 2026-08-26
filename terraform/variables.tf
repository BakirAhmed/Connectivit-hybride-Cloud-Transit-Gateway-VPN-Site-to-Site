variable "aws_region" {
  description = "Région AWS de déploiement"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Préfixe utilisé pour nommer toutes les ressources"
  type        = string
  default     = "hybrid-tgw"
}

# --- Plan d'adressage CIDR (sans chevauchement) ---
variable "onprem_cidr" {
  description = "CIDR simulant le datacenter on-premise"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dev_vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "staging_vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "prod_vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "onprem_bgp_asn" {
  description = "ASN côté on-premise (Customer Gateway) pour le peering BGP"
  type        = number
  default     = 65000
}

variable "tgw_asn" {
  description = "ASN Amazon côté Transit Gateway"
  type        = number
  default     = 64512
}

variable "onprem_public_ip" {
  description = "IP publique simulée du routeur on-premise (Customer Gateway)"
  type        = string
  default     = "203.0.113.10"
}
