terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  # Leave null to use Azure CLI, ARM_SUBSCRIPTION_ID, or your CI identity.
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}
