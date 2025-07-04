#!/bin/bash

# Infrastructure as Code Framework Deployment Script
# This script provides a unified interface for deploying and managing infrastructure

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/deployment.yaml"
LOG_FILE="${PROJECT_ROOT}/logs/deployment.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
MODULE=""
ACTION="plan"
AUTO_APPROVE=false
DESTROY=false
VERBOSE=false
DRY_RUN=false
PARALLEL=false

# Usage function
usage() {
    cat << EOF
Infrastructure as Code Framework Deployment Script

Usage: $0 [OPTIONS] [MODULE]

OPTIONS:
    -e, --environment ENV    Target environment (dev, staging, prod) [default: dev]
    -a, --action ACTION      Terraform action (plan, apply, destroy) [default: plan]
    -m, --module MODULE      Specific module to deploy (vpc, ec2, all)
    --auto-approve          Auto-approve Terraform apply
    --destroy               Destroy infrastructure
    --dry-run              Show what would be done without executing
    --parallel             Run operations in parallel where possible
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

MODULES:
    vpc                     Deploy VPC infrastructure
    ec2                     Deploy EC2 instances
    all                     Deploy all modules

EXAMPLES:
    $0 --environment dev --action plan --module vpc
    $0 -e staging -a apply -m all --auto-approve
    $0 --environment prod --destroy --module ec2
    $0 --dry-run --environment dev --module all

ENVIRONMENT VARIABLES:
    AWS_PROFILE            AWS profile to use
    AWS_REGION             AWS region to deploy to
    TF_STATE_BUCKET        S3 bucket for Terraform state
    TF_STATE_LOCK_TABLE    DynamoDB table for state locking
    TF_LOG                 Terraform log level
EOF
}

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $*${NC}" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*${NC}" | tee -a "$LOG_FILE"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -a|--action)
                ACTION="$2"
                shift 2
                ;;
            -m|--module)
                MODULE="$2"
                shift 2
                ;;
            --auto-approve)
                AUTO_APPROVE=true
                shift
                ;;
            --destroy)
                DESTROY=true
                ACTION="destroy"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --parallel)
                PARALLEL=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                if [[ -z "$MODULE" ]]; then
                    MODULE="$1"
                else
                    log_error "Unknown option: $1"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Validate environment
validate_environment() {
    log_info "Validating environment: $ENVIRONMENT"
    
    case $ENVIRONMENT in
        dev|staging|prod)
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT. Must be one of: dev, staging, prod"
            exit 1
            ;;
    esac
    
    # Check if environment configuration exists
    local env_config="${PROJECT_ROOT}/environments/${ENVIRONMENT}"
    if [[ ! -d "$env_config" ]]; then
        log_error "Environment configuration not found: $env_config"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check required tools
    local required_tools=("terraform" "aws" "jq" "yq")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "Required tool not found: $tool"
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    # Check Terraform version
    local tf_version
    tf_version=$(terraform version -json | jq -r '.terraform_version')
    log_info "Using Terraform version: $tf_version"
    
    # Check required environment variables
    local required_vars=("AWS_REGION")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable not set: $var"
            exit 1
        fi
    done
}

# Initialize Terraform backend
init_terraform() {
    local module_path="$1"
    log_info "Initializing Terraform for module: $(basename "$module_path")"
    
    cd "$module_path"
    
    # Create backend configuration
    local backend_config="backend-${ENVIRONMENT}.hcl"
    cat > "$backend_config" << EOF
bucket         = "${TF_STATE_BUCKET:-iac-framework-terraform-state-${ENVIRONMENT}}"
key            = "${ENVIRONMENT}/$(basename "$module_path")/terraform.tfstate"
region         = "${AWS_REGION}"
dynamodb_table = "${TF_STATE_LOCK_TABLE:-iac-framework-terraform-locks}"
encrypt        = true
EOF
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would initialize Terraform with backend config: $backend_config"
        return 0
    fi
    
    # Initialize with backend configuration
    terraform init -backend-config="$backend_config" -reconfigure
    
    # Select or create workspace
    terraform workspace select "$ENVIRONMENT" 2>/dev/null || terraform workspace new "$ENVIRONMENT"
    
    cd - >/dev/null
}

