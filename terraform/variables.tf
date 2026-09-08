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
  description = "Azure region for the dev environment."
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
  default     = "workspacergcommercedev9827container_apps_environment_name"
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
      app_name         = "commerce-order-service-dev"
      image_repository = "commerce-order-service"
      image_tag        = "latest"
      target_port      = 8080
      external_ingress = false
      database_name    = "order_db"
    }

    gateway = {
      app_name         = "commerce-api-gateway-dev"
      image_repository = "commerce-api-gateway"
      image_tag        = "latest"
      target_port      = 8080
      external_ingress = true
      database_name    = null
    }
  }
}
