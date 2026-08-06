provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# This root is only ever run against a cluster that already exists — either created for real by
# cluster/ (a separate Terraform state, applied first) or your own pre-existing EKS cluster.
# That's what lets the kubernetes/helm providers below be configured with fully-known values at
# plan time, sidestepping the classic "provider config depends on a resource being created in the
# same apply" problem that plagues single-root EKS+Helm setups (and especially breaks `destroy`).
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }

  # Without this, `terraform plan` can't see changes to the local chart's own contents (template
  # edits, values.yaml defaults) — it only tracks the resource's own arguments (chart path,
  # version, explicit values/set). Confirmed the hard way: a values.yaml-only tag bump showed "No
  # changes" and the cluster stayed on the old image until this was turned on.
  experiments {
    manifest = true
  }
}
