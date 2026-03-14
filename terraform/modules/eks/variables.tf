variable "project" { type = string }
variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "node_desired" {
  type    = number
  default = 2
}

variable "node_max" {
  type    = number
  default = 10
}
