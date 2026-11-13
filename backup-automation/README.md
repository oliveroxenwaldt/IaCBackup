# Backup-automation med Terraform och PowerShell

## Mål
Projektet automatiserar en enkel backup-process. Terraform skapar mappstruktur och
konfiguration, och ett PowerShell-skript tar backup, verifierar att den lyckades och
rensar gamla backuper. Målet är att visa en skriptkedja: **Terraform → PowerShell**.

## Metod
- **Terraform** (local-provider): skapar källmapp med testfiler, backup-mapp och `config.json`.
- **PowerShell 7**: läser `config.json`, kopierar filer, verifierar med filhash, loggar och rensar.
- **Git/GitHub**: versionshantering.
- **WSL2/Windows**: jag körde i Windows

## Installation och körning
```powershell
terraform init
terraform apply
./backup.ps1 -ConfigPath (terraform output -raw config_path)
```
## Resultat
[Resultat](Resultat.png)

## Reflektion
Jag tyckte att det gick relativt bra, PowerShell blir ganska simeplt när man har börjat förstå the basics. 
Terraform är även väldigt nybörjarvänligt och man förstår de lite enklare konfigarationerna vi gör nu. 
Det svåra tycker jag har varit att lära sig skriva PowerShel koden, man vet inte riktigt dom små delarna som bygger upp en funktion. Men VsCode/AI hjäpler en att komma igång och förstå vad som krävs för att kunna bygga upp en funktion.


## GitHub
[Repo](https://github.com/oliveroxenwaldt/IaCBackup/tree/main/backup-automation)
