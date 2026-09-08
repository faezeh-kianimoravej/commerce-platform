output "id" {
  description = "Container App resource ID."
  value       = azurerm_container_app.service.id
}

output "name" {
  description = "Container App name."
  value       = azurerm_container_app.service.name
}

output "fqdn" {
  description = "Container App ingress FQDN, or null when external ingress is disabled."
  value       = try(azurerm_container_app.service.ingress[0].fqdn, null)
}

output "url" {
  description = "Container App external URL, or null when external ingress is disabled."
  value       = try("https://${azurerm_container_app.service.ingress[0].fqdn}", null)
}
