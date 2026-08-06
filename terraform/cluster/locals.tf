# Only look up AZs when we're creating the VPC ourselves and the caller didn't pin specific ones.
# Wrapped in try() because this data source has count = 0 (and therefore no index [0]) whenever
# create_vpc = false or azs was set explicitly — both branches of an expression are validated by
# Terraform even though only one is used, so the unguarded reference would fail either way.
data "aws_availability_zones" "available" {
  count = var.create_vpc && var.azs == null ? 1 : 0
  state = "available"
}

locals {
  # Shared with eks.tf's cluster_name so the AWS Load Balancer Controller's subnet
  # auto-discovery tags (vpc.tf) actually match the cluster it's told to manage.
  cluster_name = "${var.name_prefix}-eks"

  azs = var.create_vpc ? coalesce(var.azs, try(slice(data.aws_availability_zones.available[0].names, 0, var.az_count), null)) : []

  # Private subnets carve the VPC CIDR into /20s starting at index 0; public subnets use /24s
  # starting at index 240 — far enough apart that the two never overlap regardless of az_count.
  private_subnet_cidrs = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnet_cidrs  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, 240 + i)]

  vpc_id             = var.create_vpc ? module.vpc[0].vpc_id : var.existing_vpc_id
  private_subnet_ids = var.create_vpc ? module.vpc[0].private_subnets : var.existing_private_subnet_ids
  public_subnet_ids  = var.create_vpc ? module.vpc[0].public_subnets : var.existing_public_subnet_ids
}
