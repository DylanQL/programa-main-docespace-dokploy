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

# ==========================================
# CEREBRO: SINCRONIZACIÓN INTELIGENTE DE PUERTOS
# ==========================================
sincronizar_puertos() {
  local servidor="$1"

  echo -e "🔄 Iniciando sincronización inteligente de puertos..."

  # 1. LA PRUEBA DE FUEGO: ¿GitHub tiene registros?
  if ! existen_registros_de_puertos_gh "$servidor"; then
    echo -e "⚠️ GitHub no reporta puertos abiertos. Procediendo a limpieza total..."
    local puertos_actuales
    puertos_actuales=$(obtener_puertos_locales_vinculados_gh)

    if [ -n "$puertos_actuales" ]; then
      detener_puertos_locales_vinculados_gh "$puertos_actuales"
    fi
  fi

  # 2. RECOPILACIÓN DE DATOS (Las dos listas)
  local puertos_docker
  puertos_docker=$(obtener_puertos_docker_del_codespace "$servidor")

  local puertos_locales
  puertos_locales=$(obtener_puertos_locales_vinculados_gh)

  echo -e "📦 Puertos que Dokploy necesita: [ $puertos_docker]"
  echo -e "💻 Puertos que Fedora ya tiene:  [ $puertos_locales]"

  # 3. IDENTIFICAR QUÉ SOBRA (Están en local, pero ya no en Docker)
  local puertos_a_cerrar=""
  for p_local in $puertos_locales; do
    # TRUCO MÁGICO: Rodeamos de espacios " $lista " para buscar la palabra exacta
    # Así evitamos que el puerto '80' coincida por error dentro de '8080'
    if [[ ! " $puertos_docker " =~ " $p_local " ]]; then
      puertos_a_cerrar="$puertos_a_cerrar $p_local"
    fi
  done

  # Si encontramos puertos obsoletos, los destruimos
  if [ -n "$puertos_a_cerrar" ]; then
    echo -e "🗑️ Se detectaron túneles obsoletos. Cerrando: [$puertos_a_cerrar ]"
    detener_puertos_locales_vinculados_gh "$puertos_a_cerrar"
  fi

  # 4. IDENTIFICAR QUÉ FALTA (Están en Docker, pero no en local)
  local puertos_a_abrir=""
  for p_docker in $puertos_docker; do
    if [[ ! " $puertos_locales " =~ " $p_docker " ]]; then
      puertos_a_abrir="$puertos_a_abrir $p_docker"
    fi
  done

  # Si encontramos puertos faltantes, los abrimos
  if [ -n "$puertos_a_abrir" ]; then
    echo -e "✨ Se detectaron túneles faltantes. Abriendo: [$puertos_a_abrir ]"
    vincular_puertos_locales_gh "$servidor" "$puertos_a_abrir"
  else
    echo -e "✅ Todo está perfectamente sincronizado. No se requieren nuevos túneles."
  fi
}

# ==========================================
# EXTRAER USUARIOS DE GITHUB VÁLIDOS (SIN ERRORES)
# ==========================================
obtener_usuarios_github_validos() {
  # 1. '2>&1' redirige los errores para poder filtrarlos.
  # 2. 'grep "✓"' deja pasar SOLO las cuentas con éxito (ignora las X).
  # 3. 'grep -i "logged in"' asegura la línea correcta.
  # 4. 'sed' extrae el nombre sin importar si dice "account" o "as".

  gh auth status 2>&1 | grep '✓' | grep -i 'logged in' | sed -E 's/.*(as|account) ([^ ]+).*/\2/' | sort -u | tr '\n' ' '
}

# ==========================================
# EXTRAER EL USUARIO ACTIVO DE GITHUB
# ==========================================
obtener_usuario_github_activo() {
  gh api user -q '.login' 2>/dev/null
}

# ==========================================
# EXTRAER TODOS LOS USUARIOS DE GITHUB (VÁLIDOS E INVÁLIDOS)
# ==========================================
obtener_todos_los_usuarios_github() {
  # 1. 2>&1: Redirige los errores para poder leerlos.
  # 2. grep -E -i '(Logged in to|Failed)': Atrapa tanto las conexiones exitosas como los tokens caídos/fallidos.
  # 3. sed -E: Extrae el nombre de usuario sin importar si la línea fue de éxito o de error.
  # 4. sort -u y tr: Ordena, elimina duplicados y lo pone en una sola línea.

  gh auth status 2>&1 | grep -E -i '(Logged in to|Failed)' | sed -E 's/.*(as|account) ([^ ]+).*/\2/' | sort -u | tr '\n' ' '
}

