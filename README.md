# School Web on AWS

This repository contains Terraform for the School Web AWS foundation and documents the intended application architecture. The design is a multi-AZ WordPress-style web application with CloudFront, an Application Load Balancer (ALB), an EC2 Auto Scaling group, private MySQL, shared EFS storage, and S3-backed media.

> **Implementation status:** The architecture diagram shows the target design. The current root Terraform configuration in `main.tf` instantiates only the network and security modules. CloudFront, ALB, EC2/Auto Scaling, RDS, S3, Secrets Manager, and EFS are not currently instantiated by the root configuration.

## Architecture

![School Web AWS architecture design](diagrams/school-web-aws-achitecture-design.svg)

The diagram is the intended design, not a claim that every shown resource is currently deployed.

### Request and application flow

1. Visitors connect through CloudFront. HTTP requests redirect to HTTPS.
2. CloudFront serves static media from S3 through Origin Access Control (OAC), with caching for `/wp-content/uploads/*`.
3. Dynamic requests are forwarded to an HTTPS-only ALB. The design restricts ALB ingress to the CloudFront origin-facing managed prefix list and includes a secret origin header.
4. The ALB forwards HTTP traffic to WordPress EC2 instances in private application subnets. An Auto Scaling group spans both Availability Zones, uses ELB health checks, and is configured for a minimum of one and a maximum of four instances.
5. Web instances read the database credential from Secrets Manager using their instance role, connect to private MySQL on port 3306, and access shared EFS over NFS on port 2049.
6. The app tier uses a regional NAT Gateway for outbound HTTPS. S3 and DynamoDB gateway endpoints provide private access to those AWS services.

### Security and operations in the target design

- **Network tiers:** public, private application, and private database subnets span two Availability Zones. The database tier has no default route to the internet.
- **Security groups:** the diagram defines separate ALB, web, EFS, and database groups. Intended flows include CloudFront → ALB on HTTPS 443; ALB → web on HTTP 80; web → MySQL on 3306; and web → EFS on NFS 2049. The groups are stateful and scoped to the required peers.
- **Network ACLs:** stateless subnet-level guardrails cover internet/return traffic, app-to-database MySQL, and ephemeral responses. The diagram's examples include an optional RDP deny rule.
- **Data services:** RDS MySQL is private and encrypted, with an optional Multi-AZ standby. The database master password is managed through Secrets Manager. EFS is encrypted; uploaded media is stored in S3.
- **Monitoring and scaling:** the target design sends VPC Flow Logs to CloudWatch Logs with KMS encryption. CPU alarms are shown scaling the web tier out above 80% for 30 minutes and in below 40% for 30 minutes.

## What Terraform currently provisions

The root stack composes:

- **Network module** — VPC with DNS support, public/app/database subnets, Internet Gateway, regional NAT Gateway, tier-specific route tables, S3/DynamoDB gateway endpoints, network ACLs, and optional VPC Flow Logs.
- **Security module** — security groups and standalone ingress/egress rules, driven by `security_groups_rules`. Rules can use an IPv4 CIDR, AWS-managed prefix list, or another group created by the module.

The root configuration does not currently create or attach application workloads. Root input defaults for the NACL and security-group rule maps are empty. Empty NACL rule maps create deny-all network ACLs; empty security-group rules create no groups. Configure the required rules in your local `terraform.tfvars` before applying.

## Project structure

```text
.
├── main.tf                         # Root composition of network and security modules
├── variables.tf                    # Root inputs, including subnet and rule configuration
├── outputs.tf                      # VPC, subnet, routing, NACL, endpoint, log, and SG IDs
├── providers.tf                    # AWS provider, region, and default tags
├── versions.tf                     # Terraform and AWS provider constraints
├── backend.tf                      # Commented example S3 backend
├── .terraform.lock.hcl             # Locked provider selections
├── diagrams/
│   ├── school-web-aws-achitecture-design.svg  # Target architecture
│   └── school-web-network-current.svg         # Network foundation diagram
└── modules/
    ├── network/                    # VPC, subnets, routes, NACLs, endpoints, Flow Logs
    │   ├── tests/                  # Network module Terraform tests
    │   └── README.md               # Network module details and rule examples
    ├── security/                   # Security groups and ingress/egress rules
    │   ├── tests/                  # Security module Terraform tests
    │   └── README.md               # Security module usage and input contract
    :
```

