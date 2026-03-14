variable "project" {
  description = "Project name used in resource names"
  type        = string
}

variable "environment" {
  description = "Environment name: dev, staging, or prod"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "domain_name" {
  description = "Full subdomain for this environment, e.g. api.yourdomain.com"
  type        = string
}

variable "root_domain" {
  description = "Root domain registered in Route 53, e.g. yourdomain.com"
  type        = string
}
variable "db_instance_class" {
  description = "RDS instance size"
  type        = string
  default     = "db.t3.micro"
}

variable "node_desired" {
  description = "Desired number of Karpenter bootstrap nodes"
  type        = number
  default     = 2
}

variable "node_max" {
  description = "Max number of nodes Karpenter can provision"
  type        = number
  default     = 10
}
