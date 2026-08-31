/*
 * Terraform Backend — Google Cloud Storage
 * 
 * Bucket padrão para fundação: gs://foundation-state-iniapet
 * (Bucket criado pela SA inia-ops-prod no projeto iniapet-ops)
 */

terraform {
  backend "gcs" {
    bucket = "foundation-state-iniapet"
    prefix = "terraform/state"
  }
}
