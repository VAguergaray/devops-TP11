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
