variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ai-ml-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

# Training node group variables
variable "training_instance_types" {
  description = "Instance types for training node group"
  type        = list(string)
  default     = ["c5.2xlarge", "c5.4xlarge"]
}

variable "training_min_size" {
  description = "Minimum number of nodes in training node group"
  type        = number
  default     = 0
}

variable "training_max_size" {
  description = "Maximum number of nodes in training node group"
  type        = number
  default     = 20
}

variable "training_desired_size" {
  description = "Desired number of nodes in training node group"
  type        = number
  default     = 2
}

variable "training_disk_size" {
  description = "Disk size for training nodes"
  type        = number
  default     = 100
}

# GPU node group variables
variable "gpu_instance_types" {
  description = "Instance types for GPU node group"
  type        = list(string)
  default     = ["p3.2xlarge", "p3.8xlarge"]
}

variable "gpu_min_size" {
  description = "Minimum number of nodes in GPU node group"
  type        = number
  default     = 0
}

variable "gpu_max_size" {
  description = "Maximum number of nodes in GPU node group"
  type        = number
  default     = 10
}

variable "gpu_desired_size" {
  description = "Desired number of nodes in GPU node group"
  type        = number
  default     = 0
}

variable "gpu_disk_size" {
  description = "Disk size for GPU nodes"
  type        = number
  default     = 200
}

# General purpose node group variables
variable "general_instance_types" {
  description = "Instance types for general node group"
  type        = list(string)
  default     = ["m5.large", "m5.xlarge"]
}

variable "general_min_size" {
  description = "Minimum number of nodes in general node group"
  type        = number
  default     = 2
}

variable "general_max_size" {
  description = "Maximum number of nodes in general node group"
  type        = number
  default     = 10
}

variable "general_desired_size" {
  description = "Desired number of nodes in general node group"
  type        = number
  default     = 3
}

variable "general_disk_size" {
  description = "Disk size for general nodes"
  type        = number
  default     = 50
}

# MLflow database variables
variable "mlflow_db_instance_class" {
  description = "Instance class for MLflow database"
  type        = string
  default     = "db.t3.micro"
}

variable "mlflow_db_storage" {
  description = "Storage size for MLflow database"
  type        = number
  default     = 20
}

variable "mlflow_db_max_storage" {
  description = "Maximum storage size for MLflow database"
  type        = number
  default     = 100
}

variable "mlflow_db_password" {
  description = "Password for MLflow database"
  type        = string
  sensitive   = true
  default     = "mlflow123!"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "AI-ML-Platform"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}