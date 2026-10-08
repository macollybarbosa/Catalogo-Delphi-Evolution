#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Remove todas as modificações feitas pelo setup.ps1
#>

Write-Host "=== Removendo bypass do Catálogo Direct Evolution ===" -ForegroundColor Yellow

# Stop server process
Get-Process python -ErrorAction SilentlyContinue | Where-Object {
    $_.MainModule.FileName -like "*python*"
} | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "[+] Processos Python encerrados"

# Remove scheduled task
Unregister-ScheduledTask -TaskName "CatalogoExpresso-Bypass" -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "[+] Tarefa agendada removida"

# Remove port proxy
netsh interface portproxy delete v4tov4 listenport=80 listenaddress=127.0.0.1 2>$null | Out-Null
Write-Host "[+] Port proxy removido"

# Remove firewall rule
netsh advfirewall firewall delete rule name="CatalogoBypass-80" 2>$null | Out-Null

# Clean hosts file
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$lines = Get-Content $hostsPath | Where-Object { $_ -notmatch 'ideia2001\.com\.br' }
Set-Content $hostsPath $lines
Write-Host "[+] Hosts restaurado"

ipconfig /flushdns | Out-Null
Write-Host "[+] DNS cache limpo"

Write-Host "`n[+] Desinstalação completa." -ForegroundColor Green
