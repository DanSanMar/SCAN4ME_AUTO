#!/usr/bin/env bash

export TERM=xterm-256color

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
FEROX_BIN=$(command -v feroxbuster || echo "/usr/bin/feroxbuster")
WPSCAN_BIN=$(command -v wpscan || echo "/usr/bin/wpscan")

# Intentar localizar la wordlist común en orden de prioridad
for path in \
    "/home/kali/wordlists/seclists/Discovery/Web-Content/common.txt" \
    "/usr/share/seclists/Discovery/Web-Content/common.txt" \
    "/home/kali/seclists/Discovery/Web-Content/common.txt"; do
    if [ -f "$path" ]; then
        wordlist="$path"
        break
    fi
done

echo -e "🕒 INICIO DE PRE-RECONOCIMIENTO AUTOMATIZADO: $(date '+%d-%m-%Y %H:%M:%S')" > "$reporte_txt"
echo -e "🎯 OBJETIVO CRÍTICO ASIGNADO: $target\n" >> "$reporte_txt"

# ---------------------------------------------------------
# FASE 1: NMAP (DESCUBRIMIENTO RÁPIDO TCP Y UDP)
# ---------------------------------------------------------
echo "[+] scan4me -> Buscando puertos TCP abiertos..."
open_ports=$(nmap -sS -p- -n -Pn --open -T4 "$target" 2>/dev/null | grep "/tcp" | cut -d/ -f1 | xargs | tr ' ' ',')

if [ -z "$open_ports" ]; then
    echo -e "⚠️ Nmap no detectó puertos abiertos usando escaneo SYN estándar. Intentando escaneo Connect (-sT)..."
    open_ports=$(nmap -sT -p- -n -Pn --open -T4 "$target" 2>/dev/null | grep "/tcp" | cut -d/ -f1 | xargs | tr ' ' ',')
fi

open_udp_ports=""
# Si no hay puertos TCP o queremos ampliar el espectro, buscamos los UDP más comunes
if [ -z "$open_ports" ]; then
    echo -e "⚠️ No se detectaron puertos TCP abiertos. Intentando escaneo UDP rápido (--top-ports 100)..."
    open_udp_ports=$(nmap -sU --top-ports 100 -n -Pn --open -T4 "$target" 2>/dev/null | grep "/udp" | cut -d/ -f1 | xargs | tr ' ' ',')
fi

# Control crítico unificado: Si ambos están completamente vacíos, se aborta y se notifica a la IA
if [ -z "$open_ports" ] && [ -z "$open_udp_ports" ]; then
    echo -e "❌ CRÍTICO: No se encontraron puertos abiertos (TCP ni UDP) en $target. Generando reporte mínimo para la IA." >> "$reporte_txt"
    mv "$reporte_txt" "$FOLDER_EVIDENCES/pre_recon_${target}.txt"
    echo "TARGET_IP=$target" > /home/kali/autodeploy/active_lab.txt
    echo "SCAN_READY=FALLBACK" >> /home/kali/autodeploy/active_lab.txt
    exit 0
fi

# Volcar la información recolectada al reporte preliminar
[ -n "$open_ports" ] && echo -e "Puertos TCP abiertos identificados: $open_ports" >> "$reporte_txt"
[ -n "$open_udp_ports" ] && echo -e "Puertos UDP abiertos identificados: $open_udp_ports" >> "$reporte_txt"

# ---------------------------------------------------------
# FASE 2: NMAP PROFUNDO (Especializado según protocolo)
# ---------------------------------------------------------
echo -e "\n==================================================" >> "$reporte_txt"
echo -e "🔍 ANÁLISIS DE VERSIONES Y VULNERABILIDADES (NMAP)" >> "$reporte_txt"
echo -e "==================================================\n" >> "$reporte_txt"

if [ -n "$open_ports" ]; then
    echo "[+] scan4me -> Analizando versiones y scripts en puertos TCP ($open_ports)..."
    nmap -sCV -p "$open_ports" -Pn -n "$target" >> "$reporte_txt" 2>/dev/null
fi

if [ -n "$open_udp_ports" ]; then
    echo "[+] scan4me -> Analizando versiones y scripts en puertos UDP ($open_udp_ports)..."
    nmap -sCV -sU -p "$open_udp_ports" -Pn -n "$target" >> "$reporte_txt" 2>/dev/null
fi

# ---------------------------------------------------------
# FASES WEB: DETECCIÓN AMPLIADA DE PUERTOS COMUNES ALTERNATIVOS
# ---------------------------------------------------------
# Comprobamos puertos web típicos: 80, 443, 8000, 8080, 81, 3000, 5000, 8443
if echo "$open_ports" | grep -qE '\b(80|443|8000|8080|81|3000|5000|8443)\b'; then
    
    # Determinar el puerto exacto para los escaneos web inmediatos (usa el primero disponible)
    web_port=$(echo "$open_ports" | grep -oE '\b(80|443|8000|8080|81|3000|5000|8443)\b' | head -n 1)
    
    if [ "$web_port" == "443" ] || [ "$web_port" == "8443" ]; then
        url="https://$target:$web_port"
    else
        url="http://$target:$web_port"
    fi

    # ---------------------------------------------------------
    # FASE 3: WHATWEB (TECNOLOGÍAS)
    # ---------------------------------------------------------
    echo "[+] scan4me -> Identificando tecnologías web en $url (WhatWeb)..."
    echo -e "\n==================================================" >> "$reporte_txt"
    echo -e "🌐 RECONOCIMIENTO DE TECNOLOGÍAS (WHATWEB)" >> "$reporte_txt"
    echo -e "==================================================\n" >> "$reporte_txt"
    whatweb -a 1 -t 1 -v --no-errors --open-timeout=5 --read-timeout=5 "$url" >> "$reporte_txt" 2>/dev/null

    # ---------------------------------------------------------
    # FASE 4: FEROXBUSTER (FUZZING DIR CON RUTA VERIFICADA)
    # ---------------------------------------------------------
    if [ -n "$wordlist" ] && [ -x "$FEROX_BIN" ]; then
        echo "[+] scan4me -> Realizando descubrimiento de directorios con $wordlist..."
        echo -e "\n==================================================" >> "$reporte_txt"
        echo -e "📂 ESTRUCTURA DE DIRECTORIOS WEB (FEROXBUSTER)" >> "$reporte_txt"
        echo -e "==================================================\n" >> "$reporte_txt"
        $FEROX_BIN --url "$url" --wordlist "$wordlist" --extensions php,txt,xml,html --no-recursion --filter-size 0 --threads 40 --timeout 5 >> "$reporte_txt" 2>/dev/null
    else
        echo "⚠️ Alerta: Feroxbuster o la wordlist común no están disponibles para el pre-escaneo."
    fi

    # ---------------------------------------------------------
    # FASE 5: WPSCAN (SI EXISTE WORDPRESS)
    # ---------------------------------------------------------
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
# PASO CRÍTICO: MOVER REPORTE Y DEJAR EL TESTIGO PARA EL AGENTE DE IA
# -----------------------------------------------------------------
mv "$reporte_txt" "$FOLDER_EVIDENCES/pre_recon_${target}.txt"

echo "[✓] Scan4me finalizado. Despertando al Agente de IA para el análisis estratégico..."
echo "TARGET_IP=$target" > /home/kali/autodeploy/active_lab.txt
echo "SCAN_READY=TRUE" >> /home/kali/autodeploy/active_lab.txt
