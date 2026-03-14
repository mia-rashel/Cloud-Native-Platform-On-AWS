terraform {
  backend "s3" {
    bucket         = "devops-tfstate-muhammad-mia"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
