# ---------------------------------------------------------------------------
# User-Assigned Managed Identity - for the app, which sends its telemetry to
# Application Insights.
#
# Application Insights has local (instrumentation key) authentication disabled
# in 3-monitoring.tf, so telemetry is only accepted with an Entra access token.
# The app gets one for this identity from the App Service managed identity
# endpoint.
#
# The receiver doesn't call any Azure service - Azure Monitor calls it - so it
# has no identity at all.
#
# User-assigned (rather than system-assigned) identities exist before the web
# app does, so the role assignment is granted up front - the app can send
# telemetry from its very first request, rather than racing a grant that lands
# later.
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "app" {
  name                = "${var.name_prefix}-app-id"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}
