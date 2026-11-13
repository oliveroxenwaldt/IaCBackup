#Requires -Version 7.0
<#
.SYNOPSIS 
    Tar backup av källmapp, verifierar den och rensar gamla backuper.
    Terraform skapar config.json, det här skriptet läser den och gör jobbet.
.PARAMETER ConfigPath
    Söjväg till config.json. Hämtas med: terraform output -raw config_path
.EXAMPLE
    ./backup.ps1 -ConfigPath (terraform output -raw config_path)
#>

[CmdletBinding()]
param (
    # Standardvärde så att skriptet går att köra utan argument
    [string]$ConfigPath = "./backup_demo/config.json"
)

# Loggfilens sökväg sätts när konfigurationen har lästs in
$script:Logfile = $null

# Funktion 1: Loggning med tidstämpel
function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        # ValidateSet stoppar felstavade nivåer direkt, till exempel, "FEL"
        [ValidateSet("INFO", "WARN", "ERROR")][string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    
    # Färgen påverkar bara skärmen, $line är ren text, så loggfilen blir läsbar.
    switch ($Level) {
        "WARN" { Write-Host $line -ForegroundColor Yellow }
        "ERROR" { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line }
    }

    # Loggar till fil först när konfigurationen är läst och sökvägen finns
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $line
    }
}

# Funktion 2: Läs och validera konfigurationen
function Get-BackupConfig {
    param([Parameter(Mandatory)][string]$Path)

    # Kontrollerar filen innan vi läser den, för ett begripligt felmeddelande
    if (-not (Test-Path $Path)) {
        throw "Konfigurationsfilen hittades inte: $Path (har du kört terraform apply?)"
    }

    # -Raw läser hela filen som en sträng, ConvertFrom-Json gör den till ett objekt
    $config = Get-Content -Path $Path -Raw | ConvertFrom-Json
    
    # Validerar att alla nycklar finns.
    $requiredKeys = @("source_dir", "backup_dir", "log_file", "retention_count")
    foreach($key in $requiredKeys) {
        if ($config.PSObject.Properties.Name -notcontains $key) {
            throw "Nykeln '$key' saknas i $Path"
        }
    }
    return $config
}

function New-BackupFolder {
    param([Parameter(Mandatory)][string]$BackupRoot)

    # Tidsstämepln gör namnet unikt och sorterbart: alfabetisk ordning = tidsordning
    $name = "backup_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    $path = Join-Path $BackupRoot $name

    # Out-Null: allt som skrivs ut i en funktion hamnar i returvärdet
    # New-Item skriver ut ett mappobjekt, och det vill vi inte ha med.
    New-Item -Path $path -ItemType Directory -Force | Out-Null
    return $path
}

# Funktion 3: Skapa tidstämplad backup-mapp
function Copy-SourceFiles {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    $files = Get-ChildItem -Path $Source -File -Recurse
    # Hellre ett tydligt fel nu än en "lykcad" backup av ingenting
    if ($files.Count -eq 0) {
        throw "Inga filer att backa upp i $Source"
    }

    $copied = 0
    foreach ($file in $files) {
        # Tar bort källsökvägen från början för att få den relativa sökvägen,
        # så att undermappar bevaras i backupen
        $relative   = $file.FullName.Substring($Source.Length).TrimStart('\', '/')
        $target     = Join-Path $Destination $relative
        $targetDir  = Split-Path $target -Parent

        if(-not (Test-Path $targetDir)) {
            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
        }

        try {
            Copy-Item -Path $file.Fullname -Destination $target -ErrorAction Stop
            Write-Log "Kopierade: $relative"
            $copied++
        }
        catch {
        # Fortsätter med nästa fil så att ett enda fel inte stoppar hela backupen    
        Write-Log "Kunde inte kopiera $relative : $($_.Exception.Message)" -Level "ERROR"
        }
    }
    return $copied
}

# Funktion 5: Verifiera backupen med filhash
function Test-Backup {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$BackupFolder
    )

    # Antar att allt är OK och sätte flaggan till false så fort något är fel
    $allOK = $true
    foreach ($file in (Get-ChildItem -Path $Source -File -Recurse)) {
        $relative   = $file.FullName.Substring($Source.Length).TrimStart('\', '/')
        $backupFile = Join-Path $BackupFolder $relative

        if (-not (Test-Path $backupFile)) {
            Write-Log "SAKNAS i backup: $relative" Level "ERROR"
            $allOK = $false
        }
        # Tre fall: filen saknas, filen finns men innehållet skiljer sig, eller allt är OK
        # Hash jämför innehållet. Det är starkare än Test-Path, som bara visar att filen finns.
        elseif ((Get-FileHash $file.FullName).Hash -ne (Get-FileHash $backupFile).Hash) {
            Write-Log "HASH STÄMMER INTE: $relative" -Level "ERROR"
            $allOK = $false
        } 
        else {
            Write-Log "Verifierad OK: $relative"
        }
    }
    return $allOK
}

# Funktion 6: Ta bort gamla backuper
function Remove-OldBackups {
    param(
        [Parameter(Mandatory)][string]$BackupRoot,
        [Parameter(Mandatory)][int]$Keep
    )

    # Hämta backupmappar, sortera nyast först, hoppa över de N första, resten är gamla 
    $old = Get-ChildItem -Path $BackupRoot -Directory -Filter "backup_*" |
        Sort-Object Name -Descending |
        Select-Object -Skip $Keep

    foreach ($folder in $old) {
        Remove-Item -Path $folder.FullName -Recurse -Force
        Write-Log "Tog bort gammal backup: $($folder.Name)" -Level "WARN"
    }
}

# Huvudprogrammet 
try {
    $config =Get-BackupConfig -Path $ConfigPath
    $script:Logfile = $config.log_file

    Write-Log "=== Backup startar ==="
    $backupFolder = New-BackupFolder -BackupRoot $config.backup_dir

    $count = Copy-SourceFiles -Source $config.source_dir -Destination $backupFolder
    Write-Log "Antal filer kopierade: $count"

    if (Test-Backup -Source $config.source_dir -BackupFolder $backupFolder) {
        Write-Log "VERIFIERING LYCKADES"
    }
    else {
        throw "Verifiering misslyckades"
    }

    Remove-OldBackups -BackupRoot $config.backup_dir -Keep $config.retention_count
    Write-Log "=== Backup klar ==="
}
catch {
    Write-Log "FEL: $($_.Exception.Message)" -Level "ERROR"
    # Exit-kod 1 talar om för omvärlden att skriptet misslyckades
    exit 1
}
