Markdown
# autoscan4me 🚀

`autoscan4me` es un script de automatización en Bash diseñado para agilizar las fases de **reconocimiento, enumeración y detección de vulnerabilidades** en auditorías de seguridad y entornos de Pentesting (CTFs, HackTheBox, Dockerlabs...). 

El script inicia de forma secuencial herramientas bajo un enfoque de "un solo comando", exportando un reporte final que facilite la interpretación rápida de resultados.

---

## ✨ Características Principales

* **🛡️ Ejecución Centralizada:** Automatiza múltiples fases secuenciales de escaneo en una sola herramienta.
* **📦 Gestión de Dependencias Inteligente:** Detecta tu gestor de paquetes (`apt`, `dnf`, `pacman` o `zypper`) e instala automáticamente las herramientas faltantes mediante repositorios nativos, `snap` o `RubyGems`.
* **📂 Descarga Automática de SecLists:** Si no encuentra un diccionario web estructurado, clona de forma automática el repositorio `SecLists` optimizando el proceso de fuzzing.
* **📊 Reporte Consolidado:** Guarda tanto los comandos ejecutados como los resultados detallados en tiempo real dentro de una estructura limpia de carpetas por fecha y objetivo.

---

## 🔍 Fases de la Auditoría

El script ejecuta de forma estructurada un flujo de auditoría profesional:

1. **Fase 1: Nmap Stealth Scan (`-sS`)** – Descubrimiento ultra-rápido de todos los puertos TCP abiertos (`-p-`).
2. **Fase 2: Nmap Deep Scan (`-sSCV --script vuln`)** – Escaneo profundo enfocado únicamente en los puertos activos descubiertos para extraer versiones de servicios y vulnerabilidades conocidas.
3. **Fase 3: WhatWeb** – Huella digital (fingerprinting) tecnológica del servicio web.
4. **Fase 4: Feroxbuster** – Fuzzing agresivo y no recursivo de directorios y archivos sensibles (`.bak`, `.zip`, `.txt`, `.sql`, `.old`, `.php`).
5. **Fase 5: WPScan** – Escaneo agresivo orientado a CMS WordPress (`-e u,ap`) para enumerar usuarios y plugins vulnerables.

---

## 🛠️ Requisitos e Instalación

El script requiere privilegios de **root** (`sudo`) para interactuar con sockets de red nativos (Nmap Stealth Scan) y gestionar paquetes del sistema.

🚀 Modo de Uso
La sintaxis del script es minimalista y directa:

Bash
sudo ./autoscan4me.sh <IP_O_DOMINIO> [subdirectorio_wordpress]
Ejemplos Prácticos
Escaneo básico a un objetivo (IP o Dominio):

Bash
sudo ./autoscan4me.sh 10.10.11.42
Escaneo especificando una ruta raíz alternativa para WordPress:

Bash
sudo ./autoscan4me.sh mi-objetivo.local /wordpress
📁 Estructura de Resultados
Cada ejecución genera una carpeta organizada de forma dinámica utilizando la IP/dominio y la fecha actual:

Plaintext
📂 Auditoria_<TARGET>_DD-MM-AAAA/
├── 📄 Auditoria_Completa_<TARGET>.txt     <-- Contiene todo el flujo e outputs consolidados
├── 📄 nmap_<TARGET>.nmap
├── 📄 nmap_<TARGET>.xml                   <-- Ideal para importar en herramientas como CherryTree
└── 📄 nmap_<TARGET>.gnmap
El archivo principal Auditoria_Completa_*.txt incluye marcas de tiempo, la orden exacta del comando utilizado y la salida nativa formateada.

⚠️ Descargo de Responsabilidad (Disclaimer)
Esta herramienta ha sido desarrollada con fines exclusivamente educativos y para la ejecución de auditorías de seguridad autorizadas. El uso de este script contra objetivos sin el debido consentimiento explícito y por escrito es ilegal. El desarrollador no se hace responsable de daños o mal uso de este software.
