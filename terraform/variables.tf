variable "subscription_id" {
  description = "Azure subscription ID. Leave null to use the Azure CLI, ARM_SUBSCRIPTION_ID, or CI identity."
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "Name of the Azure resource group for the dev environment."
  type        = string
  default     = "rg-commerce-dev"
}

variable "location" {
  description = "Azure region of the existing resource group."
  type        = string
  default     = "West Europe"
}

variable "workload_location" {
  description = "Azure region for resources inside the resource group, such as Container Apps and PostgreSQL."
  type        = string
  default     = "North Europe"
}

variable "environment" {
  description = "Short environment name used for tags."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Additional tags to apply to managed resources."
  type        = map(string)
  default     = {}
}

variable "acr_name" {
  description = "Azure Container Registry name."
  type        = string
  default     = "acrcommerceplatformdev"
}

variable "acr_sku" {
  description = "Azure Container Registry SKU."
  type        = string
  default     = "Basic"
}

variable "acr_admin_enabled" {
  description = "Whether the ACR admin account is enabled. Managed identity pull access is preferred."
  type        = bool
  default     = false
}

variable "log_analytics_workspace_name" {
  description = "Log Analytics Workspace used by Azure Container Apps Environment."
  type        = string
  default     = "workspacergcommercedev9827"
}

variable "container_apps_environment_name" {
  description = "Shared Azure Container Apps Environment name."
  type        = string
  default     = "managedEnvironment-rgcommercedev-a0e2"
}

variable "container_apps_identity_name" {
  description = "User-assigned managed identity used by Container Apps to pull from ACR."
  type        = string
  default     = "id-commerce-containerapps-acrpull-dev"
}

variable "postgres_server_name" {
  description = "Azure Database for PostgreSQL Flexible Server name. Set this to the existing server name before import."
  type        = string
  default     = "commerce-product-db-dev"
}

variable "postgres_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "postgres_admin_username" {
  description = "PostgreSQL administrator username."
  type        = string
  default     = "commerceadmin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL administrator password. Supply via TF_VAR_postgres_admin_password or a secure CI secret."
  type        = string
  sensitive   = true
}

variable "database_usernames" {
  description = "Optional database usernames keyed by service key. Defaults to postgres_admin_username for database-backed services."
  type        = map(string)
  default     = {}
}

variable "database_passwords" {
  description = "Optional database passwords keyed by service key. Defaults to postgres_admin_password for database-backed services."
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "retained_database_names" {
  description = "Logical databases to keep managed while their services are temporarily inactive."
  type        = map(string)
  default     = {}
}

variable "service_secrets" {
  description = "Optional Container App secret values keyed by service key, then secret name."
  type        = map(map(string))
  sensitive   = true
  default     = {}
}

variable "services" {
  description = "Microservice definitions used to create Container Apps and optional logical databases."
  type = map(object({
    app_name                     = string
    image_repository             = string
    image_tag                    = string
    target_port                  = number
    external_ingress             = bool
    database_name                = optional(string)
    liveness_probe_path          = optional(string)
    readiness_probe_path         = optional(string)
    cpu                          = optional(number, 0.5)
    memory                       = optional(string, "1Gi")
    min_replicas                 = optional(number, 0)
    max_replicas                 = optional(number, 2)
    environment_variables        = optional(map(string), {})
    secret_environment_variables = optional(map(string), {})
  }))

  default = {
    product = {
      app_name         = "commerce-product-service-dev"
      image_repository = "commerce-product-service"
      image_tag        = "latest"
      target_port      = 8080
      external_ingress = true
      database_name    = "product_db"
    }

    order = {
      app_name             = "commerce-order-service-dev"
      image_repository     = "commerce-order-service"
      image_tag            = "bootstrap"
      target_port          = 8080
      external_ingress     = false
      database_name        = "order_db"
      liveness_probe_path  = "/actuator/health/liveness"
      readiness_probe_path = "/actuator/health/readiness"
    }
  }
}

variable "prometheus_container_app_name" {
  description = "Name of the shared Prometheus Container App."
  type        = string
  default     = "commerce-prometheus-dev"
}

variable "prometheus_image" {
  description = "Official Prometheus container image used for the shared monitoring Container App."
  type        = string
  default     = "prom/prometheus:latest"
}

variable "prometheus_scrape_interval" {
  description = "Default interval used by Prometheus scrape jobs."
  type        = string
  default     = "15s"
}

variable "prometheus_scrape_targets" {
  description = "Container App services scraped by Prometheus, keyed by stable monitoring target name."
  type = map(object({
    service_key  = string
    job_name     = string
    metrics_path = string
  }))
  default = {
    product = {
      service_key  = "product"
      job_name     = "commerce-product-service"
      metrics_path = "/actuator/prometheus"
    }

    order = {
      service_key  = "order"
      job_name     = "commerce-order-service"
      metrics_path = "/actuator/prometheus"
    }
  }
}

variable "prometheus_cpu" {
  description = "CPU cores allocated to the Prometheus Container App."
  type        = number
  default     = 0.5
}

variable "prometheus_memory" {
  description = "Memory allocated to the Prometheus Container App."
  type        = string
  default     = "1Gi"
}

variable "grafana_container_app_name" {
  description = "Name of the shared Grafana Container App."
  type        = string
  default     = "commerce-grafana-dev"
}

variable "grafana_image" {
  description = "Official Grafana container image used for the shared monitoring Container App."
  type        = string
  default     = "grafana/grafana:latest"
}

variable "grafana_admin_user" {
  description = "Grafana administrator username."
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana administrator password. Supply via TF_VAR_grafana_admin_password or a secure CI secret."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.grafana_admin_password)) > 0
    error_message = "Grafana administrator password must not be empty."
  }
}

variable "grafana_prometheus_datasource_name" {
  description = "Name of the default Prometheus datasource provisioned in Grafana."
  type        = string
  default     = "Prometheus"
}

variable "grafana_cpu" {
  description = "CPU cores allocated to the Grafana Container App."
  type        = number
  default     = 0.5
}

variable "grafana_memory" {
  description = "Memory allocated to the Grafana Container App."
  type        = string
  default     = "1Gi"
}
