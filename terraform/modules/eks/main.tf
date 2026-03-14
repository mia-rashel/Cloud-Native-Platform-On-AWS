module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  # Small node group just to run Karpenter itself.
  # Karpenter will then provision the actual workload nodes.
  eks_managed_node_groups = {
    bootstrap = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 2
      desired_size   = 2
      disk_size      = 20
      labels = {
        role = "bootstrap"
      }
    }
  }

  tags = {
    Environment              = var.environment
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# IAM Role for GitHub Actions to authenticate via OIDC
# (no stored access keys — much more secure)
data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:<YOUR-GITHUB-USERNAME>/<YOUR-REPO-NAME>:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project}-${var.environment}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json
}

resource "aws_iam_role_policy" "github_actions" {
  name = "github-actions-policy"
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:*"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:*:*:secret:devops-platform/*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
