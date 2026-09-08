terraform {
  backend "azurerm" {
    resource_group_name  = "rg-commerce-dev"
    storage_account_name = "stcommercetf9827"
    container_name       = "tfstate"
    key                  = "commerce-platform-dev.tfstate"
  }
}
