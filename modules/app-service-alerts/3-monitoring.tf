# ---------------------------------------------------------------------------
# Log Analytics - where Application Insights stores the app's telemetry, and
# what the alert rule in 6-alerts.tf queries.
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.name_prefix}-logs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Application Insights - workspace-based, so the telemetry the app sends lands
# in the Log Analytics Workspace above, in tables such as AppRequests and
# AppMetrics.
#
# Local authentication is disabled: the instrumentation key in the connection
# string only says where to send telemetry, it no longer lets anyone send it.
# Each request must carry an Entra access token for an identity holding the
# Monitoring Metrics Publisher role.
# ---------------------------------------------------------------------------
resource "azurerm_application_insights" "main" {
  name                         = "${var.name_prefix}-insights"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  workspace_id                 = azurerm_log_analytics_workspace.main.id
  application_type             = "web"
  local_authentication_enabled = false
  tags                         = var.tags
}

resource "azurerm_role_assignment" "app_telemetry" {
  scope                = azurerm_application_insights.main.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

# ---------------------------------------------------------------------------
# Diagnostic settings - ship both apps' Console Logs into the Log Analytics
# Workspace too. Within the Locally Dashboard these can be queried using:
#   AppServiceConsoleLogs | order by TimeGenerated desc
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "main" {
  for_each = {
    app      = azurerm_linux_web_app.app.id
    receiver = azurerm_linux_web_app.receiver.id
  }

  name                       = "console-logs"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AppServiceConsoleLogs"
  }
}
