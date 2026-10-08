#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Setup permanente -- hosts file + portproxy + Windows Service.
    Executar UMA VEZ como Administrador (ou via instalar.bat com duplo clique).
#>

$ErrorActionPreference = 'Stop'
$AppDir = Split-Path -Parent (Resolve-Path $MyInvocation.MyCommand.Path)

Write-Host "=== Catalogo Direct Evolution -- Setup ===" -ForegroundColor Cyan

# -- Python check ---------------------------------------------------------------
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pythonCmd) { $python = $pythonCmd.Source } else { $python = $null }
if (-not $python) {
    $python3Cmd = Get-Command python3 -ErrorAction SilentlyContinue
    if ($python3Cmd) { $python = $python3Cmd.Source }
}
if (-not $python) {
    Write-Host "[!] Python 3 nao encontrado. Instale em python.org (marque 'Add to PATH')." -ForegroundColor Red
    exit 1
}
Write-Host "[+] Python: $python"

# -- pywin32 --------------------------------------------------------------------
Write-Host "[*] Instalando pywin32..."
& $python -m pip install pywin32 --quiet
if ($LASTEXITCODE -ne 0) { Write-Host "[!] pip falhou -- continuando sem pywin32 (modo scheduled task)" -ForegroundColor Yellow }

# -- Hosts file -----------------------------------------------------------------
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsLines = [System.Collections.Generic.List[string]](Get-Content $hostsPath)
$changed = $false
foreach ($entry in @("127.0.0.1 www.ideia2001.com.br", "127.0.0.1 ideia2001.com.br")) {
    $domain = ($entry -split ' ')[1]
    $exists = $hostsLines | Where-Object { $_ -match [regex]::Escape($domain) }
    if (-not $exists) {
        $hostsLines.Add($entry)
        Write-Host "[+] Hosts: $entry" -ForegroundColor Green
        $changed = $true
    } else {
        Write-Host "[=] Hosts ja tem: $domain"
    }
}
if ($changed) {
    $hostsLines | Set-Content -Path $hostsPath -Encoding UTF8
}
ipconfig /flushdns | Out-Null
Write-Host "[+] DNS cache limpo"

# -- Port proxy 80 -> 8080 -------------------------------------------------------
netsh interface portproxy delete v4tov4 listenport=80 listenaddress=127.0.0.1 2>$null | Out-Null
netsh interface portproxy add v4tov4 listenport=80 listenaddress=127.0.0.1 connectport=8080 connectaddress=127.0.0.1
Write-Host "[+] Port proxy: 127.0.0.1:80 -> 8080"

# -- Windows Service (preferred) ------------------------------------------------
$serviceScript = Join-Path $AppDir "service.py"
$serviceName   = "CatalogoExpressoBypass"

$hasPywin32 = & $python -c "import win32serviceutil; print('ok')" 2>$null
if ($hasPywin32 -eq 'ok') {
    Write-Host "[*] Instalando Windows Service..."

    $existing = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($existing) {
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        & $python $serviceScript remove 2>$null | Out-Null
        Start-Sleep -Seconds 1
    }

    & $python $serviceScript install
    & sc.exe config $serviceName start= auto | Out-Null
    Start-Service -Name $serviceName
    Write-Host "[+] Servico '$serviceName' instalado e iniciado (inicio automatico)" -ForegroundColor Green

} else {
    Write-Host "[*] pywin32 indisponivel -- usando Scheduled Task como fallback"
    $serverScript = Join-Path $AppDir "server.py"
    $action    = New-ScheduledTaskAction -Execute $python -Argument "`"$serverScript`"" -WorkingDirectory $AppDir
    $trigger   = New-ScheduledTaskTrigger -AtLogOn
    $settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 0) -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
    Unregister-ScheduledTask -TaskName $serviceName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $serviceName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
    Start-Process $python -ArgumentList "`"$serverScript`"" -WindowStyle Hidden
    Write-Host "[+] Scheduled Task '$serviceName' registrada e servidor iniciado" -ForegroundColor Green
}

# -- Verify ---------------------------------------------------------------------
Start-Sleep -Seconds 2
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:8080/" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "[+] Servidor respondendo OK na porta 8080" -ForegroundColor Green
} catch {
    Write-Host "[?] Servidor pode ainda estar inicializando. Verifique service.log" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Instalacao concluida! ===" -ForegroundColor Cyan
Write-Host "  Hosts  : www.ideia2001.com.br -> 127.0.0.1"
Write-Host "  Proxy  : :80 -> :8080"
Write-Host "  Servico: $serviceName (inicio automatico)"
Write-Host ""
Write-Host "Para desinstalar: execute desinstalar.bat com duplo clique"
