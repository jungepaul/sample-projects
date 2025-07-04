# Basic VPC test configuration

vpc_name = "test-vpc-basic"
vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "us-west-2a",
  "us-west-2b"
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.10.0/24",
  "10.0.20.0/24"
]

# Basic configuration
enable_nat_gateway = true
single_nat_gateway = true
enable_dns_hostnames = true
enable_dns_support = true
enable_flow_logs = false
enable_vpc_endpoints = false

tags = {
  Environment = "test"
  Project     = "iac-framework-test"
  TestSuite   = "vpc-basic"
  Owner       = "infrastructure-team"
  ManagedBy   = "Terraform"
}