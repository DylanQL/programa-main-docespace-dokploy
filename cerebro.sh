#!/bin/bash

# ==========================================
# IMPORTACIÓN DE FUNCIONES
# ==========================================
# Cargamos todas las funciones desde tu archivo principal
source ./principal-script.sh

# ==========================================
# MOTOR DEL CEREBRO (Bucle de validación)
# ==========================================
iniciar_cerebro() {
  clear
  echo -e "🧠 INICIANDO CEREBRO DE ROTACIÓN Y SEGURIDAD..."
  echo -e "   El sistema revisará el estado de los usuarios cada 60 segundos.\n"

  while true; do
    echo -e "-----------------------------------------------------"
    echo -e "⏰ [$(date +'%Y-%m-%d %H:%M:%S')] Ejecutando chequeo del sistema..."
    echo -e "-----------------------------------------------------"

    # 1. Sincronizamos quién está vivo y quién se cayó en GitHub CLI
    sincronizar_registro_usuarios

    # 2. Protocolo de emergencia: Si el usuario activo cayó, lo cambia y restaura
    gestionar_caida_usuario_activo

    # 3. Protocolo de rutina: Si el usuario activo cumplió 27 horas, lo rota
    ejecutar_rotacion_por_tiempo

    echo -e "\n⏳ Chequeo finalizado. Durmiendo por 60 segundos..."
    sleep 60
  done
}

# ==========================================
# ARRANQUE
# ==========================================
iniciar_cerebro
