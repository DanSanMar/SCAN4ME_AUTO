#!/usr/bin/env bash

export TERM=xterm-256color

# --- COMPROBACIÓN DE ROOT Y ARGUMENTOS ---
if [[ $EUID -ne 0 ]]; then
   echo "❌ Este script debe ejecutarse como root (necesario para escaneos SYN de Nmap)." 
   exit 1
fi

target=$1
subpath=$2 # Opcional: subdirectorio para WPScan (ej: /wordpress)

if [ -z "$target" ]; then
    echo "❌ Error: debes introducir la IP para empezar"
    exit 1
fi

# Las rutas deben coincidir con los volúmenes de tu Docker Compose
FOLDER_EVIDENCES="/home/kali/evidences"
reporte_txt="/tmp/recon_${target}.txt"
touch "$reporte_txt"

echo "======================================================"
echo " 🚀 SCAN4ME: PREPARANDO RECONOCIMIENTO PARA EL AGENTE IA: $target "
echo "======================================================"

# --- ENCONTRAR BINARIOS DE FORMA ROBUSTA EN TU DOCKER KALI ---
FEROX_BIN=$(command -v feroxbuster || echo "/snap/bin/feroxbuster")
WPSCAN_BIN=$(command -v wpscan || echo "/usr/local/bin/wpscan")
wordlist="/usr/share/seclists/Discovery/Web-Content/common.txt"

# Si no existe en la ruta de apt, buscamos en el home del usuario
if [ ! -f "$wordlist" ]; then
    wordlist="/home/kali/seclists/Discovery/Web-Content/common.txt"
fi

echo -e "🕒 INICIO DE PRE-RECONOCIMIENTO AUTOMATIZADO: $(date '+%d-%m-%Y %H:%M:%S')" > "$reporte_txt"
echo -e "🎯 OBJETIVO CRÍTICO ASIGNADO: $target\n" >> "$reporte_txt"

# ---------------------------------------------------------
# FASE 1: NMAP (DESCUBRIMIENTO RÁPIDO)
# ---------------------------------------------------------
echo "[+] scan4me -> Buscando puertos abiertos..."
open_ports=$(nmap -sS -p- -n -Pn --open -T4 "$target" 2>/dev/null | grep "/tcp" | cut -d/ -f1 | xargs | tr ' ' ',')

if [ -z "$open_ports" ]; then
    echo -e "⚠️ Nmap no detectó puertos abiertos usando escaneo SYN estándar. Intentando escaneo Connect (-sT)..."
    open_ports=$(nmap -sT -p- -n -Pn --open -T4 "$target" 2>/dev/null | grep "/tcp" | cut -d/ -f1 | xargs | tr ' ' ',')
fi

if [ -z "$open_ports" ]; then
    echo -e "❌ CRÍTICO: No se encontraron puertos abiertos en $target. Generando reporte mínimo para la IA." >> "$reporte_txt"
    # Aun así levantamos la alerta para que la IA decida qué hacer o use ping/udp.
    echo "TARGET_IP=$target" > /home/kali/autodeploy/active_lab.txt
    exit 0
fi

echo -e "Puertos abiertos identificados: $open_ports" >> "$reporte_txt"

# ---------------------------------------------------------
# FASE 2: NMAP PROFUNDO (Versiones y vulnerabilidades básicas)
# ---------------------------------------------------------
echo "[+] scan4me -> Ejecutando escaneo de versiones y scripts NSE contra puertos ($open_ports)..."
echo -e "\n==================================================" >> "$reporte_txt"
echo -e "🔍 ANÁLISIS DE VERSIONES Y VULNERABILIDADES (NMAP)" >> "$reporte_txt"
echo -e "==================================================\n" >> "$reporte_txt"

# Redirigimos el output de nmap directo al txt que leerá la IA
nmap -sCV -p "$open_ports" -Pn -n "$target" >> "$reporte_txt" 2>/dev/null

# Establecer URL base para las herramientas web
url="http://$target"

# Verificar si el puerto 80 u otros comunes web están abiertos antes de lanzar fuzzers pesados
if [[ "$open_ports" == *"80"* ]] || [[ "$open_ports" == *"443"* ]] || [[ "$open_ports" == *"8080"* ]]; then

    # ---------------------------------------------------------
    # FASE 3: WHATWEB (TECNOLOGÍAS)
    # ---------------------------------------------------------
    echo "[+] scan4me -> Identificando tecnologías web (WhatWeb)..."
    echo -e "\n==================================================" >> "$reporte_txt"
    echo -e "🌐 RECONOCIMIENTO DE TECNOLOGÍAS (WHATWEB)" >> "$reporte_txt"
    echo -e "==================================================\n" >> "$reporte_txt"
    whatweb -a 1 -t 1 -v --no-errors --open-timeout=5 --read-timeout=5 "$url" >> "$reporte_txt" 2>/dev/null

    # ---------------------------------------------------------
    # FASE 4: FEROXBUSTER (FUZZING DIR CORTO)
    # ---------------------------------------------------------
    if [ -f "$wordlist" ] && [ -x "$FEROX_BIN" ]; then
        echo "[+] scan4me -> Realizando descubrimiento de directorios (Feroxbuster)..."
        echo -e "\n==================================================" >> "$reporte_txt"
        echo -e "📂 ESTRUCTURA DE DIRECTORIOS WEB (FEROXBUSTER)" >> "$reporte_txt"
        echo -e "==================================================\n" >> "$reporte_txt"
        $FEROX_BIN --url "$url" --wordlist "$wordlist" --extensions php,txt,xml --no-recursion --filter-size 0 --threads 30 --timeout 5 >> "$reporte_txt" 2>/dev/null
    fi

    # ---------------------------------------------------------
    # FASE 5: WPSCAN (SI EXISTE WORDPRESS)
    # ---------------------------------------------------------
    # Un check rápido para no lanzar WPScan si no es necesario
    if grep -iq "wordpress" "$reporte_txt" || [ -n "$subpath" ]; then
        echo "[+] scan4me -> Detectado posible entorno WordPress. Lanzando WPScan..."
        echo -e "\n==================================================" >> "$reporte_txt"
        echo -e "🛠️ ESCANEO ESPECÍFICO DE WORDPRESS (WPSCAN)" >> "$reporte_txt"
        echo -e "==================================================\n" >> "$reporte_txt"
        $WPSCAN_BIN --url "$url$subpath" -e u,ap --detection-mode aggressive --force --no-update >> "$reporte_txt" 2>/dev/null
    fi
fi

echo -e "\n🏁 FINALIZACIÓN DEL RECONOCIMIENTO PREVIO: $(date '+%d-%m-%Y %H:%M:%S')" >> "$reporte_txt"

# -----------------------------------------------------------------
# PASO CRÍTICO: SEÑALIZAR EL INICIO DEL AGENTE DE IA
# -----------------------------------------------------------------
# Mover el reporte finalizado a un directorio donde la IA pueda leerlo con total certeza
mv "$reporte_txt" "$FOLDER_EVIDENCES/pre_recon_${target}.txt"

echo "[✓] Scan4me finalizado. Despertando al Agente de IA para el análisis estratégico..."
echo "TARGET_IP=$target" > /home/kali/autodeploy/active_lab.txt