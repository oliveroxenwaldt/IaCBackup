#Requires -Version 7.0
[CmdletBinding()]
param (
    [string]$ConfigPath = "./backup_demo/config.json"
)

$script:Logfile = $null


function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")][string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "WARN" { Write-Host $line -ForegroundColor Yellow }
        "ERROR" { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line }
    }
    
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $line
    }
}

function Get-BackupConfig {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Konfigurationsfilen hittades inte: $Path (har du kört terraform apply?)"
    }

    $config = Get-Content -Path $Path -Raw | ConvertFrom-Json
    
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

    $name = "backup_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    $path = Join-Path $BackupRoot $name
    New-Item -Path $path -ItemType Directory -Force | Out-Null
    return $path
}

function Copy-SourceFiles {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    $files = Get-ChildItem -Path $Source -File -Recurse
    if ($files.Count -eq 0) {
        throw "Inga filer att backa upp i $Source"
    }

    $copied = 0
    foreach ($file in $files) {
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
        Write-Log "Kunde inte kopiera $relative : $($_.Exception.Message)" -Level "ERROR"
        }
    }
    return $copied
}

function Test-Backup {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$BackupFolder
    )

    $allOK = $true
    foreach ($file in (Get-ChildItem -Path $Source -File -Recurse)) {
        $relative   = $file.FullName.Substring($Source.Length).TrimStart('\', '/')
        $backupFile = Join-Path $BackupFolder $relative

        if (-not (Test-Path $backupFile)) {
            Write-Log "SAKNAS i backup: $relative" Level "ERROR"
            $allOK = $false
        }
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

function Remove-OldBackups {
    param(
        [Parameter(Mandatory)][string]$BackupRoot,
        [Parameter(Mandatory)][int]$Keep
    )

    $old = Get-ChildItem -Path $BackupRoot -Directory -Filter "backup_*" |
        Sort-Object Name -Descending |
        Select-Object -Skip $Keep

    foreach ($folder in $old) {
        Remove-Item -Path $folder.FullName -Recurse -Force
        Write-Log "Tog bort gammal backup: $($folder.Name)" -Level "WARN"
    }
}

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
    exit 1
}


#$c = Get-BackupConfig -Path $ConfigPath
#New-BackupFolder -BackupRoot $c.Backup_dir
#$f = New-BackupFolder -BackupRoot $c.backup_dir
#Copy-SourceFiles -Source $c.source_dir -Destination $f
#Remove-OldBackups -BackupRoot $c.backup_dir -Keep 3