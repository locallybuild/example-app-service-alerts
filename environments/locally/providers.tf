terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "app-service-alerts" {
  source = "../../modules/app-service-alerts"

  name_prefix = "locally-example-alerts"
  location    = "berlin"
  tags = {
    ProvisionedVia = "Terraform"
  }
}
