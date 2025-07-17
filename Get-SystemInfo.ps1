<#
.SYNOPSIS
    System Information Tool - Ferramenta para coleta de informações do sistema Windows
    
.DESCRIPTION
    Script PowerShell que coleta e exibe informações detalhadas sobre hardware, software,
    rede e armazenamento do sistema Windows. Ideal para técnicos de TI e administradores
    de sistema que precisam de relatórios rápidos e organizados.
    
.PARAMETER None
    Este script não aceita parâmetros.
    
.EXAMPLE
    .\Get-SystemInfo.ps1
    Executa o script e exibe todas as informações do sistema.
    
.NOTES
    Autor: Isaac Oolibama R. Lacerda
    Versão: 1.0
    Data: $(Get-Date -Format 'dd/MM/yyyy')
    Requer: Windows 10/11, PowerShell 5.1+
    Permissões: Administrador (recomendado)
    LinkedIn: https://www.linkedin.com/in/isaaclacerda/
    
.LINK
    https://github.com/isaaclacerda/system-info-tool
#>

# =============================================================================
# CONFIGURAÇÕES INICIAIS E FUNÇÕES AUXILIARES
# =============================================================================

# Configuração para execução automática
if ($Host.Name -eq "ConsoleHost") {
    # Se executado via duplo clique, abre uma nova janela do PowerShell
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -NoNewWindow
        exit
    }
}

# Configuração de codificação para suporte a caracteres especiais
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Função para simular loading visual ---
function Show-Loading {
    param([string[]]$Steps)
    
    foreach ($step in $Steps) {
        Write-Host $step -ForegroundColor Yellow
        Start-Sleep -Milliseconds 600
    }
}

# --- Funções de formatação e exibição ---
function Write-Header($t) {
    Write-Host "`n===== $t =====`n" -ForegroundColor Magenta
}

function Write-Field($k, $v) {
    $fmtKey = "{0,-18}:" -f $k
    Write-Host -NoNewline $fmtKey -ForegroundColor Cyan
    Write-Host " $v"
}

# =============================================================================
# SEQUÊNCIA DE LOADING VISUAL
# =============================================================================

$loadingSteps = @(
    "Carregando informações do sistema..."
    "Carregando hardware..."
    "Carregando informações de rede..."
    "Carregando discos..."
)
Show-Loading $loadingSteps

Start-Sleep -Milliseconds 500
Clear-Host

# =============================================================================
# COLETA DE DADOS DO SISTEMA OPERACIONAL
# =============================================================================

# Obtém informações básicas do sistema operacional
$o          = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$SO         = $o.Caption
$VERS       = "v$($o.Version) Build $($o.BuildNumber)"
$ARCH       = $o.OSArchitecture

# =============================================================================
# COLETA DE DADOS DO PROCESSADOR
# =============================================================================

# Obtém informações detalhadas do processador
$c          = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
$baseGHz    = [math]::Round($c.CurrentClockSpeed/1000,1)
$boostGHz   = [math]::Round($c.MaxClockSpeed/1000,1)
$CPU        = "$($c.Name.Trim()) | Cores: $($c.NumberOfCores) | Threads: $($c.NumberOfLogicalProcessors) | Base: ${baseGHz}GHz"

# =============================================================================
# COLETA DE DADOS DA MEMÓRIA RAM
# =============================================================================

# Obtém informações dos módulos de memória física
$memModules = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
$RAMGB      = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,0)
$RAM        = "$RAMGB GB"

# Determina as velocidades dos módulos de memória
$speedsList = $memModules | Select-Object -ExpandProperty Speed -Unique
$Speeds     = if ($speedsList) { ($speedsList -join ', ') + ' MHz' } else { 'N/A' }

# Determina a configuração de canais baseada no número de módulos
$Channel    = switch ($memModules.Count) {
    1 { 'Single Channel' }
    2 { 'Dual Channel' }
    4 { 'Quad Channel' }
    Default { "$($memModules.Count)-Channel" }
}

# =============================================================================
# COLETA DE DADOS DA PLACA DE VÍDEO
# =============================================================================

# Obtém informações da placa de vídeo principal
$g          = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
$GPU        = "$($g.Name) | $([math]::Round($g.AdapterRAM/1MB)) MB | Driver: $($g.DriverVersion)"

