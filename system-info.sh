#!/bin/bash

# =============================
# SYSTEM INFORMATION TOOL - LINUX
# =============================

# Cores
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
PURPLE="\033[35m"
RESET="\033[0m"

# Converte KB para GiB ou MiB sem bc (forca LC_NUMERIC=C para evitar erros com locale)
convert_kb() {
    local kb=$1
    if (( kb >= 1048576 )); then
        LC_NUMERIC=C printf "%.1f GiB" "$(LC_NUMERIC=C awk "BEGIN {print $kb/1024/1024}")"
    else
        LC_NUMERIC=C printf "%.1f MiB" "$(LC_NUMERIC=C awk "BEGIN {print $kb/1024}")"
    fi
}

# Sistema
HOSTNAME=$(hostname)
USUARIO=$(whoami)
SISTEMA=$(grep '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
KERNEL=$(uname -r)
ARQUITETURA=$(uname -m)
UPTIME=$(uptime -p | sed 's/up //')
NUMERO_SERIE=$(sudo dmidecode -s system-serial-number 2>/dev/null || echo "Desconhecido")
SESSAO=${XDG_SESSION_TYPE:-Desconhecido}

# Pacotes
PACK_PACMAN=0
PACK_FLATPAK=0
command -v pacman &>/dev/null && PACK_PACMAN=$(pacman -Qq | wc -l)
command -v flatpak &>/dev/null && PACK_FLATPAK=$(flatpak list --app | wc -l)

# Hardware
PROCESSADOR=$(grep -m1 -i 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')
if [[ -z "$PROCESSADOR" ]]; then
    PROCESSADOR=$(lscpu | awk -F: 'tolower($1) ~ /model name|nome do modelo|modelo/ {print $2; exit}' | sed 's/^ *//')
fi
MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_AVAILABLE_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
MEM_USADA_KB=$((MEM_TOTAL_KB - MEM_AVAILABLE_KB))
MEM_TOTAL=$(convert_kb $MEM_TOTAL_KB)
MEM_USADA=$(convert_kb $MEM_USADA_KB)
SWAP_TOTAL_KB=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
SWAP_FREE_KB=$(grep SwapFree /proc/meminfo | awk '{print $2}')
SWAP_USADA_KB=$((SWAP_TOTAL_KB - SWAP_FREE_KB))
SWAP_TOTAL=$(convert_kb $SWAP_TOTAL_KB)
SWAP_USADA=$(convert_kb $SWAP_USADA_KB)

# GPU(s)
GPU_INFO=$(lspci | grep -E "VGA|3D" | cut -d: -f3- | sed 's/^ *//')

# Rede
GATEWAY=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -1)
DNS=$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
DNS=${DNS:-Desconhecido}

# Interfaces
INTERFACES=""
for IFACE in $(ls /sys/class/net); do
    STATE=$(cat /sys/class/net/$IFACE/operstate 2>/dev/null)
    IPV4=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1)
    INTERFACES+=$(printf "Interface %-8s : %-6s %s" "$IFACE" "${STATE^^}" "${IPV4:-N/A}")$'\n'
done

# Discos
DISCOS=$(lsblk -d -o NAME,SIZE,TYPE | grep disk | awk '{printf "%-8s : %s\n", $1, $2}')

# Bateria
if command -v upower &>/dev/null; then
    BATTERY_DEVICE=$(upower -e 2>/dev/null | grep BAT | head -1)
    if [[ -n "$BATTERY_DEVICE" ]]; then
        BATTERY_PERCENT=$(upower -i "$BATTERY_DEVICE" 2>/dev/null | grep percentage | awk '{print $2}')
    fi
    BATTERY_PERCENT=${BATTERY_PERCENT:-Desconhecido}
else
    BATTERY_PERCENT="Desconhecido"
fi

# Locale
LOCALE=$(locale | grep LANG= | cut -d= -f2)

# Retorna o caminho padrão de Downloads (fallback para ~/Downloads)
get_downloads_dir() {
    if command -v xdg-user-dir &>/dev/null; then
        xdg-user-dir DOWNLOAD
    else
        echo "$HOME/Downloads"
    fi
}

