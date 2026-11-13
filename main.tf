# Del 1 i kedjan Terraform -> PowerShell

# Provider:
terraform {
    required_providers {
        local = {
            # Visar att providern är local
            source = "hashicorp/local"
            # Skyddar mot att en framtida version med ändringar bryter koden
            version = "~> 2.5"
        }
    }
}
provider "local" {}

# Variabler:
# En variabel är ett värde utifrån som kan ändras utan att jag rör resten av koden.
variable "base_dir" {
    description = "Rotmap för hela projektets testmiljö"
    type = string
    default = "./backup_demo"
}

variable "retention_count" {
    description = "Hur många backuper som ska sparas (äldre tas bort)"
    type = number
    default = 3
}

# Locals:
# En local är en intern genväg som beräknas av andra värden
locals {
    source_dir = "${var.base_dir}/source"
    backup_dir = "${var.base_dir}/backup"
}

# Resurser: 

# Testfiler som ska backas upp. local_file skapar även mappen "source" automatiskt.
resource "local_file" "sample_report" {
    filename = "${local.source_dir}/rapport.txt"
    content = "Detta är en viktig rapport som måste backas upp.\n"
}

resource "local_file" "sample_notes" {
    filename = "${local.source_dir}/anteckningar.txt"
    content = "Anteckningar från kursen Infrastruktur konfigurering.\n"
}

# local_file skapar mappen åt sin fil så att markörfil i backups/ ge mappen på köpet
resource "local_file" "backup_dir_marker" {
    filename = "${local.backup_dir}/.keep"
    content = "Backup-mapp skapad av Terraform.\n"
}


# Kopplingen till PowerShell: Terraform skriver en konfigurationsfil som backup.ps1 sedan läser
resource "local_file" "config" {
    filename ="${var.base_dir}/config.json"
     # jsonencode gör om en Terraform-struktur till korrekt JSON
    content = jsonencode({
         # abspath gör relativa sökvägar absoluta
        source_dir      = abspath(local.source_dir)
        backup_dir      = abspath(local.backup_dir)
        log_file        = abspath("${var.base_dir}/backup.log")
        retention_count = var.retention_count
    })
}

# Outputs: 

# Outputs visar information efter apply och gör att nästa steg i kedjan (PoerShell) kan hämta värdena: terraform output -raw config_path
output "config_path" {
    description = "Sökväg till konfigurationsfilen som Powershell-skriptet ska läsa"
    # local_file.config.filename är en referens (typ.namn.egenskap)
    value       = abspath(local_file.config.filename)    
}

output "source_dir" {
    description = "Mapppen som ska backas upp"
    value       = abspath(local.source_dir)
}

output "backup_dir" {
    description = "Mappen där backupen hamnar"
    value       = abspath(local.backup_dir)
}
