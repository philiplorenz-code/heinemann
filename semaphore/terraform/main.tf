terraform {
  required_version = ">= 1.6"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Semaphore HTTP Backend (Pro): State direkt in Semaphore speichern.
  # Aktivieren sobald SEMAPHORE_HTTP_BACKEND=true gesetzt ist.
  #
  # backend "http" {
  #   address        = "https://semaphore.example.com/api/terraform/xyz123"
  #   username       = "semaphore-service-account"
  #   password       = "token-aus-dem-key-store"
  #   lock_address   = "https://semaphore.example.com/api/terraform/xyz123/lock"
  #   unlock_address = "https://semaphore.example.com/api/terraform/xyz123/lock"
  # }
}

# ── Zufällige Server-Namen (à la Heroku / Docker) ─────────────────────────────
resource "random_pet" "server_names" {
  count     = var.server_count
  length    = 2
  separator = "-"
  keepers = {
    environment = var.environment
  }
}

# ── Zufällige Ports pro Server ────────────────────────────────────────────────
resource "random_integer" "server_ports" {
  count = var.server_count
  min   = 8000
  max   = 9000
  keepers = {
    name = random_pet.server_names[count.index].id
  }
}

# ── Simuliertes Server-Inventory als lokale Datei ─────────────────────────────
resource "local_file" "inventory" {
  filename        = "/tmp/semaphore-tf-inventory-${var.environment}.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/inventory.tftpl", {
    environment  = var.environment
    server_names = random_pet.server_names[*].id
    server_ports = random_integer.server_ports[*].result
    owner        = var.owner
  })
}

# ── Deployment-Manifest ───────────────────────────────────────────────────────
resource "local_file" "manifest" {
  filename        = "/tmp/semaphore-tf-manifest-${var.environment}.json"
  file_permission = "0644"
  content = jsonencode({
    environment  = var.environment
    owner        = var.owner
    created_at   = timestamp()
    server_count = var.server_count
    servers = [
      for i, name in random_pet.server_names[*].id : {
        name = name
        port = random_integer.server_ports[i].result
        fqdn = "${name}.${var.environment}.example.com"
      }
    ]
  })
}
