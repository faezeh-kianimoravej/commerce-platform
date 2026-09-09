locals {
  prometheus_scrape_jobs = [
    for _, scrape_target in var.prometheus_scrape_targets : {
      job_name         = scrape_target.job_name
      metrics_path     = scrape_target.metrics_path
      target_addresses = [module.container_app_services[scrape_target.service_key].name]
    }
  ]

  prometheus_config = templatefile("${path.module}/monitoring/prometheus.yml.tftpl", {
    scrape_interval = var.prometheus_scrape_interval
    scrape_jobs     = local.prometheus_scrape_jobs
  })

  grafana_datasources_config = templatefile("${path.module}/monitoring/grafana-datasources.yml.tftpl", {
    prometheus_datasource_name = var.grafana_prometheus_datasource_name
    prometheus_datasource_url  = "http://${var.prometheus_container_app_name}:9090"
  })
}

resource "azurerm_container_app" "prometheus" {
  name                         = var.prometheus_container_app_name
  container_app_environment_id = azurerm_container_app_environment.shared.id
  resource_group_name          = azurerm_resource_group.commerce.name
  revision_mode                = "Single"
  tags                         = local.common_tags

  secret {
    name  = "prometheus-config"
    value = local.prometheus_config
  }

  ingress {
    external_enabled = false
    target_port      = 9090
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "prometheus"
      image  = var.prometheus_image
      cpu    = var.prometheus_cpu
      memory = var.prometheus_memory

      command = ["/bin/sh", "-c"]
      args = [
        "printf '%s' \"$PROMETHEUS_CONFIG\" > /tmp/prometheus.yml && exec /bin/prometheus --config.file=/tmp/prometheus.yml --storage.tsdb.path=/prometheus --web.listen-address=0.0.0.0:9090"
      ]

      env {
        name        = "PROMETHEUS_CONFIG"
        secret_name = "prometheus-config"
      }

      volume_mounts {
        name = "prometheus-data"
        path = "/prometheus"
      }
    }

    volume {
      name         = "prometheus-data"
      storage_type = "EmptyDir"
    }
  }

  depends_on = [
    module.container_app_services
  ]
}

resource "azurerm_container_app" "grafana" {
  name                         = var.grafana_container_app_name
  container_app_environment_id = azurerm_container_app_environment.shared.id
  resource_group_name          = azurerm_resource_group.commerce.name
  revision_mode                = "Single"
  tags                         = local.common_tags

  secret {
    name  = "grafana-admin-password"
    value = var.grafana_admin_password
  }

  secret {
    name  = "grafana-datasources-config"
    value = local.grafana_datasources_config
  }

  ingress {
    external_enabled = true
    target_port      = 3000
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "grafana"
      image  = var.grafana_image
      cpu    = var.grafana_cpu
      memory = var.grafana_memory

      command = ["/bin/sh", "-c"]
      args = [
        "mkdir -p /tmp/grafana-provisioning/datasources && printf '%s' \"$GRAFANA_DATASOURCES_CONFIG\" > /tmp/grafana-provisioning/datasources/prometheus.yml && exec /run.sh"
      ]

      env {
        name  = "GF_PATHS_PROVISIONING"
        value = "/tmp/grafana-provisioning"
      }

      env {
        name  = "GF_SECURITY_ADMIN_USER"
        value = var.grafana_admin_user
      }

      env {
        name        = "GF_SECURITY_ADMIN_PASSWORD"
        secret_name = "grafana-admin-password"
      }

      env {
        name        = "GRAFANA_DATASOURCES_CONFIG"
        secret_name = "grafana-datasources-config"
      }
    }
  }

  depends_on = [
    azurerm_container_app.prometheus
  ]
}
