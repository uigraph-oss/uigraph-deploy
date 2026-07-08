resource "aws_db_subnet_group" "uigraph" {
  name       = "${var.name_prefix}-postgres"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "postgres" {
  name        = "${var.name_prefix}-postgres"
  description = "Allow Postgres access from the EKS cluster"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_security_group_rule" "postgres_ingress_from_eks" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.postgres.id
  source_security_group_id = var.eks_node_security_group_id
  description              = "Postgres from EKS nodes/pods"
}

resource "aws_security_group_rule" "postgres_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.postgres.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# manage_master_user_password puts the generated password directly into Secrets Manager —
# it never appears in Terraform state or CLI output. The Secrets Manager ARN is exported in
# outputs.tf; k8s/README.md documents wiring it into the Helm chart's Secret.
resource "aws_db_instance" "uigraph" {
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = var.db_engine_version

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.uigraph.name
  vpc_security_group_ids = [aws_security_group.postgres.id]

  multi_az            = var.db_multi_az
  publicly_accessible = false

  backup_retention_period   = 7
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name_prefix}-postgres-final"
  deletion_protection       = true

  tags = var.tags
}
