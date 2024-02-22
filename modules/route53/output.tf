output "route53_record_name" {
  value = aws_route53_record.selected.name
}

output "route53_zone_name" {
  value = data.aws_route53_zone.selected.name
}