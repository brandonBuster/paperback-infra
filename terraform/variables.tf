variable "subscription_id" {
  type        = string
  description = "Azure subscription ID (also set via ARM_SUBSCRIPTION_ID or TF_VAR_subscription_id)"
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg-alpaca"
  description = "Prefix for resource group name (combined with random suffix)"
}

variable "resource_group_location" {
  type        = string
  default     = "eastus"
  description = "Azure region for resources"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment tag (dev, prod)"
}
