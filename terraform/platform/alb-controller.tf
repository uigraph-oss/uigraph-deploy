# Installs the AWS Load Balancer Controller, which is what actually provisions the ALB in
# response to the app's Ingress resource. Skip this (install_alb_controller = false) if your
# existing cluster already has it — see k8s/README.md's prerequisites for the manual equivalent.
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

# Deliberately a real `helm` CLI invocation, not terraform-provider-helm's helm_release resource.
# This chart auto-generates a random self-signed webhook certificate on every template render
# (no cert-manager/static certs configured) -- so its rendered manifest legitimately differs
# between terraform-provider-helm's plan-time render and its apply-time render, which trips
# Terraform's plan/apply consistency check with "Provider produced inconsistent final plan ...
# This is a bug in the provider" on a completely fresh install, every time, regardless of
# depends_on/resource ordering. The real Helm CLI doesn't do that comparison (or the Terraform-
# side CRD-then-CR sequencing dance terraform-provider-helm also gets wrong on a brand new
# cluster) -- it just applies what it renders in one atomic operation, which is what upstream
# recommends for this exact class of issue. Requires helm/aws/kubectl on the machine running
# `terraform apply` -- kubectl and aws are already assumed elsewhere in this repo's workflow.
resource "null_resource" "alb_controller" {
  count = var.install_alb_controller ? 1 : 0

  triggers = {
    chart_version = var.alb_controller_chart_version
    cluster_name  = var.cluster_name
    aws_region    = var.aws_region
    aws_profile   = coalesce(var.aws_profile, "")
    vpc_id        = var.vpc_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      KUBECONFIG_FILE=$(mktemp)
      aws eks update-kubeconfig \
        --name "${self.triggers.cluster_name}" \
        --region "${self.triggers.aws_region}" \
        ${var.aws_profile != null ? "--profile ${self.triggers.aws_profile}" : ""} \
        --kubeconfig "$KUBECONFIG_FILE"
      helm repo add eks-charts https://aws.github.io/eks-charts --force-update
      helm repo update eks-charts
      KUBECONFIG="$KUBECONFIG_FILE" helm upgrade --install aws-load-balancer-controller \
        eks-charts/aws-load-balancer-controller \
        --version "${self.triggers.chart_version}" \
        --namespace kube-system \
        --set clusterName="${self.triggers.cluster_name}" \
        --set region="${self.triggers.aws_region}" \
        --set vpcId="${self.triggers.vpc_id}" \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --wait --timeout 5m
      rm -f "$KUBECONFIG_FILE"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -euo pipefail
      KUBECONFIG_FILE=$(mktemp)
      aws eks update-kubeconfig \
        --name "${self.triggers.cluster_name}" \
        --region "${self.triggers.aws_region}" \
        ${self.triggers.aws_profile != "" ? "--profile ${self.triggers.aws_profile}" : ""} \
        --kubeconfig "$KUBECONFIG_FILE" || exit 0
      KUBECONFIG="$KUBECONFIG_FILE" helm uninstall aws-load-balancer-controller --namespace kube-system || true
      rm -f "$KUBECONFIG_FILE"
    EOT
  }

  depends_on = [kubernetes_service_account.alb_controller]
}