# =============================================================================
# COLETA DE DADOS DO SISTEMA E BIOS
# =============================================================================

# Obtém número de série do produto
$prod       = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
$SERIAL     = if ($prod.IdentifyingNumber) { $prod.IdentifyingNumber } else { 'N/A' }

# Obtém informações do BIOS
$b          = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
$BIOS       = "$($b.Manufacturer) v$($b.SMBIOSBIOSVersion) ($(Get-Date $b.ReleaseDate -Format 'dd/MM/yyyy'))"

# Obtém informações da placa-mãe
$mb         = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
$BOARD      = "$($mb.Manufacturer) $($mb.Product) S/N: $($mb.SerialNumber)"

# =============================================================================
# COLETA DE DADOS DE REDE (APRIMORADA)
# =============================================================================

# Obtém o adaptador de rede ativo principal
$nic = Get-CimInstance Win32_NetworkAdapter -ErrorAction SilentlyContinue |
       Where-Object { $_.NetEnabled -eq $true -and $_.PhysicalAdapter } | Select-Object -First 1

if ($nic) {
    # Obtém configuração de rede do adaptador
    $conf = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "Index=$($nic.DeviceID)" -ErrorAction SilentlyContinue
    
    # Formata endereço MAC com separadores
    $mac = $nic.MACAddress
    if ($mac) {$mac = $mac -replace "(.{2})(?!$)", '$1:'}
    else {$mac = 'N/A'}
    
    # Determina se é conexão WiFi ou Ethernet
    $isWifi = ($nic.AdapterType -match "Wireless") -or ($nic.Name -match "Wi.?Fi|802\.11|Wireless")
    $tipoCon = if ($isWifi) { "WiFi" } else { "Ethernet" }

    # Extrai informações de rede
    $ipv4     = $conf.IPAddress          | Where-Object { $_ -match "\." } | Select-Object -First 1
    $mask     = $conf.IPSubnet           | Where-Object { $_ -match "\." } | Select-Object -First 1
    $gateway  = $conf.DefaultIPGateway   | Where-Object { $_ -match "\." } | Select-Object -First 1
    $dns      = $conf.DNSServerSearchOrder | Where-Object { $_ -match "\." }

    # Formata servidores DNS
    if ($dns) {
        $dnsString = $dns -join ", "
    } else {
        $dnsString = "N/A"
    }

    $NET = "$($nic.Name) ($($nic.NetConnectionID))"
    $NETINFO = @(
        "Tipo de Conexao    : $tipoCon"
        "MAC Address        : $mac"
        "IPv4               : $ipv4"
        "Mascara            : $mask"
        "Gateway            : $gateway"
        "DNS                : $dnsString"
    ) -join "`n"
} else {
    $NET = "N/A"
    $NETINFO = "N/A"
}

# =============================================================================
# COLETA DE DADOS DE ARMAZENAMENTO
# =============================================================================

# Obtém informações de todos os discos físicos
$DISKS      = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue |
              ForEach-Object { "{0}: {1:N1} GB ({2})" -f $_.Model, ($_.Size/1GB), $_.InterfaceType }

# =============================================================================
# EXIBIÇÃO ESTILIZADA DOS RESULTADOS
# =============================================================================

Write-Header "Resumo do Sistema"
Write-Field "Sistema Operacional" $SO
Write-Field "Versao"             $VERS
Write-Field "Arquitetura"        $ARCH

Write-Header "Hardware"
Write-Field "Processador"        $CPU
Write-Field "Memoria"            "$RAM - $Channel - $Speeds"
Write-Field "GPU"                $GPU
Write-Field "Placa-Mae"          $BOARD
Write-Field "BIOS"               $BIOS
Write-Field "Serial do PC"       $SERIAL

Write-Header "Rede"
Write-Field "Rede" $NET
Write-Host $NETINFO

Write-Header "Discos"
foreach ($d in $DISKS) {
    Write-Host "  $d"
}

# =============================================================================
# FINALIZAÇÃO E PAUSA
# =============================================================================

# Pausa para manter a janela aberta e permitir leitura dos resultados
Write-Host "`nPressione qualquer tecla para sair..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 