#####################################################
# providers.tf
#####################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }

  required_version = ">= 1.6.0"
}

provider "azurerm" {
  features {}
  subscription_id = "1cea4233-25fd-4df7-8355-60b5d7064bae"
}

provider "azuread" {}

#####################################################
# variables.tf (Beispielwerte können natürlich angepasst werden)
#####################################################

variable "location" {
  type    = string
  default = "westeurope"
}

variable "prefix" {
  type    = string
  default = "avd-demo"
}

#####################################################
# main.tf
#####################################################

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# Virtual Network + Subnetz für Session Hosts
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet_hosts" {
  name                 = "${var.prefix}-hosts-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

# AVD Hostpool (Pooled)
resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  name                = "${var.prefix}-hostpool"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  maximum_sessions_allowed = 20

  # optional, aber praktisch für größere Umgebungen
  friendly_name = "AVD Demo Hostpool"
  description   = "Hostpool für Demo-Umgebung (Pooled, Multi-Session)"
}

# Desktop Application Group
resource "azurerm_virtual_desktop_application_group" "dag_desktop" {
  name                = "${var.prefix}-dag-desktop"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type      = "Desktop"
  host_pool_id = azurerm_virtual_desktop_host_pool.hostpool.id

  friendly_name = "AVD Demo Desktop"
  description   = "Vollständiger Desktop für AVD-Demo"
}

# Workspace
resource "azurerm_virtual_desktop_workspace" "workspace" {
  name                = "${var.prefix}-workspace"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  friendly_name = "AVD Demo Workspace"
  description   = "Workspace für AVD-Demo"
}

# Workspace ↔ Application Group verknüpfen
resource "azurerm_virtual_desktop_workspace_application_group_association" "ws_dag_link" {
  workspace_id         = azurerm_virtual_desktop_workspace.workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.dag_desktop.id
}
