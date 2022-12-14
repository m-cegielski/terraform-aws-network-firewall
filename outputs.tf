output "network_firewall_arn" {
  value = aws_networkfirewall_firewall.this.arn
}

output "network_firewall_endpoint_ids" {
  value = flatten(aws_networkfirewall_firewall.this.firewall_status[*].sync_states[*].*.attachment[*])[*].endpoint_id
}

output "network_firewall_object" {
  value = aws_networkfirewall_firewall.this
}
