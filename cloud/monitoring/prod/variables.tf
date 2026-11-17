terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.prod_project_id
  region  = var.default_region
}

variable "prod_project_id" {
  description = "Projeto GCP de producao (InIA Vet)."
  type        = string
  default     = "iniapet-producao"
}

variable "default_region" {
  description = "Regiao padrao."
  type        = string
  default     = "us-central1"
}

variable "slack_channel_name" {
  description = "Canal Slack de destino dos alertas (com #)."
  type        = string
  default     = "#ops"
}

variable "slack_bot_token" {
  description = <<-EOT
    Bot User OAuth token do app Slack (xoxb-...) com o escopo chat:write,
    usado pelo canal Slack NATIVO do Cloud Monitoring.
    NUNCA commitar: passar por TF_VAR_slack_bot_token (env).
    Para gravar em Secret Manager e materializar no shell, ver README desta stack.
  EOT
  type        = string
  sensitive   = true
}

variable "api_public_host" {
  description = "Host publico que serve a API de prod para o app (probe de /ping)."
  type        = string
  default     = "app.inia.api.br"
}

# ---- Limiares (calibrados contra o baseline medido em prod, 17/11/2026) ----
# Baseline de dia tranquilo: 0-20 ERROR/hora. Volume de usuarios e' baixo, mas um bug
# atinge muitos usuarios rapido -> comecar sensivel (3 em 5 min) e afrouxar se ruido.

variable "error_threshold" {
  description = "ERRORs por servico na janela para disparar."
  type        = number
  default     = 3
}

variable "transcription_threshold" {
  description = "Falhas de chunk/transcricao na janela para disparar."
  type        = number
  default     = 3
}

variable "models_threshold" {
  description = "Esgotamentos de modelo/retries na janela para disparar."
  type        = number
  default     = 3
}

variable "no_user_threshold" {
  description = "Logins sem doc na janela. Alto de proposito: o SA do gateway ja' emite ~363/dia."
  type        = number
  default     = 60
}

variable "error_window" {
  description = "Janela de avaliacao (texto, uso em display)."
  type        = string
  default     = "5 minutos"
}

variable "error_window_seconds" {
  description = "Janela de avaliacao em segundos."
  type        = number
  default     = 300
}