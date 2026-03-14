output "db_endpoint" {
  value     = aws_db_instance.postgres.address
  sensitive = true
}
output "secret_arn" { value = aws_secretsmanager_secret.db.arn }
output "secret_name" { value = aws_secretsmanager_secret.db.name }
