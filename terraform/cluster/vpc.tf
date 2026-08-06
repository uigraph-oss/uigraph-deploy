# Only created when create_vpc = true. If you already have a VPC, set create_vpc = false and
# fill in existing_vpc_id / existing_private_subnet_ids / existing_public_subnet_ids — see
# locals.tf for how those two paths merge into a single vpc_id/private_subnet_ids/public_subnet_ids
# used by eks.tf and outputs.tf.
module "vpc" {
  count   = var.create_vpc ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${var.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnet_cidrs
  public_subnets  = local.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required for the AWS Load Balancer Controller (installed by platform/) to auto-discover
  # subnets when provisioning the app's ALB.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = var.tags
}
