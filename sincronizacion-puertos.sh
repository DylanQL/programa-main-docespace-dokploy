#!/bin/bash

# ==========================================
# IMPORTACIÓN DE FUNCIONES
# ==========================================
# Esto carga en memoria todas las funciones de extracción, migración y Docker
source ./principal-script.sh

# ==========================================
# EL GUARDIÁN (Seguridad Anti-Zombies)
# ==========================================
limpiar_entorno() {
  echo -e "\n🛑 [Alerta] Apagando el sistema y limpiando memoria..."

  # 1. Vemos qué puertos quedaron abiertos y los cerramos
  local puertos_abiertos
  puertos_abiertos=$(obtener_puertos_locales_vinculados_gh)
  if [ -n "$puertos_abiertos" ]; then
    detener_puertos_locales_vinculados_gh "$puertos_abiertos"
  fi

  # 2. Matamos los procesos de fondo (como el latido)
  kill $(jobs -p) 2>/dev/null

  echo -e "👋 ¡Hasta pronto! Entorno limpio."
  exit 0
}

# ==========================================
# MOTOR PRINCIPAL (El corazón del script)
# ==========================================
main() {
  clear
  echo -e "🚀 INICIANDO GESTOR AUTOMÁTICO DE DOKPLOY..."

  # 1. Instalamos la trampa: Si presionas Ctrl+C, ejecuta la limpieza
  trap limpiar_entorno SIGINT SIGTERM

  # 2. Obtenemos los nombres UNA SOLA VEZ para no saturar a GitHub
  echo -e "⏳ Buscando tu servidor Codespace..."

  local mi_servidor=$(obtener_nombre_codespace)

  if [ -z "$mi_servidor" ]; then
    echo -e "❌ Error: No se encontró ningún Codespace activo."
    exit 1
  fi

  echo -e "✅ Conectado a mi servidor: $mi_servidor"

  # 3. Lanzamos el Latido al fondo (con &)
  mantener_codespace_vivo &

  # 4. El Bucle Infinito Controlado
  echo -e "🔄 Iniciando el radar de sincronización continua...\n"
  while true; do
    # Ejecutamos la sincronización SIN el '&'. Queremos que termine antes de repetir.
    sincronizar_puertos "$(obtener_nombre_codespace)"

    # LA REGLA DE ORO: Descansamos 15 segundos antes del siguiente escaneo
    # Así no consumimos CPU y le damos tiempo a los contenedores de arrancar
    sleep 15
  done
}

# ==========================================
# ARRANQUE DEL PROGRAMA
# ==========================================
main
