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

# Default values
CLOUD_PROVIDER=""
ENVIRONMENT="dev"
FORCE_DESTROY=false
SKIP_CONFIRMATION=false

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
    echo "  -f, --force               Force destroy without confirmation"
    echo "  -y, --yes                 Skip confirmation prompts"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -p aws -e dev"
    echo "  $0 --provider gcp --environment prod --force"
    exit 1
}

confirm_destroy() {
    if [ "$SKIP_CONFIRMATION" = true ]; then
        return 0
    fi
    
    echo ""
    log_warn "⚠️  WARNING: This will destroy all resources for $CLOUD_PROVIDER-$ENVIRONMENT"
    log_warn "⚠️  This action cannot be undone!"
    echo ""
    
    read -p "Are you sure you want to proceed? (type 'yes' to confirm): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        log_info "Destruction cancelled by user"
        exit 0
    fi
}

validate_provider() {
    case $CLOUD_PROVIDER in
        aws|gcp|azure)
            log_info "Targeting cloud provider: $CLOUD_PROVIDER"
            ;;
        *)
            log_error "Invalid cloud provider: $CLOUD_PROVIDER"
            log_error "Supported providers: aws, gcp, azure"
            exit 1
            ;;
    esac
}

destroy_shared_resources() {
    log_info "Destroying shared resources..."
    
    # Destroy Istio if it exists
    if [ -d "$PROJECT_ROOT/shared/modules/istio/.terraform" ]; then
        log_info "Destroying Istio service mesh..."
        terraform -chdir="$PROJECT_ROOT/shared/modules/istio" destroy -auto-approve -var="cluster_name=$CLOUD_PROVIDER-cluster" || true
    fi
    
    # Destroy monitoring if it exists
    if [ -d "$PROJECT_ROOT/shared/modules/monitoring/.terraform" ]; then
        log_info "Destroying monitoring stack..."
        terraform -chdir="$PROJECT_ROOT/shared/modules/monitoring" destroy -auto-approve || true
    fi
    
    log_info "Shared resources destroyed"
}

destroy_infrastructure() {
    local provider_dir="$PROJECT_ROOT/$CLOUD_PROVIDER"
    local tfvars_file="$PROJECT_ROOT/shared/configs/common.tfvars"
    
    log_info "Destroying infrastructure for $CLOUD_PROVIDER..."
    
    cd "$provider_dir"
    
    # Check if Terraform state exists
    if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
        log_warn "No Terraform state found. Nothing to destroy."
        return 0
    fi
    
    # Run terraform destroy
    terraform destroy -var-file="$tfvars_file" -var="environment=$ENVIRONMENT" -auto-approve
    
    if [ $? -ne 0 ]; then
        log_error "Failed to destroy infrastructure"
        exit 1
    fi
    
    log_info "Infrastructure destroyed successfully"
}

cleanup_terraform_state() {
    local provider_dir="$PROJECT_ROOT/$CLOUD_PROVIDER"
    
    log_info "Cleaning up Terraform state files..."
    
    cd "$provider_dir"
    
    # Remove state files if they exist
    if [ -f "terraform.tfstate" ]; then
        rm -f terraform.tfstate
        rm -f terraform.tfstate.backup
        log_info "Removed local state files"
    fi
    
    # Clean up .terraform directory
    if [ -d ".terraform" ]; then
        rm -rf .terraform
        log_info "Removed .terraform directory"
    fi
    
    # Clean up shared modules state
    for module_dir in "$PROJECT_ROOT/shared/modules"/*; do
        if [ -d "$module_dir/.terraform" ]; then
            rm -rf "$module_dir/.terraform"
            log_info "Cleaned up $(basename "$module_dir") module state"
        fi
    done
}

remove_kubeconfig() {
    log_info "Removing kubeconfig entries..."
    
    case $CLOUD_PROVIDER in
        aws)
            local cluster_name="multicloud-platform-eks-$ENVIRONMENT"
            kubectl config delete-context "$cluster_name" 2>/dev/null || true
            kubectl config delete-cluster "$cluster_name" 2>/dev/null || true
            kubectl config delete-user "$cluster_name" 2>/dev/null || true
            ;;
        gcp)
            local cluster_name="multicloud-platform-gke-$ENVIRONMENT"
            kubectl config delete-context "$cluster_name" 2>/dev/null || true
            kubectl config delete-cluster "$cluster_name" 2>/dev/null || true
            kubectl config delete-user "$cluster_name" 2>/dev/null || true
            ;;
        azure)
            local cluster_name="multicloud-platform-aks-$ENVIRONMENT"
            kubectl config delete-context "$cluster_name" 2>/dev/null || true
            kubectl config delete-cluster "$cluster_name" 2>/dev/null || true
            kubectl config delete-user "$cluster_name" 2>/dev/null || true
            ;;
    esac
    
    log_info "Kubeconfig entries removed"
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
            -f|--force)
                FORCE_DESTROY=true
                shift
                ;;
            -y|--yes)
                SKIP_CONFIRMATION=true
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
    
    # Main destruction flow
    validate_provider
    
    if [ "$FORCE_DESTROY" = false ]; then
        confirm_destroy
    fi
    
    destroy_shared_resources
    destroy_infrastructure
    cleanup_terraform_state
    remove_kubeconfig
    
    log_info "🎉 Destruction completed successfully!"
    log_info "All resources for $CLOUD_PROVIDER-$ENVIRONMENT have been destroyed"
}

# Run main function
main "$@"