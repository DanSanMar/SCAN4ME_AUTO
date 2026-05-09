Queremos un laboratorio autonomo que realice CTF y auditorias de ciberseguridad con la ayuda de IA en local.

queremos levantar el lab con ayuda de docker, para securizar al máximo el flujo de trabajo.

Queremos un script de arranque que compruebe el sistema operativo windows o linux por si hay diferencias para instalar los programas necesarios, tiene que comprobar los que ya se tienen instalados (con autoinstalación si es necesario) para levantar el compose y genere los directorios necesarios, el docker-compose.yml y los dockerfile de cada contenedor.

Queremos levantar en un contenedor de kali para realizar las auditorias, necesitamos 4 volumes: uno para las maquinas vulnerables, dockerlabs, otro para los scripts automaticos, otra para los resultados obtenidos y otra para los informes generados a partir de esos resultados por la IA local.

Desde el host anfitrión se descargarán los laboratorios y se podrán subir al volumes y se podrán añadir scripts, informes para analizar.

Necesitamos que la IA analice cada resultado obtenido y genere un informe con la información importante, busque posibles vulnerabilidades y exploits ,recomenando los siguientes pasos de la auditoria.

Los informes deben servir para documentar el proceso de auditoría o CTF con los datos obtenidos por los escaneos automatizados.
