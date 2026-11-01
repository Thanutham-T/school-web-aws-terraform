locals {
  # Key example: "web-out-mysql-db"
  rules = {
    for rule in flatten([
      for sg_key, sg in var.security_groups_rules : [
        for rule_key, r in sg.rules : merge(r, {
          key    = "${sg_key}-${rule_key}"
          sg_key = sg_key
        })
      ]
    ]) : rule.key => rule
  }

  ingress_rules = { for k, r in local.rules : k => r if r.direction == "ingress" }
  egress_rules  = { for k, r in local.rules : k => r if r.direction == "egress" }

  prefix_list_names = toset([for r in local.rules : r.prefix_list_name if r.prefix_list_name != null])
}

data "aws_ec2_managed_prefix_list" "this" {
  for_each = local.prefix_list_names

  name = each.value
}

resource "aws_security_group" "this" {
  #checkov:skip=CKV2_AWS_5:SGs are created in this module and attached to resources in other modules via outputs
  for_each = var.security_groups_rules

  # name and description can't change in place, so a replacement must create the new group first.
  # A fixed name would clash with the old group, hence name_prefix; the clean name is in the Name tag.
  name_prefix = "${each.value.name}-"
  description = each.value.description
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = each.value.name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.ingress_rules

  security_group_id            = aws_security_group.this[each.value.sg_key].id
  description                  = each.value.description
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  cidr_ipv4                    = each.value.cidr_ipv4
  prefix_list_id               = each.value.prefix_list_name == null ? null : data.aws_ec2_managed_prefix_list.this[each.value.prefix_list_name].id
  referenced_security_group_id = each.value.referenced_sg_key == null ? null : aws_security_group.this[each.value.referenced_sg_key].id
  tags                         = merge(var.tags, { Name = each.key })
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = local.egress_rules

  security_group_id            = aws_security_group.this[each.value.sg_key].id
  description                  = each.value.description
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  cidr_ipv4                    = each.value.cidr_ipv4
  prefix_list_id               = each.value.prefix_list_name == null ? null : data.aws_ec2_managed_prefix_list.this[each.value.prefix_list_name].id
  referenced_security_group_id = each.value.referenced_sg_key == null ? null : aws_security_group.this[each.value.referenced_sg_key].id
  tags                         = merge(var.tags, { Name = each.key })
}
