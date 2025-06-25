#!/bin/bash

# Deploy GKE Cluster for Ontoserver
# This script creates the GKE cluster using Terraform

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TERRAFORM_DIR="../terraform"
TFVARS_FILE="terraform.tfvars"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v gcloud &> /dev/null; then
        missing_tools+=("gcloud")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed."
}

# Function to check if tfvars file exists
check_tfvars() {
    if [ ! -f "$TERRAFORM_DIR/$TFVARS_FILE" ]; then
        print_error "Terraform variables file not found: $TERRAFORM_DIR/$TFVARS_FILE"
        print_error "Please create this file with your configuration. Example:"
        print_error "project_id = \"your-project-id\""
        print_error "database_password = \"your-secure-password\""
        print_error "domain_name = \"your-domain.com\"  # Optional"
        exit 1
    fi
}

# Function to initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Get project ID from tfvars
    PROJECT_ID=$(grep -E '^project_id\s*=' "$TFVARS_FILE" | cut -d'"' -f2)
    
    if [ -z "$PROJECT_ID" ]; then
        print_error "Could not find project_id in $TFVARS_FILE"
        exit 1
    fi
    
    # Initialize with GCS backend
    terraform init -backend-config="bucket=${PROJECT_ID}-terraform-state" -reconfigure
    
    print_success "Terraform initialized successfully."
}

# Function to plan Terraform deployment
plan_terraform() {
    print_status "Planning Terraform deployment..."
    
    terraform plan -var-file="$TFVARS_FILE" -input=false -out=tfplan
    
    print_success "Terraform plan completed successfully."
}

# Function to apply Terraform deployment
apply_terraform() {
    print_status "Applying Terraform deployment..."
    print_warning "This will create GCP resources and may incur costs."
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled."
        exit 0
    fi
    
    terraform apply tfplan
    
    print_success "Terraform deployment completed successfully."
}

# Function to configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl..."
    
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    CLUSTER_LOCATION=$(terraform output -raw cluster_location)
    PROJECT_ID=$(grep -E '^project_id\s*=' "$TFVARS_FILE" | cut -d'"' -f2)
    
    gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --location="$CLUSTER_LOCATION" \
        --project="$PROJECT_ID"
    
    print_success "kubectl configured successfully."
}

# Function to display cluster information
display_cluster_info() {
    print_status "Cluster Information:"
    echo "===================="
    
    echo "Cluster Name: $(terraform output -raw cluster_name)"
    echo "Cluster Location: $(terraform output -raw cluster_location)"
    echo "Database Private IP: $(terraform output -raw database_private_ip)"
    echo "Artifact Registry URL: $(terraform output -raw artifact_registry_url)"
    
    if terraform output ingress_ip > /dev/null 2>&1; then
        INGRESS_IP=$(terraform output -raw ingress_ip)
        if [ "$INGRESS_IP" != "null" ]; then
            echo "Ingress IP: $INGRESS_IP"
        fi
    fi
    
    echo "===================="
}

# Function to show next steps
show_next_steps() {
    print_status "Next Steps:"
    echo "1. Update the Kubernetes manifests in ../k8s/ with your specific values:"
    echo "   - Replace PROJECT_ID in deployment.yaml"
    echo "   - Replace POSTGRESQL_IP with: $(terraform output -raw database_private_ip)"
    echo "   - Update domain in ingress.yaml if using custom domain"
    echo ""
    echo "2. Create database secrets:"
    echo "   kubectl create secret generic ontoserver-db-secret \\"
    echo "     --from-literal=username=ontoserver \\"
    echo "     --from-literal=password=YOUR_DB_PASSWORD \\"
    echo "     --namespace=ontoserver"
    echo ""
    echo "3. Deploy Ontoserver to Kubernetes:"
    echo "   ./deploy-ontoserver-k8s.sh"
    echo ""
    echo "4. To access the cluster:"
    echo "   kubectl get pods -n ontoserver"
}

# Main execution
main() {
    print_status "Starting GKE cluster deployment for Ontoserver..."
    
    check_prerequisites
    check_tfvars
    init_terraform
    plan_terraform
    apply_terraform
    configure_kubectl
    display_cluster_info
    show_next_steps
    
    print_success "GKE cluster deployment completed successfully!"
}

# Check if running from correct directory
if [ ! -d "$TERRAFORM_DIR" ]; then
    print_error "Terraform directory not found. Please run this script from the scripts directory."
    exit 1
fi

# Run main function
main "$@"