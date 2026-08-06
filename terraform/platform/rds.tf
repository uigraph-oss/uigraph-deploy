resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-postgres"
  subnet_ids = var.private_subnet_ids
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
  source_security_group_id = var.node_security_group_id
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

# secret_management = "terraform": we generate and own the password so it can go straight into
# the app's Kubernetes Secret in the same apply (see app.tf). It ends up in Terraform state as a
# result — use a remote encrypted backend if that matters to you.
resource "random_password" "postgres" {
  count   = var.secret_management == "terraform" ? 1 : 0
  length  = 32
  special = false
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = var.db_engine_version

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username

  # secret_management = "external-secrets": let AWS generate and own the password instead — it
  # goes directly to Secrets Manager and is never in Terraform state or CLI output. See
  # k8s/README.md's ExternalSecret example for wiring the resulting secret into the chart.
  password                    = var.secret_management == "terraform" ? random_password.postgres[0].result : null
  manage_master_user_password = var.secret_management == "external-secrets" ? true : null

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.postgres.id]

  multi_az            = var.db_multi_az
  publicly_accessible = false

  backup_retention_period   = 7
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${var.name_prefix}-postgres-final"
  deletion_protection       = var.db_deletion_protection

  tags = var.tags
}
