module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  enable_irsa = true

  # Without this, the IAM principal that ran `terraform apply` has no way to authenticate to the
  # cluster afterward (kubectl/helm/platform's own providers would all be locked out).
  enable_cluster_creator_admin_permissions = true

  # AWS account-level admin (an IAM policy) and Kubernetes-level access to *this* cluster are two
  # separate systems — being an AWS admin doesn't grant kubectl/console access to cluster
  # resources by itself. Only the exact principal above (the apply-time caller) gets in for free;
  # list every other admin identity here (e.g. an SSO permission set's role ARN) or they'll see
  # "Unauthorized" in the console/kubectl despite having full AWS account permissions.
  access_entries = {
    for arn in var.additional_admin_principal_arns : replace(arn, "/[^a-zA-Z0-9]/", "-") => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  cluster_addons = {
    coredns        = {}
    kube-proxy     = {}
    vpc-cni        = {}
    metrics-server = {} # needed for the chart's HPAs (api/graphql/gateway/ui) to actually scale on CPU
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      subnet_ids     = local.private_subnet_ids
    }
  }

  tags = var.tags
}
