output "nightscout_ip" {
  value = "http://${module.ec2.ec2_ip_address}"
}


output "nightscout_url" {
  value = "${module.route53.route53_record_name}"
}

output "nightscout_route53_zone_name" {
  value = "${module.route53.route53_zone_name}"
}