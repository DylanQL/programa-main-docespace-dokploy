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
