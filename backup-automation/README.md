# Backup-automation med Terraform och PowerShell

## Mål
Projektet automatiserar en enkel backup-process. Terraform skapar mappstruktur och
konfiguration, och ett PowerShell-skript tar backup, verifierar att den lyckades och
rensar gamla backuper. Målet är att visa en skriptkedja: **Terraform → PowerShell**.