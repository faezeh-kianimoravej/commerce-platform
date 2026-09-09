variable "app_name" {
  description = "Azure Container App name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that contains the Container App."
  type        = string
}

variable "container_app_environment_id" {
  description = "Shared Azure Container Apps Environment resource ID."
  type        = string
}

variable "acr_login_server" {
  description = "ACR login server, for example acrcommerceplatformdev.azurecr.io."
  type        = string
}

variable "managed_identity_id" {
  description = "User-assigned managed identity resource ID used for ACR image pulls."
  type        = string
}

variable "image_repository" {
  description = "ACR repository name for this service image."
  type        = string
}

variable "image_tag" {
  description = "Container image tag for this service."
  type        = string
}

variable "target_port" {
  description = "Application port exposed by the container."
  type        = number
}

variable "external_ingress" {
  description = "Whether the Container App should expose public ingress. Services still receive internal ingress when false."
  type        = bool
}

variable "liveness_probe_path" {
  description = "Optional HTTP liveness probe path for the service container."
  type        = string
  default     = null
}

variable "readiness_probe_path" {
  description = "Optional HTTP readiness probe path for the service container."
  type        = string
  default     = null
}

variable "cpu" {
  description = "CPU cores per replica."
  type        = number
}

variable "memory" {
  description = "Memory per replica."
  type        = string
}

variable "min_replicas" {
  description = "Minimum replica count."
  type        = number
}

variable "max_replicas" {
  description = "Maximum replica count."
  type        = number
}

variable "environment_variables" {
  description = "Plain-text environment variables for this service."
  type        = map(string)
  default     = {}
}

variable "secret_values" {
  description = "Container App secrets keyed by secret name. Values are stored in Terraform state."
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "secret_environment_variables" {
  description = "Environment variables keyed by env var name, with values referencing Container App secret names."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to the Container App."
  type        = map(string)
  default     = {}
}
