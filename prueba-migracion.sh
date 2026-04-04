#!/bin/bash

# 1. Cargar todas las funciones que creamos
# Reemplaza 'principal-script.sh' por el nombre real de tu archivo si es diferente
source ./principal-script.sh

echo -e "🧪 INICIANDO SIMULACRO DE ROTACIÓN MANUAL..."

# ---------------------------------------------------------
# FASE 1: ESTABLECER EL ESTADO INICIAL
# ---------------------------------------------------------
echo -e "\n--- CONFIGURANDO ESTADO INICIAL ---"
# Forzamos empezar con brayanbautista113
gh auth switch -u "brayanbautista113" >/dev/null 2>&1
echo "✅ Usuario activo fijado: $(obtener_usuario_github_activo)"

# Obtenemos el nombre del Codespace de Brayan
servidor_actual=$(obtener_nombre_codespace)
nuevo_candidato="carloscampos817"

echo "🖥️  Servidor de origen (Brayan): $servidor_actual"
echo "👤 Candidato de destino: $nuevo_candidato"

# ---------------------------------------------------------
# FASE 2: EXTRACCIÓN (BACKUP DEL ORIGEN)
# ---------------------------------------------------------
echo -e "\n--- PASO 1: BACKUP DEL ORIGEN ---"
preparar_vincular_vps "$servidor_actual"
crear_backup_dokploy "$servidor_actual"

# ---------------------------------------------------------
# FASE 3: SALTO DE CUENTA
# ---------------------------------------------------------
echo -e "\n--- PASO 2: CAMBIO DE IDENTIDAD ---"
cambiar_usuario_activo_github "$nuevo_candidato"
echo "✅ Usuario activo ahora es: $(obtener_usuario_github_activo)"

# Obtenemos el nombre del Codespace de Carlos (asumiendo que ya está creado y corriendo)
nuevo_servidor=$(obtener_nombre_codespace)
echo "🖥️  Nuevo servidor destino (Carlos): $nuevo_servidor"

# ---------------------------------------------------------
# FASE 4: RESTAURACIÓN (MIGRACIÓN EN DESTINO)
# ---------------------------------------------------------
echo -e "\n--- PASO 3: PREPARACIÓN Y MIGRACIÓN ---"
preparar_vincular_vps "$nuevo_servidor"
preparar_sistema_dokploy "$nuevo_servidor"
migrar_backup_dokploy "$nuevo_servidor"

echo -e "\n🎉 SIMULACRO FINALIZADO CON ÉXITO."
