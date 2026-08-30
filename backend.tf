/*
 * Terraform Backend — Google Cloud Storage
 * 
 * Bucket padrão para fundação: gs://vet-ai-foundation-state-bucket
 * (Criar primeiro no projeto iniapet-ops antes de rodar terraform init)
 */

terraform {
  backend "gcs" {
    bucket = "vet-ai-foundation-state-bucket"
    prefix = "terraform/state"
  }
}
