resource "aws_route53_record" "selected" {
  zone_id = data.aws_route53_zone.selected.id
  name    = format("%s.%s", var.record_name, var.zone_name)
  type    = "A"
  ttl     = 300
  records = [var.ip]
}