variable "zone_name" {
  description = "Name of the GCP DNS managed zone (short, e.g., inia-api-br)."
  type        = string
}

variable "parent_domain" {
  description = "Parent domain without trailing dot (e.g., inia-api-br → becomes inia.api.br.)."
  type        = string
}

variable "domain_suffix" {
  description = "Subdomain suffix to prepend. If empty, only creates the zone. Example: "app" → app.inia.api.br."
  type        = string
  default     = ""
}

variable "record_type" {
  description = "DNS record type (A, AAAA, CNAME)."
  type        = string
  default     = "A"
}

variable "lb_ip_address" {
  description = "IP/CNAME target for the DNS record."
  type        = string
  default     = ""
}
