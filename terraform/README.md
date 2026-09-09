# Commerce Platform Terraform

This directory contains Terraform for the commerce-platform dev infrastructure on Azure. The setup is intentionally small and readable: shared infrastructure is defined once, and microservices are declared through a reusable `services` map.

## What Terraform Manages

Shared resources:

- Resource group: `rg-commerce-dev`
- Azure Container Registry: `acrcommerceplatformdev`
- Log Analytics Workspace for Container Apps
- Shared Azure Container Apps Environment
- Shared Prometheus Container App for centralized metrics scraping
- One user-assigned managed identity for Container Apps to pull from ACR
- `AcrPull` role assignment scoped only to the ACR
- One Azure Database for PostgreSQL Flexible Server

Per-service resources:

- One Azure Container App per entry in `var.services`
- One logical PostgreSQL database for each service where `database_name` is not `null`

Current services:

- `product`: `commerce-product-service-dev`, database `product_db`
- `order`: `commerce-order-service-dev`, database `order_db`
- `gateway`: `commerce-api-gateway-dev`, no database

## Monitoring

Prometheus is managed centrally in `monitoring.tf` as one internal-only Azure Container App in the shared Container Apps Environment. It uses the official `prom/prometheus` image.

Prometheus configuration is rendered from `monitoring/prometheus.yml.tftpl`, stored in a Container Apps secret, injected into the container as `PROMETHEUS_CONFIG`, and written to `/tmp/prometheus.yml` before Prometheus starts. Runtime TSDB data uses an `EmptyDir` volume mounted at `/prometheus`.

Scrape jobs are driven by `prometheus_scrape_targets`. Each entry references a key from `services`, and Terraform resolves that service to its Azure Container Apps same-environment service name.

```hcl
prometheus_scrape_targets = {
  product = {
    service_key  = "product"
    job_name     = "commerce-product-service"
    metrics_path = "/actuator/prometheus"
  }
}
```

To add Order Service or API Gateway later, add the service to `services` and then add one more `prometheus_scrape_targets` entry with its `service_key`, `job_name`, and `metrics_path`.

Grafana is managed in the same monitoring file as a separate shared Container App with external ingress enabled for development access. It uses the official `grafana/grafana` image.

Grafana's Prometheus datasource is provisioned from `monitoring/grafana-datasources.yml.tftpl`. Terraform renders the datasource URL as `http://commerce-prometheus-dev:9090`, stores the rendered YAML in a Container Apps secret, injects it as `GRAFANA_DATASOURCES_CONFIG`, and writes it under `/tmp/grafana-provisioning/datasources` before Grafana starts. `GF_PATHS_PROVISIONING` points Grafana at that generated provisioning directory.

Set the Grafana admin password with a sensitive Terraform variable:

```powershell
$env:TF_VAR_grafana_admin_password = "<grafana-admin-password>"
```

The dev PostgreSQL setup uses public access and an `AllowAzureServices` firewall rule so Azure-hosted services can connect. For production, prefer private networking with VNet integration, private DNS, and restricted database firewall rules.

The existing resource group is in `West Europe`. Resources inside that group can still be deployed to another Azure region; this dev configuration keeps workload resources in `North Europe` via `workload_location`.

## Directory Structure

```text
terraform/
├── modules/
│   └── container-app-service/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── providers.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── README.md
```

## Reusable Service Map

Services are configured in `var.services`. Each key is a stable Terraform identity for the service, and the value describes the Container App and optional database.

```hcl
services = {
  product = {
    app_name         = "commerce-product-service-dev"
    image_repository = "commerce-product-service"
    image_tag        = "dev"
    target_port      = 8080
    external_ingress = true
    database_name    = "product_db"
  }

  order = {
    app_name         = "commerce-order-service-dev"
    image_repository = "commerce-order-service"
    image_tag        = "dev"
    target_port      = 8080
    external_ingress = false
    database_name    = "order_db"
  }

  gateway = {
    app_name         = "commerce-api-gateway-dev"
    image_repository = "commerce-api-gateway"
    image_tag        = "dev"
    target_port      = 8080
    external_ingress = true
    database_name    = null
  }
}
```

