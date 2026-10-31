locals {
  # ==========================================
  # PUBLIC NACL RULES
  # ==========================================
  public_nacl_rules_map = {
    for rule in flatten([
      # INBOUND
      { id = "in_https_anywhere", rule_number = 100, egress = false, cidr_block = "0.0.0.0/0", from_port = var.https_port, to_port = var.https_port },
      { id = "in_ephemeral_low", rule_number = 110, egress = false, cidr_block = "0.0.0.0/0", from_port = 1024, to_port = 3388 },
      { id = "in_ephemeral_high", rule_number = 111, egress = false, cidr_block = "0.0.0.0/0", from_port = 3390, to_port = 65535 },

      # OUTBOUND
      [for idx, cidr in sort(keys(local.app_subnets)) : {
        id = "out_http_to_app_${idx}", rule_number = 100 + idx, egress = true, cidr_block = cidr, from_port = var.app_port, to_port = var.app_port
      }],
      { id = "out_https_anywhere", rule_number = 110, egress = true, cidr_block = "0.0.0.0/0", from_port = var.https_port, to_port = var.https_port },
      { id = "out_ephemeral_anywhere", rule_number = 120, egress = true, cidr_block = "0.0.0.0/0", from_port = 1024, to_port = 65535 }
    ]) : rule.id => rule
  }

  # ==========================================
  # APP NACL RULES
  # ==========================================
  app_nacl_rules_map = {
    for rule in flatten([
      # INBOUND
      [for idx, cidr in sort(keys(local.public_subnets)) : {
        id = "in_http_from_public_${idx}", rule_number = 100 + idx, egress = false, cidr_block = cidr, from_port = var.app_port, to_port = var.app_port
      }],
      [for idx, cidr in sort(keys(local.public_subnets)) : {
        id = "in_ephem_from_public_${idx}", rule_number = 110 + idx, egress = false, cidr_block = cidr, from_port = 1024, to_port = 65535
      }],
      [for idx, cidr in sort(keys(local.db_subnets)) : {
        id = "in_ephem_from_db_${idx}", rule_number = 120 + idx, egress = false, cidr_block = cidr, from_port = 1024, to_port = 65535
      }],

      # OUTBOUND
      { id = "out_https_anywhere", rule_number = 100, egress = true, cidr_block = "0.0.0.0/0", from_port = var.https_port, to_port = var.https_port },
      [for idx, cidr in sort(keys(local.db_subnets)) : {
        id = "out_mysql_to_db_${idx}", rule_number = 110 + idx, egress = true, cidr_block = cidr, from_port = var.db_port, to_port = var.db_port
      }],
      [for idx, cidr in sort(keys(local.public_subnets)) : {
        id = "out_ephem_to_public_${idx}", rule_number = 120 + idx, egress = true, cidr_block = cidr, from_port = 1024, to_port = 65535
      }]
    ]) : rule.id => rule
  }

  # ==========================================
  # DB NACL RULES
  # ==========================================
  db_nacl_rules_map = {
    for rule in flatten([
      # INBOUND
      [for idx, cidr in sort(keys(local.app_subnets)) : {
        id = "in_mysql_from_app_${idx}", rule_number = 100 + idx, egress = false, cidr_block = cidr, from_port = var.db_port, to_port = var.db_port
      }],

      # OUTBOUND
      [for idx, cidr in sort(keys(local.app_subnets)) : {
        id = "out_ephem_to_app_${idx}", rule_number = 100 + idx, egress = true, cidr_block = cidr, from_port = 1024, to_port = 65535
      }]
    ]) : rule.id => rule
  }
}


# ==========================================
# PUBLIC TIER
# ==========================================
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = [for s in aws_subnet.public : s.id]
  tags       = { Name = "${var.project}-public-nacl" }
}

resource "aws_network_acl_rule" "public_rules" {
  for_each       = local.public_nacl_rules_map
  network_acl_id = aws_network_acl.public.id

  rule_number = each.value.rule_number
  egress      = each.value.egress
  protocol    = "tcp"
  rule_action = "allow"
  cidr_block  = each.value.cidr_block
  from_port   = each.value.from_port
  to_port     = each.value.to_port
}

# ==========================================
# APP TIER
# ==========================================
resource "aws_network_acl" "app" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = [for s in aws_subnet.private : s.id if s.tags.Tier == "app"]
  tags       = { Name = "${var.project}-app-nacl" }
}

resource "aws_network_acl_rule" "app_rules" {
  for_each       = local.app_nacl_rules_map
  network_acl_id = aws_network_acl.app.id

  rule_number = each.value.rule_number
  egress      = each.value.egress
  protocol    = "tcp"
  rule_action = "allow"
  cidr_block  = each.value.cidr_block
  from_port   = each.value.from_port
  to_port     = each.value.to_port
}

# ==========================================
# DB TIER
# ==========================================
resource "aws_network_acl" "db" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = [for s in aws_subnet.private : s.id if s.tags.Tier == "db"]
  tags       = { Name = "${var.project}-db-nacl" }
}

resource "aws_network_acl_rule" "db_rules" {
  for_each       = local.db_nacl_rules_map
  network_acl_id = aws_network_acl.db.id

  rule_number = each.value.rule_number
  egress      = each.value.egress
  protocol    = "tcp"
  rule_action = "allow"
  cidr_block  = each.value.cidr_block
  from_port   = each.value.from_port
  to_port     = each.value.to_port
}
