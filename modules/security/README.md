# Security Module

## Overview

This Terraform module creates reusable AWS security groups and their ingress and egress rules in an existing VPC.

* **Security groups** are created from a keyed map, with the supplied name used as a `Name` tag and as the prefix for the AWS security group name.
* **Ingress and egress rules** are separate resources, keyed from the security group and rule map keys.
* Each rule supports exactly one source: an IPv4 CIDR, an AWS-managed prefix list name, or another security group created by this module.
* **Tags** are merged into every security group and rule; each resource's `Name` tag is set by the module.
* **Rule direction, source selection, and security group references** are validated before resources are created.

The module does not create a VPC or attach security groups to compute resources. Consumers use the output IDs to attach groups in other modules.

## File Structure

* `security_group.tf` – Security groups, managed prefix list lookups, and standalone ingress/egress rules.
* `variables.tf` – VPC ID, security group/rule definitions, and tags.
* `outputs.tf` – Security group IDs keyed by the input security group keys.
* `versions.tf` – Terraform and AWS provider version constraints.
* `tests/security_group.tftest.hcl` – Terraform tests for rule creation and input validation.

## Usage

```hcl
module "security" {
  source = "./modules/security"

  vpc_id = module.network.vpc_id

  security_groups_rules = {
    app = {
      name        = "school-web-app-sg"
      description = "Application tier security group"
      rules = {
        in-http-alb = {
          direction         = "ingress"
          protocol          = "tcp"
          from_port         = 80
          to_port           = 80
          referenced_sg_key = "alb"
          description       = "HTTP from the ALB"
        }
        out-https = {
          direction   = "egress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          cidr_ipv4   = "0.0.0.0/0"
          description = "HTTPS outbound"
        }
      }
    }

    alb = {
      name        = "school-web-alb-sg"
      description = "Load balancer security group"
      rules = {
        in-https-cloudfront = {
          direction        = "ingress"
          protocol         = "tcp"
          from_port        = 443
          to_port          = 443
          prefix_list_name = "com.amazonaws.global.cloudfront.origin-facing"
          description      = "HTTPS from CloudFront"
        }
      }
    }
  }

  tags = {
    Environment = "dev"
  }
}

output "security_group_ids" {
  value = module.security.security_group_ids
}
```

In this example, `referenced_sg_key` points to the `alb` key in the same `security_groups_rules` map. Use the same key to look up an ID from `module.security.security_group_ids`, for example `module.security.security_group_ids["app"]`.

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|:--------:|
| `vpc_id` | `string` | ID of the VPC in which to create the security groups. | — | **yes** |
| `security_groups_rules` | `map(object(...))` | Security groups keyed by stable identifiers; each group contains a name, description, and keyed rules. | `{}` | no |
| `tags` | `map(string)` | Tags merged into every security group and rule. | `{}` | no |

Each entry in `security_groups_rules` has this shape:

| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | `string` | Human-readable group name; used as the `Name` tag and security group name prefix. |
| `description` | `string` | Security group description. |
| `rules` | `map(object(...))` | Rules keyed by a stable rule identifier. An empty map creates a group with no rules declared by this module. |

Each rule supports:

| Attribute | Type | Description |
|-----------|------|-------------|
| `direction` | `string` | Required; `ingress` or `egress`. |
| `protocol` | `string` | Required; AWS protocol value, such as `tcp`, `udp`, `icmp`, or `-1`. |
| `from_port` | `number` | Optional start port or protocol-specific value. |
| `to_port` | `number` | Optional end port or protocol-specific value. |
| `cidr_ipv4` | `string` | Optional IPv4 CIDR source/destination. |
| `prefix_list_name` | `string` | Optional AWS-managed prefix list name; looked up by the provider. |
| `referenced_sg_key` | `string` | Optional key of another security group in `security_groups_rules`. |
| `description` | `string` | Optional rule description. |

Exactly one of `cidr_ipv4`, `prefix_list_name`, or `referenced_sg_key` must be set on each rule. A referenced security group key must exist in the input map. Ports can be omitted for protocols such as `-1` that do not use port ranges.

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `security_group_ids` | `map(string)` | Security group IDs keyed by the corresponding keys in `security_groups_rules`. |

## Security & Compliance

* The module does not add application-specific rules. Define only the ingress and egress rules required by the workload.
* Security groups are stateful; NACL behavior and subnet-level filtering remain the responsibility of the network module.
* The module accepts IPv4 CIDRs, prefix lists, or security groups as rule sources/destinations; it does not expose IPv6 rule fields.
* AWS-managed prefix list names must exist and be resolvable by the AWS provider in the target account and Region.
* Security group rules can reference only groups declared in this module's `security_groups_rules` map.
* Rule resource keys are derived from both map keys (`<security-group-key>-<rule-key>`). Keep keys stable and unique so changes do not unnecessarily replace rule addresses.

## Dependencies

* Terraform **>= 1.9, < 2.0**
* AWS provider (`hashicorp/aws`) **~> 6.71**

## Versioning

This module is consumed via a relative `source` path, so no module version constraint is declared. Treat changes to input/output names and types as breaking. For remote module consumption, publish with semantic-version tags and pin the source to a release tag.

---
*Keep this file in sync with code changes.*
