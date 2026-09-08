locals {
  common_tags = merge(var.tags, {
    environment = var.environment
    managed_by  = "terraform"
    project     = "commerce-platform"
  })

  active_database_services = {
    for service_key, service in var.services : service_key => service
    if service.database_name != null
  }

  managed_database_names = merge(
    {
      for service_key, service in local.active_database_services :
      service_key => service.database_name
    },
    var.retained_database_names
  )

  database_urls = {
    for service_key, service in local.active_database_services :
    service_key => "jdbc:postgresql://${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/${service.database_name}?sslmode=require"
  }

  database_usernames = {
    for service_key, service in local.active_database_services :
    service_key => lookup(var.database_usernames, service_key, var.postgres_admin_username)
  }

  database_passwords = {
    for service_key, service in local.active_database_services :
    service_key => lookup(var.database_passwords, service_key, var.postgres_admin_password)
  }
}

resource "azurerm_resource_group" "commerce" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.commerce.name
  location            = var.workload_location
  sku                 = var.acr_sku
  admin_enabled       = var.acr_admin_enabled
  tags                = local.common_tags
}

resource "azurerm_log_analytics_workspace" "container_apps" {
  name                = var.log_analytics_workspace_name
  resource_group_name = azurerm_resource_group.commerce.name
  location            = var.workload_location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_container_app_environment" "shared" {
  name                       = var.container_apps_environment_name
  resource_group_name        = azurerm_resource_group.commerce.name
  location                   = var.workload_location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.container_apps.id
  tags                       = local.common_tags
}

resource "azurerm_user_assigned_identity" "container_apps_acr_pull" {
  name                = var.container_apps_identity_name
  resource_group_name = azurerm_resource_group.commerce.name
  location            = var.workload_location
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.container_apps_acr_pull.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                          = var.postgres_server_name
  resource_group_name           = azurerm_resource_group.commerce.name
  location                      = var.workload_location
  version                       = var.postgres_version
  zone                          = "2"
  administrator_login           = var.postgres_admin_username
  administrator_password        = var.postgres_admin_password
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  backup_retention_days         = 7
  public_network_access_enabled = true
  tags                          = local.common_tags

  # High availability is intentionally omitted for the low-cost dev setup.
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_database" "service_databases" {
  for_each = local.managed_database_names

  name      = each.value
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = "utf8"
  collation = "en_US.utf8"
}

module "container_app_services" {
  source   = "./modules/container-app-service"
  for_each = var.services

  app_name                     = each.value.app_name
  resource_group_name          = azurerm_resource_group.commerce.name
  container_app_environment_id = azurerm_container_app_environment.shared.id
  acr_login_server             = azurerm_container_registry.acr.login_server
  managed_identity_id          = azurerm_user_assigned_identity.container_apps_acr_pull.id
  image_repository             = each.value.image_repository
  image_tag                    = each.value.image_tag
  target_port                  = each.value.target_port
  external_ingress             = each.value.external_ingress
  cpu                          = each.value.cpu
  memory                       = each.value.memory
  min_replicas                 = each.value.min_replicas
  max_replicas                 = each.value.max_replicas
  tags                         = local.common_tags

  environment_variables = merge(
    each.value.environment_variables,
    each.value.database_name != null ? {
      DB_URL      = local.database_urls[each.key]
      DB_USERNAME = local.database_usernames[each.key]
    } : {}
  )

  secret_values = merge(
    lookup(var.service_secrets, each.key, {}),
    each.value.database_name != null ? {
      "db-password" = local.database_passwords[each.key]
    } : {}
  )

  secret_environment_variables = merge(
    each.value.secret_environment_variables,
    each.value.database_name != null ? {
      DB_PASSWORD = "db-password"
    } : {}
  )

  depends_on = [
    azurerm_postgresql_flexible_server_firewall_rule.allow_azure_services,
    azurerm_postgresql_flexible_server_database.service_databases,
    azurerm_role_assignment.acr_pull
  ]
}
