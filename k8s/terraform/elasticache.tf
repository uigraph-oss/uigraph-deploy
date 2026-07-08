resource "aws_elasticache_subnet_group" "uigraph" {
  name       = "${var.name_prefix}-redis"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "redis" {
  name        = "${var.name_prefix}-redis"
  description = "Allow Redis access from the EKS cluster"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_security_group_rule" "redis_ingress_from_eks" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = var.eks_node_security_group_id
  description              = "Redis from EKS nodes/pods"
}

resource "aws_security_group_rule" "redis_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.redis.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# transit_encryption_enabled is required for AUTH tokens, so it's always on here; when
# redis_auth_token_enabled is false the chart's redis.tls should still be set to true to match
# (see k8s/README.md — this differs from the chart's plain-redis:// default, which assumes no
# ElastiCache TLS/AUTH at all).
resource "aws_elasticache_replication_group" "uigraph" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "UiGraph Redis (cache + queue)"

  engine         = "redis"
  engine_version = var.redis_engine_version
  node_type      = var.redis_node_type

  num_cache_clusters = var.redis_num_cache_clusters

  subnet_group_name  = aws_elasticache_subnet_group.uigraph.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token_enabled ? var.redis_auth_token : null

  automatic_failover_enabled = var.redis_num_cache_clusters > 1

  tags = var.tags
}
