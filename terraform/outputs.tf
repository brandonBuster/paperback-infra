output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Resource group name"
}

output "function_app_name" {
  value       = azurerm_linux_function_app.main.name
  description = "Function App name"
}

output "function_app_url" {
  value       = "https://${azurerm_linux_function_app.main.default_hostname}"
  description = "Function App base URL"
}

output "key_vault_name" {
  value       = azurerm_key_vault.main.name
  description = "Key Vault name - add ALPACA-API-KEY and ALPACA-SECRET-KEY secrets after deploy"
}
