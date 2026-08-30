/*
 * ROOT COMPOSITION — Cloud DNS Foundation
 * 
 * Estado atual da zona: já existe em um projeto GCP (hoje iniapet-producao).
 * Estrutura inicial importa a zona existente (sem criar/recriar) e adiciona 
 * novos registros A/CNAME para as stacks de app.
 *
 * Passos para migração futura da zona inteira para o projeto iniapet-ops:
 *   1. Remover este arquivo .tf ou comentar a import do zone.
 *   2. Rodar: terraform apply --target="module.zone_inia_api_br"
 *      (Isso vai destruir a zona antiga e recriar no novo projeto)
 *   3. Atualizar Registro.br com os novos nameservers exportados.
 */

# -------------------------------------------------------------------
# 1. Zone DNS principal (importada/existente)
# -------------------------------------------------------------------
data "google_dns_managed_zone" "main" {
  name = var.zone_name
  # Se a zona estiver num projeto diferente do root, especifique aqui:
  # project = "iniapet-producao" 
}

output "foundation_nameservers" {
  description = "Nameservers atuais da zona (para verificar consistência com Registro.br)."
  value       = data.google_dns_managed_zone.main.name_servers
}

# -------------------------------------------------------------------
# 2. Registros de subdomínios (app.inia.api.br, dev-app.inia.api.br...)
# -------------------------------------------------------------------
locals {
  parent_domain_short = replace(var.base_domain, ".", "")
  # Exemplo de como consumir estados dos apps para obter o IP do ALB:
  # prod_lb_ip = data.terraform_remote_state.prod_app.outputs.app_lb_ip
}

/*
module "record_app_inia_api_br" {
  source          = "./modules/dns"
  
  zone_name       = data.google_dns_managed_zone.main.name
  parent_domain   = local.parent_domain_short
  
  # Se o domínio final incluir subdomain
  domain_suffix   = "app"
  
  # IP vindo do stack de aplicação via remote_state
  lb_ip_address   = "" # Placeholder — preencher após definir variável ou data source
}
*/

/*
module "record_dev_app_inia_api_br" {
  source          = "./modules/dns"
  
  zone_name       = data.google_dns_managed_zone.main.name
  parent_domain   = local.parent_domain_short
  
  domain_suffix   = "dev-app"
  lb_ip_address   = "" # Placeholder — preencher após definir variável ou data source
}
*/
