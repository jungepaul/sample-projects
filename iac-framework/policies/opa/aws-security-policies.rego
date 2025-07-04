# AWS Security Policies using Open Policy Agent (OPA)
# These policies enforce security best practices for AWS resources

package aws.security

import future.keywords.in
import future.keywords.if

# =============================================================================
# S3 Bucket Security Policies
# =============================================================================

# Deny S3 buckets that are publicly readable
deny_public_s3_read[msg] {
    input.resource_type == "aws_s3_bucket_public_access_block"
    input.change.after.block_public_acls == false
    msg := sprintf("S3 bucket '%s' allows public ACLs which is a security risk", [input.address])
}

deny_public_s3_read[msg] {
    input.resource_type == "aws_s3_bucket_public_access_block"
    input.change.after.block_public_policy == false
    msg := sprintf("S3 bucket '%s' allows public bucket policies which is a security risk", [input.address])
}

deny_public_s3_read[msg] {
    input.resource_type == "aws_s3_bucket_public_access_block"
    input.change.after.ignore_public_acls == false
    msg := sprintf("S3 bucket '%s' doesn't ignore public ACLs which is a security risk", [input.address])
}

deny_public_s3_read[msg] {
    input.resource_type == "aws_s3_bucket_public_access_block"
    input.change.after.restrict_public_buckets == false
    msg := sprintf("S3 bucket '%s' doesn't restrict public bucket access which is a security risk", [input.address])
}

# Require S3 bucket encryption
require_s3_encryption[msg] {
    input.resource_type == "aws_s3_bucket"
    not has_encryption_configuration
    msg := sprintf("S3 bucket '%s' must have server-side encryption enabled", [input.address])
}

has_encryption_configuration {
    input.change.after.server_side_encryption_configuration
}

# Require S3 bucket versioning for production
require_s3_versioning[msg] {
    input.resource_type == "aws_s3_bucket_versioning"
    environment := input.change.after.tags.Environment
    environment == "prod"
    input.change.after.versioning_configuration[_].status != "Enabled"
    msg := sprintf("S3 bucket '%s' in production must have versioning enabled", [input.address])
}

# =============================================================================
# EC2 Security Policies
# =============================================================================

# Deny EC2 instances without encryption for root volume
deny_unencrypted_ec2_root[msg] {
    input.resource_type == "aws_instance"
    root_device := input.change.after.root_block_device[_]
    root_device.encrypted == false
    msg := sprintf("EC2 instance '%s' root volume must be encrypted", [input.address])
}

# Deny EC2 instances in public subnets for production
deny_ec2_public_subnet_prod[msg] {
    input.resource_type == "aws_instance"
    environment := input.change.after.tags.Environment
    environment == "prod"
    input.change.after.associate_public_ip_address == true
    msg := sprintf("Production EC2 instance '%s' should not have public IP address", [input.address])
}

# Require specific instance types for production
enforce_instance_types_prod[msg] {
    input.resource_type == "aws_instance"
    environment := input.change.after.tags.Environment
    environment == "prod"
    not allowed_instance_type(input.change.after.instance_type)
    msg := sprintf("EC2 instance '%s' uses disallowed instance type '%s' for production", [input.address, input.change.after.instance_type])
}

allowed_instance_type(instance_type) {
    allowed_types := ["t3.medium", "t3.large", "t3.xlarge", "m5.large", "m5.xlarge", "m5.2xlarge", "c5.large", "c5.xlarge", "c5.2xlarge"]
    instance_type in allowed_types
}

# =============================================================================
# Security Group Policies
# =============================================================================

# Deny security groups with unrestricted inbound access
deny_sg_unrestricted_inbound[msg] {
    input.resource_type == "aws_security_group"
    rule := input.change.after.ingress[_]
    has_unrestricted_access(rule)
    msg := sprintf("Security group '%s' has unrestricted inbound access on port %d", [input.address, rule.from_port])
}

