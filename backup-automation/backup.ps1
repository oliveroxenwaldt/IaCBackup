#Requires -Version 7.0
[CmdletBinding()]
param (
    [string]$ConfigPath = "./backup_demo/config.json"
)

$script:Logfile = $null
