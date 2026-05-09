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
