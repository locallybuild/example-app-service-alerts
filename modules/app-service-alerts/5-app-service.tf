# ---------------------------------------------------------------------------
# App Service Plan - houses both App Services.
# ---------------------------------------------------------------------------
resource "azurerm_service_plan" "main" {
  name                = "${var.name_prefix}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
}

# ---------------------------------------------------------------------------
# App - a web page with a "Generate errors" button, instrumented with
# Application Insights.
#
# Each click makes a burst of requests that fail with a 500, which Application
# Insights stores in the AppRequests table - enough to cross the alert rule's
# threshold. The
# app authenticates to Application Insights as its user-assigned identity,
# through the managed identity endpoint (IDENTITY_ENDPOINT and IDENTITY_HEADER).
# ---------------------------------------------------------------------------
resource "azurerm_linux_web_app" "app" {
  name                = "${var.name_prefix}-app"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = var.tags

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  site_config {
    health_check_path                 = "/healthz"
    health_check_eviction_time_in_min = 2

    application_stack {
      docker_image_name        = "${local.image_name}:${local.image_tag}"
      docker_registry_url      = "https://${azurerm_container_registry.main.login_server}"
      docker_registry_username = azurerm_container_registry.main.admin_username
      docker_registry_password = azurerm_container_registry.main.admin_password
    }
  }

  app_settings = {
    ROLE = "app"

    # App Service routes public traffic to the container on this port, and the
    # app binds to it (12-factor port binding).
    WEBSITES_PORT = tostring(local.app_port)
    PORT          = tostring(local.app_port)

    # Where to send telemetry. This isn't a secret: with local authentication
    # disabled, the instrumentation key in it can't be used to send anything
    # without an Entra access token.
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.main.connection_string

    # Selects which of the web app's identities the managed identity endpoint
    # issues a token for.
    AZURE_CLIENT_ID = azurerm_user_assigned_identity.app.client_id

    # Shown on the page, so you know what it takes to fire the alert, and
    # linked so you can watch it arrive.
    ALERT_THRESHOLD = tostring(var.alert_threshold)
    ALERT_WINDOW    = var.alert_window_duration
    RECEIVER_URL    = "https://${azurerm_linux_web_app.receiver.default_hostname}"
  }

  # The image must exist in the registry, and the identity must hold its role,
  # before the app starts.
  depends_on = [
    terraform_data.build_and_push,
    azurerm_role_assignment.app_telemetry,
  ]
}

# ---------------------------------------------------------------------------
# Receiver - the endpoint the Action Group's webhook posts alerts to.
#
# It keeps the most recent alerts in memory and lists them on its page. Always
# On keeps the container running, so alerts aren't lost to a cold start and the
# list survives between page visits.
# ---------------------------------------------------------------------------
resource "azurerm_linux_web_app" "receiver" {
  name                = "${var.name_prefix}-receiver"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = var.tags

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  site_config {
    always_on                         = true
    health_check_path                 = "/healthz"
    health_check_eviction_time_in_min = 2

    application_stack {
      docker_image_name        = "${local.image_name}:${local.image_tag}"
      docker_registry_url      = "https://${azurerm_container_registry.main.login_server}"
      docker_registry_username = azurerm_container_registry.main.admin_username
      docker_registry_password = azurerm_container_registry.main.admin_password
    }
  }

  app_settings = {
    ROLE = "receiver"

    WEBSITES_PORT = tostring(local.app_port)
    PORT          = tostring(local.app_port)
  }

  depends_on = [
    terraform_data.build_and_push,
  ]
}
