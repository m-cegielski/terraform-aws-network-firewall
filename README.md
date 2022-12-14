# Terraform module for Network Firewall

Terraform module that creates network firewall, network firewall policy, rule groups and logging configuration.

## Usage

    module "network_firewall" {

      source = ".."
      name   = "nfw-development"
      vpc_id = "vpc-xxxxxxxx"

      subnet_mapping = [
        {
          subnet_id = "subnet-xxxxxxxx"
        },
        {
          subnet_id = "subnet-yyyyyyyy"
        }
      ]

      rule_groups = [
        {
          name        = "domain-blacklist"
          capacity    = 100
          type        = "STATEFUL"
          description = "Block domains"

          rule_variables = [
            {
              key    = "HOME_NET"
              ip_set = ["10.0.0.0/8", "172.16.0.0/12"]
            }
          ]

          rules_source_list = [
            {
              actions     = "DENYLIST"
              protocols   = ["HTTP_HOST", "TLS_SNI"]
              domain_list = ["google.com"]
            }
          ]

        },
        {
          name        = "block-public-dns"
          capacity    = 100
          type        = "STATEFUL"
          description = "Block public DNS resolvers"

          stateful_rule = [
            {
              action           = "DROP"
              destination      = "ANY"
              destination_port = "ANY"
              direction        = "ANY"
              protocol         = "DNS"
              source           = "ANY"
              source_port      = "ANY"
              rule_option      = "sid:50"
            }
          ]
        },
        {
          name        = "drop-icmp"
          capacity    = 100
          type        = "STATELESS"
          description = "Block ICMP traffic"
          priority    = 1

          stateless_rule = [
            {
              priority    = 1
              actions     = ["aws:drop"]
              source      = "0.0.0.0/0"
              destination = "0.0.0.0/0"
              protocols   = [1]

            }
          ]
        },
        {
          name        = "example"
          capacity    = 100
          type        = "STATEFUL"
          description = "Example Suricata compatible rule group that uses the variables"

          rule_variables = [
            {
              key    = "HTTP_SERVERS"
              ip_set = ["10.0.2.0/24", "10.0.1.19/32"]
            },
            {
              key      = "HTTP_PORTS"
              port_set = ["80", "8080"]
            }
          ]

          rules_string = "alert tcp $EXTERNAL_NET any -> $HTTP_SERVERS $HTTP_PORTS (msg:\".htpasswd access attempt\"; flow:to_server,established; content:\".htpasswd\"; nocase; sid:210503; rev:1;)"
        }
      ]

      logging_configuration = [
        {
          log_destination_config = {
            logGroup             = "cw_log_group"
            log_destination_type = "CloudWatchLogs"
            log_type             = "ALERT"
          },
        },
        {
          log_destination_config = {
            bucketName           = "s3_bucket"
            log_destination_type = "S3"
            log_type             = "FLOW"
          },
        }
      ]

      tags = {
        Environment = "Development"
        Managed_By  = "Terraform"
      }
    }

## Inputs

| Name                               | Description                                               |
|------                              |-------------                                              |
| name                               | Firewall name                                             |
| subnet_mapping                     | Subnet ids mapping to have individual firewall endpoint   |
| vpc_id                             | Vpc ID                                                    |
| rule_groups                        | Definition of firewall rule groups                        |
| stateless_default_actions          | Stateless default actions                                 |
| stateless_fragment_default_actions | Stateless fragment default actions                        |
| logging_configuration              | Logging configuration for the firewall                    |
| tags                               | Tags to add to resources                                  |

## Outputs

| Name                               | Description                                               |
|------                              |-------------                                              |
| network_firewall_arn               | Network Firewall ARN                                      |
| network_firewall_endpoint_ids      | List of endpoint Ids                                      |
| network_firewall_object            | Network Firewall object with all attributes               |
