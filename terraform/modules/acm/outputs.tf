output "certificate_arn" {
  description = "Paste this into kubernetes/ingress.yaml"
  value       = aws_acm_certificate_validation.main.certificate_arn
}
