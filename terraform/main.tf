terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── VPC ────────────────────────────────────────────────────
module "vpc" {
  source       = "./modules/vpc"
  project      = var.project
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  cluster_name = var.cluster_name
}

# ── EKS ────────────────────────────────────────────────────
module "eks" {
  source             = "./modules/eks"
  project            = var.project
  environment        = var.environment
  cluster_name       = var.cluster_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  node_desired       = var.node_desired
  node_max           = var.node_max
}

# ── RDS ────────────────────────────────────────────────────
module "rds" {
  source               = "./modules/rds"
  project              = var.project
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.db_subnet_group_name
  eks_node_sg_id       = module.eks.node_security_group_id
  db_instance_class    = var.db_instance_class
}

# ── ECR ────────────────────────────────────────────────────
module "ecr" {
  source = "./modules/ecr"
  project =  var.project
  environment = var.environment
}

# ── ACM (TLS Certificate) ───────────────────────────────────
module "acm" {
 source      = "./modules/acm"
domain_name = var.domain_name
root_domain = var.root_domain
}