locals {
  # Sorted subnet CIDRs per group for deterministic AZ indexing
  subnet_cidrs = {
    public = sort(keys(local.public_subnets))
    app    = sort(keys(local.app_subnets))
    db     = sort(keys(local.db_subnets))
  }

  # Tier subnet IDs for NACL association
  tier_subnets = {
    public = values(aws_subnet.public)[*].id
    app    = [for s in aws_subnet.private : s.id if s.tags.Tier == "app"]
    db     = [for s in aws_subnet.private : s.id if s.tags.Tier == "db"]
  }

  # Flatten static rules
  static_rules_map = {
    for item in flatten([
      for tier, rules in var.nacl_static_rules : [
        for rule in rules : merge(rule, { tier = tier })
      ]
    ]) : "${item.tier}_${item.id}" => item
  }

  # Flatten dynamic rules — expand one entry per subnet CIDR
  dynamic_rules_map = {
    for item in flatten([
      for tier, rules in var.nacl_dynamic_rules : [
        for rule in rules : [
          for idx, cidr in local.subnet_cidrs[rule.subnet_group] : merge(rule, {
            tier        = tier
            cidr_block  = cidr
            rule_number = rule.rule_number + idx # 100, 101, 102 per AZ
            id          = "${rule.id}_${idx}"
          })
        ]
      ]
    ]) : "${item.tier}_${item.id}" => item
  }
}

# Create all NACLs by looping over the keys ("public", "app", "db")
resource "aws_network_acl" "all_tiers" {
  for_each = local.tier_subnets

  vpc_id     = aws_vpc.this.id
  subnet_ids = local.tier_subnets[each.key]

  tags = {
    Name = "${var.project}-${each.key}-nacl"
  }
}

# Static rules (fixed CIDR)
resource "aws_network_acl_rule" "static" {
  for_each = local.static_rules_map

  network_acl_id = aws_network_acl.all_tiers[each.value.tier].id
  rule_number    = each.value.rule_number
  egress         = each.value.egress
  protocol       = each.value.protocol
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

# Dynamic rules (per-subnet CIDR, one per AZ)
resource "aws_network_acl_rule" "dynamic" {
  for_each = local.dynamic_rules_map

  network_acl_id = aws_network_acl.all_tiers[each.value.tier].id
  rule_number    = each.value.rule_number
  egress         = each.value.egress
  protocol       = each.value.protocol
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}
