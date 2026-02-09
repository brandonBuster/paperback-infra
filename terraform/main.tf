# Minimal, secure Azure infrastructure for Alpaca paper trading API
# Uses Key Vault for secrets, Managed Identity for access - no credentials in code

locals {
  name_suffix = substr(random_string.suffix.result, 0, 6)
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "main" {
  name     = "${var.resource_group_name_prefix}-${local.name_suffix}"
  location = var.resource_group_location
}

resource "azurerm_storage_account" "main" {
  name                     = "alpaca${local.name_suffix}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "functions" {
  name                  = "functions"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
  depends_on = [azurerm_storage_account.main]

}

resource "azurerm_key_vault" "main" {
  name                       = "kv-alpaca-${local.name_suffix}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
}

data "azurerm_client_config" "current" {}

# Function App with system-assigned managed identity
resource "azurerm_service_plan" "main" {
  name                = "asp-alpaca-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_name            = "Y1" # Consumption plan - minimal cost, pay per execution
  os_type             = "Linux"
}

resource "azurerm_linux_function_app" "main" {
  name                = "func-alpaca-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "AzureWebJobsStorage"            = azurerm_storage_account.main.primary_connection_string
    "ALPACA_BASE_URL"                = "https://paper-api.alpaca.markets"
    "ALPACA_API_KEY"                 = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=ALPACA-API-KEY)"
    "ALPACA_SECRET_KEY"              = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=ALPACA-SECRET-KEY)"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
    ftps_state = "Disabled"
  }
}

# Grant Function App access to Key Vault secrets
resource "azurerm_key_vault_access_policy" "function_app" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_function_app.main.identity[0].principal_id

  secret_permissions = ["Get"]
}

# Grant deploying user access to add secrets (required for initial setup)
resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete"]
}
