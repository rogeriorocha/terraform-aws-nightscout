data "aws_route53_zone" "selected" {
  name         = var.zone_name
  private_zone = false
}