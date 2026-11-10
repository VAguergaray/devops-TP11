#!/bin/bash
# TP11 - Operaciones 1 - Terraform + Docker (version corregida)
# Uso:  bash tp11-setup.sh      (crea todo el proyecto en ~/devops-TP11)
set -euo pipefail

mkdir -p ~/devops-TP11/{modules/{network,storage,app},envs/{dev,prod},scripts}
cd ~/devops-TP11

# ── providers.tf ─────────────────────────────────────────
cat > providers.tf << 'EOF'
# ============================================
# providers.tf — Configuración del provider
# TP11 — Plan DevOps Operaciones1
# ============================================
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }

  # En producción el state va en S3, GCS o Terraform Cloud
  # Para este ejercicio usamos local
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "docker" {
  # Conecta al Docker daemon local via socket
  host = "unix:///var/run/docker.sock"
}
EOF

# ── variables.tf ─────────────────────────────────────────
cat > variables.tf << 'EOF'
# ============================================
# variables.tf — Declaración de variables
# ============================================
variable "environment" {
  description = "Entorno de deployment (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "El entorno debe ser dev, staging o prod."
  }
}

variable "project_name" {
  description = "Nombre del proyecto (prefijo para todos los recursos)"
  type        = string
  default     = "devops-portfolio"
}

# ── Base de datos ─────────────────────────────────────────
variable "postgres_image" {
  description = "Imagen de Postgres"
  type        = string
  default     = "postgres:16-alpine"
}

variable "postgres_password" {
  description = "Contraseña de Postgres"
  type        = string
  sensitive   = true # no se muestra en logs ni en plan
  default     = "devops123"
}

variable "postgres_db" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "notesdb"
}

# ── Backend ───────────────────────────────────────────────
variable "backend_image" {
  description = "Imagen del backend"
  type        = string
  default     = "python:3.12-slim"
}

variable "backend_port" {
  description = "Puerto del backend"
  type        = number
  default     = 5000
}

variable "backend_replicas" {
  description = "Número de contenedores del backend"
  type        = number
  default     = 1
  validation {
    condition     = var.backend_replicas >= 1 && var.backend_replicas <= 5
    error_message = "Las réplicas deben estar entre 1 y 5."
  }
}

# ── Frontend ──────────────────────────────────────────────
variable "frontend_image" {
  description = "Imagen del frontend Nginx"
  type        = string
  default     = "nginx:alpine"
}

variable "frontend_port" {
  description = "Puerto expuesto del frontend en el host"
  type        = number
  default     = 8080
}

# ── Networking ────────────────────────────────────────────
variable "network_subnet" {
  description = "Subnet de la red principal de la app"
  type        = string
  default     = "172.20.0.0/16"
}

variable "monitoring_subnet" {
  description = "Subnet de la red de monitoreo"
  type        = string
  default     = "172.21.0.0/16"
}
EOF

# ── Módulo network ───────────────────────────────────────
cat > modules/network/main.tf << 'EOF'
# modules/network/main.tf — Redes Docker del proyecto
resource "docker_network" "app_network" {
  name   = "${var.project_name}-app-${var.environment}"
  driver = "bridge"

  ipam_config {
    subnet  = var.app_subnet
    gateway = cidrhost(var.app_subnet, 1)
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "environment"
    value = var.environment
  }
  labels {
    label = "managed-by"
    value = "terraform"
  }
}

resource "docker_network" "monitoring_network" {
  name   = "${var.project_name}-monitoring-${var.environment}"
  driver = "bridge"

  ipam_config {
    subnet  = var.monitoring_subnet
    gateway = cidrhost(var.monitoring_subnet, 1)
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "environment"
    value = var.environment
  }
  # CORREGIDO: faltaba este label y verificar.sh lo filtra por managed-by
  labels {
    label = "managed-by"
    value = "terraform"
  }
}
EOF

cat > modules/network/variables.tf << 'EOF'
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "app_subnet" {
  type    = string
  default = "172.20.0.0/16"
}

variable "monitoring_subnet" {
  type    = string
  default = "172.21.0.0/16"
}
EOF

cat > modules/network/outputs.tf << 'EOF'
output "app_network_id" {
  description = "ID de la red principal de la app"
  value       = docker_network.app_network.id
}

