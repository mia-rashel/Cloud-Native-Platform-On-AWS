resource "random_password" "db" {
  length  = 32
  special = false
}

# Store DB credentials in Secrets Manager
# Your app pods will read from here — the password is NEVER in any code file
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project}/${var.environment}/db-credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "appuser"
    password = random_password.db.result
    host     = aws_db_instance.postgres.address
    port     = 5432
    dbname   = "appdb"
  })
  # Wait until the RDS instance is ready before storing its address
  depends_on = [aws_db_instance.postgres]
}

# Security Group — only EKS nodes can reach the database on port 5432
resource "aws_security_group" "rds" {
  name   = "${var.project}-${var.environment}-rds-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.environment}-rds-sg" }
}

resource "aws_db_instance" "postgres" {
  identifier        = "${var.project}-${var.environment}-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_encrypted = true

  db_name  = "appdb"
  username = "appuser"
  password = random_password.db.result

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period = var.environment == "prod" ? 7 : 1
  skip_final_snapshot     = var.environment != "prod"
  deletion_protection     = var.environment == "prod"

  tags = { Environment = var.environment }
}
