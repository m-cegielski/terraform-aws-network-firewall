locals {
  rule_groups_map             = zipmap(var.rule_groups[*]["name"], var.rule_groups[*]["type"])
  stateful_rule_groups_names  = compact([for name, type in local.rule_groups_map : type == "STATEFUL" ? name : ""])
  stateless_rule_groups_names = compact([for name, type in local.rule_groups_map : type == "STATELESS" ? name : ""])
}

resource "aws_networkfirewall_firewall" "this" {
  name                = var.name
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = var.vpc_id

  dynamic "subnet_mapping" {
    for_each = var.subnet_mapping
    content {
      subnet_id = subnet_mapping.value.subnet_id
    }
  }
  tags = merge(var.tags)
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = var.name

  firewall_policy {
    stateless_default_actions          = var.stateless_default_actions
    stateless_fragment_default_actions = var.stateless_fragment_default_actions

    dynamic "stateless_rule_group_reference" {
      for_each = local.stateless_rule_groups_names
      content {
        priority     = var.rule_groups[index(var.rule_groups[*]["name"], stateless_rule_group_reference.value)]["priority"]
        resource_arn = aws_networkfirewall_rule_group.this[stateless_rule_group_reference.value].arn
      }
    }

    dynamic "stateful_rule_group_reference" {
      for_each = local.stateful_rule_groups_names
      content {
        resource_arn = aws_networkfirewall_rule_group.this[stateful_rule_group_reference.value].arn
      }
    }
  }

  tags = merge(var.tags)
}

resource "aws_networkfirewall_rule_group" "this" {
  for_each = toset(var.rule_groups[*]["name"])

  name        = each.key
  description = var.rule_groups[index(var.rule_groups[*]["name"], each.key)]["description"]
  type        = var.rule_groups[index(var.rule_groups[*]["name"], each.key)]["type"]
  capacity    = var.rule_groups[index(var.rule_groups[*]["name"], each.key)]["capacity"]

  rules = lookup(var.rule_groups[index(var.rule_groups[*]["name"], each.key)], "rules_file", null)

  dynamic "rule_group" {
    for_each = [var.rule_groups[index(var.rule_groups[*]["name"], each.key)]]

    content {

      dynamic "rule_variables" {
        for_each = length(lookup(rule_group.value, "rule_variables", [])) > 0 ? [1] : []

        content {

          dynamic "ip_sets" {
            for_each = [for variable in rule_group.value["rule_variables"] : variable if lookup(variable, "ip_set", "") != ""]

            content {
              key = ip_sets.value["key"]
              ip_set {
                definition = ip_sets.value["ip_set"]
              }
            }
          }

          dynamic "port_sets" {
            for_each = [for variable in rule_group.value["rule_variables"] : variable if lookup(variable, "port_set", "") != ""]

            content {
              key = port_sets.value["key"]
              port_set {
                definition = port_sets.value["port_set"]
              }
            }
          }
        }
      }

      rules_source {

        rules_string = lookup(rule_group.value, "rules_string", null)

        dynamic "stateful_rule" {
          for_each = lookup(rule_group.value, "stateful_rule", [])
          content {
            action = upper(stateful_rule.value.action)
            header {
              destination      = stateful_rule.value.destination
              destination_port = stateful_rule.value.destination_port
              direction        = upper(stateful_rule.value.direction)
              protocol         = upper(stateful_rule.value.protocol)
              source           = stateful_rule.value.source
              source_port      = stateful_rule.value.source_port
            }
            rule_option {
              keyword  = stateful_rule.value.rule_option
              settings = lookup(stateful_rule.value, "settings", null)
            }
          }
        }

        dynamic "rules_source_list" {
          for_each = lookup(rule_group.value, "rules_source_list", [])

          content {
            generated_rules_type = rules_source_list.value["actions"]
            target_types         = rules_source_list.value["protocols"]
            targets              = rules_source_list.value["domain_list"]
          }
        }



        dynamic "stateless_rules_and_custom_actions" {
          for_each = upper(rule_group.value["type"]) == "STATELESS" ? [1] : []

          content {

            dynamic "custom_action" {
              for_each = lookup(rule_group.value, "custom_action", [])

              content {
                action_name = custom_action.value["name"]
                action_definition {
                  publish_metric_action {
                    dimension {
                      value = custom_action.value["dimension"]
                    }
                  }
                }
              }
            }

            dynamic "stateless_rule" {
              for_each = lookup(rule_group.value, "stateless_rule", [])

              content {
                priority = stateless_rule.value.priority
                rule_definition {
                  actions = stateless_rule.value.actions
                  match_attributes {

                    protocols = stateless_rule.value.protocols

                    dynamic "source" {
                      for_each = contains(keys(stateless_rule.value), "source") ? [1] : []

                      content {
                        address_definition = stateless_rule.value["source"]
                      }
                    }

                    dynamic "destination" {
                      for_each = contains(keys(stateless_rule.value), "destination") ? [1] : []

                      content {
                        address_definition = stateless_rule.value["destination"]
                      }
                    }

                    dynamic "source_port" {
                      for_each = contains(keys(stateless_rule.value), "source_from_port") ? [1] : []

                      content {
                        from_port = stateless_rule.value["source_from_port"]
                        to_port   = lookup(stateless_rule.value, "source_to_port", null)
                      }
                    }

                    dynamic "destination_port" {
                      for_each = contains(keys(stateless_rule.value), "destination_from_port") ? [1] : []

                      content {
                        from_port = stateless_rule.value["destination_from_port"]
                        to_port   = lookup(stateless_rule.value, "destination_to_port", null)
                      }
                    }

                    dynamic "tcp_flag" {
                      for_each = contains(keys(stateless_rule.value), "flags") ? [1] : []

                      content {
                        flags = stateless_rule.value["flags"]
                        masks = lookup(stateless_rule.value, "masks", null)
                      }
                    }

                  }
                }
              }
            }
          }
        }
      }
    }
  }

  tags = merge(var.tags)
}

resource "aws_networkfirewall_logging_configuration" "this" {
  count = length(var.logging_configuration) > 0 ? 1 : 0

  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {

    dynamic "log_destination_config" {
      for_each = toset(var.logging_configuration[*]["log_destination_config"])

      content {
        log_destination = {
          logGroup       = lookup(log_destination_config.value, "logGroup", null)
          bucketName     = lookup(log_destination_config.value, "bucketName", null)
          prefix         = lookup(log_destination_config.value, "prefix", null)
          deliveryStream = lookup(log_destination_config.value, "deliveryStream", null)
        }
        log_destination_type = log_destination_config.value["log_destination_type"]
        log_type             = log_destination_config.value["log_type"]
      }
    }

  }
}
