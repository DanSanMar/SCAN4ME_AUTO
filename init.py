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
        
        # 1. Comprobar Docker
        if shutil.which("docker") is None:
            print("[!] Docker no encontrado. Instálalo antes de continuar.")
            exit(1)

        # 2. Detección de GPU (NVIDIA o AMD)
        gpu_detected = False
        
        # Check NVIDIA
        if shutil.which("nvidia-smi"):
            print("[+] GPU NVIDIA detectada (CUDA).")
            gpu_detected = True
        
        # Check AMD (Linux utiliza rocm-smi)
        elif shutil.which("rocm-smi") or self._check_amd_win():
            print("[+] GPU AMD detectada (ROCm).")
            print("[!] Nota: Asegúrate de usar la imagen ollama/ollama:rocm en el compose.")
            gpu_detected = True

        if not gpu_detected:
            print("[!] No se detectó GPU compatible. La IA funcionará en modo CPU.")

        # 3. Comprobar Archivo .env
        if not os.path.exists(".env"):
            print("[*] Creando archivo .env por defecto...")
            with open(".env", "w") as f:
                f.write("OLLAMA_MODEL=llama3\nSERPER_API_KEY=tu_clave_aqui\nKALI_ROOT_PASS=kali")
                
    def _check_amd_win(self):
        """Intenta detectar GPU AMD en Windows usando el registro o comandos de sistema"""
        if self.os == "Windows":
            try:
                output = subprocess.check_output(["wmic", "path", "win32_VideoController", "get", "name"]).decode()
                return "AMD" in output or "Radeon" in output
            except:
                return False
        return False

    def fix_permissions(self):
        if self.os != "Windows":
            print("[*] Ajustando permisos en sistemas Unix...")
            # Asegurar que el script tenga permisos sobre sus propios volúmenes
            subprocess.run(["chmod", "-R", "755", "volumes/scripts"])

    def create_volumes(self):
        print("[*] Configurando volúmenes locales...")
        for folder in self.required_folders:
            os.makedirs(folder, exist_ok=True)
        
        # Crear un archivo de ejemplo en targets si está vacío
        if not os.listdir("volumes/targets"):
            with open("volumes/targets/INSTRUCCIONES.txt", "w") as f:
                f.write("Coloca aquí tus .tar de DockerLabs")

    def launch(self):
        print("[*] Levantando infraestructura con Docker Compose...")
        try:
            # Comando moderno (docker compose) vs antiguo (docker-compose)
            cmd = ["docker", "compose"] if shutil.which("docker-compose") is None else ["docker-compose"]
            subprocess.run(cmd + ["up", "--build", "-d"], check=True)
            print("\n" + "="*40)
            print("[SUCCESS] LABORATORIO ACTIVO")
            print(f"[*] OS: {self.os}")
            print(f"[*] IA: http://localhost:11434")
            print(f"[*] SSH KALI: root@localhost -p 2222") # Si mapeas el puerto 22 al 2222
            print("="*40)
        except subprocess.CalledProcessError:
            print("[!] Error crítico al levantar el laboratorio.")

if __name__ == "__main__":
    init = LabInitializer()
    init.check_env()
    init.create_volumes()
    init.fix_permissions()
    init.launch()
