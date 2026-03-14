resource "aws_ecr_repository" "nodejs" {
  name                 = "${var.project}/nodejs-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = { Environment = var.environment }
}

resource "aws_ecr_repository" "python" {
  name                 = "${var.project}/python-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = { Environment = var.environment }
}

# Keep only the last 10 images to save storage cost
resource "aws_ecr_lifecycle_policy" "nodejs" {
  repository = aws_ecr_repository.nodejs.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "python" {
  repository = aws_ecr_repository.python.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}