output "app_network_name" {
  description = "Nombre de la red principal"
  value       = docker_network.app_network.name
}

output "monitoring_network_id" {
  description = "ID de la red de monitoreo"
  value       = docker_network.monitoring_network.id
}

output "monitoring_network_name" {
  description = "Nombre de la red de monitoreo"
  value       = docker_network.monitoring_network.name
}
EOF

# ── Módulo storage ───────────────────────────────────────
cat > modules/storage/main.tf << 'EOF'
# modules/storage/main.tf — Volúmenes Docker persistentes
resource "docker_volume" "postgres_data" {
  name   = "${var.project_name}-postgres-${var.environment}"
  driver = "local"

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "environment"
    value = var.environment
  }
  labels {
    label = "managed-by"
    value = "terraform"
  }
  labels {
    label = "component"
    value = "database"
  }
}

resource "docker_volume" "grafana_data" {
  name   = "${var.project_name}-grafana-${var.environment}"
  driver = "local"

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "environment"
    value = var.environment
  }
  # CORREGIDO: faltaba managed-by (verificar.sh lo filtra)
  labels {
    label = "managed-by"
    value = "terraform"
  }
  labels {
    label = "component"
    value = "monitoring"
  }
}

resource "docker_volume" "prometheus_data" {
  name   = "${var.project_name}-prometheus-${var.environment}"
  driver = "local"

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "environment"
    value = var.environment
  }
  # CORREGIDO: faltaba managed-by (verificar.sh lo filtra)
  labels {
    label = "managed-by"
    value = "terraform"
  }
  labels {
    label = "component"
    value = "monitoring"
  }
}
EOF

cat > modules/storage/variables.tf << 'EOF'
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}
EOF

cat > modules/storage/outputs.tf << 'EOF'
output "postgres_volume_name" {
  value = docker_volume.postgres_data.name
}

output "grafana_volume_name" {
  value = docker_volume.grafana_data.name
}

output "prometheus_volume_name" {
  value = docker_volume.prometheus_data.name
}
EOF

# ── Módulo app ───────────────────────────────────────────
cat > modules/app/main.tf << 'EOF'
# modules/app/main.tf — Contenedores Docker de la app

# ── Imágenes (pull desde registry) ───────────────────────
resource "docker_image" "postgres" {
  name         = var.postgres_image
  keep_locally = true # no borrar la imagen al destroy
}

resource "docker_image" "backend" {
  name         = var.backend_image
  keep_locally = true
}

resource "docker_image" "frontend" {
  name         = var.frontend_image
  keep_locally = true
}

# ── Contenedor Postgres ───────────────────────────────────
resource "docker_container" "postgres" {
  name    = "${var.project_name}-postgres-${var.environment}"
  image   = docker_image.postgres.image_id
  restart = "unless-stopped"

  env = [
    "POSTGRES_DB=${var.postgres_db}",
    "POSTGRES_USER=postgres",
    "POSTGRES_PASSWORD=${var.postgres_password}",
  ]

  # Montar el volumen persistente
  volumes {
    volume_name    = var.postgres_volume_name
    container_path = "/var/lib/postgresql/data"
  }

  # Conectar a la red de la app
  networks_advanced {
    name    = var.app_network_name
    aliases = ["postgres"] # hostname dentro de la red
  }

  healthcheck {
    test         = ["CMD-SHELL", "pg_isready -U postgres"]
    interval     = "10s"
    timeout      = "5s"
    retries      = 5
    start_period = "20s"
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "environment"
    value = var.environment
  }
  labels {
    label = "managed-by"
    value = "terraform"
  }
}

