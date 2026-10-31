output "app_url" {
  description = "Where to reach the app (generate errors) in a browser."
  value       = module.app-service-alerts.app_url
}

output "receiver_url" {
  description = "Where to reach the receiver (received alerts) in a browser."
  value       = module.app-service-alerts.receiver_url
}

output "log_analytics_workspace_id" {
  description = "The workspace (customer) ID of the Log Analytics Workspace holding the app's telemetry."
  value       = module.app-service-alerts.log_analytics_workspace_id
}

output "alert_rule" {
  description = "The log search alert rule that counts the app's failed requests."
  value       = module.app-service-alerts.alert_rule
}
