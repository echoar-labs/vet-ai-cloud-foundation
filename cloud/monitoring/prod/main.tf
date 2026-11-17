/*
 * Monitoramento PROD — InIA Vet (projeto iniapet-producao)
 *
 * Stack dedicada e ISOLADA do root de DNS (`cloud/dns.tf`), com backend e
 * prefixo de state próprios:
 *   gs://foundation-state-iniapet/terraform/state/monitoring/prod
 *
 * Escopo: alertas proativos de erro/disponibilidade do ambiente de produção.
 * NÃO cria servico, deploy nem DNS — só read-only (probe HTTP e leitura de log),
 * metricas de log e alert policies.
 *
 * Alvos de erro (17/11/2026): o backend que atende prod hoje e' `prod-iniapet-api`
 * (nome legado, mas e' ele que carrega o trafego e os erros); `app-iniapet-api` e' a
 * API nova e o `inia-admin-app` o painel admin. Os tres entram nas policies.
 *
 * A credencial do canal Slack NAO vive em .tf/.tfvars/git: entra por
 * TF_VAR_slack_bot_token (ver README desta stack).
 */

locals {
  # Servicos de aplicacao de PROD (Cloud Run em iniapet-producao).
  services = {
    backend = "prod-iniapet-api" # atende prod hoje (app em producao aponta aqui)
    api_new = "app-iniapet-api"  # API nova (release)
    admin   = "inia-admin-app"   # painel admin
  }

  # Frases de sintoma (usadas nos filtros de log-based metric). Frases multi-palavra
  # NO Cloud Logging casam sozinhas aqui porque o filtro vai em textPayload/jsonPayload;
  # manter curtas e especificas para nao pegar ruido.
  transcription_failure_msgs = [
    "Failed chunk",
    "Error processing transcription",
  ]
}

# -------------------------------------------------------------------
# Canal de notificacao: Slack nativo do Cloud Monitoring -> #ops
# -------------------------------------------------------------------
resource "google_monitoring_notification_channel" "slack_ops" {
  project      = var.prod_project_id
  display_name = "Slack #ops (alertas de prod InIA)"
  type         = "slack"
  enabled      = true

  labels = {
    channel_name = var.slack_channel_name
  }

  sensitive_labels {
    auth_token = var.slack_bot_token
  }
}

# -------------------------------------------------------------------
# A) ERRO por servico — log-based metrics (um counter por service_name)
# -------------------------------------------------------------------
resource "google_logging_metric" "error_rate" {
  for_each = local.services

  project     = var.prod_project_id
  name        = "inia_prod_error_${replace(each.key, "_", "-")}"
  description = "Contagem de ERROR/CRITICAL do Cloud Run ${each.value} em prod (por minuto no alerta)."
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${each.value}\" AND severity>=ERROR"

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    unit         = "1"
    display_name = "ERRORs ${each.value}"
  }
}

