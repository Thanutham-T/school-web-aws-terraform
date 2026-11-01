mock_provider "aws" {}

variables {
  vpc_id = "vpc-12345678"
}

run "builds_all_rules" {
  command = plan

  assert {
    condition     = length(aws_security_group.this) == 4
    error_message = "expected 4 security groups"
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 4 && length(aws_vpc_security_group_egress_rule.this) == 4
    error_message = "expected 4 ingress and 4 egress rules"
  }
}

run "rejects_rule_with_no_source" {
  command = plan

  variables {
    security_groups_rules = {
      db = {
        name        = "db-sg"
        description = "db"
        rules       = { in-mysql = { direction = "ingress", protocol = "tcp", from_port = 3306, to_port = 3306 } }
      }
    }
  }

  expect_failures = [var.security_groups_rules]
}

run "rejects_bad_direction" {
  command = plan

  variables {
    security_groups_rules = {
      db = {
        name        = "db-sg"
        description = "db"
        rules       = { out-x = { direction = "egres", protocol = "tcp", from_port = 1, to_port = 1, cidr_ipv4 = "10.0.0.0/8" } }
      }
    }
  }

  expect_failures = [var.security_groups_rules]
}