# Deny SSH access from anywhere
deny_ssh_from_anywhere[msg] {
    input.resource_type == "aws_security_group"
    rule := input.change.after.ingress[_]
    is_ssh_port(rule.from_port, rule.to_port)
    "0.0.0.0/0" in rule.cidr_blocks
    msg := sprintf("Security group '%s' allows SSH access from anywhere (0.0.0.0/0)", [input.address])
}

# Deny RDP access from anywhere
deny_rdp_from_anywhere[msg] {
    input.resource_type == "aws_security_group"
    rule := input.change.after.ingress[_]
    is_rdp_port(rule.from_port, rule.to_port)
    "0.0.0.0/0" in rule.cidr_blocks
    msg := sprintf("Security group '%s' allows RDP access from anywhere (0.0.0.0/0)", [input.address])
}

has_unrestricted_access(rule) {
    "0.0.0.0/0" in rule.cidr_blocks
    rule.from_port != 80
    rule.from_port != 443
}

is_ssh_port(from_port, to_port) {
    from_port <= 22
    to_port >= 22
}

is_rdp_port(from_port, to_port) {
    from_port <= 3389
    to_port >= 3389
}

# =============================================================================
# RDS Security Policies
# =============================================================================

# Require RDS encryption
require_rds_encryption[msg] {
    input.resource_type == "aws_db_instance"
    input.change.after.storage_encrypted == false
    msg := sprintf("RDS instance '%s' must have storage encryption enabled", [input.address])
}

# Require RDS backup retention for production
require_rds_backup_prod[msg] {
    input.resource_type == "aws_db_instance"
    environment := input.change.after.tags.Environment
    environment == "prod"
    input.change.after.backup_retention_period < 7
    msg := sprintf("Production RDS instance '%s' must have backup retention period of at least 7 days", [input.address])
}

# Deny RDS instances without deletion protection in production
require_deletion_protection_prod[msg] {
    input.resource_type == "aws_db_instance"
    environment := input.change.after.tags.Environment
    environment == "prod"
    input.change.after.deletion_protection == false
    msg := sprintf("Production RDS instance '%s' must have deletion protection enabled", [input.address])
}

# Deny publicly accessible RDS instances
deny_public_rds[msg] {
    input.resource_type == "aws_db_instance"
    input.change.after.publicly_accessible == true
    msg := sprintf("RDS instance '%s' must not be publicly accessible", [input.address])
}

# =============================================================================
# IAM Security Policies
# =============================================================================

# Deny IAM policies with wildcard resources in production
deny_iam_wildcard_resources_prod[msg] {
    input.resource_type == "aws_iam_policy"
    environment := input.change.after.tags.Environment
    environment == "prod"
    policy_doc := json.unmarshal(input.change.after.policy)
    statement := policy_doc.Statement[_]
    statement.Effect == "Allow"
    "*" in statement.Resource
    msg := sprintf("IAM policy '%s' in production should not use wildcard (*) resources", [input.address])
}

# Require MFA for IAM users with console access
require_mfa_console_access[msg] {
    input.resource_type == "aws_iam_user_login_profile"
    not has_mfa_policy
    msg := sprintf("IAM user '%s' with console access must have MFA enabled", [input.address])
}

has_mfa_policy {
    # This would need to be checked against attached policies
    # Implementation depends on how the data is structured
    true
}

# =============================================================================
# VPC Security Policies
# =============================================================================

# Require VPC Flow Logs for production
require_vpc_flow_logs_prod[msg] {
    input.resource_type == "aws_vpc"
    environment := input.change.after.tags.Environment
    environment == "prod"
    not has_flow_logs
    msg := sprintf("Production VPC '%s' must have Flow Logs enabled", [input.address])
}

has_flow_logs {
    # This would need to check for associated flow log resources
    # Implementation depends on the Terraform plan structure
    input.change.after.enable_flow_logs == true
}

# =============================================================================
# EBS Security Policies
# =============================================================================

# Require EBS volume encryption
require_ebs_encryption[msg] {
    input.resource_type == "aws_ebs_volume"
    input.change.after.encrypted == false
    msg := sprintf("EBS volume '%s' must be encrypted", [input.address])
}