# Escolhe onde salvar o CSV e, se possível, abre seletor gráfico
escolher_caminho_csv() {
    local nome_padrao=$1
    echo -e "${YELLOW}Onde deseja salvar o CSV?${RESET}" >&2
    echo "1) Pasta Home" >&2
    echo "2) Pasta Downloads" >&2
    echo "3) Escolher local (abre seletor ou digite caminho completo)" >&2
    read -rp "Opcao [1/2/3]: " escolha

    case "$escolha" in
        1)
            printf "%s\n" "$HOME/$nome_padrao"
            ;;
        2)
            local downloads_dir
            downloads_dir=$(get_downloads_dir)
            mkdir -p "$downloads_dir"
            printf "%s\n" "$downloads_dir/$nome_padrao"
            ;;
        3)
            # Tenta abrir seletor gráfico disponível
            if command -v zenity &>/dev/null; then
                zenity --file-selection --save --confirm-overwrite --filename="$HOME/$nome_padrao"
            elif command -v kdialog &>/dev/null; then
                kdialog --getsavefilename "$HOME/$nome_padrao"
            else
                echo "Selecione digitando o caminho completo (ex: /caminho/para/$nome_padrao)" >&2
                read -rp "Caminho: " caminho_manual
                printf "%s\n" "$caminho_manual"
            fi
            ;;
        *)
            printf "%s\n" "$HOME/$nome_padrao"
            ;;
    esac
}

# ======== Print ========
echo -e "${YELLOW}=================================================${RESET}"
echo -e "           ${PURPLE}SYSTEM INFORMATION TOOL (LINUX${RESET})"
echo -e "${YELLOW}=================================================${RESET}\n"

echo -e "${CYAN}===== Resumo do Sistema =====${RESET}"
echo -e "Hostname             : $HOSTNAME"
echo -e "Usuario              : $USUARIO"
echo -e "Sistema              : $SISTEMA"
echo -e "Kernel               : $KERNEL"
echo -e "Arquitetura          : $ARQUITETURA"
echo -e "Tempo Ligado         : $UPTIME"
echo -e "Numero de Serie      : $NUMERO_SERIE"
echo -e "Sessao               : $SESSAO"
echo -e "Pacotes (pacman)     : $PACK_PACMAN"
echo -e "Pacotes (flatpak)    : $PACK_FLATPAK\n"

echo -e "${CYAN}===== Hardware =====${RESET}"
echo -e "Processador          : $PROCESSADOR"
echo -e "Memoria RAM          : $MEM_USADA / $MEM_TOTAL"
echo -e "Swap                 : $SWAP_USADA / $SWAP_TOTAL"
echo -e "GPU(s)               :\n$(echo "$GPU_INFO" | sed 's/^/  /')\n"

echo -e "${CYAN}===== Rede =====${RESET}"
echo -e "$INTERFACES"
echo -e "Gateway              : $GATEWAY"
echo -e "DNS                  : $DNS\n"

echo -e "${CYAN}===== Discos =====${RESET}"
echo -e "$DISCOS\n"

echo -e "${CYAN}===== Bateria =====${RESET}"
echo -e "Bateria              : $BATTERY_PERCENT\n"

echo -e "${CYAN}===== Local =====${RESET}"
echo -e "Locale               : $LOCALE\n"

echo -e "${YELLOW}==============================================${RESET}"
echo -e "              ${PURPLE}OPCOES ADICIONAIS${RESET}"
echo -e "${YELLOW}==============================================${RESET}\n"

read -rp "Deseja gerar CSV com todas as informações? (s/n): " OPC
if [[ "$OPC" =~ ^[Ss]$ ]]; then
    CSV_FILE="system_info_$(date +%Y%m%d_%H%M%S).csv"
    CSV_PATH=$(escolher_caminho_csv "$CSV_FILE")
    # Garante diretorio
    mkdir -p "$(dirname "$CSV_PATH")"
    {
        echo "Campo,Valor"
        echo "Hostname,$HOSTNAME"
        echo "Usuario,$USUARIO"
        echo "Sistema,$SISTEMA"
        echo "Kernel,$KERNEL"
        echo "Arquitetura,$ARQUITETURA"
        echo "Tempo Ligado,$UPTIME"
        echo "Numero de Serie,$NUMERO_SERIE"
        echo "Sessao,$SESSAO"
        echo "Pacotes (pacman),$PACK_PACMAN"
        echo "Pacotes (flatpak),$PACK_FLATPAK"
        echo "Processador,\"$PROCESSADOR\""
        echo "Memoria RAM,$MEM_USADA / $MEM_TOTAL"
        echo "Swap,$SWAP_USADA / $SWAP_TOTAL"
        echo "GPU(s),\"$(echo "$GPU_INFO" | tr '\n' '|' | sed 's/|$//')\""
        echo "Gateway,$GATEWAY"
        echo "DNS,\"$DNS\""
        echo "Discos,\"$(echo "$DISCOS" | tr '\n' '|' | sed 's/|$//')\""
        echo "Bateria,$BATTERY_PERCENT"
        echo "Locale,$LOCALE"
    } > "$CSV_PATH"
    echo -e "${GREEN}Arquivo CSV gerado: $CSV_PATH${RESET}"
fi
