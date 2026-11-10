#!/bin/bash
set -uo pipefail
ERRORS=0
ok()   { echo " [OK]   $1"; }
fail() { echo " [FAIL] $1"; ERRORS=$((ERRORS+1)); }

echo "=== Verificación Terraform — TP11 ==="
echo ""
echo "--- Terraform state ---"
COUNT=$(terraform state list 2>/dev/null | wc -l)
if [ "$COUNT" -gt 0 ]; then
  ok "$COUNT recursos en el state"
else
  fail "State vacío o no inicializado"
fi

echo ""
echo "--- Redes Docker (creadas por Terraform) ---"
for net in app monitoring; do
  NAME=$(docker network ls --filter "label=managed-by=terraform" \
    --filter "label=environment=dev" \
    --format "{{.Name}}" | grep "$net" || true)
  [ -n "$NAME" ] && ok "Red $net → $NAME" || fail "Red $net no encontrada"
done

echo ""
echo "--- Volúmenes Docker ---"
for vol in postgres grafana prometheus; do
  NAME=$(docker volume ls --filter "label=managed-by=terraform" \
    --format "{{.Name}}" | grep "$vol" || true)
  [ -n "$NAME" ] && ok "Volumen $vol → $NAME" || fail "Volumen $vol no encontrado"
done

echo ""
echo "--- Contenedores ---"
for svc in postgres backend frontend; do
  NAME=$(docker ps --filter "label=managed-by=terraform" \
    --filter "status=running" \
    --format "{{.Names}}" | grep "$svc" || true)
  [ -n "$NAME" ] && ok "Contenedor $svc → running" || fail "Contenedor $svc no está running"
done

echo ""
echo "--- Outputs de Terraform ---"
APP_URL=$(terraform output -raw app_url 2>/dev/null || true)
[ -n "$APP_URL" ] && ok "app_url → $APP_URL" || fail "Output app_url no disponible"

echo ""
[ "$ERRORS" -eq 0 ] && echo "Infraestructura OK" || echo "$ERRORS recursos con problemas"
