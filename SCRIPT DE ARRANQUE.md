El Script de Inicio se encargará de la orquestación, validación y creación de carpetas, pero leerá los Dockerfiles y el Compose de archivos físicos independientes en lugar de tenerlos embebidos en el código.

Aquí tienes la estructura de archivos final y el script de arranque optimizado.

1. Estructura de Archivos (Pre-requisito)
Crea una carpeta para el proyecto y organiza los archivos así:

Plaintext
/proyecto-lab
├── init.py                # Script de arranque multiplataforma
├── docker-compose.yml     # Orquestación de servicios
├── .env                   # Variables (Modelos, IPs, Credenciales)
├── /workspace
│   └── Dockerfile.kali    # Definición de la máquina de ataque
├── /core
│   └── Dockerfile.agent   # Definición del Orquestador (Python/IA)
├── /hermes
│   └── Dockerfile.hermes  # Agente con acceso a Internet
└── /volumes               # Se crearán automáticamente
    ├── targets, scripts, evidence, reports
2. El Docker-Compose Independiente (docker-compose.yml)
Este archivo es el mapa maestro. Fíjate en el aislamiento de redes.

YAML
services:
  # El Cerebro Local
  ollama:
    image: ollama/ollama
    container_name: ollama_brain
    volumes:
      - ./volumes/ollama_data:/root/.ollama
    networks:
      - net_admin

  # El Brazo Ejecutor
  kali:
    build:
      context: ./workspace
      dockerfile: Dockerfile.kali
    container_name: kali_lab
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    volumes:
      - ./volumes/targets:/home/kali/targets
      - ./volumes/scripts:/home/kali/scripts
      - ./volumes/evidence:/home/kali/evidence
      - ./volumes/reports:/home/kali/reports
    networks:
      - net_attack

  # El Orquestador (IA Local)
  agent:
    build:
      context: ./core
      dockerfile: Dockerfile.agent
    container_name: agent_bridge
    depends_on:
      - ollama
      - kali
    volumes:
      - ./volumes/evidence:/app/evidence:ro
      - ./volumes/reports:/app/reports
    networks:
      - net_admin
      - net_attack

  # El Investigador (Acceso a Internet)
  hermes:
    build:
      context: ./hermes
      dockerfile: Dockerfile.hermes
    container_name: hermes_cti
    volumes:
      - ./volumes/reports:/app/reports
    networks:
      - net_admin
      - net_internet

networks:
  net_admin:    # Comunicación IA <-> Orquestador
  net_attack:   # Comunicación Orquestador <-> Kali <-> Targets (Aislada)
  net_internet: # Solo para Hermes
3. El Script de Arranque Inteligente (init.py)
Este script ahora es un gestor de entorno. No escribe los archivos, sino que prepara el sistema para que docker-compose funcione.

Python
import os
import platform
import subprocess
import shutil

class LabInitializer:
    def __init__(self):
        self.os = platform.system()
        self.required_folders = [
            "volumes/targets", "volumes/scripts", 
            "volumes/evidence", "volumes/reports",
            "volumes/ollama_data"
        ]

    def check_env(self):
        print(f"[*] Detectado sistema operativo: {self.os}")
        
        # Comprobar Docker
        if shutil.which("docker") is None:
            print("[!] Docker no encontrado.")
            if self.os == "Windows":
                print("[>] Por favor, instala Docker Desktop desde la web oficial.")
            else:
                print("[>] Ejecuta: sudo apt update && sudo apt install docker.io")
            exit(1)

    def create_volumes(self):
        print("[*] Configurando volúmenes locales...")
        for folder in self.required_folders:
            os.makedirs(folder, exist_ok=True)
            print(f"  [+] Preparado: {folder}")

    def launch(self):
        print("[*] Levantando infraestructura independiente...")
        try:
            # Recomienda build para asegurar que los Dockerfiles independientes se procesen
            subprocess.run(["docker-compose", "up", "--build", "-d"], check=True)
            print("\n[SUCCESS] Laboratorio autónomo en marcha.")
            print("[INFO] Coloca tus máquinas en ./volumes/targets")
            print("[INFO] Los informes aparecerán en ./volumes/reports")
        except subprocess.CalledProcessError:
            print("[!] Error al levantar el compose. Revisa los Dockerfiles.")

if __name__ == "__main__":
    init = LabInitializer()
    init.check_env()
    init.create_volumes()
    init.launch()
4. Dockerfile de Kali Independiente (./workspace/Dockerfile.kali)
Dockerfile
FROM kalilinux/kali-rolling

# Instalación de herramientas sin interacción
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    kali-linux-headless \
    openssh-server \
    iputils-ping \
    curl \
    nmap \
    metasploit-framework \
    && apt-get clean

# Configuración SSH para el Agente
RUN mkdir /var/run/sshd
RUN echo 'root:kali' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
¿Por qué hacerlo así?
Mantenibilidad: Si quieres actualizar Kali, solo editas Dockerfile.kali sin tocar el script de Python.

Portabilidad: Puedes llevarte la carpeta /volumes a otro disco duro y el sistema seguirá funcionando.

Seguridad: Al estar separados, puedes auditar el docker-compose.yml para asegurarte de que ninguna red se "mezcle" accidentalmente.

Queremos un laboratorio autonomo que realice CTF y auditorias de ciberseguridad con la ayuda de IA en local.

queremos levantar el lab con ayuda de docker, para securizar al máximo el flujo de trabajo.

