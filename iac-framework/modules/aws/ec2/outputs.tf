output "instance_ids" {
  description = "List of instance IDs"
  value       = aws_instance.this[*].id
}

output "instance_arns" {
  description = "List of instance ARNs"
  value       = aws_instance.this[*].arn
}

output "instance_public_ips" {
  description = "List of public IP addresses assigned to the instances"
  value       = aws_instance.this[*].public_ip
}

output "instance_private_ips" {
  description = "List of private IP addresses assigned to the instances"
  value       = aws_instance.this[*].private_ip
}

output "instance_public_dns" {
  description = "List of public DNS names assigned to the instances"
  value       = aws_instance.this[*].public_dns
}

output "instance_private_dns" {
  description = "List of private DNS names assigned to the instances"
  value       = aws_instance.this[*].private_dns
}

output "instance_availability_zones" {
  description = "List of availability zones of the instances"
  value       = aws_instance.this[*].availability_zone
}

output "instance_subnet_ids" {
  description = "List of subnet IDs of the instances"
  value       = aws_instance.this[*].subnet_id
}

output "instance_vpc_security_group_ids" {
  description = "List of VPC security group IDs assigned to the instances"
  value       = aws_instance.this[*].vpc_security_group_ids
}

output "instance_state" {
  description = "List of instance states"
  value       = aws_instance.this[*].instance_state
}

output "instance_primary_network_interface_id" {
  description = "List of IDs of the primary network interface"
  value       = aws_instance.this[*].primary_network_interface_id
}

output "instance_private_dns_name_options" {
  description = "List of options for the instance hostname"
  value       = aws_instance.this[*].private_dns_name_options
}

# Key Pair
output "key_pair_id" {
  description = "The key pair ID"
  value       = try(aws_key_pair.this[0].id, "")
}

output "key_pair_arn" {
  description = "The key pair ARN"
  value       = try(aws_key_pair.this[0].arn, "")
}

output "key_pair_name" {
  description = "The key pair name"
  value       = try(aws_key_pair.this[0].key_name, "")
}

output "key_pair_fingerprint" {
  description = "The MD5 public key fingerprint"
  value       = try(aws_key_pair.this[0].fingerprint, "")
}

# Security Group
output "security_group_id" {
  description = "ID of the security group"
  value       = try(aws_security_group.this[0].id, "")
}

output "security_group_arn" {
  description = "ARN of the security group"
  value       = try(aws_security_group.this[0].arn, "")
}

output "security_group_name" {
  description = "Name of the security group"
  value       = try(aws_security_group.this[0].name, "")
}

output "security_group_description" {
  description = "Description of the security group"
  value       = try(aws_security_group.this[0].description, "")
}

# IAM
output "iam_role_name" {
  description = "Name of the IAM role"
  value       = try(aws_iam_role.this[0].name, "")
}

output "iam_role_arn" {
  description = "Amazon Resource Name (ARN) specifying the role"
  value       = try(aws_iam_role.this[0].arn, "")
}

output "iam_role_unique_id" {
  description = "Stable and unique string identifying the role"
  value       = try(aws_iam_role.this[0].unique_id, "")
}

output "iam_instance_profile_id" {
  description = "Instance profile's ID"
  value       = try(aws_iam_instance_profile.this[0].id, "")
}

output "iam_instance_profile_arn" {
  description = "ARN assigned by AWS to the instance profile"
  value       = try(aws_iam_instance_profile.this[0].arn, "")
}

output "iam_instance_profile_name" {
  description = "Name of the instance profile"
  value       = try(aws_iam_instance_profile.this[0].name, "")
}

output "iam_instance_profile_unique_id" {
  description = "Unique ID assigned by AWS"
  value       = try(aws_iam_instance_profile.this[0].unique_id, "")
}

# Launch Template
output "launch_template_id" {
  description = "The ID of the launch template"
  value       = try(aws_launch_template.this[0].id, "")
}

output "launch_template_arn" {
  description = "Amazon Resource Name (ARN) of the launch template"
  value       = try(aws_launch_template.this[0].arn, "")
}

output "launch_template_name" {
  description = "The name of the launch template"
  value       = try(aws_launch_template.this[0].name, "")
}

output "launch_template_latest_version" {
  description = "The latest version of the launch template"
  value       = try(aws_launch_template.this[0].latest_version, "")
}

output "launch_template_default_version" {
  description = "The default version of the launch template"
  value       = try(aws_launch_template.this[0].default_version, "")
}

# Elastic IP
output "eip_ids" {
  description = "List of EIP IDs"
  value       = aws_eip.this[*].id
}

output "eip_public_ips" {
  description = "List of EIP public IPs"
  value       = aws_eip.this[*].public_ip
}

output "eip_public_dns" {
  description = "List of EIP public DNS names"
  value       = aws_eip.this[*].public_dns
}

output "eip_allocation_ids" {
  description = "List of EIP allocation IDs"
  value       = aws_eip.this[*].allocation_id
}

# Root Block Device
output "root_block_device_volume_ids" {
  description = "List of volume IDs of root block devices"
  value       = aws_instance.this[*].root_block_device[0].volume_id
}

output "root_block_device_volume_size" {
  description = "List of volume sizes of root block devices"
  value       = aws_instance.this[*].root_block_device[0].volume_size
}

output "root_block_device_volume_type" {
  description = "List of volume types of root block devices"
  value       = aws_instance.this[*].root_block_device[0].volume_type
}

output "root_block_device_encrypted" {
  description = "List of whether root block devices are encrypted"
  value       = aws_instance.this[*].root_block_device[0].encrypted
}

# Additional outputs for monitoring and management
output "instance_tags" {
  description = "List of tags of the instances"
  value       = aws_instance.this[*].tags_all
}

output "instance_placement" {
  description = "List of placement information of the instances"
  value = [
    for instance in aws_instance.this : {
      availability_zone = instance.availability_zone
      tenancy          = instance.tenancy
      host_id          = instance.host_id
    }
  ]
}

output "instance_cpu_options" {
  description = "List of CPU options of the instances"
  value = [
    for instance in aws_instance.this : {
      core_count       = instance.cpu_core_count
      threads_per_core = instance.cpu_threads_per_core
    }
  ]
}