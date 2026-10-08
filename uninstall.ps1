#Requires -RunAsAdministrator

$ErrorActionPreference = 'SilentlyContinue'
$pythonCmd  = Get-Command python -ErrorAction SilentlyContinue
$python     = if ($pythonCmd) { $pythonCmd.Source } else { $null }
$AppDir     = Split-Path -Parent (Resolve-Path $MyInvocation.MyCommand.Path)
$svcName    = "CatalogoExpressoBypass"
$hostsPath  = "$env:SystemRoot\System32\drivers\etc\hosts"

Write-Host "=== Removendo Catalogo Direct Evolution Bypass ===" -ForegroundColor Yellow

# Stop & remove Windows Service
Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
if ($python) { & $python (Join-Path $AppDir "service.py") remove 2>$null | Out-Null }

# Remove Scheduled Task (fallback)
Unregister-ScheduledTask -TaskName $svcName -Confirm:$false -ErrorAction SilentlyContinue

# Kill server processes
Get-Process python -ErrorAction SilentlyContinue | ForEach-Object {
    try { $_.Kill() } catch {}
}
Write-Host "[+] Processos encerrados"

# Remove port proxy
netsh interface portproxy delete v4tov4 listenport=80 listenaddress=127.0.0.1 2>$null | Out-Null
Write-Host "[+] Port proxy removido"

# Clean hosts
(Get-Content $hostsPath) -notmatch 'ideia2001\.com\.br' | Set-Content $hostsPath
ipconfig /flushdns | Out-Null
Write-Host "[+] Hosts restaurado"

Write-Host "`n[+] Desinstalado com sucesso." -ForegroundColor Green