# Run Terraform plan
terraform_plan() {
    local module_path="$1"
    local plan_file="$2"
    
    log_info "Planning Terraform for module: $(basename "$module_path")"
    
    cd "$module_path"
    
    local tf_vars_file="${PROJECT_ROOT}/environments/${ENVIRONMENT}/terraform.tfvars"
    local additional_vars=""
    
    # Add common variables
    additional_vars+="-var environment=${ENVIRONMENT} "
    additional_vars+="-var project_name=iac-framework "
    additional_vars+="-var aws_region=${AWS_REGION} "
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would run terraform plan with vars file: $tf_vars_file"
        cd - >/dev/null
        return 0
    fi
    
    # Run plan
    terraform plan \
        -var-file="$tf_vars_file" \
        $additional_vars \
        -out="$plan_file" \
        ${VERBOSE:+-json | jq '.'}
    
    cd - >/dev/null
}

# Run Terraform apply
terraform_apply() {
    local module_path="$1"
    local plan_file="$2"
    
    log_info "Applying Terraform for module: $(basename "$module_path")"
    
    cd "$module_path"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would run terraform apply with plan file: $plan_file"
        cd - >/dev/null
        return 0
    fi
    
    local apply_args=""
    if [[ "$AUTO_APPROVE" == true ]]; then
        apply_args="-auto-approve"
    fi
    
    terraform apply $apply_args "$plan_file"
    
    cd - >/dev/null
}

# Run Terraform destroy
terraform_destroy() {
    local module_path="$1"
    
    log_warn "Destroying Terraform for module: $(basename "$module_path")"
    
    cd "$module_path"
    
    local tf_vars_file="${PROJECT_ROOT}/environments/${ENVIRONMENT}/terraform.tfvars"
    local additional_vars=""
    
    # Add common variables
    additional_vars+="-var environment=${ENVIRONMENT} "
    additional_vars+="-var project_name=iac-framework "
    additional_vars+="-var aws_region=${AWS_REGION} "
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would run terraform destroy with vars file: $tf_vars_file"
        cd - >/dev/null
        return 0
    fi
    
    # Confirm destruction unless auto-approved
    if [[ "$AUTO_APPROVE" != true ]]; then
        read -p "Are you sure you want to destroy infrastructure in $ENVIRONMENT? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Destruction cancelled"
            cd - >/dev/null
            return 0
        fi
    fi
    
    terraform destroy \
        -var-file="$tf_vars_file" \
        $additional_vars \
        ${AUTO_APPROVE:+-auto-approve}
    
    cd - >/dev/null
}

# Deploy a single module
deploy_module() {
    local module_name="$1"
    local module_path="${PROJECT_ROOT}/modules/aws/${module_name}"
    
    if [[ ! -d "$module_path" ]]; then
        log_error "Module not found: $module_path"
        return 1
    fi
    
    log_info "Deploying module: $module_name"
    
    # Create logs directory
    mkdir -p "${PROJECT_ROOT}/logs"
    
    # Initialize Terraform
    init_terraform "$module_path"
    
    if [[ "$DESTROY" == true ]]; then
        terraform_destroy "$module_path"
    else
        # Plan
        local plan_file="${PROJECT_ROOT}/logs/${module_name}-${ENVIRONMENT}.tfplan"
        terraform_plan "$module_path" "$plan_file"
        
        # Apply if requested
        if [[ "$ACTION" == "apply" ]]; then
            terraform_apply "$module_path" "$plan_file"
        fi
    fi
}

