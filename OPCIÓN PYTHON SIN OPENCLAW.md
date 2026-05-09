## 1. El Script Orquestador (`core/main.py`)

Este script utilizará la librería `ollama` para el cerebro y `paramiko` para ejecutar comandos en el contenedor de Kali vía SSH.

Python

```
import ollama
import paramiko

# Configuración de conexión
KALI_CONFIG = {
    "host": "kali",
    "user": "root",
    "pass": "kali"
}

def execute_kali_command(command):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(KALI_CONFIG["host"], username=KALI_CONFIG["user"], password=KALI_CONFIG["pass"])
    
    stdin, stdout, stderr = ssh.exec_command(command)
    output = stdout.read().decode()
    error = stderr.read().decode()
    ssh.close()
    return output if output else error

def run_agent(prompt):
    # 1. Consultar a Ollama
    response = ollama.chat(model='kali-expert', messages=[
        {'role': 'user', 'content': prompt}
    ])
    
    cmd = response['message']['content'] # Aquí deberías usar Regex para extraer el comando
    print(f"[*] La IA sugiere ejecutar: {cmd}")
    
    # 2. Ejecutar en Kali
    result = execute_kali_command(cmd)
    print(f"[+] Resultado de Kali: {result}")
    
    # 3. Retroalimentación (Opcional: enviar el resultado de vuelta a la IA)
    # ...
```

---

## 2. Actualización de la Estructura del Proyecto

Cambiamos la carpeta `/core` para que sea un entorno de ejecución de Python:

Plaintext

```
kali-ai-lab/
├── core/
│   ├── Dockerfile         # Instalación de python, ollama-python y paramiko
│   ├── main.py            # El script que acabamos de ver
│   └── requirements.txt
├── workspace/
│   └── Dockerfile         # Ahora DEBE incluir openssh-server
└── ... (resto igual)
```

---

## 3. Ventajas de usar un Script de Python (Agente)

### A. Control de Flujo (Loops de Razonamiento)

Puedes implementar un bucle **ReAct** (Reason + Act). Si la IA intenta ejecutar un comando de `nmap` y falla porque no tiene permisos, el script captura el error, se lo devuelve a la IA, y esta puede decidir usar `sudo` o cambiar de estrategia.

### B. "Guardrails" de Seguridad

En el script de Python puedes poner una lista negra de comandos. Si la IA intenta ejecutar algo como `rm -rf /` o atacar una IP que no está en el rango permitido, el script bloquea la ejecución antes de que llegue a Kali.

### C. Formateo de Datos

Ollama te devolverá texto plano. Con Python, puedes limpiar ese texto, extraer solo el comando de Bash y guardar el output de Kali en un archivo JSON o Markdown dentro de la carpeta `/shared_data`.

---

## 4. El Dockerfile del Agente (`core/Dockerfile`)

Para que este script funcione dentro de tu `docker-compose`, su contenedor sería algo así:

Dockerfile

```
FROM python:3.11-slim
WORKDIR /app
RUN pip install ollama paramiko
COPY . .
CMD ["python", "main.py"]
```