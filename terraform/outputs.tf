output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.this.id
}

output "vpc_ids" {
  value = { for k, v in aws_vpc.this : k => v.id }
}

output "vpn_connection_id" {
  value = aws_vpn_connection.onprem.id
}

output "vpn_tunnel1_address" {
  value = aws_vpn_connection.onprem.tunnel1_address
}

output "resolver_inbound_ips" {
  value = aws_route53_resolver_endpoint.inbound.ip_address
}

output "network_firewall_status" {
  value = aws_networkfirewall_firewall.this.firewall_status
}
