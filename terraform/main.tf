##############################################
# 1. VPCs (Dev / Staging / Prod)
##############################################
locals {
  vpcs = {
    dev     = var.dev_vpc_cidr
    staging = var.staging_vpc_cidr
    prod    = var.prod_vpc_cidr
  }
}

resource "aws_vpc" "this" {
  for_each             = local.vpcs
  cidr_block           = each.value
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc-${each.key}"
    Env  = each.key
  }
}

resource "aws_subnet" "private" {
  for_each          = local.vpcs
  vpc_id            = aws_vpc.this[each.key].id
  cidr_block        = cidrsubnet(each.value, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-${each.key}-private-a"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

##############################################
# 2. Transit Gateway - hub central
##############################################
resource "aws_ec2_transit_gateway" "this" {
  description                    = "${var.project_name} hub-and-spoke TGW"
  amazon_side_asn                = var.tgw_asn
  auto_accept_shared_attachments = "enable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = { Name = "${var.project_name}-tgw" }
}

resource "aws_ec2_transit_gateway_route_table" "spokes" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags = { Name = "${var.project_name}-rt-spokes" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_attach" {
  for_each           = local.vpcs
  subnet_ids         = [aws_subnet.private[each.key].id]
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = aws_vpc.this[each.key].id

  tags = { Name = "${var.project_name}-attach-${each.key}" }
}

resource "aws_ec2_transit_gateway_route_table_association" "assoc" {
  for_each                       = local.vpcs
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_attach[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "propagate" {
  for_each                       = local.vpcs
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_attach[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

# Route dans chaque VPC vers le TGW pour le reste du plan d'adressage
resource "aws_route_table" "private" {
  for_each = local.vpcs
  vpc_id   = aws_vpc.this[each.key].id
  tags     = { Name = "${var.project_name}-rt-${each.key}" }
}

resource "aws_route_table_association" "private" {
  for_each       = local.vpcs
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route" "to_tgw" {
  for_each               = local.vpcs
  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0" # simplifié: à restreindre en prod (10.0.0.0/8 par ex.)
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on              = [aws_ec2_transit_gateway_vpc_attachment.vpc_attach]
}

##############################################
# 3. Site-to-Site VPN + BGP vers l'on-premise
##############################################
resource "aws_customer_gateway" "onprem" {
  bgp_asn    = var.onprem_bgp_asn
  ip_address = var.onprem_public_ip
  type       = "ipsec.1"
  tags       = { Name = "${var.project_name}-cgw-onprem" }
}

resource "aws_vpn_connection" "onprem" {
  customer_gateway_id = aws_customer_gateway.onprem.id
  transit_gateway_id  = aws_ec2_transit_gateway.this.id
  type                = "ipsec.1"
  static_routes_only  = false # BGP dynamique (IKEv2)

  tags = { Name = "${var.project_name}-vpn-onprem" }
}

resource "aws_ec2_transit_gateway_route_table_association" "vpn_assoc" {
  transit_gateway_attachment_id  = aws_vpn_connection.onprem.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpn_propagate" {
  transit_gateway_attachment_id  = aws_vpn_connection.onprem.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

##############################################
# 4. Route 53 Resolver - résolution DNS hybride
##############################################
resource "aws_security_group" "resolver" {
  name   = "${var.project_name}-resolver-sg"
  vpc_id = aws_vpc.this["prod"].id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.onprem_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route53_resolver_endpoint" "inbound" {
  name      = "${var.project_name}-inbound"
  direction = "INBOUND"
  security_group_ids = [aws_security_group.resolver.id]

  ip_address {
    subnet_id = aws_subnet.private["prod"].id
  }
}

resource "aws_route53_resolver_endpoint" "outbound" {
  name      = "${var.project_name}-outbound"
  direction = "OUTBOUND"
  security_group_ids = [aws_security_group.resolver.id]

  ip_address {
    subnet_id = aws_subnet.private["prod"].id
  }
}

resource "aws_route53_resolver_rule" "to_onprem" {
  domain_name          = "corp.local"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  target_ip {
    ip = cidrhost(var.onprem_cidr, 2) # DNS on-prem simulé
  }

  tags = { Name = "${var.project_name}-rule-onprem" }
}

resource "aws_route53_resolver_rule_association" "prod" {
  resolver_rule_id = aws_route53_resolver_rule.to_onprem.id
  vpc_id           = aws_vpc.this["prod"].id
}

##############################################
# 5. Network Firewall - inspection est-ouest
##############################################
resource "aws_networkfirewall_rule_group" "east_west" {
  capacity = 100
  name     = "${var.project_name}-rg-eastwest"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      stateful_rule {
        action = "PASS"
        header {
          destination      = "ANY"
          destination_port = "ANY"
          protocol         = "IP"
          direction        = "ANY"
          source           = var.dev_vpc_cidr
          source_port      = "ANY"
        }
        rule_option {
          keyword = "sid:1"
        }
      }
    }
  }
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.project_name}-fw-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.east_west.arn
    }
  }
}

resource "aws_networkfirewall_firewall" "this" {
  name                = "${var.project_name}-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = aws_vpc.this["prod"].id

  subnet_mapping {
    subnet_id = aws_subnet.private["prod"].id
  }
}

##############################################
# 6. AWS RAM - partage du TGW (multi-comptes)
##############################################
resource "aws_ram_resource_share" "tgw_share" {
  name                      = "${var.project_name}-tgw-share"
  allow_external_principals = false
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw_share.arn
}
