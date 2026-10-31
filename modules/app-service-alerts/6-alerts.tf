# ---------------------------------------------------------------------------
# Action Group - what happens when an alert fires: Azure Monitor posts it to
# the receiver's webhook.
#
# The common alert schema gives every kind of alert (log search, metric,
# activity log) the same JSON shape - an "essentials" section (rule, severity,
# fired time, fired/resolved) plus rule-specific context - so the receiver
# needs only one parser.
# ---------------------------------------------------------------------------
resource "azurerm_monitor_action_group" "main" {
  name                = "${var.name_prefix}-actions"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "alerts"
  tags                = var.tags

  webhook_receiver {
    name                    = "receiver"
    service_uri             = "https://${azurerm_linux_web_app.receiver.default_hostname}/alerts"
    use_common_alert_schema = true
  }
}

# ---------------------------------------------------------------------------
# Log search alert rule - counts the app's failed requests.
#
# Every evaluation_frequency, Azure Monitor runs the query over the last
# window_duration of telemetry. If it returns more than the threshold, the
# alert fires and the Action Group is notified.
#
# The query adds up ItemCount rather than counting rows. The Application
# Insights SDK samples requests once there are more than a few a second, and
# each sampled row stands in for ItemCount requests - a burst of 10 failures
# can arrive as 5 rows. Summing ItemCount gives the real number either way.
#
# auto_mitigation_enabled resolves the alert by itself once the count falls
# back under the threshold, which sends a second notification with the monitor
# condition "Resolved".
# ---------------------------------------------------------------------------
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "failed_requests" {
  name                = "${var.name_prefix}-failed-requests"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  description         = "More than ${var.alert_threshold} failed requests to the app within ${var.alert_window_duration}."
  tags                = var.tags

  scopes               = [azurerm_application_insights.main.id]
  severity             = 2
  evaluation_frequency = var.alert_evaluation_frequency
  window_duration      = var.alert_window_duration
  enabled              = true

  auto_mitigation_enabled = true

  criteria {
    query                   = "AppRequests | where Success == false | summarize FailedRequests = sum(ItemCount)"
    metric_measure_column   = "FailedRequests"
    time_aggregation_method = "Total"
    operator                = "GreaterThan"
    threshold               = var.alert_threshold

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.main.id]
  }
}
