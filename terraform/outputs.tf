output "acr_login_server" {
  description = "Login server for the shared Azure Container Registry."
  value       = azurerm_container_registry.acr.login_server
}

output "postgresql_host" {
  description = "Hostname for the shared PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
}

output "product_container_app_url" {
  description = "External URL for the product service Container App."
  value       = try(module.container_app_services["product"].url, null)
}

output "order_container_app_url" {
  description = "External URL for the order service Container App, when external ingress is enabled."
  value       = try(module.container_app_services["order"].url, null)
}

output "gateway_container_app_url" {
  description = "External URL for the API gateway Container App."
  value       = try(module.container_app_services["gateway"].url, null)
}

output "container_app_urls" {
  description = "External URLs for all services. Values are null for services without external ingress."
  value = {
    for service_key, service in module.container_app_services :
    service_key => service.url
  }
}

output "postgresql_databases" {
  description = "Logical PostgreSQL databases managed by Terraform."
  value       = [for database in azurerm_postgresql_flexible_server_database.service_databases : database.name]
}