Queremos un script de arranque que compruebe el sistema operativo windows o linux por si hay diferencias para instalar los programas necesarios, tiene que comprobar los que ya se tienen instalados (con autoinstalación si es necesario) para levantar el compose y genere los directorios necesarios, el docker-compose.yml y los dockerfile de cada contenedor.

Queremos levantar en un contenedor de kali para realizar las auditorias, necesitamos 4 volumes: uno para las maquinas vulnerables, dockerlabs, otro para los scripts automaticos, otra para los resultados obtenidos y otra para los informes generados a partir de esos resultados por la IA local.

Desde el host anfitrión se descargarán los laboratorios y se podrán subir al volumes y se podrán añadir scripts, informes para analizar.

Necesitamos que la IA analice cada resultado obtenido y genere un informe con la información importante, busque posibles vulnerabilidades y exploits ,recomenando los siguientes pasos de la auditoria.

Los informes deben servir para documentar el proceso de auditoría o CTF con los datos obtenidos por los escaneos automatizados.

1. El Script de Arranque Inteligente (init.py)
Este script realizará las siguientes tareas:

Detección de OS: Identifica si es Windows o Linux.

Check de Dependencias: Verifica Docker, Docker Compose y NVIDIA Toolkit (para la IA).

Andamiaje: Crea la estructura de carpetas y los 4 volúmenes.

Generación Dinámica: Escribe el docker-compose.yml y los Dockerfiles desde el propio script para asegurar que no falte nada.

Python
import os
import platform
import subprocess
import sys

def check_dependencies():
    print("[*] Comprobando dependencias...")
    # Lista de comandos a verificar
    deps = ["docker", "docker-compose"]
    for dep in deps:
        try:
            subprocess.run([dep, "--version"], check=True, capture_output=True)
            print(f"[+] {dep} instalado.")
        except:
            print(f"[!] ERROR: {dep} no encontrado. Por favor, instálalo.")
            # Aquí podrías añadir lógica de autoinstalación con 'apt' o 'winget'
            sys.exit(1)

def create_structure():
    print("[*] Creando estructura de volúmenes y carpetas...")
    folders = [
        "targets",      # v_targets
        "scripts",      # v_scripts
        "evidence",     # v_evidence
        "reports",      # v_reports
        "core",         # Agente Orquestador
        "workspace",    # Kali Config
        "brain"         # Ollama Config
    ]
    for folder in folders:
        os.makedirs(folder, exist_ok=True)
        print(f"  - Creada: {folder}/")

def generate_dockerfile_kali():
    content = """FROM kalilinux/kali-rolling
RUN apt-get update && apt-get install -y kali-linux-headless openssh-server iputils-ping curl nmap && apt-get clean
RUN mkdir /var/run/sshd && echo 'root:kali' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]"""
    with open("workspace/Dockerfile", "w") as f:
        f.write(content)

def generate_compose():
    content = """
services:
  ollama:
    image: ollama/ollama
    container_name: ollama_brain
    volumes: ["./brain:/root/.ollama"]
    networks: ["ai_net"]

  kali:
    build: ./workspace
    container_name: kali_lab
    volumes:
      - ./targets:/home/kali/targets
      - ./scripts:/home/kali/scripts
      - ./evidence:/home/kali/evidence
      - ./reports:/home/kali/reports
    networks: ["target_net"]
    cap_add: ["NET_ADMIN", "SYS_ADMIN"]

  agent:
    build: ./core
    container_name: agent_bridge
    depends_on: [ollama, kali]
    networks: ["ai_net", "target_net"]
    env_file: .env

networks:
  ai_net:
  target_net:
"""
    with open("docker-compose.yml", "w") as f:
        f.write(content)

if __name__ == "__main__":
    print(f"--- Iniciando Lab IA en {platform.system()} ---")
    check_dependencies()
    create_structure()
    generate_dockerfile_kali()
    generate_compose()
    
    print("[+] Entorno listo. Lanzando contenedores...")
    subprocess.run(["docker-compose", "up", "-d", "--build"])
    print("[***] LAB LEVANTADO. Accede a los reportes en ./reports")
2. Organización de los 4 Volúmenes (El Corazón del Lab)
El script de arriba mapea las carpetas locales con el contenedor de Kali. Así es como interactuarás tú desde el Host Anfitrión:

./targets: Aquí arrastrarás los archivos .tar o carpetas de DockerLabs. Kali los verá en /home/kali/targets.

./scripts: Aquí pondrás tus herramientas personalizadas de automatización. La IA podrá invocarlas.

./evidence: Kali guardará aquí los .xml de Nmap o los logs de SQLmap. La IA leerá esta carpeta constantemente.

./reports: El destino final. Aquí aparecerán los .md o .pdf generados por el Agente Hermes y Ollama.

3. El Flujo de Autoinstalación (Diferencias de OS)
Para que el script sea realmente autónomo, dentro de check_dependencies() puedes diferenciar la lógica de instalación:

En Windows: El script puede llamar a winget install Docker.DockerDesktop.

En Linux: El script puede ejecutar sudo apt-get install docker-ce docker-compose-plugin.

4. Por qué esta base es sólida para la IA
Este esquema permite que el Agente de Python (el orquestador) funcione como un demonio:

Vigila la carpeta evidence/.

En cuanto aparece un archivo nuevo, lo lee.

Lo envía al contenedor ollama_brain.

Escribe la conclusión en reports/.