# Policy de volume de erro — sensivel de proposito (PH: volume de usuarios baixo,
# mas um bug atinge muitos usuarios rapido). Baseline medido em dia tranquilo:
# 0-20 ERROR/hora; 3 erros em 5 min ja e' sinal fora do normal.
resource "google_monitoring_alert_policy" "error_volume" {
  for_each = local.services

  project      = var.prod_project_id
  display_name = "[PROD] Erros ${each.key} (${each.value})"
  combiner     = "OR"
  severity     = "ERROR"
  enabled      = true

  conditions {
    display_name = "ERRORs >= ${var.error_threshold} em ${var.error_window}"

    condition_threshold {
      filter = join(" AND ", [
        "metric.type=\"logging.googleapis.com/user/${google_logging_metric.error_rate[each.key].name}\"",
        "resource.type=\"cloud_run_revision\"",
        "resource.labels.service_name=\"${each.value}\"",
      ])

      comparison      = "COMPARISON_GT"
      threshold_value = var.error_threshold
      duration        = "${var.error_window_seconds}s"

      aggregations {
        alignment_period   = "${var.error_window_seconds}s"
        per_series_aligner = "ALIGN_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.slack_ops.id]

  documentation {
    mime_type = "text/markdown"
    subject   = "PROD: erros em ${each.value}"
    content   = <<-EOT
      O Cloud Run **${each.value}** (${each.key}) passou de ${var.error_threshold} ERRORs
      em ${var.error_window}.

      Triagem:
      1. Logs: https://console.cloud.google.com/logs/query?project=${var.prod_project_id} (filtro: `resource.labels.service_name="${each.value}" severity>=ERROR`)
      2. A exception real mora em `jsonPayload.exception` / `jsonPayload.category`, NAO em `jsonPayload.message`.
      3. Se for `HttpRequestMessage` / "This instance has already started one or more requests" → bug conhecido de mutacao de request compartilhada (transcricao).
      4. Contar consultas distintas (TraceId), nao so linhas de log — um bug amplifica em ~40x por retry de chunk.

      Incidente de referencia: 17/11/2026 (~20k ERRORs, ~19 consultas travadas).
    EOT
  }
}

# -------------------------------------------------------------------
# B) SINTOMAS de negocio
# -------------------------------------------------------------------

# B1) Falha de transcricao (chunk/processamento) — o sintoma que travou consultas
resource "google_logging_metric" "transcription_failure" {
  project     = var.prod_project_id
  name        = "inia_prod_transcription_failure"
  description = "Falhas de transcricao (chunk/processamento) em prod."
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${local.services.backend}\" AND severity>=ERROR AND (textPayload:\"Failed chunk\" OR jsonPayload.message:\"Failed chunk\" OR textPayload:\"Error processing transcription\" OR jsonPayload.message:\"Error processing transcription\")"

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    unit         = "1"
    display_name = "Falhas de transcricao"
  }
}

resource "google_monitoring_alert_policy" "transcription_failure" {
  project      = var.prod_project_id
  display_name = "[PROD] Falha de transcricao (backend)"
  combiner     = "OR"
  severity     = "ERROR"
  enabled      = true

  conditions {
    display_name = "Falhas de chunk/transcricao >= ${var.transcription_threshold} em ${var.error_window}"

    condition_threshold {
      filter = join(" AND ", [
        "metric.type=\"logging.googleapis.com/user/${google_logging_metric.transcription_failure.name}\"",
        "resource.type=\"cloud_run_revision\"",
        "resource.labels.service_name=\"${local.services.backend}\"",
      ])

      comparison      = "COMPARISON_GT"
      threshold_value = var.transcription_threshold
      duration        = "${var.error_window_seconds}s"

      aggregations {
        alignment_period   = "${var.error_window_seconds}s"
        per_series_aligner = "ALIGN_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.slack_ops.id]

  documentation {
    mime_type = "text/markdown"
    subject   = "PROD: transcricao falhando"
    content   = <<-EOT
      Falhas de transcricao acima do limiar em **${local.services.backend}**.
      Isso normalmente significa **consulta travada** para o usuario final
      (task em `Processing` sem documento gerado).

      1. Consultas afetadas: rodar `~/ops/afetadas_transcricao.py --csv f.csv` (le Firestore prod, read-only).
      2. Verificar `TranscriptionTasks` em `Processing`/`Scheduled` e a ausencia de `Transcriptions`.
      3. Causa historica: mutacao de request compartilhada em `VertexPromptEngineService`.
    EOT
  }
}

# B2) Modelos esgotados (Vertex/Gemini fora ou 429 sustentado)
resource "google_logging_metric" "models_exhausted" {
  project     = var.prod_project_id
  name        = "inia_prod_models_exhausted"
  description = "Esgotamento de modelos/retries em prod (Vertex/Gemini indisponivel ou rate limit)."
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${local.services.backend}\" AND severity>=ERROR AND (textPayload:\"retries exhausted\" OR jsonPayload.message:\"retries exhausted\")"

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    unit         = "1"
    display_name = "Modelos esgotados"
  }
}

resource "google_monitoring_alert_policy" "models_exhausted" {
  project      = var.prod_project_id
  display_name = "[PROD] Modelos/retries esgotados (backend)"
  combiner     = "OR"
  severity     = "ERROR"
  enabled      = true

  conditions {
    display_name = "Esgotamento de modelos >= ${var.models_threshold} em ${var.error_window}"

    condition_threshold {
      filter = join(" AND ", [
        "metric.type=\"logging.googleapis.com/user/${google_logging_metric.models_exhausted.name}\"",
        "resource.type=\"cloud_run_revision\"",
        "resource.labels.service_name=\"${local.services.backend}\"",
      ])

      comparison      = "COMPARISON_GT"
      threshold_value = var.models_threshold
      duration        = "${var.error_window_seconds}s"

      aggregations {
        alignment_period   = "${var.error_window_seconds}s"
        per_series_aligner = "ALIGN_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.slack_ops.id]

  documentation {
    mime_type = "text/markdown"
    subject   = "PROD: modelos esgotados"
    content   = <<-EOT
      Todas as tentativas de modelo falharam em **${local.services.backend}**.
      Verificar: quota/rate limit no Vertex AI (projeto `iniavet-producao`), permissao
      `aiplatform.endpoints.predict` da SA de runtime, e se o erro de base e' de rede
      ou de request mutada (bug de codigo).
    EOT
  }
}

# B3) Usuario/SA sem doc no Firestore (403 admin-gated) — hoje o WARNING mais comum.
#     Baseline ~363/dia e' o SA do gateway (conhecido, benigno), por isso o limiar
#     e' alto e o alerta aponta o discriminador para nao virar ruido.
resource "google_logging_metric" "no_user_for_email" {
  project     = var.prod_project_id
  name        = "inia_prod_no_user_for_email"
  description = "Logins/SA sem doc em Users no Firestore (risco de 403 admin-gated)."
  filter      = "resource.type=\"cloud_run_revision\" AND severity=WARNING AND (textPayload:\"No user found for email\" OR jsonPayload.message:\"No user found for email\")"

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    unit         = "1"
    display_name = "Usuarios sem doc"
  }
}

resource "google_monitoring_alert_policy" "no_user_for_email" {
  project      = var.prod_project_id
  display_name = "[PROD] Usuario sem doc no Firestore (403 admin-gated)"
  combiner     = "OR"
  severity     = "WARNING"
  enabled      = true

  conditions {
    display_name = "Logins sem doc >= ${var.no_user_threshold} em ${var.error_window}"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.no_user_for_email.name}\" resource.type=\"cloud_run_revision\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.no_user_threshold
      duration        = "${var.error_window_seconds}s"

      aggregations {
        alignment_period   = "${var.error_window_seconds}s"
        per_series_aligner = "ALIGN_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.slack_ops.id]

  documentation {
    mime_type = "text/markdown"
    subject   = "PROD: usuario sem doc no Firestore"
    content   = <<-EOT
      Muitos acessos sem doc correspondente em `Users`.

      **Primeiro checar se e' ruido conhecido**: o SA `api-gateway-sa-prod@${var.prod_project_id}.iam.gserviceaccount.com`
      e' o maior emissor e e' benigno. Se o alerta for so' dele, ajuste o limiar.

      Se aparecerem subs de 15-25 digitos (usuario Google), e' o cenario de **403 em toda rota
      admin-gated**: criar `Users/<email do login>` com `isAdmin: true` — o fallback por e-mail
      (`AdminUserEmailClaimsTransformation`) so' age se o doc com o email EXATO existir.
    EOT
  }
}

# -------------------------------------------------------------------
# A) DISPONIBILIDADE — uptime checks (hoje: 0 configurados em prod)
# -------------------------------------------------------------------
resource "google_monitoring_uptime_check_config" "app_front" {
  project      = var.prod_project_id
  display_name = "App (inia.pet)"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.prod_project_id
      host       = "inia.pet"
    }
  }
}

resource "google_monitoring_uptime_check_config" "admin" {
  project      = var.prod_project_id
  display_name = "Admin (inia-admin-app)"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.prod_project_id
      host       = "inia-admin-app-us2x2xsjaq-uc.a.run.app"
    }
  }
}

# API de prod pela rota PUBLICA (mesma que o app usa). O /ping direto no Cloud Run
# legado devolve 403 (IAM) — nao serve como probe externo; o dominio publico devolve 204.
resource "google_monitoring_uptime_check_config" "api_public" {
  project      = var.prod_project_id
  display_name = "API publica (${var.api_public_host}/ping)"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/ping"
    port         = 443
    use_ssl      = true
    validate_ssl = true
    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.prod_project_id
      host       = var.api_public_host
    }
  }
}

# Alerta de disponibilidade para cada uptime check
resource "google_monitoring_alert_policy" "uptime_failure" {
  for_each = {
    app_front  = google_monitoring_uptime_check_config.app_front.display_name
    admin      = google_monitoring_uptime_check_config.admin.display_name
    api_public = google_monitoring_uptime_check_config.api_public.display_name
  }

  project      = var.prod_project_id
  display_name = "[PROD] Indisponivel: ${each.value}"
  combiner     = "OR"
  severity     = "CRITICAL"
  enabled      = true

  conditions {
    display_name = "${each.value} falhando"

    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.label.check_id=\"${replace(each.key, "app_front", google_monitoring_uptime_check_config.app_front.uptime_check_id)}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "300s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.*"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.slack_ops.id]

  documentation {
    mime_type = "text/markdown"
    subject   = "PROD indisponivel: ${each.value}"
    content   = "O probe HTTP `${each.value}` falhou de forma sustentada. Verificar ingress/revisao do Cloud Run, DNS e LB."
  }
}