# ==========================================
# EXTRAER USUARIOS DE GITHUB INVÁLIDOS (TOKENS CAÍDOS)
# ==========================================
obtener_usuarios_github_invalidos() {
  # 1. '2>&1' redirige los errores para poder leerlos.
  # 2. 'grep "X Failed"' es el filtro de francotirador: solo atrapa las líneas de error.
  # 3. 'sed' extrae limpiamente el nombre del usuario, ignorando la ruta del archivo al final.
  # 4. 'sort -u' y 'tr' limpian y formatean en una sola línea horizontal.

  gh auth status 2>&1 | grep 'X Failed' | sed -E 's/.*(as|account) ([^ ]+).*/\2/' | sort -u | tr '\n' ' '
}

# ==========================================
# CAMBIAR USUARIO ACTIVO DE GITHUB
# ==========================================
cambiar_usuario_activo_github() {
  local nuevo_usuario="$1"

  # 1. Validación de seguridad: ¿Nos pasaron un nombre vacío?
  if [ -z "$nuevo_usuario" ]; then
    echo -e "❌ Error: No se proporcionó ningún nombre de usuario para el cambio."
    return 1
  fi

  echo -e "🔄 Solicitando cambio de identidad a: $nuevo_usuario..."

  # 2. Ejecutamos el comando ocultando la salida técnica (>/dev/null 2>&1)
  # El 'if' evalúa automáticamente si el comando anterior tuvo éxito (código 0) o falló
  if gh auth switch -u "$nuevo_usuario" >/dev/null 2>&1; then
    echo -e "✅ ¡Identidad cambiada! Ahora estás operando al mando de: $nuevo_usuario"
    return 0
  else
    echo -e "⚠️ Fallo en la matriz: No se pudo cambiar a '$nuevo_usuario'. ¿Estás seguro de que el token es válido?"
    return 1
  fi
}

# ==========================================
# 1. CREACIÓN DE BACKUP (SERVIDOR ORIGEN)
# ==========================================
crear_backup_dokploy() {
  local servidor_origen="$1"

  echo -e "\n📦 [FASE 1] Iniciando creación de backup en: $servidor_origen..."
  echo -e "   ⏳ Extrayendo base de datos y configuraciones de Dokploy..."
  echo -e "   ⏳ Comprimiendo volúmenes de Docker..."
  echo -e "   💾 Guardando archivo de respaldo de forma segura en el VPS..."
  echo -e "✅ Backup generado y empaquetado exitosamente."
}

# ==========================================
# 2. LIMPIEZA Y PREPARACIÓN (SERVIDOR DESTINO)
# ==========================================
preparar_sistema_dokploy() {
  local servidor_destino="$1"

  echo -e "\n🧹 [FASE 2] Preparando servidor destino: $servidor_destino..."
  echo -e "   🛑 Deteniendo servicios actuales de Dokploy..."
  echo -e "   🗑️  Purgando base de datos y configuraciones antiguas..."
  echo -e "   🧼 Limpiando volúmenes residuales..."
  echo -e "✨ El sistema ha quedado en blanco, como recién instalado."
}

# ==========================================
# 3. MIGRACIÓN Y RESTAURACIÓN (DESDE EL VPS)
# ==========================================
migrar_backup_dokploy() {
  local servidor_actual="$1"

  echo -e "\n🚀 [FASE 3] Iniciando restauración de datos en el nuevo servidor..."
  echo -e "   🌐 Conectando al VPS para descargar el último backup..."
  echo -e "   ⬇️  Transfiriendo archivo de respaldo hacia $servidor_actual..."
  echo -e "   📂 Descomprimiendo archivos en las rutas oficiales de Dokploy..."
  echo -e "   ♻️  Restaurando base de datos y levantando contenedores..."
  echo -e "🎉 ¡Migración completada! El panel está listo para usarse."
}

# ==========================================
# 0. DETENER PROCESOS (PARADA SEGURA)
# ==========================================
detener_procesos_dokploy() {
  local servidor_actual="$1"

  echo -e "\n🛑 [FASE 0] Iniciando apagado seguro en: $servidor_actual..."
  echo -e "   ⏳ Congelando bases de datos para evitar corrupción en el backup..."
  echo -e "   ⏳ Deteniendo los contenedores de las aplicaciones desplegadas..."
  echo -e "   ⏳ Apagando el panel principal de Dokploy..."
  echo -e "✅ Todos los procesos de Dokploy han sido detenidos correctamente."
}