# ── Contenedor Backend ────────────────────────────────────
resource "docker_container" "backend" {
  count   = var.backend_replicas
  name    = "${var.project_name}-backend-${var.environment}-${count.index}"
  image   = docker_image.backend.image_id
  restart = "unless-stopped"

  # CORREGIDO: python:3.12-slim sin comando termina al instante.
  # Levantamos un servidor HTTP simple (placeholder del backend).
  command = ["python", "-m", "http.server", tostring(var.backend_port)]

  depends_on = [docker_container.postgres]

  env = [
    "DB_HOST=postgres",
    "DB_PORT=5432",
    "DB_NAME=${var.postgres_db}",
    "DB_USER=postgres",
    "DB_PASSWORD=${var.postgres_password}",
    "APP_ENV=${var.environment}",
    "PORT=${var.backend_port}",
  ]

  # Solo exponer el puerto del primer contenedor al host
  dynamic "ports" {
    for_each = count.index == 0 ? [1] : []
    content {
      internal = var.backend_port
      external = var.backend_port
    }
  }

  networks_advanced {
    name    = var.app_network_name
    aliases = ["backend-${count.index}"]
  }

  # CORREGIDO: la imagen python-slim no trae curl -> healthcheck con python
  healthcheck {
    test         = ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:${var.backend_port}/')"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 3
    start_period = "30s"
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "environment"
    value = var.environment
  }
  labels {
    label = "managed-by"
    value = "terraform"
  }
  labels {
    label = "replica"
    value = tostring(count.index)
  }
}

