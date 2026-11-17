output "slack_channel_id" {
  description = "Resource name do notification channel Slack (referenciado pelas policies)."
  value       = google_monitoring_notification_channel.slack_ops.id
}

output "error_policies" {
  description = "Policies de volume de erro por servico."
  value       = { for k, p in google_monitoring_alert_policy.error_volume : k => p.display_name }
}

output "symptom_policies" {
  description = "Policies de sintoma de negocio."
  value = [
    google_monitoring_alert_policy.transcription_failure.display_name,
    google_monitoring_alert_policy.models_exhausted.display_name,
    google_monitoring_alert_policy.no_user_for_email.display_name,
  ]
}

output "uptime_checks" {
  description = "Uptime checks criados."
  value = {
    app_front  = google_monitoring_uptime_check_config.app_front.display_name
    admin      = google_monitoring_uptime_check_config.admin.display_name
    api_public = google_monitoring_uptime_check_config.api_public.display_name
  }
}