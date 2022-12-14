variable "name" {
  type        = string
  description = "Firewall name"
}

variable "subnet_mapping" {
  type        = list
  description = "Subnet mapping for the firewall"
}

variable "vpc_id" {
  type        = string
  description = "Vpc id in which firewall will be created"
}

variable "rule_groups" {
  type        = any
  description = "Rule groups to use in network firewall"
}

variable "stateless_default_actions" {
  type        = list(string)
  description = "Stateless default action"
  default     = ["aws:forward_to_sfe"]
}

variable "stateless_fragment_default_actions" {
  type        = list(string)
  description = "Stateless fragment default actions"
  default     = ["aws:forward_to_sfe"]
}

variable "logging_configuration" {
  type        = any
  description = "Logging configuration"
  default     = []
}

variable "tags" {
  type        = map(any)
  description = "Tags for all resources"
  default     = {}
}
