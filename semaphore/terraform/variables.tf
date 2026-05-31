variable "environment" {
  description = "Deployment-Umgebung (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment muss dev, staging oder prod sein."
  }
}

variable "server_count" {
  description = "Anzahl simulierter Server"
  type        = number
  default     = 3

  validation {
    condition     = var.server_count >= 1 && var.server_count <= 10
    error_message = "server_count muss zwischen 1 und 10 liegen."
  }
}

variable "owner" {
  description = "Team oder Person die diese Umgebung besitzt"
  type        = string
  default     = "platform-team"
}
