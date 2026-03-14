variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "db_subnet_group_name" { type = string }
variable "eks_node_sg_id" { type = string }
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
