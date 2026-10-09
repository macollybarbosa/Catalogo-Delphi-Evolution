#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Setup permanente -- hosts file + Windows Service.
    Executar UMA VEZ como Administrador (ou via instalar.bat com duplo clique).
#>

$ErrorActionPreference = 'Continue'
$AppDir = Split-Path -Parent (Resolve-Path $MyInvocation.MyCommand.Path)

# Log tudo para arquivo (diagnostico)
$logFile = Join-Path $AppDir "setup.log"
Start-Transcript -Path $logFile -Append -Force | Out-Null

Write-Host "=== Catalogo Direct Evolution -- Setup ===" -ForegroundColor Cyan

# -- Python check / auto-install ------------------------------------------------
function Find-Python {
    $c = Get-Command python -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $c = Get-Command python3 -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}

$python = Find-Python
if (-not $python) {
    Write-Host "[*] Python nao encontrado. Baixando e instalando Python 3.12..." -ForegroundColor Yellow
    $pyUrl  = "https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe"
    $pyInst = "$env:TEMP\python_installer_bypass.exe"
    if (Test-Path $pyInst) { Remove-Item $pyInst -Force -ErrorAction SilentlyContinue }
    Write-Host "[*] Baixando de $pyUrl ..."
    Invoke-WebRequest -Uri $pyUrl -OutFile $pyInst -UseBasicParsing
    Write-Host "[*] Instalando Python silenciosamente..."
    Start-Process $pyInst -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait
    Remove-Item $pyInst -ErrorAction SilentlyContinue
    # Recarregar PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
    $python = Find-Python
}
if (-not $python) {
    Write-Host "[!] Nao foi possivel instalar Python. Verifique a conexao e tente novamente." -ForegroundColor Red
    exit 1
}
Write-Host "[+] Python: $python"

# -- pywin32 --------------------------------------------------------------------
$hasPywin32Check = & $python -c "import win32serviceutil; print('ok')" 2>$null
if ($hasPywin32Check -ne 'ok') {
    Write-Host "[*] Instalando pywin32..."
    & $python -m pip install pywin32 --quiet
    # Rodar pos-instalacao do pywin32 (registra DLLs no sistema)
    $pywin32post = & $python -c "import sys, os; print(os.path.join(os.path.dirname(sys.executable), 'Scripts', 'pywin32_postinstall.py'))" 2>$null
    if ($pywin32post -and (Test-Path $pywin32post)) {
        Write-Host "[*] Executando pywin32_postinstall..."
        & $python $pywin32post -install 2>$null | Out-Null
    }
} else {
    Write-Host "[=] pywin32 ja instalado"
}

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

# -- Limpar portproxy antigo se existir -----------------------------------------
netsh interface portproxy delete v4tov4 listenport=80 listenaddress=127.0.0.1 2>$null | Out-Null

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
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:80/" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "[+] Servidor respondendo OK na porta 80" -ForegroundColor Green
} catch {
    Write-Host "[?] Servidor pode ainda estar inicializando. Verifique service.log" -ForegroundColor Yellow
}

# -- Autocadastro (preenchimento automatico do formulario de primeiro acesso) ---
$autocadScript = Join-Path $AppDir "autocadastro.ps1"
if (Test-Path $autocadScript) {
    Write-Host ""
    Write-Host "[*] Abrindo catalogo e preenchendo cadastro automaticamente..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$autocadScript`"" -WindowStyle Normal
    Write-Host "[+] Autocadastro iniciado em segundo plano" -ForegroundColor Green
} else {
    Write-Host "[?] autocadastro.ps1 nao encontrado -- abra o catalogo e cadastre manualmente" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Instalacao concluida! ===" -ForegroundColor Cyan
Write-Host "  Hosts  : www.ideia2001.com.br -> 127.0.0.1"
Write-Host "  Servico: $serviceName na porta 80 (inicio automatico)"
Write-Host ""
Write-Host "Para desinstalar: execute desinstalar.bat com duplo clique"
