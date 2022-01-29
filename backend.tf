terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
    backend "azurerm" {
        resource_group_name  = "cloud-shell-storage-southcentralus"
        storage_account_name = "cs71003200121b9a285"
        container_name       = "terraform-state"
        key                  = "terraform.tfstate"
    }

}

provider "azurerm" {
  features {}
}
