terraform {
  required_version = ">= 1.5.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.71, <= 3.108.0 "
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
  backend "azurerm" {
    storage_account_name = ""
    container_name       = ""
    key                  = "sqlcluster/terraform.tfstate"
    subscription_id      = ""
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = ""
}