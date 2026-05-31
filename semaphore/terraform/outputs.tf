output "server_names" {
  description = "Generierte Server-Namen"
  value       = random_pet.server_names[*].id
}

output "server_inventory" {
  description = "Pfad zum generierten Ansible-Inventory"
  value       = local_file.inventory.filename
}

output "manifest_path" {
  description = "Pfad zum Deployment-Manifest"
  value       = local_file.manifest.filename
}

output "environment_summary" {
  description = "Übersicht der Umgebung"
  value = {
    environment  = var.environment
    server_count = var.server_count
    servers = [
      for i, name in random_pet.server_names[*].id : {
        name = name
        port = random_integer.server_ports[i].result
      }
    ]
  }
}
