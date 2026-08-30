output "name_servers" {
  description = "List of nameservers for the managed zone."
  value       = google_dns_managed_zone.main.name_servers
}

output "dns_zone_name" {
  description = "The short name of the managed zone."
  value       = google_dns_managed_zone.main.name
}

output "full_domain" {
  description = "Full qualified domain name of the record (empty if only zone was created)."
  value       = var.domain_suffix != "" ? local.full_domain : ""
}