When `database_name` is not `null`, Terraform creates that logical database and injects:

- `DB_URL`
- `DB_USERNAME`
- `DB_PASSWORD`, backed by a Container Apps secret named `db-password`

When `database_name = null`, database configuration is omitted. The gateway does not receive database environment variables.

## Adding A New Service

Add one entry to the `services` map:

```hcl
inventory = {
  app_name         = "commerce-inventory-service-dev"
  image_repository = "commerce-inventory-service"
  image_tag        = "dev"
  target_port      = 8080
  external_ingress = false
  database_name    = "inventory_db"
}
```

If the service needs no database, set `database_name = null`.

Optional per-service settings:

- `cpu`
- `memory`
- `min_replicas`
- `max_replicas`
- `environment_variables`
- `secret_environment_variables`

Additional Container App secrets can be supplied with `service_secrets`, keyed by service name and secret name. Keep real values out of committed files.

## Configure Variables

Start from the example:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Only put non-secret values in `terraform.tfvars`. This repository ignores `*.tfvars`, `*.tfstate`, and plan files.

Required secret variables should be supplied via environment variables, CI secrets, or a secure Terraform variable store:

```powershell
$env:TF_VAR_postgres_admin_password = "<postgres-admin-password>"
$env:TF_VAR_grafana_admin_password = "<grafana-admin-password>"
```

Optional separate service database passwords can be supplied as a map:

```powershell
$env:TF_VAR_database_passwords = '{"product":"<product-db-password>","order":"<order-db-password>"}'
```

For a simple dev setup, `database_passwords` may be omitted and Terraform will reuse `postgres_admin_password` for database-backed services. For better least privilege, create separate PostgreSQL users for each service, grant each user access only to its logical database, and set `database_usernames` plus `database_passwords`.

Terraform state can contain sensitive values such as Container App secrets. Local state is acceptable only for early development. The next recommended improvement is a secured remote backend, for example Azure Storage with blob versioning, encryption, and restricted access.

Important variables:

- `subscription_id`
- `location`, the existing resource group region
- `workload_location`, the region for resources inside the resource group
- `prometheus_container_app_name`
- `prometheus_image`
- `prometheus_scrape_interval`
- `prometheus_scrape_targets`
- `grafana_container_app_name`
- `grafana_image`
- `grafana_admin_user`
- `grafana_admin_password`
- `grafana_prometheus_datasource_name`
- `postgres_server_name`
- `postgres_admin_username`
- `postgres_admin_password`
- `database_usernames`
- `database_passwords`
- `services`
- `service_secrets`
- `container_apps_environment_name`
- `log_analytics_workspace_name`

## Run Terraform Locally

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Destroy dev infrastructure when it is no longer needed:

```powershell
terraform destroy
```

Be careful with `terraform destroy`: it deletes resources tracked in state, including databases and Container Apps.

## Azure Resource Providers

The AzureRM provider has automatic resource provider registration disabled:

```hcl
resource_provider_registrations = "none"
```

This is intentional because the GitHub Actions identity follows least-privilege permissions. It should manage only the commerce infrastructure it needs, not register arbitrary Azure providers at the subscription level.

The required Azure Resource Providers must already be registered in the subscription before Terraform runs. For the resources in this repository, the expected providers are:

- `Microsoft.Resources`
- `Microsoft.ContainerRegistry`
- `Microsoft.OperationalInsights`
- `Microsoft.App`
- `Microsoft.ManagedIdentity`
- `Microsoft.Authorization`
- `Microsoft.DBforPostgreSQL`

Do not broaden the GitHub Actions identity just to grant `*/register/action`. Ask a subscription owner or platform administrator to register only the required providers ahead of time.

## Import Existing Azure Resources First

Some Azure resources already exist. Import them into Terraform state before the first `terraform apply`; otherwise Terraform will try to create resources with the same names.

Replace `<SUBSCRIPTION_ID>` and placeholder names with the actual values in Azure. Run these commands from this `terraform/` directory.

