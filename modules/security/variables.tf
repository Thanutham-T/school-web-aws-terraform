variable "vpc_id" {
  description = "The VPC ID where the security groups will be created."
  type        = string
}

variable "security_groups_rules" {
  description = "Security groups and their rules. Each rule has exactly one source."
  type = map(object({
    name        = string
    description = string
    rules = map(object({ # map key = rule id, e.g. "in-https-cloudfront"
      direction         = string # "ingress" or "egress"
      description       = optional(string)
      protocol          = string
      from_port         = optional(number) # omit for protocol "-1"
      to_port           = optional(number)
      cidr_ipv4         = optional(string)
      prefix_list_name  = optional(string)
      referenced_sg_key = optional(string)
    }))
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for sg in values(var.security_groups_rules) : [
        for r in values(sg.rules) : contains(["ingress", "egress"], r.direction)
      ]
    ]))
    error_message = "direction must be \"ingress\" or \"egress\"."
  }

  validation {
    condition = alltrue(flatten([
      for sg in values(var.security_groups_rules) : [
        for r in values(sg.rules) :
        length(compact([r.cidr_ipv4, r.prefix_list_name, r.referenced_sg_key])) == 1
      ]
    ]))
    error_message = "Each rule needs exactly one of cidr_ipv4, prefix_list_name or referenced_sg_key."
  }

  validation {
    condition = alltrue(flatten([
      for sg in values(var.security_groups_rules) : [
        for r in values(sg.rules) :
        r.referenced_sg_key == null ? true : contains(keys(var.security_groups_rules), r.referenced_sg_key)
      ]
    ]))
    error_message = "referenced_sg_key must be a key of security_groups_rules."
  }
}

variable "tags" {
  description = "Tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
