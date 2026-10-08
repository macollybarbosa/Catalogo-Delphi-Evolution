#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Setup permanente do bypass para Catálogo Direct Evolution.
    Executa UMA VEZ como Administrador. O servidor (server.py) pode
    ser iniciado sem privilégios depois disso.
#>

$ErrorActionPreference = 'Stop'

Write-Host "=== Catálogo Direct Evolution - Setup do Bypass ===" -ForegroundColor Cyan

# ── 1. Hosts file ──────────────────────────────────────────────────────────────
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$entriesToAdd = @(
    "127.0.0.1 www.ideia2001.com.br",
    "127.0.0.1 ideia2001.com.br"
)

$hostsContent = Get-Content $hostsPath -Raw
foreach ($entry in $entriesToAdd) {
    if ($hostsContent -notmatch [regex]::Escape($entry.Split(' ')[1])) {
        Add-Content $hostsPath "`n$entry"
        Write-Host "[+] Hosts: $entry" -ForegroundColor Green
    } else {
        Write-Host "[=] Hosts já tem: $entry"
    }
}

# Flush DNS cache
ipconfig /flushdns | Out-Null
Write-Host "[+] DNS cache limpo"

# ── 2. Port proxy 80 -> 8080 ───────────────────────────────────────────────────
# Remove existing rule first (idempotent)
netsh interface portproxy delete v4tov4 listenport=80 listenaddress=127.0.0.1 2>$null | Out-Null
netsh interface portproxy add v4tov4 listenport=80 listenaddress=127.0.0.1 connectport=8080 connectaddress=127.0.0.1
Write-Host "[+] Port proxy: 127.0.0.1:80 -> 8080"

# Allow port 80 inbound on loopback (firewall)
try {
    netsh advfirewall firewall delete rule name="CatalogoBypass-80" 2>$null | Out-Null
    netsh advfirewall firewall add rule name="CatalogoBypass-80" protocol=TCP dir=in localport=80 action=allow | Out-Null
    Write-Host "[+] Firewall: porta 80 liberada"
} catch {}

# ── 3. Scheduled Task: auto-start server on login ─────────────────────────────
$scriptDir  = Split-Path -Parent (Resolve-Path $MyInvocation.MyCommand.Path)
$serverPath = Join-Path $scriptDir "server.py"

# Find python
$pythonCmd = (Get-Command python -ErrorAction SilentlyContinue)?.Source
if (-not $pythonCmd) {
    $pythonCmd = (Get-Command python3 -ErrorAction SilentlyContinue)?.Source
}
if (-not $pythonCmd) {
    Write-Host "[!] Python não encontrado no PATH. Instale Python 3 antes de continuar." -ForegroundColor Yellow
    $pythonCmd = "python"
}

Write-Host "[+] Python: $pythonCmd"

$taskName   = "CatalogoExpresso-Bypass"
$action     = New-ScheduledTaskAction -Execute $pythonCmd -Argument "`"$serverPath`"" -WorkingDirectory $scriptDir
$trigger    = New-ScheduledTaskTrigger -AtLogOn
$settings   = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal  = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
Write-Host "[+] Tarefa agendada: '$taskName' (inicia no login)"

# ── 4. Start server now ────────────────────────────────────────────────────────
Write-Host "`n[*] Iniciando servidor agora..."
Start-Process $pythonCmd -ArgumentList "`"$serverPath`"" -WindowStyle Hidden
Start-Sleep -Seconds 2

# Quick connectivity test
try {
    $resp = Invoke-WebRequest -Uri "http://127.0.0.1:8080/" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    Write-Host "[+] Servidor respondendo na porta 8080" -ForegroundColor Green
} catch {
    Write-Host "[?] Servidor pode ainda estar iniciando. Verifique server.log" -ForegroundColor Yellow
}

Write-Host @"

=== Setup concluído! ===
  - Hosts: www.ideia2001.com.br -> 127.0.0.1
  - Proxy: :80 -> :8080
  - Servidor: inicia automaticamente no login

Para parar/desinstalar: execute uninstall.ps1 como Admin
"@ -ForegroundColor Cyan
