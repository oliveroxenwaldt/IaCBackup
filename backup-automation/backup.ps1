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
    Write-Host $line
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
