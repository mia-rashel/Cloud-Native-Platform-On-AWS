variable "domain_name" {
  description = "Full subdomain, e.g. api.mydevopsproject.dev"
  type        = string
}

variable "root_domain" {
  description = "Root domain in Route 53, e.g. mydevopsproject.dev"
  type        = string
}