# Deploy multiple modules
deploy_modules() {
    local modules=("$@")
    
    if [[ "$PARALLEL" == true && ${#modules[@]} -gt 1 ]]; then
        log_info "Deploying modules in parallel: ${modules[*]}"
        
        local pids=()
        for module in "${modules[@]}"; do
            deploy_module "$module" &
            pids+=($!)
        done
        
        # Wait for all background jobs
        for pid in "${pids[@]}"; do
            if ! wait "$pid"; then
                log_error "Module deployment failed (PID: $pid)"
                return 1
            fi
        done
    else
        log_info "Deploying modules sequentially: ${modules[*]}"
        for module in "${modules[@]}"; do
            deploy_module "$module"
        done
    fi
}

# Run security checks
run_security_checks() {
    log_info "Running security checks..."
    
    local modules_dir="${PROJECT_ROOT}/modules/aws"
    
    # Run Checkov
    if command -v checkov >/dev/null 2>&1; then
        log_info "Running Checkov security scan..."
        if [[ "$DRY_RUN" == true ]]; then
            log_info "DRY RUN: Would run Checkov on $modules_dir"
        else
            checkov -d "$modules_dir" --framework terraform || log_warn "Checkov found issues"
        fi
    fi
    
    # Run TFSec
    if command -v tfsec >/dev/null 2>&1; then
        log_info "Running TFSec security scan..."
        if [[ "$DRY_RUN" == true ]]; then
            log_info "DRY RUN: Would run TFSec on $modules_dir"
        else
            tfsec "$modules_dir" || log_warn "TFSec found issues"
        fi
    fi
    
    # Run Semgrep
    if command -v semgrep >/dev/null 2>&1; then
        log_info "Running Semgrep security scan..."
        if [[ "$DRY_RUN" == true ]]; then
            log_info "DRY RUN: Would run Semgrep on $modules_dir"
        else
            semgrep --config="${PROJECT_ROOT}/security/semgrep/semgrep-rules.yaml" "$modules_dir" || log_warn "Semgrep found issues"
        fi
    fi
}

# Run cost estimation
run_cost_estimation() {
    log_info "Running cost estimation..."
    
    if command -v infracost >/dev/null 2>&1; then
        local config_file="${PROJECT_ROOT}/cost-optimization/infracost/infracost-config.yml"
        if [[ "$DRY_RUN" == true ]]; then
            log_info "DRY RUN: Would run Infracost with config: $config_file"
        else
            infracost breakdown --config-file="$config_file"
        fi
    else
        log_warn "Infracost not available, skipping cost estimation"
    fi
}

# Generate deployment report
generate_report() {
    log_info "Generating deployment report..."
    
    local report_file="${PROJECT_ROOT}/logs/deployment-report-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "deployment": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "environment": "$ENVIRONMENT",
    "module": "$MODULE",
    "action": "$ACTION",
    "auto_approve": $AUTO_APPROVE,
    "destroy": $DESTROY,
    "dry_run": $DRY_RUN,
    "parallel": $PARALLEL
  },
  "aws": {
    "region": "${AWS_REGION}",
    "account_id": "$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'unknown')",
    "caller_identity": "$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo 'unknown')"
  },
  "terraform": {
    "version": "$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo 'unknown')"
  }
}
EOF
    
    log_info "Deployment report saved to: $report_file"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    
    # Remove plan files older than 7 days
    find "${PROJECT_ROOT}/logs" -name "*.tfplan" -mtime +7 -delete 2>/dev/null || true
    
    # Remove old log files (keep last 30 days)
    find "${PROJECT_ROOT}/logs" -name "*.log" -mtime +30 -delete 2>/dev/null || true
}

# Main function
main() {
    # Create logs directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log_info "Starting IAC Framework deployment script"
    log_info "Environment: $ENVIRONMENT, Module: $MODULE, Action: $ACTION"
    
    # Parse arguments
    parse_args "$@"
    
    # Validate inputs
    validate_environment
    check_prerequisites
    
    # Determine modules to deploy
    local modules_to_deploy=()
    case "$MODULE" in
        "vpc")
            modules_to_deploy=("vpc")
            ;;
        "ec2")
            modules_to_deploy=("ec2")
            ;;
        "all"|"")
            modules_to_deploy=("vpc" "ec2")
            ;;
        *)
            log_error "Unknown module: $MODULE"
            exit 1
            ;;
    esac
    
    # Run pre-deployment checks
    if [[ "$ACTION" != "destroy" ]]; then
        run_security_checks
        run_cost_estimation
    fi
    
    # Deploy modules
    deploy_modules "${modules_to_deploy[@]}"
    
    # Generate report
    generate_report
    
    # Cleanup
    cleanup
    
    log "Deployment completed successfully!"
}

# Signal handlers
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Run main function with all arguments
main "$@"