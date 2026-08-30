
# ===============================================================
# ROOT COMPOSITION
# ===============================================================

# Exemplo inicial de como consumir os módulos
# Aqui ficariam as chamadas para configurar as zonas e registros reais.

locals {
  foundation_project = "iniapet-ops"
  base_domain_name   = "inia.api.br."
}

# Módulo 1: Zona base
# module "dns_inia_api_br" {
#   source         = "./modules/dns_zone"
#   project_id     = local.foundation_project
#   zone_name      = "inia-api-br"
#   dns_name       = local.base_domain_name
#   description    = "InIA API public domain"
# }

# Módulo 2: Registro A (Placeholder para quando tivermos o ALB IP)
# module "dns_app_inia_api_br" {
#   source       = "./modules/dns_record"
#   project_id   = local.foundation_project
#   zone_name    = "inia-api-br"
#   name         = "app.${local.base_domain_name}"
#   type         = "A"
#   ttl          = 300
#   records      = ["PLACEHOLDER_IP_LB_PROD"]
# }
