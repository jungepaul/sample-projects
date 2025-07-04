variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "name" {
  description = "Name of the EC2 instance. If empty, will use project_name-environment-instance"
  type        = string
  default     = ""
}

variable "create_instance" {
  description = "Whether to create EC2 instance"
  type        = bool
  default     = true
}

variable "instance_count" {
  description = "Number of instances to launch"
  type        = number
  default     = 1
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 100
    error_message = "Instance count must be between 1 and 100."
  }
}

variable "ami_id" {
  description = "ID of AMI to use for the instance. If empty, will use data source to find latest AMI"
  type        = string
  default     = ""
}

variable "ami_owners" {
  description = "List of AMI owners to limit search. Used when ami_id is empty"
  type        = list(string)
  default     = ["amazon"]
}

variable "ami_name_filter" {
  description = "List of AMI name patterns to filter. Used when ami_id is empty"
  type        = list(string)
  default     = ["amzn2-ami-hvm-*-x86_64-gp2"]
}

variable "instance_type" {
  description = "The type of instance to start"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "The key name to use for the instance"
  type        = string
  default     = ""
}

variable "create_key_pair" {
  description = "Whether to create a new key pair"
  type        = bool
  default     = false
}

variable "public_key" {
  description = "The public key material for the key pair. Required if create_key_pair is true"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "ID of the VPC where to create security group"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "The VPC Subnet ID to launch in"
  type        = string
}

variable "security_group_ids" {
  description = "A list of security group IDs to associate with"
  type        = list(string)
  default     = []
}

variable "create_security_group" {
  description = "Whether to create a new security group"
  type        = bool
  default     = true
}

variable "enable_ssh_access" {
  description = "Whether to enable SSH access in the security group"
  type        = bool
  default     = true
}

variable "ssh_cidr_blocks" {
  description = "List of CIDR blocks for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_http_access" {
  description = "Whether to enable HTTP access in the security group"
  type        = bool
  default     = false
}

variable "http_cidr_blocks" {
  description = "List of CIDR blocks for HTTP access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_https_access" {
  description = "Whether to enable HTTPS access in the security group"
  type        = bool
  default     = false
}

variable "https_cidr_blocks" {
  description = "List of CIDR blocks for HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ingress_rules" {
  description = "List of custom ingress rules"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

variable "associate_public_ip_address" {
  description = "If true, the EC2 instance will have associated public IP address"
  type        = bool
  default     = false
}

variable "create_eip" {
  description = "Whether to create Elastic IP for the instance"
  type        = bool
  default     = false
}

variable "user_data" {
  description = "The user data to provide when launching the instance"
  type        = string
  default     = ""
}

variable "user_data_base64" {
  description = "Can be used instead of user_data to pass base64-encoded binary data directly"
  type        = string
  default     = ""
}

variable "enable_detailed_monitoring" {
  description = "If true, the launched EC2 instance will have detailed monitoring enabled"
  type        = bool
  default     = false
}

variable "ebs_optimized" {
  description = "If true, the launched EC2 instance will be EBS-optimized"
  type        = bool
  default     = null
}

variable "root_block_device" {
  description = "Configuration block to customize details about the root block device of the instance"
  type        = map(string)
  default = {
    volume_type           = "gp3"
    volume_size           = "20"
    encrypted             = "true"
    delete_on_termination = "true"
  }
}

variable "ebs_block_devices" {
  description = "Additional EBS block devices to attach to the instance"
  type        = list(map(string))
  default     = []
}

variable "metadata_options" {
  description = "Customize the metadata options of the instance"
  type        = map(string)
  default = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = "1"
    instance_metadata_tags      = "disabled"
  }
}

variable "create_iam_role" {
  description = "Whether to create IAM role for the instance"
  type        = bool
  default     = false
}

variable "iam_instance_profile_name" {
  description = "The IAM Instance Profile to launch the instance with"
  type        = string
  default     = ""
}

variable "iam_policy_arns" {
  description = "List of IAM policy ARNs to attach to the instance role"
  type        = list(string)
  default     = []
}

variable "create_launch_template" {
  description = "Whether to create a launch template"
  type        = bool
  default     = false
}

variable "launch_template_version" {
  description = "Template version. Can be version number, $Latest, or $Default"
  type        = string
  default     = "$Latest"
}

variable "block_device_mappings" {
  description = "Specify volumes to attach to the instance besides the volumes specified by the AMI"
  type        = list(map(string))
  default     = []
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}