```powershell
terraform import azurerm_resource_group.commerce "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-commerce-dev"

terraform import azurerm_container_registry.acr "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-commerce-dev/providers/Microsoft.ContainerRegistry/registries/acrcommerceplatformdev"

terraform import azurerm_log_analytics_workspace.container_apps "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-commerce-dev/providers/Microsoft.OperationalInsights/workspaces/<LOG_ANALYTICS_WORKSPACE_NAME>"

terraform import azurerm_container_app_environment.shared "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-commerce-dev/providers/Microsoft.App/managedEnvironments/<CONTAINER_APPS_ENVIRONMENT_NAME>"

terraform import azurerm_postgresql_flexible_server.postgres "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-commerce-dev/providers/Microsoft.DBforPostgreSQL/flexibleServers/<POSTGRES_SERVER_NAME>"
```

If the user-assigned identity or role assignment already exists, import those too:

```powershell
terraform import azurerm_user_assigned_identity.container_apps_acr_pull "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-commerce-dev/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<IDENTITY_NAME>"

terraform import azurerm_role_assignment.acr_pull "<ROLE_ASSIGNMENT_RESOURCE_ID>"
```

If logical databases already exist, import them with the service map keys:

```powershell
terraform import 'azurerm_postgresql_flexible_server_database.service_databases["product"]' "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-commerce-dev/providers/Microsoft.DBforPostgreSQL/flexibleServers/<POSTGRES_SERVER_NAME>/databases/product_db"

terraform import 'azurerm_postgresql_flexible_server_database.service_databases["order"]' "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-commerce-dev/providers/Microsoft.DBforPostgreSQL/flexibleServers/<POSTGRES_SERVER_NAME>/databases/order_db"
```

Import any existing Container Apps with their module addresses:

```powershell
terraform import 'module.container_app_services["product"].azurerm_container_app.service' "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-commerce-dev/providers/Microsoft.App/containerApps/commerce-product-service-dev"

terraform import 'module.container_app_services["order"].azurerm_container_app.service' "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-commerce-dev/providers/Microsoft.App/containerApps/commerce-order-service-dev"

terraform import 'module.container_app_services["gateway"].azurerm_container_app.service' "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-commerce-dev/providers/Microsoft.App/containerApps/commerce-api-gateway-dev"
```

Order and Gateway infrastructure may be created by Terraform if they do not already exist. If they do exist, import them before applying.

After importing, run `terraform plan` and adjust `terraform.tfvars` so configured values match the current Azure resources before applying.

## GitHub Actions Workflow

The infrastructure workflow lives at `.github/workflows/terraform.yml`.

It runs only when these paths change:

- `terraform/**`
- `.github/workflows/terraform.yml`

For pull requests to `main`, it runs:

- Checkout
- Setup Terraform
- Azure login using OIDC
- `terraform fmt -check -recursive`
- `terraform init`
- `terraform validate`
- `terraform plan`

For pushes to `main`, it runs:

- Checkout
- Setup Terraform
- Azure login using OIDC
- `terraform init`
- `terraform validate`
- `terraform plan`
- `terraform apply -auto-approve`

Required GitHub repository secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `TF_VAR_POSTGRES_ADMIN_PASSWORD`
- `GRAFANA_ADMIN_PASSWORD`

The Azure identity represented by `AZURE_CLIENT_ID` must have a federated identity credential for this repository and enough Azure RBAC permission to manage the resources in `rg-commerce-dev`.

This workflow is for infrastructure only. Service CI/CD remains responsible for testing application code, building images, pushing images to ACR, and choosing image tags. Terraform only points Container Apps at the configured image tags.

## Manual Azure Steps

- Configure Azure OIDC federation for GitHub Actions.
- Push service images to ACR before applying Container App changes.
- Import existing Azure resources into Terraform state before the first apply.
- Create separate PostgreSQL application users manually if services should not use the PostgreSQL admin account in dev.
- Review `terraform plan`; mismatched imported settings can cause Terraform to update existing infrastructure.
- Add a secure remote Terraform backend before relying on automated `apply` from GitHub Actions.
- For production, replace public PostgreSQL access with private networking, VNet integration, private DNS, and tighter firewall rules.
