# Installs the AWS Load Balancer Controller, which is what actually provisions the ALB in
# response to the app's Ingress resource. Skip this (install_alb_controller = false) if your
# existing cluster already has it — see k8s/README.md's prerequisites for the manual equivalent.

# terraform-provider-helm builds its Kubernetes REST discovery mapping once at the start of an
# apply and doesn't refresh it after a chart's own CRDs are created mid-release -- so on a
# completely fresh cluster, installing this chart's CRDs and its IngressClassParams object in the
# same Helm release fails with "no matches for kind IngressClassParams" (longstanding issue with
# terraform-provider-helm + this specific chart, not a transient race -- retrying the apply as-is
# fails identically every time). Applying the CRDs as their own step first, so they're already
# registered by the time the release runs, works around it. Requires aws/kubectl on the machine
# running `terraform apply` -- already assumed elsewhere in this repo's workflow.
#
# eks-charts tags repo-wide releases (v0.0.X), not per-chart versions, so there's no tag matching
# alb_controller_chart_version to pin the CRDs to -- master is what the community workarounds for
# this exact issue use too. This resource type's CRD schema is stable/additive across versions in
# practice, so tracking master here doesn't meaningfully risk drift with the pinned chart version.
resource "null_resource" "alb_controller_crds" {
  count = var.install_alb_controller ? 1 : 0

  triggers = {
    chart_version = var.alb_controller_chart_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      KUBECONFIG_FILE=$(mktemp)
      aws eks update-kubeconfig \
        --name "${var.cluster_name}" \
        --region "${var.aws_region}" \
        ${var.aws_profile != null ? "--profile ${var.aws_profile}" : ""} \
        --kubeconfig "$KUBECONFIG_FILE"
      kubectl --kubeconfig "$KUBECONFIG_FILE" apply -f \
        "https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml"
      rm -f "$KUBECONFIG_FILE"
    EOT
  }
}

module "alb_controller_irsa" {
  count   = var.install_alb_controller ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name = "${var.name_prefix}-alb-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

resource "kubernetes_service_account" "alb_controller" {
  count = var.install_alb_controller ? 1 : 0

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = module.alb_controller_irsa[0].iam_role_arn
    }
  }
}

resource "helm_release" "alb_controller" {
  count = var.install_alb_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_chart_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = var.vpc_id
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.alb_controller[0].metadata[0].name
  }

  depends_on = [kubernetes_service_account.alb_controller, null_resource.alb_controller_crds]
}
