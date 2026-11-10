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
