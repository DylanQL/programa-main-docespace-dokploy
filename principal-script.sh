#!/bin/bash

# ==========================================
# 1. FUNCIONES DE EXTRACCIÓN DE DATOS
# ==========================================

obtener_nombre_codespace() {
  # Extrae el ID largo original (ej. ideal-journey-q9pqwg45j624x7)
  # Toma el primer resultado (.[0])
  gh codespace list --json name --jq '.[0].name'
}

obtener_display_codespace() {
  # Extrae el nombre bonito que le pusiste (ej. SERVER-C)
  # Toma el primer resultado (.[0])
  gh codespace list --json displayName --jq '.[0].displayName'
}

# ==========================================
# LATIDO DE CORAZÓN (Evita que el Codespace se apague)
# ==========================================
mantener_codespace_vivo() {
  local servidor="$1"
  local displayName="$2"
  echo -e "🛡️ [Fondo] Iniciando guardián Anti-Apagado para $displayName (Latido cada 60s)..."

  while true; do
    # Nos conectamos, hacemos un echo y salimos al instante.
    # '> /dev/null 2>&1' agarra todo el texto (y posibles errores) y los lanza al agujero negro para no ensuciar tu pantalla.
    gh codespace ssh -c "$servidor" -- echo "latido" >/dev/null 2>&1

    # Esperamos 60 segundos antes del siguiente latido
    sleep 60
  done
}

# ==========================================
# EXTRACCIÓN DE PUERTOS DE DOCKER (CODESPACE)
# ==========================================
obtener_puertos_docker_del_codespace() {
  local servidor="$1"

  # 1. Traemos la información cruda del contenedor (sin filtros complejos por SSH)
  local raw_ports
  raw_ports=$(gh codespace ssh -c "$servidor" -- "docker ps --format '{{.Ports}}'" 2>/dev/null)

  # 2. Procesamos el texto localmente (Tu lógica ganadora):
  # Filtramos la flecha '->', cortamos el número, ordenamos sin duplicados y separamos por espacios.
  echo "$raw_ports" | grep -oE '[0-9]+->' | cut -d'-' -f1 | sort -nu | tr '\n' ' '
}

# ==========================================
# EXTRACCIÓN DE PUERTOS LOCALES DE GH (TÚNELES ACTIVOS)
# ==========================================
obtener_puertos_locales_vinculados_gh() {
  # Usamos sudo para poder "ver" los túneles que fueron creados como root (ej. el puerto 80).
  sudo lsof -i -P -n 2>/dev/null | grep LISTEN | grep gh | grep '\*:' | awk '{print $9}' | cut -d':' -f2 | sort -nu | tr '\n' ' '
}

# ==========================================
# DETENER TÚNELES VINCULADOS (LIMPIEZA)
# ==========================================
detener_puertos_locales_vinculados_gh() {
  local puertos_a_cerrar="$1"

  # 1. Validación de seguridad: Si la lista está vacía, no hacemos nada.
  if [ -z "$puertos_a_cerrar" ]; then
    echo -e "ℹ️ No hay ningún túnel activo para cerrar."
    return 0
  fi

  echo -e "🛑 Iniciando el cierre de túneles locales..."

  # 2. Bucle mágico: Recorremos cada puerto
  for puerto in $puertos_a_cerrar; do
    local pid
    pid=$(sudo lsof -t -i TCP:"$puerto" -s TCP:LISTEN 2>/dev/null)

    if [ -n "$pid" ]; then
      sudo kill -9 $pid 2>/dev/null
      echo -e "   🔒 Túnel en el puerto $puerto cerrado exitosamente."
    else
      echo -e "   ⚠️ El puerto $puerto ya estaba cerrado o no se encontró el proceso."
    fi
  done

  echo -e "✅ Limpieza de puertos finalizada."
}

# ==========================================
# VERIFICACIÓN BOOLEANA: ¿HAY PUERTOS REGISTRADOS EN GH?
# ==========================================
existen_registros_de_puertos_gh() {
  local servidor="$1"
  local salida_puertos

  # Ejecutamos el comando y guardamos el resultado, mandando los errores al agujero negro
  salida_puertos=$(gh codespace ports -c "$servidor" 2>/dev/null)

  # La bandera -z verifica si la variable está completamente vacía (Zero length)
  if [ -z "$salida_puertos" ]; then
    return 1 # FALSE: No hay lista, está vacío
  else
    return 0 # TRUE: La lista tiene al menos un elemento (texto)
  fi
}

# ==========================================
# VINCULAR PUERTOS AL CODESPACE (CREAR TÚNELES)
# ==========================================
vincular_puertos_locales_gh() {
  local servidor="$1"
  local puertos_a_vincular="$2"

  # 1. Validación de seguridad: Si la lista está vacía, no hacemos nada.
  if [ -z "$puertos_a_vincular" ]; then
    return 0
  fi

  echo -e "🚀 Iniciando la vinculación de nuevos puertos..."

  # 2. Bucle mágico: Recorremos cada puerto de la lista
  for puerto in $puertos_a_vincular; do
    echo -e "   🔗 Levantando túnel para el puerto $puerto..."

    # Usamos sudo -E para poder abrir puertos como el 80 sin perder la auth de GitHub
    sudo -E gh codespace ports forward "${puerto}:${puerto}" -c "$servidor" >/dev/null 2>&1 &
  done

  # Le damos un respiro de 1 segundo a la red para asimilar los túneles
  sleep 1
  echo -e "✅ Nuevos túneles establecidos en segundo plano."
}