# ── Contenedor Frontend ───────────────────────────────────
resource "docker_container" "frontend" {
  name       = "${var.project_name}-frontend-${var.environment}"
  image      = docker_image.frontend.image_id
  restart    = "unless-stopped"
  depends_on = [docker_container.backend]

  ports {
    internal = 80
    external = var.frontend_port
  }

  networks_advanced {
    name    = var.app_network_name
    aliases = ["frontend"]
  }

  healthcheck {
    test         = ["CMD-SHELL", "wget -q --spider http://localhost/ || exit 1"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 3
    start_period = "10s"
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "environment"
    value = var.environment
  }
  labels {
    label = "managed-by"
    value = "terraform"
  }
}
EOF

# CORREGIDO: no se puede usar ";" en bloques de una línea -> multilínea
cat > modules/app/variables.tf << 'EOF'
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "postgres_image" {
  type = string
}

variable "backend_image" {
  type = string
}

variable "frontend_image" {
  type = string
}

variable "postgres_db" {
  type = string
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "backend_port" {
  type = number
}

variable "backend_replicas" {
  type = number
}

variable "frontend_port" {
  type = number
}

variable "app_network_name" {
  type = string
}

variable "postgres_volume_name" {
  type = string
}
EOF

cat > modules/app/outputs.tf << 'EOF'
output "postgres_container_id" {
  value = docker_container.postgres.id
}

output "backend_container_ids" {
  value = [for c in docker_container.backend : c.id]
}

output "frontend_container_id" {
  value = docker_container.frontend.id
}

output "frontend_url" {
  value = "http://localhost:${var.frontend_port}"
}
EOF

# CORREGIDO: cada módulo debe declarar el provider real; si no, Terraform
# busca "hashicorp/docker" (no existe) y `terraform init` falla.
for m in network storage app; do
cat > modules/$m/versions.tf << 'EOF'
terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}
EOF
done

# ── main.tf ──────────────────────────────────────────────
cat > main.tf << 'EOF'
# main.tf — Orquestación de módulos (TP 11)
module "network" {
  source            = "./modules/network"
  project_name      = var.project_name
  environment       = var.environment
  app_subnet        = var.network_subnet
  monitoring_subnet = var.monitoring_subnet
}

module "storage" {
  source       = "./modules/storage"
  project_name = var.project_name
  environment  = var.environment
}

module "app" {
  source            = "./modules/app"
  project_name      = var.project_name
  environment       = var.environment
  postgres_image    = var.postgres_image
  backend_image     = var.backend_image
  frontend_image    = var.frontend_image
  postgres_db       = var.postgres_db
  postgres_password = var.postgres_password
  backend_port      = var.backend_port
  backend_replicas  = var.backend_replicas
  frontend_port     = var.frontend_port

  # Outputs de network y storage usados como inputs
  app_network_name     = module.network.app_network_name
  postgres_volume_name = module.storage.postgres_volume_name
}
EOF

# ── outputs.tf ───────────────────────────────────────────
cat > outputs.tf << 'EOF'
# outputs.tf — Visibles tras terraform apply
output "app_url" {
  description = "URL de la aplicación"
  value       = module.app.frontend_url
}

output "app_network" {
  description = "Nombre de la red Docker de la app"
  value       = module.network.app_network_name
}

output "monitoring_network" {
  description = "Nombre de la red Docker de monitoreo"
  value       = module.network.monitoring_network_name
}

output "postgres_volume" {
  description = "Nombre del volumen de Postgres"
  value       = module.storage.postgres_volume_name
}

output "backend_containers" {
  description = "IDs de los contenedores del backend"
  value       = module.app.backend_container_ids
}

output "infrastructure_summary" {
  description = "Resumen de la infraestructura creada"
  value = {
    environment = var.environment
    project     = var.project_name
    app_url     = module.app.frontend_url
    replicas    = var.backend_replicas
    managed_by  = "terraform"
  }
}
EOF

# ── tfvars ───────────────────────────────────────────────
cat > terraform.tfvars << 'EOF'
# terraform.tfvars — Valores por defecto (dev)
environment       = "dev"
project_name      = "devops-portfolio"
postgres_db       = "notesdb"
postgres_password = "devops123" # usar variable de entorno en prod
backend_replicas  = 1
frontend_port     = 8080
backend_port      = 5000
network_subnet    = "172.20.0.0/16"
monitoring_subnet = "172.21.0.0/16"
EOF

cat > envs/dev/terraform.tfvars << 'EOF'
environment       = "dev"
project_name      = "devops-portfolio"
postgres_db       = "notesdb"
backend_replicas  = 1
frontend_port     = 8080
backend_port      = 5000
network_subnet    = "172.20.0.0/16"
monitoring_subnet = "172.21.0.0/16"
EOF

# CORREGIDO: sin password en el archivo (va por TF_VAR_postgres_password)
cat > envs/prod/terraform.tfvars << 'EOF'
# La password NO va acá: export TF_VAR_postgres_password="..."
environment       = "prod"
project_name      = "devops-portfolio"
postgres_db       = "notesdb"
backend_replicas  = 3
frontend_port     = 80
backend_port      = 5000
network_subnet    = "172.30.0.0/16"
monitoring_subnet = "172.31.0.0/16"
EOF

# ── scripts/verificar.sh ─────────────────────────────────
cat > scripts/verificar.sh << 'EOF'
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
EOF
chmod +x scripts/verificar.sh

# ── Archivos para GitHub ─────────────────────────────────
# CORREGIDO: solo se ignora el tfvars raíz (con password); los de envs/ y
# .terraform.lock.hcl SÍ se versionan (el lock es recomendado por HashiCorp)
cat > .gitignore << 'EOF'
.terraform/
terraform.tfstate
terraform.tfstate.backup
terraform.tfstate.*.backup
/terraform.tfvars
*.auto.tfvars
.terraform.tfstate.lock.info
crash.log
EOF

cat > terraform.tfvars.example << 'EOF'
environment       = "dev"
project_name      = "devops-portfolio"
postgres_db       = "notesdb"
postgres_password = "CAMBIAR_EN_PRODUCCION"
backend_replicas  = 1
frontend_port     = 8080
backend_port      = 5000
EOF

cat > README.md << 'EOF'
# TP11 — Infraestructura como Código con Terraform

## Recursos creados

| Recurso | Tipo | Módulo |
|---|---|---|
| Red app (`*-app-dev`) | `docker_network` | network |
| Red monitoring (`*-monitoring-dev`) | `docker_network` | network |
| Volumen Postgres | `docker_volume` | storage |
| Volumen Grafana | `docker_volume` | storage |
| Volumen Prometheus | `docker_volume` | storage |
| Contenedor Postgres | `docker_container` | app |
| Contenedor Backend (×N) | `docker_container` | app |
| Contenedor Frontend | `docker_container` | app |

## Uso

```bash
# Copiar y editar variables
cp terraform.tfvars.example terraform.tfvars

# Ciclo completo
terraform init
terraform validate
terraform plan
terraform apply

# Ver outputs
terraform output

# Destruir
terraform destroy
```

## Multi-entorno

```bash
# Desarrollo (defaults)
terraform apply

# Producción (destruir dev antes: comparten state y puertos)
export TF_VAR_postgres_password="una-password-segura"
terraform apply -var-file=envs/prod/terraform.tfvars
```

## Estructura de módulos

```
modules/
├── network/ → redes Docker con subnets dedicadas
├── storage/ → volúmenes persistentes con labels
└── app/     → contenedores con healthchecks y dependencias
```
EOF

terraform fmt -recursive >/dev/null 2>&1 || true
echo ""
echo "Proyecto creado en ~/devops-TP11. Siguiente: terraform init && terraform validate && terraform plan"
