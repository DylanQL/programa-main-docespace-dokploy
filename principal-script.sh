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
