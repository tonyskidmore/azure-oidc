variable "resource_group_name" {
  type        = string
  description = "value of resource group name"
  default     = "rg-azure-github-oidc-test"
}

data "azurerm_resource_group" "example" {
  name = var.resource_group_name
}

output "tags" {
  value       = data.azurerm_resource_group.example.tags
  description = "value of tags"
}
