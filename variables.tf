variable "foundation_project_id" {
  description = "GCP Project where the foundation manages its state (e.g., iniapet-ops)."
  type        = string
  default     = "iniapet-ops"
}

variable "zone_project_id" {
  description = "GCP Project where the DNS zone actually lives (can be different from foundation_project_id if delegating)."
  type        = string
  default     = "iniapet-ops" # Initially same; change only when migrating zone later
}

variable "zone_name" {
  description = "Name of the GCP DNS managed zone (short, e.g., inia-api-br)."
  type        = string
  default     = "inia-api-br"
}

variable "base_domain" {
  description = "Base domain without trailing dot (e.g., inia-api-br becomes inia.api.br.)."
  type        = string
  default     = "inia.api.br."
}

variable "default_region" {
  description = "Default region for all resources."
  type        = string
  default     = "us-central1"
}
