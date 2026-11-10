#!/bin/bash
set -uo pipefail

ERRORS=0

ok() {
    echo "[OK] $1"
}

fail() {
    echo "[FAIL] $1"
    ERRORS=$((ERRORS + 1))
}

echo "======================================"
echo " TP11B - VERIFICACION TERRAFORM CI/CD"
echo "======================================"

echo ""
echo "=== Terraform ==="

if terraform fmt -check -recursive >/dev/null 2>&1; then
    ok "Formato Terraform"
else
    fail "Formato Terraform"
fi

if terraform validate >/dev/null 2>&1; then
    ok "Terraform Validate"
else
    fail "Terraform Validate"
fi

if terraform state list >/dev/null 2>&1; then
    ok "Estado Terraform accesible"
else
    fail "Estado Terraform inaccesible"
fi

echo ""
echo "=== GitHub Actions ==="

for file in \
    .github/workflows/terraform-pr.yml \
    .github/workflows/terraform-cd.yml \
    .github/workflows/terraform-drift.yml
do
    if [[ -f "$file" ]]; then
        ok "$file"
    else
        fail "$file no encontrado"
    fi
done

echo ""
echo "=== Scripts ==="

for file in scripts/simular-drift.sh scripts/verificar-terraform-cicd.sh
do
    if [[ -x "$file" ]]; then
        ok "$file ejecutable"
    else
        fail "$file no ejecutable"
    fi
done

echo ""
echo "======================================"

if [[ "$ERRORS" -eq 0 ]]; then
    echo "RESULTADO: TODAS LAS VERIFICACIONES OK"
else
    echo "RESULTADO: $ERRORS ERROR(ES)"
    exit 1
fi
