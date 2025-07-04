variable "prometheus_version" {
  description = "Version of Prometheus stack to install"
  type        = string
  default     = "45.0.0"
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "30d"
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus"
  type        = string
  default     = "50Gi"
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "grafana_service_type" {
  description = "Service type for Grafana"
  type        = string
  default     = "LoadBalancer"
}

variable "grafana_storage_size" {
  description = "Storage size for Grafana"
  type        = string
  default     = "10Gi"
}

variable "alertmanager_storage_size" {
  description = "Storage size for Alertmanager"
  type        = string
  default     = "10Gi"
}

variable "jaeger_version" {
  description = "Version of Jaeger to install"
  type        = string
  default     = "0.71.0"
}

variable "jaeger_service_type" {
  description = "Service type for Jaeger Query"
  type        = string
  default     = "LoadBalancer"
}

variable "elasticsearch_version" {
  description = "Version of Elasticsearch to install"
  type        = string
  default     = "7.17.3"
}

variable "elasticsearch_replicas" {
  description = "Number of Elasticsearch replicas"
  type        = number
  default     = 3
}

variable "elasticsearch_master_nodes" {
  description = "Number of Elasticsearch master nodes"
  type        = number
  default     = 2
}

variable "elasticsearch_cpu_request" {
  description = "CPU request for Elasticsearch"
  type        = string
  default     = "1000m"
}

variable "elasticsearch_memory_request" {
  description = "Memory request for Elasticsearch"
  type        = string
  default     = "2Gi"
}

variable "elasticsearch_cpu_limit" {
  description = "CPU limit for Elasticsearch"
  type        = string
  default     = "2000m"
}

variable "elasticsearch_memory_limit" {
  description = "Memory limit for Elasticsearch"
  type        = string
  default     = "4Gi"
}

variable "elasticsearch_storage_size" {
  description = "Storage size for Elasticsearch"
  type        = string
  default     = "100Gi"
}