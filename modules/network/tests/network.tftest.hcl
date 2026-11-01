# Native Terraform tests for the network module.
# Run from modules/network: terraform init -backend=false && terraform test
#
# The AWS provider is mocked, so these tests cost nothing and never touch
# a real account. They validate structure (counts, keys, routing shape) and
# input validation, not provider-side behaviour.

mock_provider "aws" {
  # Policy documents are data sources, so their rendered JSON must be mocked.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  project                   = "test"
  vpc_cidr_block            = "10.0.0.0/16"
  public_subnet_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidr_blocks = {
    app = ["10.0.11.0/24", "10.0.12.0/24"]
    db  = ["10.0.21.0/24", "10.0.22.0/24"]
  }
  availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]
}

run "creates_one_subnet_per_tier_and_az" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Expected one public subnet per availability zone."
  }

  assert {
    condition     = length(aws_subnet.private) == 4
    error_message = "Expected one private subnet per tier per availability zone."
  }

  assert {
    condition     = length(aws_network_acl_association.this) == 6
    error_message = "Expected one NACL association per subnet."
  }
}

run "ships_empty_nacl_rule_defaults" {
  command = plan

  assert {
    condition     = length(aws_network_acl_rule.static) == 0 && length(aws_network_acl_rule.dynamic) == 0
    error_message = "Module defaults should define no NACL rules (deny all); callers supply them."
  }
}

run "routes_app_through_nat_and_isolates_db" {
  command = plan

  assert {
    condition     = length(aws_route_table.private) == 2
    error_message = "Expected a separate private route table per tier."
  }

  assert {
    condition     = contains(keys(aws_route_table.private), "db") && contains(keys(aws_route_table.private), "app")
    error_message = "Expected private route tables keyed by app and db tier."
  }

  assert {
    condition     = aws_route.app_nat.destination_cidr_block == "0.0.0.0/0"
    error_message = "The app tier must have a default route to the NAT gateway."
  }
}

run "creates_gateway_endpoints_and_optional_flow_logs" {
  command = plan

  assert {
    condition     = length(aws_vpc_endpoint.gateway) == 2
    error_message = "Expected S3 and DynamoDB gateway endpoints by default."
  }

  assert {
    condition     = length(aws_flow_log.this) == 0
    error_message = "Flow logs should be opt-in (enable_flow_logs defaults to false)."
  }
}

run "encrypts_and_retains_flow_logs" {
  command = plan

  variables {
    enable_flow_logs = true
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_logs) == 1 && length(aws_flow_log.this) == 1
    error_message = "Expected a log group and a flow log when flow logs are enabled."
  }

  assert {
    condition     = length(aws_kms_key.flow_logs) == 1 && length(aws_kms_key_policy.flow_logs) == 1
    error_message = "Expected a dedicated KMS key and key policy when flow logs are enabled."
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_logs[0].retention_in_days == 365
    error_message = "Expected the default log retention to be 365 days."
  }
}

run "rejects_mismatched_az_count" {
  command = plan

  variables {
    public_subnet_cidr_blocks = ["10.0.1.0/24"]
  }

  expect_failures = [var.public_subnet_cidr_blocks]
}

run "rejects_duplicate_subnet_cidrs" {
  command = plan

  variables {
    private_subnet_cidr_blocks = {
      app = ["10.0.1.0/24", "10.0.12.0/24"]
      db  = ["10.0.21.0/24", "10.0.22.0/24"]
    }
  }

  expect_failures = [var.private_subnet_cidr_blocks]
}
