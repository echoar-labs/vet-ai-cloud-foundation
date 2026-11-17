# Monitoramento PROD — InIA Vet

Stack de **alertas proativos** do ambiente de produção (`iniapet-producao`).

Isolada do root de DNS (`cloud/dns.tf`) com **backend e prefixo de state próprios**:

```
gs://foundation-state-iniapet/terraform/state/monitoring/prod
```

## O que cria

**Entrega**
- Canal **Slack nativo do Cloud Monitoring** → `#ops` (sem incoming webhook, sem intermediário).

**A) Erro e disponibilidade**
- Log-based metric de `severity>=ERROR` por serviço, e uma policy por serviço:
  `backend = prod-iniapet-api` (é quem atende prod hoje), `api_new = app-iniapet-api`,
  `admin = inia-admin-app`.
- 3 uptime checks: `inia.pet`, `inia-admin-app` e a **API pública** (`app.inia.api.br/ping`).
  Nota: o `/ping` direto no Cloud Run legado devolve **403** (IAM), então o probe é no domínio público.

**B) Sintomas de negócio**
- Falha de transcrição (`Failed chunk` / `Error processing transcription`) → consulta travada.
- Modelos/retries esgotados (Vertex/Gemini fora ou rate limit sustentado).
- Usuário/SA sem doc em `Users` (risco de 403 admin-gated) — limiar alto porque o SA do
  gateway (`api-gateway-sa-prod@`) já emite ~363/dia e é benigno.

## Limiares (calibrados no baseline medido em 17/11/2026)

| Métrica | Limiar | Janela |
|---|---|---|
| ERROR por serviço | ≥ 3 | 5 min |
| Falha de transcrição | ≥ 3 | 5 min |
| Modelos esgotados | ≥ 3 | 5 min |
| Logins sem doc | ≥ 60 | 5 min |

Baseline de dia tranquilo: **0–20 ERROR/hora**. A escolha é sensível de propósito
(volume de usuários é baixo, mas um bug atinge muitos usuários rápido). Ajustar em
`variables.tf` após os primeiros dias — se der ruído, subir; se passar um incidente
real sem alertar, descer.

## Aplicar

A credencial do canal Slack **não** entra em `.tf`, `.tfvars` ou git. O fluxo
recomendado é gravar no Secret Manager e materializar só na sessão de apply:

```bash
export PATH="$HOME/google-cloud-sdk/bin:$PATH"
export GOOGLE_APPLICATION_CREDENTIALS=$HOME/.config/gcloud/inia-ops-prod.json

# 1) token no Secret Manager (uma vez; valor nunca colado em canal de time)
gcloud secrets create slack-alerting-bot-token --project=iniapet-producao \
  --replication-policy=automatic --data-file=- <<< "xoxb-..."

# 2) materializar na sessao
export TF_VAR_slack_bot_token="$(gcloud secrets versions access latest \
  --secret=slack-alerting-bot-token --project=iniapet-producao)"

# 3) plan / apply (esta stack)
cd cloud/monitoring/prod
terraform init
terraform plan  -out=tfplan
terraform apply tfplan
```

Se o token for usado por outros consumidores depois, vale rotacioná-lo: a `auth_token`
fica gravada no state. O state fica em bucket privado, e a SA de ops já tem
`roles/storage.admin`, então não é um caminho novo de exposição — mas é bom saber.

## Notas de operação

- **Log-based metric tem atraso de até 10 min** no Cloud Monitoring. A janela de 5 min
  com `duration = 5m` evita falso positivo por ingestão atrasada.
- **`app` (front) não emite log de erro server-side**: o único canal é `FrontLog` em
  `/api/v1/monitoring/front/logs`, hoje dominado pelo ruído `apiBaseUrl não definido...`.
  Uptime cobre indisponibilidade do `inia.pet`, mas **não** erros de JS no navegador —
  isso depende de corrigir a telemetria do front.
- **`app-iniapet-api` vs `prod-iniapet-api`**: os dois nomes convivem e o nome engana.
  Confirmado com o PH (17/11/2026): quem atende prod hoje é **`prod-iniapet-api`** (o app
  em produção ainda aponta para ele). A API nova (`app-iniapet-api`) está na mesma policy
  com o mesmo limiar, para pegar a virada de tráfego.
- **Não** remover as policies via `terraform destroy` sem confirmar — como qualquer
  recurso deste repo.