## Requirements

- Terraform `~> 1.17`
- AWS provider `hashicorp/aws ~> 6.71` (installed by `terraform init`)
- AWS credentials for an account authorized to manage the resources in the root stack, including VPC networking, IAM, CloudWatch Logs, and KMS

The default Region is `ap-southeast-1` and the default topology uses `ap-southeast-1a` and `ap-southeast-1b`. If you change Region or AZs, update the subnet CIDRs and `availability_zones` together.

## Configure and deploy the current Terraform stack

1. Configure AWS credentials with your preferred method and verify the identity:

   ```bash
   aws sts get-caller-identity
   ```

2. Create a local `terraform.tfvars` file. It is ignored by Git. At minimum, the required app and database private subnet CIDRs must be set:

   ```hcl
   private_subnet_cidr_blocks = {
     app = ["10.0.11.0/24", "10.0.12.0/24"]
     db  = ["10.0.21.0/24", "10.0.22.0/24"]
   }
   ```

   These examples match the default VPC and AZs. Configure `nacl_static_rules`, `nacl_dynamic_rules`, and `security_groups_rules` for the required traffic before deployment. Review the [network module guide](modules/network/README.md) for rule semantics and the [security module guide](modules/security/README.md) for security-group inputs.

3. Initialize and validate:

   ```bash
   terraform init
   terraform fmt -check -recursive
   terraform validate
   ```

4. Review a saved plan before applying:

   ```bash
   terraform plan -out=tfplan
   terraform show tfplan
   terraform apply tfplan
   ```

   Apply only after reviewing the complete plan, including subnet routes and NACL rules. Do not apply a production change without an approved plan artifact. NAT Gateway, KMS, and CloudWatch Logs resources can incur charges.

To run the module tests, initialize each module locally and use Terraform's native test runner:

```bash
terraform -chdir=modules/network init -backend=false
terraform -chdir=modules/network test
terraform -chdir=modules/security init -backend=false
terraform -chdir=modules/security test
```

## Main configuration inputs and outputs

Inputs are declared in the root [`variables.tf`](variables.tf) and passed to modules from [`main.tf`](main.tf).

| Input | Purpose |
|---|---|
| `region`, `project`, `environment`, `managed_by` | AWS Region and default resource tags |
| `vpc_cidr_block`, `availability_zones` | VPC address range and subnet AZ placement |
| `public_subnet_cidr_blocks` | One public subnet CIDR per AZ |
| `private_subnet_cidr_blocks` | Required `app` and `db` CIDRs, one of each per AZ |
| `gateway_vpc_endpoints` | S3 and/or DynamoDB gateway endpoints on private route tables |
| `nacl_static_rules`, `nacl_dynamic_rules` | Fixed-CIDR or subnet-group NACL rules |
| `security_groups_rules` | Security groups and keyed ingress/egress rules |
| `enable_flow_logs`, `flow_logs_retention_days` | VPC Flow Logs and CloudWatch Logs retention |

The root module exports VPC and subnet IDs, route table IDs, NAT Gateway ID, NACL IDs, gateway endpoint IDs, Flow Log ID, and security group IDs. List them with:

```bash
terraform output
```

## Terraform state and cost

No active remote backend is configured, so Terraform uses local state by default. Local state can contain sensitive infrastructure data and is not suitable for shared or production workflows. For team use, configure a secured and versioned S3 state bucket with locking; the commented example is in [`backend.tf`](backend.tf). Replace its placeholder values before enabling it and migrate existing state with `terraform init -migrate-state`.

Do not commit state files, saved plans, or `terraform.tfvars`. Review plans before applying, and inspect a destroy plan and obtain approval before removing infrastructure. The target architecture may add billable CloudFront, ALB, EC2, RDS, EFS, S3, and NAT resources as those components are implemented.
