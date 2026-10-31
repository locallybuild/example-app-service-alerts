variable "name_prefix" {
  description = "The prefix used for all resources in this example."
  type        = string
}

variable "location" {
  description = "The region where these resources should be deployed."
  type        = string
}

variable "tags" {
  description = "A mapping of tags which should be applied to each of the resources."
  type        = map(string)
  default     = {}
}

variable "app_service_sku" {
  description = "App Service plan SKU."
  type        = string
  default     = "B1"
}

variable "alert_threshold" {
  description = "The alert fires when the app has more than this many failed requests within the window."
  type        = number
  default     = 5
}

variable "alert_evaluation_frequency" {
  description = "How often the alert rule runs its query, as an ISO 8601 duration."
  type        = string
  default     = "PT1M"
}

variable "alert_window_duration" {
  description = "How far back each evaluation of the alert rule looks, as an ISO 8601 duration."
  type        = string
  default     = "PT5M"
}
