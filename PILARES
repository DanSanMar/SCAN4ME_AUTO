1. Determinismo en el Caos (Control de Ejecución)
Para que sea confiable, la IA no puede tener "llaves maestras" totales.

Whitelist de Comandos: El orquestador (Python) debe actuar como un filtro. Si la IA sugiere un comando destructivo o fuera de contexto (ej. rm -rf / o ataques a IPs externas), el script debe bloquearlo.

Modo "Human-in-the-Loop": Implementa un interruptor donde cada comando de la IA requiera una confirmación manual (Enter) antes de ejecutarse en Kali, permitiendo pasar a modo 100% autónomo solo cuando el flujo sea estable.

2. Aislamiento de Red Multinivel (Seguridad)
Un laboratorio de hacking es, por definición, un entorno peligroso.

Air-Gap Virtual: La red donde viven las máquinas vulnerables (target_net) no debe tener salida a internet ni acceso a tu red local (LAN).

Segregación del "Cerebro": El contenedor de Ollama debe estar en una red que solo vea al Orquestador. Si una máquina vulnerable logra un "escape de contenedor" hacia Kali, no debería poder llegar nunca a la IA ni a tus modelos de datos.

3. Trazabilidad y Auditoría de Decisiones (Transparencia)
Para que el proyecto sea abierto y útil para aprender, debes saber por qué la IA hizo lo que hizo.

Logs de Razonamiento: Guarda no solo el comando ejecutado, sino el "pensamiento" previo de la IA (el prompt de razonamiento).

Versionado de Evidencias: Cada paso de la auditoría debe generar un archivo con timestamp en v_evidence. Esto permite recrear la auditoría completa paso a paso si algo falla.

4. Modularidad "Plug & Play" (Ecosistema Abierto)
Para que sea un proyecto abierto, debe ser fácil de extender por la comunidad.

Abstracción de Modelos: No lo ates solo a Llama 3. Usa una interfaz que permita cambiar el modelo de Ollama simplemente editando el .env.

Drivers de Herramientas: Crea "recetas" para herramientas. Si alguien quiere añadir BurpSuite o ZAP, solo debería tener que añadir el Dockerfile y una pequeña guía de comandos para que la IA sepa usarlo.

5. Gestión Inteligente de Recursos (Autonomía)
La IA local consume mucha potencia (GPU/RAM), y los escaneos de red también.

Límites de Cuota (Docker Resources): Define límites estrictos de CPU y RAM en el docker-compose para que el laboratorio no congele tu máquina anfitriona durante un proceso pesado.

Auto-Sanación (Self-Healing): Si el contenedor de Kali se corrompe tras lanzar un exploit inestable, el script de Python debe ser capaz de reiniciar el servicio (docker-compose restart kali) y reanudar la tarea desde el último log en v_evidence.

Reflexión final: El pilar más importante para la autonomía es el manejo del contexto. La IA olvida rápido; asegúrate de que tu Agente Python siempre le envíe a la IA un resumen de "lo que ya sabemos" antes de pedirle el siguiente paso.
