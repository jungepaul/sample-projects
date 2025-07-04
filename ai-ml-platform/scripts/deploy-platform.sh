#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
CLOUD_PROVIDER=""
ENVIRONMENT="dev"
APPLY_CHANGES=false
DEPLOY_INFRASTRUCTURE=false
DEPLOY_KUBEFLOW=false
DEPLOY_MLFLOW=false
DEPLOY_SERVING=false
DEPLOY_FEAST=false
DEPLOY_MONITORING=false
DEPLOY_ALL=false

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --provider PROVIDER    Cloud provider (aws, gcp, azure)"
    echo "  -e, --environment ENV      Environment (dev, staging, prod)"
    echo "  -a, --apply               Apply Terraform changes"
    echo "  --infrastructure          Deploy infrastructure only"
    echo "  --kubeflow               Deploy Kubeflow pipelines"
    echo "  --mlflow                 Deploy MLflow tracking"
    echo "  --serving                Deploy model serving (Seldon/KServe)"
    echo "  --feast                  Deploy Feast feature store"
    echo "  --monitoring             Deploy model monitoring"
    echo "  --all                    Deploy all components"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -p aws -e dev -a --all"
    echo "  $0 --provider gcp --environment prod --apply --infrastructure --mlflow"
    exit 1
}

check_dependencies() {
    log_step "Checking dependencies..."
    
    local required_tools=("terraform" "kubectl" "helm")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    # Check cloud CLI based on provider
    case $CLOUD_PROVIDER in
        aws)
            if ! command -v aws &> /dev/null; then
                missing_tools+=("aws")
            fi
            ;;
        gcp)
            if ! command -v gcloud &> /dev/null; then
                missing_tools+=("gcloud")
            fi
            ;;
        azure)
            if ! command -v az &> /dev/null; then
                missing_tools+=("az")
            fi
            ;;
    esac
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again"
        exit 1
    fi
    
    log_info "All dependencies satisfied"
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

deploy_infrastructure() {
    if [ "$DEPLOY_INFRASTRUCTURE" = true ] || [ "$DEPLOY_ALL" = true ]; then
        log_step "Deploying infrastructure for $CLOUD_PROVIDER..."
        
        local infra_dir="$PROJECT_ROOT/infrastructure/$CLOUD_PROVIDER"
        
        if [ ! -d "$infra_dir" ]; then
            log_error "Infrastructure directory not found: $infra_dir"
            exit 1
        fi
        
        cd "$infra_dir"
        
        # Initialize Terraform
        log_info "Initializing Terraform..."
        terraform init
        
        # Plan changes
        log_info "Planning Terraform changes..."
        terraform plan -var="environment=$ENVIRONMENT"
        
        if [ "$APPLY_CHANGES" = true ]; then
            # Apply changes
            log_info "Applying Terraform changes..."
            terraform apply -var="environment=$ENVIRONMENT" -auto-approve
            
            # Configure kubectl
            log_info "Configuring kubectl..."
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
            
            log_info "Infrastructure deployment completed"
        else
            log_warn "Dry run completed. Use -a/--apply to apply changes."
        fi
        
        cd "$PROJECT_ROOT"
    fi
}

deploy_kubeflow() {
    if [ "$DEPLOY_KUBEFLOW" = true ] || [ "$DEPLOY_ALL" = true ]; then
        log_step "Deploying Kubeflow pipelines..."
        
        # Create kubeflow namespace
        kubectl create namespace kubeflow --dry-run=client -o yaml | kubectl apply -f -
        
        # Deploy Argo Workflows (Kubeflow Pipelines backend)
        log_info "Installing Argo Workflows..."
        kubectl apply -n kubeflow -f https://github.com/argoproj/argo-workflows/releases/download/v3.4.11/install.yaml
        
        # Wait for Argo to be ready
        kubectl wait --for=condition=available --timeout=300s deployment/argo-server -n kubeflow
        
        # Apply pipeline components
        log_info "Deploying pipeline components..."
        kubectl apply -f "$PROJECT_ROOT/kubeflow/components/"
        
        # Apply sample pipelines
        log_info "Deploying sample pipelines..."
        kubectl apply -f "$PROJECT_ROOT/kubeflow/pipelines/"
        
        log_info "Kubeflow deployment completed"
    fi
}

