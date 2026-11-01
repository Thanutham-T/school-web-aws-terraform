locals {
  nacl_tiers = toset(["public", "app", "db"])

  # The "vpc" group expands to the VPC CIDR and carries the Route 53
  # Resolver DNS rules (resolver = VPC CIDR + 2, i.e. 10.0.0.2 by default).
  subnet_cidrs = {
    public = sort(keys(local.public_subnets))
    app    = sort(keys(local.app_subnets))
    db     = sort(keys(local.db_subnets))
    vpc    = [var.vpc_cidr_block]
  }

  # Derived from module locals, not tags: a renamed tag could silently drop
  # a subnet back to the allow-all default NACL.
  nacl_associations = merge(
    {
      for cidr, subnet in aws_subnet.public :
      "public-${replace(cidr, "/", "-")}" => {
        nacl_tier = "public"
        subnet_id = subnet.id
      }
    },
    {
      for cidr, subnet in aws_subnet.private :
      "${local.all_private_subnets[cidr].tier}-${replace(cidr, "/", "-")}" => {
        nacl_tier = local.all_private_subnets[cidr].tier
        subnet_id = subnet.id
      }
    },
  )

  # One entry per static rule.
  static_rules_map = {
    for item in flatten([
      for tier, rules in var.nacl_static_rules : [
        for rule in rules : merge(rule, { tier = tier })
      ]
    ]) : "${item.tier}_${item.id}" => item
  }

  # One entry per CIDR in the rule's subnet group, with the AZ index added
  # to the rule number.
  dynamic_rules_map = {
    for item in flatten([
      for tier, rules in var.nacl_dynamic_rules : [
        for rule in rules : [
          for idx, cidr in local.subnet_cidrs[rule.subnet_group] : merge(rule, {
            tier        = tier
            cidr_block  = cidr
            rule_number = rule.rule_number + idx
            id          = "${rule.id}_${rule.subnet_group}_${idx}"
          })
        ]
      ]
    ]) : "${item.tier}_${item.id}" => item
  }

  all_nacl_rules = merge(local.static_rules_map, local.dynamic_rules_map)

  # Rule uniqueness is scoped per tier and direction, matching AWS semantics.
  nacl_rule_keys = [
    for rule in values(local.all_nacl_rules) :
    "${rule.tier}-${rule.egress}-${rule.rule_number}"
  ]
}

check "nacl_rules_valid" {
  assert {
    condition     = length(local.nacl_rule_keys) == length(distinct(local.nacl_rule_keys))
    error_message = "NACL rule numbers collide within a tier and direction. Adjust rule_number bases so AZ-offset rules do not overlap other rules."
  }

  assert {
    condition = alltrue([
      for rule in values(local.all_nacl_rules) :
      contains(["allow", "deny"], rule.rule_action)
    ])
    error_message = "NACL rule_action must be either \"allow\" or \"deny\"."
  }

  assert {
    condition = alltrue([
      for rule in values(local.all_nacl_rules) :
      rule.protocol == "icmp" ? (rule.icmp_type != null && rule.icmp_code != null) : (rule.from_port != null && rule.to_port != null)
    ])
    error_message = "ICMP rules require icmp_type and icmp_code; TCP/UDP rules require from_port and to_port."
  }
}

resource "aws_network_acl" "this" {
  #checkov:skip=CKV2_AWS_1:Every subnet is attached via aws_network_acl_association, which this graph check does not model.
  for_each = local.nacl_tiers

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project}-${each.key}-nacl"
  })
}

# Explicit associations keep each one addressable in plans.
resource "aws_network_acl_association" "this" {
  for_each = local.nacl_associations

  network_acl_id = aws_network_acl.this[each.value.nacl_tier].id
  subnet_id      = each.value.subnet_id
}

resource "aws_network_acl_rule" "static" {
  #checkov:skip=CKV_AWS_231:deny ingress from 0.0.0.0:0 to port 3389
  for_each = local.static_rules_map

  network_acl_id = aws_network_acl.this[each.value.tier].id
  rule_number    = each.value.rule_number
  egress         = each.value.egress
  protocol       = each.value.protocol
  rule_action    = each.value.rule_action
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
  icmp_type      = each.value.icmp_type
  icmp_code      = each.value.icmp_code
}

resource "aws_network_acl_rule" "dynamic" {
  #checkov:skip=CKV_AWS_231:deny ingress from 0.0.0.0:0 to port 3389
  for_each = local.dynamic_rules_map

  network_acl_id = aws_network_acl.this[each.value.tier].id
  rule_number    = each.value.rule_number
  egress         = each.value.egress
  protocol       = each.value.protocol
  rule_action    = each.value.rule_action
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
  icmp_type      = each.value.icmp_type
  icmp_code      = each.value.icmp_code
}
