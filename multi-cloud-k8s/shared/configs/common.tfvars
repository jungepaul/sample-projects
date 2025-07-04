# Common configuration variables for all cloud providers

# Project configuration
project_name = "multicloud-platform"
environment  = "dev"

# Kubernetes configuration
kubernetes_version = "1.28"

# Monitoring configuration
prometheus_retention      = "30d"
prometheus_storage_size   = "50Gi"
grafana_admin_password    = "admin123"
grafana_storage_size      = "10Gi"
alertmanager_storage_size = "10Gi"

# Istio configuration
istio_version  = "1.19.0"
trace_sampling = 1.0
mtls_mode      = "STRICT"

# Common tags/labels
tags = {
  Project     = "MultiCloud-K8s"
  Environment = "dev"
  ManagedBy   = "terraform"
  Owner       = "platform-team"
}