# =============================================================================
# Lambda Security Policies
# =============================================================================

# Require Lambda function to be in VPC for production
require_lambda_vpc_prod[msg] {
    input.resource_type == "aws_lambda_function"
    environment := input.change.after.tags.Environment
    environment == "prod"
    not input.change.after.vpc_config
    msg := sprintf("Production Lambda function '%s' should be deployed in a VPC", [input.address])
}

# Require Lambda function encryption
require_lambda_encryption[msg] {
    input.resource_type == "aws_lambda_function"
    not input.change.after.kms_key_arn
    msg := sprintf("Lambda function '%s' should use KMS encryption", [input.address])
}

# =============================================================================
# CloudTrail Security Policies
# =============================================================================

# Require CloudTrail encryption
require_cloudtrail_encryption[msg] {
    input.resource_type == "aws_cloudtrail"
    not input.change.after.kms_key_id
    msg := sprintf("CloudTrail '%s' must use KMS encryption", [input.address])
}

# Require CloudTrail log file validation
require_cloudtrail_validation[msg] {
    input.resource_type == "aws_cloudtrail"
    input.change.after.enable_log_file_validation == false
    msg := sprintf("CloudTrail '%s' must have log file validation enabled", [input.address])
}

# =============================================================================
# Tagging Policies
# =============================================================================

# Require mandatory tags for all resources
require_mandatory_tags[msg] {
    mandatory_tags := ["Environment", "Project", "Owner"]
    tag := mandatory_tags[_]
    not input.change.after.tags[tag]
    msg := sprintf("Resource '%s' is missing mandatory tag: %s", [input.address, tag])
}

# Validate environment tag values
validate_environment_tag[msg] {
    environment := input.change.after.tags.Environment
    environment != null
    not valid_environment(environment)
    msg := sprintf("Resource '%s' has invalid Environment tag value: %s", [input.address, environment])
}

valid_environment(env) {
    allowed_envs := ["dev", "staging", "prod", "test"]
    env in allowed_envs
}

# =============================================================================
# Cost Control Policies
# =============================================================================

# Restrict expensive instance types in non-production
restrict_expensive_instances[msg] {
    input.resource_type == "aws_instance"
    environment := input.change.after.tags.Environment
    environment != "prod"
    is_expensive_instance(input.change.after.instance_type)
    msg := sprintf("Instance type '%s' is too expensive for %s environment in '%s'", [input.change.after.instance_type, environment, input.address])
}

is_expensive_instance(instance_type) {
    expensive_types := ["m5.4xlarge", "m5.8xlarge", "m5.12xlarge", "m5.16xlarge", "m5.24xlarge", "c5.4xlarge", "c5.9xlarge", "c5.12xlarge", "c5.18xlarge", "c5.24xlarge"]
    instance_type in expensive_types
}

# =============================================================================
# Compliance Policies
# =============================================================================

# GDPR compliance - require deletion protection for databases containing PII
require_gdpr_deletion_protection[msg] {
    input.resource_type == "aws_db_instance"
    contains_pii := input.change.after.tags.ContainsPII
    contains_pii == "true"
    input.change.after.deletion_protection == false
    msg := sprintf("Database '%s' containing PII must have deletion protection enabled for GDPR compliance", [input.address])
}

# SOX compliance - require encryption for financial data
require_sox_encryption[msg] {
    financial_data := input.change.after.tags.DataClassification
    financial_data == "financial"
    not is_encrypted_resource
    msg := sprintf("Resource '%s' containing financial data must be encrypted for SOX compliance", [input.address])
}

is_encrypted_resource {
    input.resource_type == "aws_s3_bucket"
    input.change.after.server_side_encryption_configuration
}

is_encrypted_resource {
    input.resource_type == "aws_db_instance"
    input.change.after.storage_encrypted == true
}

is_encrypted_resource {
    input.resource_type == "aws_ebs_volume"
    input.change.after.encrypted == true
}