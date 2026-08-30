# Vet AI Cloud Foundation

Repositório centralizado para a infraestrutura compartilhada (foundation) dos serviços InIA.

## Objetivo
Separar recursos de base (DNS, redes, IAM compartilhado) das stacks de aplicação individuais (`vet-ai-services/cloud/{dev,prod-app}/`). Isso traz:

- **Isolamento de escopo**: mudanças na fundação não afetam workloads diretamente.
- **Controle de acesso granular**: equipes diferentes administram DNS vs app infra.
- **Clareza no ciclo de vida**: a fundação muda raramente; apps mudam a cada sprint.

## Estrutura

```
cloud/
├── dns.tf              # Root composition: zone + records por subdomínio
└── modules/
    └── dns/            # Módulo genérico: managed_zone + record_set
provider.tf             # Provider global (projeto iniapet-ops)
variables.tf            # Variáveis globais (projeto, região, domínio base)
backend.tf              # Backend GCS (comentado até primeiro init)
.gitignore
```

## Fluxo de deploy

A ordem correta de execução é sempre:

1. **Stacks de app** (`dev-app`, `prod-app`) — criam Cloud Run, gateway, ALB, publicam `lb_ip`.
2. **Foundation DNS** (`terraform apply`) — consome os `lb_ip` via `terraform_remote_state` e registra os hosts.

Nunca aplique DNS antes dos stacks de app, pois o plan ficaria incompleto.

## Uso do módulo DNS

```hcl
module "app_dns" {
  source          = "./modules/dns"
  zone_name       = "inia-api-br"
  parent_domain   = "inia-api-br"
  domain_suffix   = "app"
  lb_ip_address   = data.terraform_remote_state.prod_app.outputs.lb_ip
}
```

Resultado: registra `app.inia.api.br` (type A) apontando para o ALB do app.

## Notas

- A zona DNS original (`inia.api.br.`) estava no IaC do Flipt (`flipt-feature-toogles/iac/modules/dns`). Este módulo substitui aquele, com parâmetros mais genéricos.
- Se a zona já existe em prod (`iniapet-producao`), migrar para `iniapet-ops` requer atenção ao `prevent_destroy` e aos name servers no Registro.br.
