# OpenTofu example; the current upstream module does not verify Terraform compatibility.
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 5.0" }
  }
}
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}
variable "resource_id" { type = string }

module "legacy_tags" {
  source  = "claranet/tagging/azurerm"
  version = "9.0.0"
  resources_ids = { legacy_network = var.resource_id }
  behavior      = "merge"
  tags = {
    Application = "order-api"
    OwnerTeam   = "platform-orders"
    CostCenter  = "CC4711"
    Environment = "test"
  }
}
