output "app_url" {
  description = "Where to reach the app (generate errors) in a browser."
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "receiver_url" {
  description = "Where to reach the receiver (received alerts) in a browser."
  value       = "https://${azurerm_linux_web_app.receiver.default_hostname}"
}

output "resource_group" {
  description = "The resource group containing the deployed resources."
  value       = azurerm_resource_group.main.name
}

output "log_analytics_workspace_id" {
  description = "The workspace (customer) ID of the Log Analytics Workspace holding the app's telemetry."
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "alert_rule" {
  description = "The log search alert rule that counts the app's failed requests."
  value       = azurerm_monitor_scheduled_query_rules_alert_v2.failed_requests.name
}
