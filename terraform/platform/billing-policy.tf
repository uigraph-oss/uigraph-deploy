# Read-only Cost Explorer + Budgets access for the in-app "service costs" feature. Attached to
# the same IRSA role uigraph-api/uigraph-gateway already assume for S3 (iam-irsa.tf) — if you'd
# rather scope this to a different role/service, set enable_cost_explorer_access = false here and
# attach cost_explorer_policy_arn (see outputs.tf) yourself.
#
# One thing Terraform can't do for you: Cost Explorer has to be switched on once, account-wide,
# via the Billing console (Billing > Cost Explorer > Enable) before ce:Get* calls return data —
# there's no API/Terraform resource for that account-level opt-in.
data "aws_iam_policy_document" "cost_explorer" {
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
}

resource "aws_iam_policy" "cost_explorer" {
  count       = var.enable_cost_explorer_access ? 1 : 0
  name        = "${var.name_prefix}-cost-explorer-readonly"
  description = "Read-only Cost Explorer/Budgets access for uigraph's service-costs feature."
  policy      = data.aws_iam_policy_document.cost_explorer.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "cost_explorer" {
  count      = var.enable_cost_explorer_access ? 1 : 0
  role       = aws_iam_role.irsa.name
  policy_arn = aws_iam_policy.cost_explorer[0].arn
}
