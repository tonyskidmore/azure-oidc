terraform {

  # Azure Provider: Authenticating using a Service Principal with Open ID Connect
  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_oidc
  # azurerm
  # https://developer.hashicorp.com/terraform/language/settings/backends/azurerm

  # not using backend "azurerm" because it requires a storage account
  # but if using OIDC define it for the backend too and comment out the provider block below
  # and configure the settings for the Terraform backend
  # backend "azurerm" {
  #   resource_group_name  = "rg-azure-github-oidc-test"
  #   storage_account_name = "abcd1234"
  #   container_name       = "tfstate"
  #   key                  = "azure-oidc.tfstate"
  #   use_oidc             = true
  # }

  required_version = ">= 1.3.0, < 2"


  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  use_oidc                   = true
  features {}
}
