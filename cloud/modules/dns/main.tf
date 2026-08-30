locals {
  full_domain = var.domain_suffix != ""
    ? "${var.domain_suffix}.${var.parent_domain}."
    : "${var.parent_domain}."
  
  # Subdomain extracted from full domain for DNS record naming
  subdomain = var.domain_suffix != ""
    ? var.domain_suffix
    : ""
}

# Managed zone creation
resource "google_dns_managed_zone" "main" {
  project       = var.zone_name != "" ? null : null # resolved via provider/project context
  name          = var.zone_name
  dns_name      = "${var.parent_domain}."
  description   = "Cloud Foundation DNS zone for ${var.parent_domain}"
  
  visibility = "public"

  dnssec_config {
    state = "on"
  }

  # Prevent destroy during zone migration from legacy IaC
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [name_servers]
  }
}

# DNS record set for the subdomain
resource "google_dns_record_set" "service" {
  count = var.domain_suffix != "" ? 1 : 0
  
  name         = "${local.subdomain}.${google_dns_managed_zone.main.dns_name}"
  managed_zone = google_dns_managed_zone.main.name
  type         = var.record_type
  ttl          = 300
  rrdatas      = [var.lb_ip_address]
}
