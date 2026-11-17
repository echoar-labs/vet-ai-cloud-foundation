/*
 * Backend proprio desta stack — nao compartilha prefixo com o root de DNS.
 * Bucket: gs://foundation-state-iniapet (o mesmo do foundation).
 */

terraform {
  backend "gcs" {
    bucket = "foundation-state-iniapet"
    prefix = "terraform/state/monitoring/prod"
  }
}