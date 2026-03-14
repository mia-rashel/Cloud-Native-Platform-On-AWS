output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint URL"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials"
  value       = module.rds.secret_arn
}

output "ecr_nodejs_url" {
  description = "ECR repository URL for the Node.js image"
  value       = module.ecr.nodejs_repo_url
}

output "ecr_python_url" {
  description = "ECR repository URL for the Python image"
  value       = module.ecr.python_repo_url
}

output "certificate_arn" {
  description = "ACM certificate ARN — paste into kubernetes/ingress.yaml"
  value       = module.acm.certificate_arn
}
