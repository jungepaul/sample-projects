#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_VERSION="1.0.0"

# Default values
CLOUD_PROVIDER=""
ENVIRONMENT="dev"
APPLY_CHANGES=false
INSTALL_MONITORING=false
INSTALL_ISTIO=false

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --provider PROVIDER    Cloud provider (aws, gcp, azure)"
    echo "  -e, --environment ENV      Environment (dev, staging, prod)"
    echo "  -a, --apply               Apply Terraform changes"
    echo "  -m, --monitoring          Install monitoring stack"
    echo "  -i, --istio               Install Istio service mesh"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -p aws -e dev -a -m -i"
    echo "  $0 --provider gcp --environment prod --apply"
    exit 1
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform >= $TERRAFORM_VERSION"
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl"
        exit 1
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed. Please install Helm"
        exit 1
    fi
    
    # Check cloud CLI based on provider
    case $CLOUD_PROVIDER in
        aws)
            if ! command -v aws &> /dev/null; then
                log_error "AWS CLI is not installed. Please install AWS CLI"
                exit 1
            fi
            ;;
        gcp)
            if ! command -v gcloud &> /dev/null; then
                log_error "gcloud CLI is not installed. Please install Google Cloud CLI"
                exit 1
            fi
            ;;
        azure)
            if ! command -v az &> /dev/null; then
                log_error "Azure CLI is not installed. Please install Azure CLI"
                exit 1
            fi
            ;;
    esac
    
    log_info "All dependencies are satisfied"
}

validate_provider() {
    case $CLOUD_PROVIDER in
        aws|gcp|azure)
            log_info "Using cloud provider: $CLOUD_PROVIDER"
            ;;
        *)
            log_error "Invalid cloud provider: $CLOUD_PROVIDER"
            log_error "Supported providers: aws, gcp, azure"
            exit 1
            ;;
    esac
}

init_terraform() {
    local provider_dir="$PROJECT_ROOT/$CLOUD_PROVIDER"
    
    log_info "Initializing Terraform for $CLOUD_PROVIDER..."
    
    cd "$provider_dir"
    
    terraform init
    
    if [ $? -ne 0 ]; then
        log_error "Failed to initialize Terraform"
        exit 1
    fi
    
    log_info "Terraform initialized successfully"
}

plan_terraform() {
    local provider_dir="$PROJECT_ROOT/$CLOUD_PROVIDER"
    local tfvars_file="$PROJECT_ROOT/shared/configs/common.tfvars"
    
    log_info "Planning Terraform changes for $CLOUD_PROVIDER..."
    
    cd "$provider_dir"
    
    terraform plan -var-file="$tfvars_file" -var="environment=$ENVIRONMENT"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to plan Terraform changes"
        exit 1
    fi
    
    log_info "Terraform plan completed successfully"
}

apply_terraform() {
    local provider_dir="$PROJECT_ROOT/$CLOUD_PROVIDER"
    local tfvars_file="$PROJECT_ROOT/shared/configs/common.tfvars"
    
    log_info "Applying Terraform changes for $CLOUD_PROVIDER..."
    
    cd "$provider_dir"
    
    terraform apply -var-file="$tfvars_file" -var="environment=$ENVIRONMENT" -auto-approve
    
    if [ $? -ne 0 ]; then
        log_error "Failed to apply Terraform changes"
        exit 1
    fi
    
    log_info "Terraform apply completed successfully"
}

configure_kubectl() {
    local provider_dir="$PROJECT_ROOT/$CLOUD_PROVIDER"
    
    log_info "Configuring kubectl for $CLOUD_PROVIDER..."
    
    cd "$provider_dir"
    
    case $CLOUD_PROVIDER in
        aws)
            local cluster_name=$(terraform output -raw cluster_name)
            local region=$(terraform output -raw aws_region 2>/dev/null || echo "us-west-2")
            aws eks update-kubeconfig --region "$region" --name "$cluster_name"
            ;;
        gcp)
            local cluster_name=$(terraform output -raw cluster_name)
            local region=$(terraform output -raw gcp_region 2>/dev/null || echo "us-central1")
            local project_id=$(terraform output -raw gcp_project_id 2>/dev/null)
            gcloud container clusters get-credentials "$cluster_name" --region "$region" --project "$project_id"
            ;;
        azure)
            local cluster_name=$(terraform output -raw cluster_name)
            local resource_group=$(terraform output -raw resource_group_name)
            az aks get-credentials --resource-group "$resource_group" --name "$cluster_name"
            ;;
    esac
    
    if [ $? -ne 0 ]; then
        log_error "Failed to configure kubectl"
        exit 1
    fi
    
    log_info "kubectl configured successfully"
}

install_monitoring_stack() {
    if [ "$INSTALL_MONITORING" = true ]; then
        log_info "Installing monitoring stack..."
        
        # Apply monitoring module
        terraform -chdir="$PROJECT_ROOT/shared/modules/monitoring" init
        terraform -chdir="$PROJECT_ROOT/shared/modules/monitoring" apply -auto-approve
        
        if [ $? -ne 0 ]; then
            log_error "Failed to install monitoring stack"
            exit 1
        fi
        
        log_info "Monitoring stack installed successfully"
    fi
}

install_istio_mesh() {
    if [ "$INSTALL_ISTIO" = true ]; then
        log_info "Installing Istio service mesh..."
        
        # Apply Istio module
        terraform -chdir="$PROJECT_ROOT/shared/modules/istio" init
        terraform -chdir="$PROJECT_ROOT/shared/modules/istio" apply -auto-approve -var="cluster_name=$CLOUD_PROVIDER-cluster"
        
        if [ $? -ne 0 ]; then
            log_error "Failed to install Istio service mesh"
            exit 1
        fi
        
        log_info "Istio service mesh installed successfully"
    fi
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--provider)
                CLOUD_PROVIDER="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -a|--apply)
                APPLY_CHANGES=true
                shift
                ;;
            -m|--monitoring)
                INSTALL_MONITORING=true
                shift
                ;;
            -i|--istio)
                INSTALL_ISTIO=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$CLOUD_PROVIDER" ]; then
        log_error "Cloud provider is required"
        usage
    fi
    
    # Main deployment flow
    validate_provider
    check_dependencies
    init_terraform
    plan_terraform
    
    if [ "$APPLY_CHANGES" = true ]; then
        apply_terraform
        configure_kubectl
        install_monitoring_stack
        install_istio_mesh
        
        log_info "Deployment completed successfully!"
        log_info "Cluster: $CLOUD_PROVIDER-$ENVIRONMENT"
        log_info "Environment: $ENVIRONMENT"
        
        if [ "$INSTALL_MONITORING" = true ]; then
            log_info "Monitoring stack: Installed"
        fi
        
        if [ "$INSTALL_ISTIO" = true ]; then
            log_info "Istio service mesh: Installed"
        fi
    else
        log_warn "Dry run completed. Use -a/--apply to apply changes."
    fi
}

# Run main function
main "$@"