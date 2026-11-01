mock_provider "aws" {}

variables {
  vpc_id = "vpc-12345678"

  # Synthetic plan-only rules; TEST-NET CIDRs are reserved for documentation.
  security_groups_rules = {
    alb = {
      name        = "school-web-alb-sg"
      description = "Application load balancer"
      rules = {
        ingress-https = {
          direction   = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          cidr_ipv4   = "198.51.100.0/24"
          description = "HTTPS from test clients"
        }
        egress-http = {
          direction         = "egress"
          protocol          = "tcp"
          from_port         = 80
          to_port           = 80
          referenced_sg_key = "web"
          description       = "HTTP to web tier"
        }
      }
    }
    web = {
      name        = "school-web-app-sg"
      description = "Application instances"
      rules = {
        ingress-http = {
          direction         = "ingress"
          protocol          = "tcp"
          from_port         = 80
          to_port           = 80
          referenced_sg_key = "alb"
          description       = "HTTP from load balancer"
        }
        egress-mysql = {
          direction         = "egress"
          protocol          = "tcp"
          from_port         = 3306
          to_port           = 3306
          referenced_sg_key = "db"
          description       = "MySQL to database"
        }
      }
    }
    efs = {
      name        = "school-web-efs-sg"
      description = "Shared file system"
      rules = {
        ingress-nfs = {
          direction         = "ingress"
          protocol          = "tcp"
          from_port         = 2049
          to_port           = 2049
          referenced_sg_key = "web"
          description       = "NFS from web tier"
        }
        egress-test = {
          direction   = "egress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          cidr_ipv4   = "192.0.2.0/24"
          description = "Test egress rule"
        }
      }
    }
    db = {
      name        = "school-web-db-sg"
      description = "Database instances"
      rules = {
        ingress-mysql = {
          direction         = "ingress"
          protocol          = "tcp"
          from_port         = 3306
          to_port           = 3306
          referenced_sg_key = "web"
          description       = "MySQL from web tier"
        }
        egress-test = {
          direction   = "egress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          cidr_ipv4   = "192.0.2.0/24"
          description = "Test egress rule"
        }
      }
    }
  }
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
