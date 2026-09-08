resource "azurerm_container_app" "service" {
  name                         = var.app_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  registry {
    server   = var.acr_login_server
    identity = var.managed_identity_id
  }

  dynamic "secret" {
    for_each = toset(keys(nonsensitive(var.secret_values)))

    content {
      name  = secret.key
      value = var.secret_values[secret.key]
    }
  }

  dynamic "ingress" {
    for_each = var.external_ingress ? [1] : []

    content {
      external_enabled = true
      target_port      = var.target_port
      transport        = "auto"

      traffic_weight {
        latest_revision = true
        percentage      = 100
      }
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.image_repository
      image  = "${var.acr_login_server}/${var.image_repository}:${var.image_tag}"
      cpu    = var.cpu
      memory = var.memory

      dynamic "env" {
        for_each = var.environment_variables

        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_environment_variables

        content {
          name        = env.key
          secret_name = env.value
        }
      }
    }
  }
}
