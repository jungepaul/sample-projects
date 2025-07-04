# Basic EC2 test configuration

instance_name = "test-ec2-basic"
instance_type = "t3.micro"

# Use Amazon Linux 2 AMI (this should be updated to use data source in real module)
ami_id = "ami-0c02fb55956c7d316"

# Network configuration (these would typically come from VPC module outputs)
# For testing, these should be replaced with actual values from the test environment
subnet_id = "" # Will be populated by Kitchen-Terraform
security_group_ids = [] # Will be populated by Kitchen-Terraform

# Instance configuration
key_name = "test-key"
associate_public_ip_address = false
enable_monitoring = true

# Storage configuration
root_volume_size = 20
root_volume_type = "gp3"
root_volume_encrypted = true
delete_on_termination = true

# IAM configuration
create_iam_role = false
enable_eip = false

# User data script
user_data = <<-EOF
#!/bin/bash
yum update -y
yum install -y awscli
echo "Instance initialized successfully" > /tmp/init-complete.txt
EOF

# Tags
tags = {
  Environment = "test"
  Project     = "iac-framework-test"
  TestSuite   = "ec2-basic"
  Owner       = "infrastructure-team"
  ManagedBy   = "Terraform"
}