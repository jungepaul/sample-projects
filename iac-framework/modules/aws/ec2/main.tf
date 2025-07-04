terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # Common tags
  common_tags = merge(
    var.tags,
    {
      Module      = "ec2"
      Environment = var.environment
      Project     = var.project_name
    }
  )

  # Instance name
  instance_name = var.name != "" ? var.name : "${var.project_name}-${var.environment}-instance"
}

# Data sources
data "aws_ami" "selected" {
  count = var.ami_id == "" ? 1 : 0

  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = var.ami_name_filter
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_subnet" "selected" {
  count = var.subnet_id != "" ? 1 : 0
  id    = var.subnet_id
}

# Key Pair
resource "aws_key_pair" "this" {
  count = var.create_key_pair ? 1 : 0

  key_name   = "${local.instance_name}-key"
  public_key = var.public_key

  tags = merge(
    local.common_tags,
    {
      Name = "${local.instance_name}-key"
    }
  )
}

# Security Group
resource "aws_security_group" "this" {
  count = var.create_security_group ? 1 : 0

  name_prefix = "${local.instance_name}-sg"
  description = "Security group for ${local.instance_name}"
  vpc_id      = var.vpc_id

  # SSH access
  dynamic "ingress" {
    for_each = var.enable_ssh_access ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_cidr_blocks
      description = "SSH access"
    }
  }

  # HTTP access
  dynamic "ingress" {
    for_each = var.enable_http_access ? [1] : []
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = var.http_cidr_blocks
      description = "HTTP access"
    }
  }

  # HTTPS access
  dynamic "ingress" {
    for_each = var.enable_https_access ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.https_cidr_blocks
      description = "HTTPS access"
    }
  }

  # Custom ingress rules
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  # Default egress - allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.instance_name}-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# IAM Role for EC2 instance
resource "aws_iam_role" "this" {
  count = var.create_iam_role ? 1 : 0

  name = "${local.instance_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "this" {
  count = var.create_iam_role ? length(var.iam_policy_arns) : 0

  role       = aws_iam_role.this[0].name
  policy_arn = var.iam_policy_arns[count.index]
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "this" {
  count = var.create_iam_role ? 1 : 0

  name = "${local.instance_name}-profile"
  role = aws_iam_role.this[0].name

  tags = local.common_tags
}

# Launch Template
resource "aws_launch_template" "this" {
  count = var.create_launch_template ? 1 : 0

  name_prefix   = "${local.instance_name}-lt"
  description   = "Launch template for ${local.instance_name}"
  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.selected[0].id
  instance_type = var.instance_type
  key_name      = var.create_key_pair ? aws_key_pair.this[0].key_name : var.key_name

  vpc_security_group_ids = var.create_security_group ? [aws_security_group.this[0].id] : var.security_group_ids

  iam_instance_profile {
    name = var.create_iam_role ? aws_iam_instance_profile.this[0].name : var.iam_instance_profile_name
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  # EBS configuration
  dynamic "block_device_mappings" {
    for_each = var.block_device_mappings
    content {
      device_name = block_device_mappings.value.device_name
      ebs {
        volume_type           = lookup(block_device_mappings.value, "volume_type", "gp3")
        volume_size           = lookup(block_device_mappings.value, "volume_size", 20)
        iops                  = lookup(block_device_mappings.value, "iops", null)
        throughput            = lookup(block_device_mappings.value, "throughput", null)
        encrypted             = lookup(block_device_mappings.value, "encrypted", true)
        kms_key_id           = lookup(block_device_mappings.value, "kms_key_id", null)
        delete_on_termination = lookup(block_device_mappings.value, "delete_on_termination", true)
      }
    }
  }

  # User data
  user_data = var.user_data_base64 != "" ? var.user_data_base64 : (var.user_data != "" ? base64encode(var.user_data) : null)

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      {
        Name = local.instance_name
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      local.common_tags,
      {
        Name = "${local.instance_name}-volume"
      }
    )
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 Instance
resource "aws_instance" "this" {
  count = var.create_instance ? var.instance_count : 0

  # Use launch template if created, otherwise specify parameters directly
  dynamic "launch_template" {
    for_each = var.create_launch_template ? [1] : []
    content {
      id      = aws_launch_template.this[0].id
      version = var.launch_template_version
    }
  }

  # Direct configuration when not using launch template
  ami                         = var.create_launch_template ? null : (var.ami_id != "" ? var.ami_id : data.aws_ami.selected[0].id)
  instance_type               = var.create_launch_template ? null : var.instance_type
  key_name                    = var.create_launch_template ? null : (var.create_key_pair ? aws_key_pair.this[0].key_name : var.key_name)
  vpc_security_group_ids      = var.create_launch_template ? null : (var.create_security_group ? [aws_security_group.this[0].id] : var.security_group_ids)
  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip_address
  iam_instance_profile        = var.create_launch_template ? null : (var.create_iam_role ? aws_iam_instance_profile.this[0].name : var.iam_instance_profile_name)
  monitoring                  = var.create_launch_template ? null : var.enable_detailed_monitoring
  user_data                   = var.create_launch_template ? null : var.user_data
  user_data_base64            = var.create_launch_template ? null : var.user_data_base64

  # EBS optimized
  ebs_optimized = var.ebs_optimized

  # Instance metadata options
  metadata_options {
    http_endpoint               = var.metadata_options.http_endpoint
    http_tokens                 = var.metadata_options.http_tokens
    http_put_response_hop_limit = var.metadata_options.http_put_response_hop_limit
    instance_metadata_tags      = var.metadata_options.instance_metadata_tags
  }

  # Root block device
  dynamic "root_block_device" {
    for_each = var.create_launch_template ? [] : [var.root_block_device]
    content {
      volume_type           = lookup(root_block_device.value, "volume_type", "gp3")
      volume_size           = lookup(root_block_device.value, "volume_size", 20)
      iops                  = lookup(root_block_device.value, "iops", null)
      throughput            = lookup(root_block_device.value, "throughput", null)
      encrypted             = lookup(root_block_device.value, "encrypted", true)
      kms_key_id           = lookup(root_block_device.value, "kms_key_id", null)
      delete_on_termination = lookup(root_block_device.value, "delete_on_termination", true)
    }
  }

  # Additional EBS volumes
  dynamic "ebs_block_device" {
    for_each = var.create_launch_template ? [] : var.ebs_block_devices
    content {
      device_name           = ebs_block_device.value.device_name
      volume_type           = lookup(ebs_block_device.value, "volume_type", "gp3")
      volume_size           = lookup(ebs_block_device.value, "volume_size", 20)
      iops                  = lookup(ebs_block_device.value, "iops", null)
      throughput            = lookup(ebs_block_device.value, "throughput", null)
      encrypted             = lookup(ebs_block_device.value, "encrypted", true)
      kms_key_id           = lookup(ebs_block_device.value, "kms_key_id", null)
      delete_on_termination = lookup(ebs_block_device.value, "delete_on_termination", true)
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = count.index > 0 ? "${local.instance_name}-${count.index + 1}" : local.instance_name
    }
  )

  volume_tags = merge(
    local.common_tags,
    {
      Name = count.index > 0 ? "${local.instance_name}-${count.index + 1}-volume" : "${local.instance_name}-volume"
    }
  )

  lifecycle {
    ignore_changes = [
      ami,
      user_data,
      user_data_base64
    ]
  }
}

# Elastic IP
resource "aws_eip" "this" {
  count = var.create_eip ? var.instance_count : 0

  instance = aws_instance.this[count.index].id
  domain   = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = count.index > 0 ? "${local.instance_name}-eip-${count.index + 1}" : "${local.instance_name}-eip"
    }
  )

  depends_on = [aws_instance.this]
}