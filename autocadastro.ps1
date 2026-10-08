<#
.SYNOPSIS
    Preenche automaticamente o formulario de cadastro — cliques por coordenada.
#>

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class CatAuto {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWP cb, IntPtr lp);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder b, int m);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, int x, int y, uint d, IntPtr e);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumWP(IntPtr h, IntPtr lp);
    public static IntPtr FindByTitle(string frag) {
        IntPtr r = IntPtr.Zero;
        EnumWindows(delegate(IntPtr h, IntPtr lp) {
            var b = new StringBuilder(256);
            GetWindowText(h, b, 256);
            if (IsWindowVisible(h) && b.ToString().IndexOf(frag, StringComparison.OrdinalIgnoreCase) >= 0)
                { r = h; return false; }
            return true;
        }, IntPtr.Zero);
        return r;
    }
    public static void Click(int x, int y) {
        SetCursorPos(x, y); System.Threading.Thread.Sleep(120);
        mouse_event(0x0002, 0, 0, 0, IntPtr.Zero); System.Threading.Thread.Sleep(80);
        mouse_event(0x0004, 0, 0, 0, IntPtr.Zero); System.Threading.Thread.Sleep(300);
    }
    public static RECT GetRect(IntPtr h) { RECT r; GetWindowRect(h, out r); return r; }
}
"@

Add-Type -AssemblyName System.Windows.Forms

function Log($m) { Write-Host "[AutoCadastro] $m" }

function ClickField($rect, [int]$relX, [int]$relY) {
    $ax = $rect.Left + $relX
    $ay = $rect.Top  + $relY
    [CatAuto]::Click($ax, $ay)
}

function SendText($text) {
    [System.Windows.Forms.SendKeys]::SendWait($text)
    Start-Sleep -Milliseconds 200
}

# Matar instancias
Log "Encerrando instancias..."
Get-Process | Where-Object { $_.Name -match "CatalogoExpresso|CallCatalogo" } |
    ForEach-Object { try { $_.Kill() } catch {} }
Start-Sleep -Seconds 3

# Iniciar
Log "Iniciando..."
Start-Process "C:\ProgramData\CatalogoDelphiDirectEvolution\CallCatalogoExpresso.exe"

# Aguardar janela
$hwnd = [IntPtr]::Zero
$deadline = (Get-Date).AddSeconds(30)
while ($hwnd -eq [IntPtr]::Zero -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 800
    $hwnd = [CatAuto]::FindByTitle("Direct Evolution")
}
if ($hwnd -eq [IntPtr]::Zero) { Log "Janela nao encontrada."; exit 1 }

Log "Janela encontrada. Aguardando..."
Start-Sleep -Seconds 3

[CatAuto]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

$r = [CatAuto]::GetRect($hwnd)
$W = $r.Right - $r.Left
$H = $r.Bottom - $r.Top
Log "Janela: ${W}x${H} em ($($r.Left),$($r.Top))"

# Coordenadas relativas calibradas para janela 648x473
# (ajustadas pela escala real da janela)
$sx = $W / 648.0
$sy = $H / 473.0

function F($rx, $ry) {
    ClickField $r ([int]($rx*$sx)) ([int]($ry*$sy))
}

# Estado (x=150, y=242)
Log "[Estado]"; F 150 242; SendText "SP"

# Cidade (x=350, y=242)
Log "[Cidade]"; F 350 242; SendText "Sao Paulo"

# CPF (x=155, y=269) — digitos validos apenas
Log "[CPF]"; F 155 269; SendText "76126076036"

# Nome (x=280, y=296)
Log "[Nome]"; F 280 296; SendText "Tecnico Autorizado"

# Tel DDD (x=130, y=323) — campo pequeno
Log "[Tel DDD]"; F 130 323; SendText "11"

# Tel Num (x=210, y=323)
Log "[Tel Num]"; F 210 323; SendText "00000000"

# Email (x=280, y=350)
Log "[Email]"; F 280 350; SendText "tecnico{@}oficina.com.br"

# Chave vazia — pular

# CADASTRAR (x=576, y=404)
Log "[CADASTRAR]"
Start-Sleep -Milliseconds 500
F 576 404

Start-Sleep -Seconds 3
Log "Concluido."
