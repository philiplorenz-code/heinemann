terraform {
  required_version = ">= 1.3"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

variable "tagging" {
  type = object({
    Application = string
    OwnerTeam   = string
    CostCenter  = string
    Environment = string
  })
  nullable = false
  validation {
    condition = alltrue([
      for value in values(var.tagging) :
      try(length(trimspace(value)) > 0, false)
    ]) && try(contains(["dev", "test", "prod"], var.tagging.Environment), false)
    error_message = "Pflichtwerte fehlen oder Environment ist unzulässig."
  }
}

resource "azurerm_resource_group" "app" {
  name     = "rg-${var.tagging.Application}-${var.tagging.Environment}"
  location = "northeurope"
  tags     = var.tagging
}
