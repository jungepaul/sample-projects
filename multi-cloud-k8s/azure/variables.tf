variable "azure_location" {
  description = "Azure location"
  type        = string
  default     = "East US"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "multicloud-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vnet_cidr" {
  description = "CIDR block for the virtual network"
  type        = string
  default     = "10.20.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.20.1.0/24"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 3
}

variable "min_node_count" {
  description = "Minimum number of nodes in the default node pool"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes in the default node pool"
  type        = number
  default     = 10
}

variable "vm_size" {
  description = "VM size for the default node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "user_node_count" {
  description = "Number of nodes in the user node pool"
  type        = number
  default     = 2
}

variable "user_min_node_count" {
  description = "Minimum number of nodes in the user node pool"
  type        = number
  default     = 1
}

variable "user_max_node_count" {
  description = "Maximum number of nodes in the user node pool"
  type        = number
  default     = 5
}

variable "user_vm_size" {
  description = "VM size for the user node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB for the nodes"
  type        = number
  default     = 30
}

variable "admin_group_object_ids" {
  description = "List of Azure AD group object IDs for cluster admins"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "MultiCloud-K8s"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}