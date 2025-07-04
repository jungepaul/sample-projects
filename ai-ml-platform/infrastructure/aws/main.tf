terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name = "${var.project_name}-ml-${var.environment}"
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

  tags = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
    aws-efs-csi-driver = {
      most_recent = true
    }
  }

  # CPU-optimized node group for training workloads
  eks_managed_node_groups = {
    training = {
      name           = "training"
      instance_types = var.training_instance_types
      capacity_type  = "ON_DEMAND"
      
      min_size     = var.training_min_size
      max_size     = var.training_max_size
      desired_size = var.training_desired_size

      disk_size = var.training_disk_size

      labels = {
        role = "training"
        workload = "ml-training"
      }

      taints = [
        {
          key    = "ml-training"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]

      tags = var.tags
    }

    # GPU node group for deep learning workloads
    gpu_training = {
      name           = "gpu-training"
      instance_types = var.gpu_instance_types
      capacity_type  = "ON_DEMAND"
      
      min_size     = var.gpu_min_size
      max_size     = var.gpu_max_size
      desired_size = var.gpu_desired_size

      disk_size = var.gpu_disk_size

      labels = {
        role = "gpu-training"
        workload = "ml-gpu-training"
        "nvidia.com/gpu" = "true"
      }

      taints = [
        {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]

      tags = var.tags
    }

    # General purpose node group for serving and system workloads
    general = {
      name           = "general"
      instance_types = var.general_instance_types
      capacity_type  = "SPOT"
      
      min_size     = var.general_min_size
      max_size     = var.general_max_size
      desired_size = var.general_desired_size

      disk_size = var.general_disk_size

      labels = {
        role = "general"
        workload = "ml-serving"
      }

      tags = var.tags
    }
  }

  tags = var.tags
}

# S3 bucket for ML artifacts
resource "aws_s3_bucket" "ml_artifacts" {
  bucket = "${local.cluster_name}-ml-artifacts"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "ml_artifacts" {
  bucket = aws_s3_bucket.ml_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ml_artifacts" {
  bucket = aws_s3_bucket.ml_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket for datasets
resource "aws_s3_bucket" "datasets" {
  bucket = "${local.cluster_name}-datasets"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "datasets" {
  bucket = aws_s3_bucket.datasets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datasets" {
  bucket = aws_s3_bucket.datasets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# EFS for shared storage
resource "aws_efs_file_system" "ml_shared_storage" {
  creation_token = "${local.cluster_name}-efs"
  
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 1000

  tags = merge(var.tags, {
    Name = "${local.cluster_name}-efs"
  })
}

resource "aws_efs_mount_target" "ml_shared_storage" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.ml_shared_storage.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name        = "${local.cluster_name}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# RDS for MLflow backend
resource "aws_db_subnet_group" "mlflow" {
  name       = "${local.cluster_name}-mlflow-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = var.tags
}

resource "aws_security_group" "mlflow_db" {
  name        = "${local.cluster_name}-mlflow-db-sg"
  description = "Security group for MLflow database"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = var.tags
}

resource "aws_db_instance" "mlflow" {
  identifier = "${local.cluster_name}-mlflow-db"
  
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.mlflow_db_instance_class
  
  allocated_storage     = var.mlflow_db_storage
  max_allocated_storage = var.mlflow_db_max_storage
  storage_type         = "gp3"
  storage_encrypted    = true
  
  db_name  = "mlflow"
  username = "mlflow"
  password = var.mlflow_db_password
  
  vpc_security_group_ids = [aws_security_group.mlflow_db.id]
  db_subnet_group_name   = aws_db_subnet_group.mlflow.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = true
  deletion_protection = false
  
  tags = var.tags
}