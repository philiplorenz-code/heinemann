# backend.tf – State-Verwaltung
#
# Option A (Standard): Remote Backend auf S3 / Azure Blob / GCS
# Das Terraform-Modul bleibt vollständig unverändert, keine proprietären Formate.
#
# terraform {
#   backend "s3" {
#     bucket = "mein-terraform-state"
#     key    = "semaphore-demo/terraform.tfstate"
#     region = "eu-central-1"
#   }
# }
#
# Option B: Semaphore als HTTP Backend (Pro-Feature)
# State-History direkt in der Semaphore-UI einsehbar.
#
# terraform {
#   backend "http" {
#     address        = "https://semaphore.example.com/api/terraform/xyz123"
#     username       = "semaphore-service-account"
#     password       = "token-aus-dem-key-store"
#     lock_address   = "https://semaphore.example.com/api/terraform/xyz123/lock"
#     unlock_address = "https://semaphore.example.com/api/terraform/xyz123/lock"
#   }
# }
#
# Für lokale Demo: kein Backend konfiguriert (State im Container, flüchtig)
