data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

# The key policy needs this ARN before the log group exists, so it is built
# from known inputs instead of the resource attribute.
locals {
  flow_log_group_name = "/aws/vpc/${var.project}/flow-logs"
  flow_log_group_arn  = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.flow_log_group_name}"
}

# A dedicated key lets flow-log access be audited and revoked on its own.
resource "aws_kms_key" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  description         = "${var.project} VPC flow logs"
  enable_key_rotation = true

  tags = merge(var.tags, {
    Name = "${var.project}-vpc-flow-logs"
  })
}

resource "aws_kms_key_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  key_id = aws_kms_key.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableAccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        # Only this module's log group may use the key.
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.region}.amazonaws.com" }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*",
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = local.flow_log_group_arn
          }
        }
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = local.flow_log_group_name
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = aws_kms_key.flow_logs[0].arn

  tags = merge(var.tags, {
    Name = "${var.project}-vpc-flow-logs"
  })
}

data "aws_iam_policy_document" "flow_logs_assume_role" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name_prefix        = "${var.project}-vpc-flow-logs-"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role[0].json

  tags = merge(var.tags, {
    Name = "${var.project}-vpc-flow-logs"
  })
}

# Least privilege: writes are scoped to this module's log group.
data "aws_iam_policy_document" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = [
      aws_cloudwatch_log_group.flow_logs[0].arn,
      "${aws_cloudwatch_log_group.flow_logs[0].arn}:*",
    ]
  }

  # DescribeLogGroups does not support resource-level permissions.
  statement {
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name   = "${var.project}-vpc-flow-logs"
  role   = aws_iam_role.flow_logs[0].id
  policy = data.aws_iam_policy_document.flow_logs[0].json
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = var.flow_logs_traffic_type
  vpc_id          = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project}-vpc-flow-log"
  })

  depends_on = [aws_iam_role_policy.flow_logs]
}