deploy_mlflow() {
    if [ "$DEPLOY_MLFLOW" = true ] || [ "$DEPLOY_ALL" = true ]; then
        log_step "Deploying MLflow tracking and registry..."
        
        # Create mlflow namespace
        kubectl create namespace mlflow --dry-run=client -o yaml | kubectl apply -f -
        
        # Deploy MLflow components
        log_info "Deploying MLflow server and database..."
        kubectl apply -f "$PROJECT_ROOT/mlflow/tracking/mlflow-deployment.yaml"
        
        # Wait for PostgreSQL to be ready
        kubectl wait --for=condition=ready --timeout=300s pod -l app=postgres -n mlflow
        
        # Wait for MLflow server to be ready
        kubectl wait --for=condition=available --timeout=300s deployment/mlflow-server -n mlflow
        
        # Deploy model registry configuration
        log_info "Configuring model registry..."
        kubectl apply -f "$PROJECT_ROOT/mlflow/registry/model-registry-config.yaml"
        
        log_info "MLflow deployment completed"
    fi
}

deploy_serving() {
    if [ "$DEPLOY_SERVING" = true ] || [ "$DEPLOY_ALL" = true ]; then
        log_step "Deploying model serving infrastructure..."
        
        # Deploy Seldon Core
        log_info "Deploying Seldon Core..."
        kubectl create namespace seldon-system --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -f "$PROJECT_ROOT/serving/seldon/seldon-deployment.yaml"
        
        # Deploy KServe
        log_info "Deploying KServe..."
        kubectl create namespace kserve --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -f "$PROJECT_ROOT/serving/kserve/kserve-deployment.yaml"
        
        # Wait for deployments
        kubectl wait --for=condition=available --timeout=300s deployment/seldon-core-operator -n seldon-system || true
        
        log_info "Model serving deployment completed"
    fi
}

deploy_feast() {
    if [ "$DEPLOY_FEAST" = true ] || [ "$DEPLOY_ALL" = true ]; then
        log_step "Deploying Feast feature store..."
        
        # Create feast namespace
        kubectl create namespace feast --dry-run=client -o yaml | kubectl apply -f -
        
        # Deploy Redis for online store
        log_info "Deploying Redis online store..."
        kubectl apply -f "$PROJECT_ROOT/feast/feature-store/feast-deployment.yaml"
        
        # Wait for Redis to be ready
        kubectl wait --for=condition=ready --timeout=300s pod -l app=redis -n feast
        
        # Wait for Feast serving to be ready
        kubectl wait --for=condition=available --timeout=300s deployment/feast-serving -n feast
        
        # Initialize feature store
        log_info "Initializing feature store..."
        kubectl wait --for=condition=complete --timeout=300s job/feast-init -n feast
        
        log_info "Feast deployment completed"
    fi
}

deploy_monitoring() {
    if [ "$DEPLOY_MONITORING" = true ] || [ "$DEPLOY_ALL" = true ]; then
        log_step "Deploying model monitoring..."
        
        # Create monitoring namespace
        kubectl create namespace ml-monitoring --dry-run=client -o yaml | kubectl apply -f -
        
        # Deploy Evidently monitoring service
        log_info "Deploying Evidently monitoring..."
        kubectl apply -f "$PROJECT_ROOT/monitoring/evidently/model-monitoring.yaml"
        
        # Wait for Evidently service to be ready
        kubectl wait --for=condition=available --timeout=300s deployment/evidently-service -n ml-monitoring
        
        log_info "Model monitoring deployment completed"
    fi
}

