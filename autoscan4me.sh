#!/usr/bin/env bash

export TERM=xterm-256color

# --- COLORES ---
BLANCO="\033[1;37m"
AZUL="\033[1;36m"
AMARILLO="\033[1;33m"
ROJO="\033[1;31m"
VERDE="\033[1;32m"
CYAN="\033[1;36m"
MAGENTA="\033[1;35m"
RESET="\033[0m"

# --- COMPROBACIÓN DE ROOT Y ARGUMENTOS ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${ROJO}❌ Este script debe ejecutarse con sudo.${RESET}" 
   echo -e "${AMARILLO}Ejemplo: sudo $0 10.10.10.1 /wordpress${RESET}"
   exit 1
fi

target=$1
subpath=$2 # Opcional: subdirectorio para WPScan (ej: /wordpress)

if [ -z "$target" ]; then
    echo -e "${ROJO}❌ Error: debes introducir la IP o Dominio para empezar${RESET}"
    echo -e "${BLANCO}Uso: sudo $0 <TARGET> [subdirectorio]${RESET}"
    exit 1
fi

# --- DETECCIÓN DE GESTOR DE PAQUETES ---
detectar_gestor() {
    if command -v apt &> /dev/null; then echo "apt"
    elif command -v dnf &> /dev/null; then echo "dnf"
    elif command -v pacman &> /dev/null; then echo "pacman"
    elif command -v zypper &> /dev/null; then echo "zypper"
    else echo "unknown"; fi
}
GESTOR=$(detectar_gestor)

# --- DEPENDENCIAS ---
dependencies=(nmap whatweb feroxbuster wpscan xsltproc host)

get_package_name() {
    local tool=$1
    case "$tool" in
        "xsltproc") echo "xsltproc" ;;
        "host") [[ "$GESTOR" == "apt" ]] && echo "dnsutils" || echo "bind-utils" ;;
        "feroxbuster") echo "SNAP_REQUIRED" ;;
        "wpscan") echo "GEM_REQUIRED" ;;
        *) echo "$tool" ;;
    esac
}

# --- INSTALACIÓN AUTOMÁTICA SILENCIOSA ---
install_tools() {
    local tools_to_install=("$@")
    echo -e "${AZUL}🔄 Instalando dependencias faltantes automáticamente...${RESET}"
    
    [[ "$GESTOR" == "apt" ]] && sudo apt update -y -qq
    [[ "$GESTOR" == "dnf" ]] && sudo dnf makecache -q

    for tool in "${tools_to_install[@]}"; do
        pkg=$(get_package_name "$tool")

        if [[ "$pkg" == "GEM_REQUIRED" ]]; then
            [[ "$GESTOR" == "apt" ]] && sudo apt install -y ruby-full build-essential zlib1g-dev libcurl4-openssl-dev
            [[ "$GESTOR" == "dnf" ]] && sudo dnf install -y ruby ruby-devel gcc make zlib-devel libcurl-devel
            sudo gem install wpscan -q
            continue
        fi

        if [[ "$pkg" == "SNAP_REQUIRED" ]]; then
            if ! command -v snap &> /dev/null; then
                [[ "$GESTOR" == "apt" ]] && sudo apt install -y snapd && sudo systemctl enable --now snapd.socket && sudo ln -s /var/lib/snapd/snap /snap 2>/dev/null
            fi
            sudo snap install "$tool" 2>/dev/null || sudo snap install "$tool" --classic
            export PATH=$PATH:/var/lib/snapd/snap/bin:/snap/bin
            continue
        fi

        [[ "$GESTOR" == "apt" ]] && sudo apt install -y "$pkg" -qq
        [[ "$GESTOR" == "dnf" ]] && sudo dnf install -y "$pkg" -q
    done
}

missing_tools=()
for tool in "${dependencies[@]}"; do
    if ! command -v "$tool" &> /dev/null && [ ! -f "/snap/bin/$tool" ] && [ ! -f "/var/lib/snapd/snap/bin/$tool" ]; then
        missing_tools+=("$tool")
    fi
done

