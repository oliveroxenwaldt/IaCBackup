terraform {
    required_providers {
        local = {
            source = "hashicorp/local"
            version = "~> 2.5"
        }
    }
}
provider "local" {}

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

locals {
    source_dir = "${var.base_dir}/source"
    backup_dir = "${var.base_dir}/backup"
}

resource "local_file" "sample_report" {
    filename = "${local.source_dir}/rapport.txt"
    content = "Detta är en viktig rapport som måste backas upp.\n"
}

resource "local_file" "sample_notes" {
    filename = "${local.source_dir}/anteckningar.txt"
    content = "Anteckningar från kursen Infrastruktur konfigurering.\n"
}

resource "local_file" "backup_dir_marker" {
    filename = "${local.backup_dir}/.keep"
    content = "Backup-mapp skapad av Terraform.\n"
}

resource "local_file" "config" {
    filename ="${var.base_dir}/config.json"
    content = jsonencode({
        source_dir      = abspath(local.source_dir)
        backup_dir      = abspath(local.backup_dir)
        log_file        = abspath("${var.base_dir}/backup.log")
        retention_count = var.retention_count
    })
}