setup_ingress() {
    log_step "Setting up ingress and networking..."
    
    # Install NGINX ingress controller if not present
    if ! kubectl get namespace ingress-nginx &> /dev/null; then
        log_info "Installing NGINX ingress controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
        
        # Wait for ingress controller to be ready
        kubectl wait --namespace ingress-nginx \
          --for=condition=ready pod \
          --selector=app.kubernetes.io/component=controller \
          --timeout=300s
    fi
    
    log_info "Ingress setup completed"
}

verify_deployment() {
    log_step "Verifying deployment..."
    
    # Check cluster status
    log_info "Checking cluster status..."
    kubectl get nodes
    
    # Check all namespaces
    log_info "Checking deployed components..."
    kubectl get pods --all-namespaces | grep -E "(kubeflow|mlflow|seldon-system|kserve|feast|ml-monitoring)"
    
    # Check services
    log_info "Checking services..."
    kubectl get services --all-namespaces | grep -E "(mlflow|seldon|kserve|feast|evidently)"
    
    # Check ingresses
    log_info "Checking ingresses..."
    kubectl get ingress --all-namespaces
    
    log_info "Deployment verification completed"
}

display_access_info() {
    log_step "Access Information"
    
    echo ""
    echo "🎉 AI/ML Platform deployment completed successfully!"
    echo ""
    echo "Access URLs (update /etc/hosts or use port-forwarding):"
    echo ""
    
    if [ "$DEPLOY_MLFLOW" = true ] || [ "$DEPLOY_ALL" = true ]; then
        echo "📊 MLflow Tracking Server:"
        echo "   http://mlflow.local (or kubectl port-forward -n mlflow svc/mlflow-server 5000:5000)"
        echo ""
    fi
    
    if [ "$DEPLOY_SERVING" = true ] || [ "$DEPLOY_ALL" = true ]; then
        echo "🚀 Model Serving:"
        echo "   Seldon Core: http://seldon.local"
        echo "   KServe: http://kserve.local"
        echo ""
    fi
    
    if [ "$DEPLOY_FEAST" = true ] || [ "$DEPLOY_ALL" = true ]; then
        echo "🍽️ Feast Feature Store:"
        echo "   http://feast.local (or kubectl port-forward -n feast svc/feast-serving-service 6566:6566)"
        echo ""
    fi
    
    if [ "$DEPLOY_MONITORING" = true ] || [ "$DEPLOY_ALL" = true ]; then
        echo "📈 Model Monitoring:"
        echo "   http://monitoring.local (or kubectl port-forward -n ml-monitoring svc/evidently-service 8501:8501)"
        echo ""
    fi
    
    if [ "$DEPLOY_KUBEFLOW" = true ] || [ "$DEPLOY_ALL" = true ]; then
        echo "🔄 Kubeflow Pipelines:"
        echo "   kubectl port-forward -n kubeflow svc/argo-server 2746:2746"
        echo "   Then access: https://localhost:2746"
        echo ""
    fi
    
    echo "📚 Useful Commands:"
    echo "   kubectl get pods --all-namespaces"
    echo "   kubectl logs -f deployment/mlflow-server -n mlflow"
    echo "   kubectl get inferenceservices -n kserve"
    echo ""
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
            --infrastructure)
                DEPLOY_INFRASTRUCTURE=true
                shift
                ;;
            --kubeflow)
                DEPLOY_KUBEFLOW=true
                shift
                ;;
            --mlflow)
                DEPLOY_MLFLOW=true
                shift
                ;;
            --serving)
                DEPLOY_SERVING=true
                shift
                ;;
            --feast)
                DEPLOY_FEAST=true
                shift
                ;;
            --monitoring)
                DEPLOY_MONITORING=true
                shift
                ;;
            --all)
                DEPLOY_ALL=true
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
    
    # Deploy components
    deploy_infrastructure
    
    if [ "$APPLY_CHANGES" = true ]; then
        setup_ingress
        deploy_kubeflow
        deploy_mlflow
        deploy_serving
        deploy_feast
        deploy_monitoring
        
        # Wait a bit for everything to settle
        sleep 10
        
        verify_deployment
        display_access_info
    else
        log_warn "Dry run completed. Use -a/--apply to apply changes."
    fi
}

# Run main function
main "$@"