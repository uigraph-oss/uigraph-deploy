# The in-app "service costs" feature (Settings → Cloud Connections) doesn't use the caller's own
# permissions directly — uigraph-api's AWS billing provider (internal/billing/providers/aws/aws.go)
# always calls sts:AssumeRole against a Role ARN + External ID entered in that UI, even to monitor
# the same account this app runs in. So this creates a role the app's IRSA identity can assume,
# scoped to exactly what that feature calls: Cost Explorer, Budgets, and Resource Groups Tagging
# (used to discover which tagged resources exist in the first place). Paste billing_role_arn and
# billing_external_id (see outputs.tf) into that dialog to connect this account.
#
# One thing Terraform can't do for you: Cost Explorer has to be switched on once, account-wide,
# via the Billing console (Billing > Cost Explorer > Enable) before ce:Get* calls return data —
# there's no API/Terraform resource for that account-level opt-in.

resource "random_password" "billing_external_id" {
  count   = var.enable_cost_explorer_access ? 1 : 0
  length  = 32
  special = false
}

data "aws_iam_policy_document" "billing_assume_role_trust" {
  count = var.enable_cost_explorer_access ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.irsa.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [random_password.billing_external_id[0].result]
    }
  }
}

resource "aws_iam_role" "billing" {
  count              = var.enable_cost_explorer_access ? 1 : 0
  name               = "${var.name_prefix}-billing-read"
  assume_role_policy = data.aws_iam_policy_document.billing_assume_role_trust[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "billing" {
  count = var.enable_cost_explorer_access ? 1 : 0

  statement {
    sid    = "CostExplorerReadOnly"
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage",
      "ce:GetCostForecast",
      "ce:GetUsageForecast",
      "ce:GetDimensionValues",
      "ce:GetTags",
      "ce:GetCostCategories",
      "ce:ListCostCategoryDefinitions",
    ]
    # Cost Explorer APIs don't support resource-level scoping — they operate account/org-wide.
    resources = ["*"]
  }

  statement {
    sid       = "BudgetsReadOnly"
    effect    = "Allow"
    actions   = ["budgets:ViewBudget", "budgets:DescribeBudgets", "budgets:DescribeBudgetPerformanceHistory"]
    resources = ["*"]
  }

  statement {
    sid       = "ResourceDiscoveryReadOnly"
    effect    = "Allow"
    actions   = ["tag:GetResources"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "billing" {
  count  = var.enable_cost_explorer_access ? 1 : 0
  name   = "${var.name_prefix}-billing-read"
  role   = aws_iam_role.billing[0].id
  policy = data.aws_iam_policy_document.billing[0].json
}
