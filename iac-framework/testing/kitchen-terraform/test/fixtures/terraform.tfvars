# Default test variables for Kitchen-Terraform

# Common variables
environment = "test"
project_name = "iac-framework-test"

# AWS region
aws_region = "us-west-2"

# VPC Configuration
vpc_name = "test-vpc"
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# Subnet Configuration
public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24", 
  "10.0.3.0/24"
]

private_subnet_cidrs = [
  "10.0.10.0/24",
  "10.0.20.0/24",
  "10.0.30.0/24"
]

# Network Configuration
enable_nat_gateway = true
single_nat_gateway = false
enable_dns_hostnames = true
enable_dns_support = true
enable_flow_logs = false

# Common tags
tags = {
  Environment = "test"
  Project     = "iac-framework-test"
  Owner       = "infrastructure-team"
  ManagedBy   = "Terraform"
  Purpose     = "testing"
}