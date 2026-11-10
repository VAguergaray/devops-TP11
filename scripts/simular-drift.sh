#!/bin/bash
set -euo pipefail

ENVIRONMENT="${1:-dev}"

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo "Uso: $0 [dev|prod]"
    exit 1
fi

echo "=== SIMULACIÓN DE DRIFT ==="
echo "Entorno: $ENVIRONMENT"

CONTAINER=$(docker ps \
    --filter "label=managed-by=terraform" \
    --filter "label=environment=$ENVIRONMENT" \
    --filter "name=backend" \
    --format "{{.Names}}" | head -n 1)

if [[ -z "$CONTAINER" ]]; then
    echo "[ERROR] No se encontró un backend activo de $ENVIRONMENT."
    exit 1
fi

echo "[INFO] Backend seleccionado: $CONTAINER"
echo "[INFO] Deteniendo contenedor para simular drift..."

docker stop "$CONTAINER"

echo "[OK] Drift simulado."
echo "Para restaurar el contenedor:"
echo "docker start $CONTAINER"