if [ ${#missing_tools[@]} -gt 0 ]; then
    install_tools "${missing_tools[@]}"
fi

# --- SECLISTS (Instalación automática si no existe) ---
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
wordlist="$REAL_HOME/seclists/Discovery/Web-Content/common.txt"

if [ ! -f "$wordlist" ] && [ ! -f "/usr/share/seclists/Discovery/Web-Content/common.txt" ]; then
    echo -e "${AZUL}📥 Instalando SecLists para Fuzzing...${RESET}"
    [[ "$GESTOR" == "apt" ]] && sudo apt install -y git -qq
    sudo -u "$REAL_USER" git clone --depth 1 https://github.com/danielmiessler/SecLists "$REAL_HOME/seclists" -q
    wordlist="$REAL_HOME/seclists/Discovery/Web-Content/common.txt"
elif [ -f "/usr/share/seclists/Discovery/Web-Content/common.txt" ]; then
    wordlist="/usr/share/seclists/Discovery/Web-Content/common.txt"
fi

# --- PREPARACIÓN DEL ENTORNO ---
folder="Auditoria_${target}_$(date +%d-%m-%Y)"
mkdir -p "$folder"
reporte_txt="$folder/Auditoria_Completa_${target}.txt"

echo -e "${CYAN}======================================================${RESET}"
echo -e "${BLANCO} 🚀 INICIANDO AUDITORÍA AUTOMÁTICA: $target ${RESET}"
echo -e "${CYAN}======================================================${RESET}\n"

# --- VERIFICACIÓN DE CONEXIÓN ---
if ! ping -c 1 -W 2 -q "$target" &>/dev/null; then
    echo -e "${AMARILLO}⚠️ El objetivo no responde al ping. Se intentará escanear de todos modos (-Pn).${RESET}"
fi

# --- DEFINICIÓN DE BINARIOS ---
FEROX_BIN=$(command -v feroxbuster || echo "/snap/bin/feroxbuster")
WPSCAN_BIN=$(command -v wpscan || echo "/usr/local/bin/wpscan")

echo -e "🕒 INICIO DE AUDITORÍA: $(date '+%d-%m-%Y %H:%M:%S')" > "$reporte_txt"
echo -e "🎯 OBJETIVO: $target\n" >> "$reporte_txt"

# ---------------------------------------------------------
# FASE 1: NMAP (DESCUBRIMIENTO RÁPIDO Y LUEGO PROFUNDO)
# ---------------------------------------------------------
echo -e "${VERDE}[+] Fase 1: Escaneando puertos abiertos...${RESET}"
open_ports=$(nmap -sS -p- -n -Pn --open -T4 "$target" | grep "/tcp" | cut -d/ -f1 | xargs | tr ' ' ',')

if [ -z "$open_ports" ]; then
    echo -e "${ROJO}❌ No se encontraron puertos abiertos. Finalizando auditoría.${RESET}" | tee -a "$reporte_txt"
    exit 0
fi

echo -e "${BLANCO}Puertos descubiertos: $open_ports${RESET}" | tee -a "$reporte_txt"

echo -e "\n${VERDE}[+] Fase 2: Escaneo profundo (Versiones, Scripts y Vulnerabilidades)...${RESET}"
echo -e "==================================================" >> "$reporte_txt"
echo -e "🔍 NMAP: VERSIONES Y VULNERABILIDADES" >> "$reporte_txt"
echo -e "COMANDO: nmap -sSCV --script vuln -p $open_ports -Pn -n $target" >> "$reporte_txt"
echo -e "==================================================\n" >> "$reporte_txt"

# Guardamos también en XML por si lo necesitas luego, pero la salida va al TXT
nmap -sSCV --script vuln -p "$open_ports" -Pn -n "$target" -oA "$folder/nmap_$target" | tee -a "$reporte_txt"

# Generar URL base para las herramientas web
url="$target"
if [[ ! "$url" =~ ^https?:// ]]; then
    # Por defecto probamos con HTTP
    url="http://$url"
fi

# ---------------------------------------------------------
# FASE 3: WHATWEB (RECONOCIMIENTO WEB)
# ---------------------------------------------------------
echo -e "\n${VERDE}[+] Fase 3: Reconocimiento Web (WhatWeb)...${RESET}"
echo -e "\n==================================================" >> "$reporte_txt"
echo -e "🌐 WHATWEB RECON" >> "$reporte_txt"
echo -e "COMANDO: whatweb -a 1 -t 1 -v --no-errors $url" >> "$reporte_txt"
echo -e "==================================================\n" >> "$reporte_txt"

whatweb -a 1 -t 1 -v --no-errors --open-timeout=5 --read-timeout=5 "$url" | tee -a "$reporte_txt"

# ---------------------------------------------------------
# FASE 4: FEROXBUSTER (FUZZING DE DIRECTORIOS)
# ---------------------------------------------------------
if [ -f "$wordlist" ]; then
    echo -e "\n${VERDE}[+] Fase 4: Fuzzing de directorios (Feroxbuster)...${RESET}"
    echo -e "\n==================================================" >> "$reporte_txt"
    echo -e "📂 FEROXBUSTER (FUZZING)" >> "$reporte_txt"
    echo -e "COMANDO: feroxbuster --url $url --wordlist SecLists/... --threads 50" >> "$reporte_txt"
    echo -e "==================================================\n" >> "$reporte_txt"

    $FEROX_BIN --url "$url" --wordlist "$wordlist" --extensions bak,zip,txt,sql,old,php --no-recursion --filter-size 0 --threads 50 --timeout 5 | tee -a "$reporte_txt"
fi

# ---------------------------------------------------------
# FASE 5: WPSCAN (ESCANEO WORDPRESS)
# ---------------------------------------------------------
echo -e "\n${VERDE}[+] Fase 5: Escaneo de WordPress (WPScan)...${RESET}"
echo -e "\n==================================================" >> "$reporte_txt"
echo -e "🛠️ WPSCAN (WORDPRESS)" >> "$reporte_txt"
echo -e "COMANDO: wpscan --url $url$subpath -e u,ap --detection-mode aggressive --force" >> "$reporte_txt"
echo -e "==================================================\n" >> "$reporte_txt"

$WPSCAN_BIN --url "$url$subpath" -e u,ap --detection-mode aggressive --force --no-update | tee -a "$reporte_txt"

# ---------------------------------------------------------
# FIN DEL SCRIPT
# ---------------------------------------------------------
echo -e "\n${CYAN}======================================================${RESET}"
echo -e "${VERDE}✅ AUDITORÍA FINALIZADA CORRECTAMENTE${RESET}"
echo -e "${BLANCO}📁 Todo el reporte ha sido guardado en: ${AMARILLO}$reporte_txt${RESET}"
echo -e "${CYAN}======================================================${RESET}\n"