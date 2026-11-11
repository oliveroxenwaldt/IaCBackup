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
