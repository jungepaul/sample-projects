variable "istio_version" {
  description = "Version of Istio to install"
  type        = string
  default     = "1.19.0"
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "mesh_id" {
  description = "Mesh ID for multi-cluster setup"
  type        = string
  default     = "mesh1"
}

variable "network_name" {
  description = "Network name for multi-cluster setup"
  type        = string
  default     = "network1"
}

variable "trace_sampling" {
  description = "Trace sampling percentage"
  type        = number
  default     = 1.0
}

variable "pilot_cpu_request" {
  description = "CPU request for Pilot"
  type        = string
  default     = "500m"
}

variable "pilot_memory_request" {
  description = "Memory request for Pilot"
  type        = string
  default     = "2048Mi"
}

variable "pilot_cpu_limit" {
  description = "CPU limit for Pilot"
  type        = string
  default     = "1000m"
}

variable "pilot_memory_limit" {
  description = "Memory limit for Pilot"
  type        = string
  default     = "4096Mi"
}

variable "gateway_service_type" {
  description = "Service type for Istio Gateway"
  type        = string
  default     = "LoadBalancer"
}

variable "gateway_cpu_request" {
  description = "CPU request for Gateway"
  type        = string
  default     = "100m"
}

variable "gateway_memory_request" {
  description = "Memory request for Gateway"
  type        = string
  default     = "128Mi"
}

variable "gateway_cpu_limit" {
  description = "CPU limit for Gateway"
  type        = string
  default     = "2000m"
}

variable "gateway_memory_limit" {
  description = "Memory limit for Gateway"
  type        = string
  default     = "1024Mi"
}

variable "mtls_mode" {
  description = "mTLS mode for the mesh"
  type        = string
  default     = "STRICT"
  validation {
    condition     = contains(["STRICT", "PERMISSIVE", "DISABLE"], var.mtls_mode)
    error_message = "mtls_mode must be one of: STRICT, PERMISSIVE, DISABLE."
  }
}