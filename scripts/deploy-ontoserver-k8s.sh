#!/bin/bash

# Deploy Ontoserver to Kubernetes (GKE)
# This script deploys Ontoserver using the Kubernetes manifests

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
K8S_DIR="../k8s"
TERRAFORM_DIR="../terraform"
NAMESPACE="ontoserver"
IMAGE_TAG="ctsa-6"

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
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v gcloud &> /dev/null; then
        missing_tools+=("gcloud")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Check if kubectl is configured
    if ! kubectl cluster-info &> /dev/null; then
        print_error "kubectl is not configured or cluster is not accessible"
        print_error "Please run ./deploy-gke-cluster.sh first"
        exit 1
    fi
    
    print_success "All prerequisites are met."
}

# Function to get Terraform outputs
get_terraform_outputs() {
    print_status "Getting Terraform outputs..."
    
    cd "$TERRAFORM_DIR"
    
    PROJECT_ID=$(terraform output -raw cluster_name | cut -d'-' -f1)
    DATABASE_IP=$(terraform output -raw database_private_ip)
    ARTIFACT_REGISTRY_URL=$(terraform output -raw artifact_registry_url)
    
    if [ -z "$PROJECT_ID" ] || [ -z "$DATABASE_IP" ] || [ -z "$ARTIFACT_REGISTRY_URL" ]; then
        print_error "Could not get required Terraform outputs"
        print_error "Please ensure Terraform has been applied successfully"
        exit 1
    fi
    
    cd - > /dev/null
    
    print_success "Retrieved Terraform outputs successfully."
}

# Function to update Kubernetes manifests
update_manifests() {
    print_status "Updating Kubernetes manifests..."
    
    # Create temporary directory for processed manifests
    TEMP_DIR=$(mktemp -d)
    cp -r "$K8S_DIR"/* "$TEMP_DIR/"
    
    # Update deployment.yaml with actual values
    sed -i.bak \
        -e "s/PROJECT_ID/${PROJECT_ID}/g" \
        -e "s/POSTGRESQL_IP/${DATABASE_IP}/g" \
        "$TEMP_DIR/deployment.yaml"
    
    # Update PVC to use standard-rwo (ReadWriteOnce for GKE)
    sed -i.bak 's/ReadWriteMany/ReadWriteOnce/g' "$TEMP_DIR/pvc.yaml"
    
    print_success "Manifests updated successfully."
}

# Function to create database secret
create_db_secret() {
    print_status "Creating database secret..."
    
    # Check if secret exists
    if kubectl get secret ontoserver-db-secret -n "$NAMESPACE" &> /dev/null; then
        print_warning "Database secret already exists. Skipping creation."
        return
    fi
    
    # Prompt for database password
    # echo -n "Enter database password: "
    # read -s DB_PASSWORD
    # echo
    
    if [ -z "$DATABASE_PASSWORD" ]; then
        print_error "Database password cannot be empty"
        exit 1
    fi
    
    # Create secret
    kubectl create secret generic ontoserver-db-secret \
        --from-literal=username=ontoserver \
        --from-literal=password="$DATABASE_PASSWORD" \
        --namespace="$NAMESPACE"
    
    print_success "Database secret created successfully."
}

# Function to apply Kubernetes manifests
apply_manifests() {
    print_status "Applying Kubernetes manifests..."
    
    # Apply manifests in order
    kubectl apply -f "$TEMP_DIR/namespace.yaml"
    kubectl apply -f "$TEMP_DIR/serviceaccount.yaml"
    kubectl apply -f "$TEMP_DIR/configmap.yaml"
    kubectl apply -f "$TEMP_DIR/pvc.yaml"
    kubectl apply -f "$TEMP_DIR/service.yaml"
    kubectl apply -f "$TEMP_DIR/deployment.yaml"
    
    # Apply ingress if enabled
    if [ -f "$TEMP_DIR/ingress.yaml" ]; then
        print_status "Applying ingress configuration..."
        kubectl apply -f "$TEMP_DIR/ingress.yaml"
    fi
    
    print_success "Kubernetes manifests applied successfully."
}

# Function to wait for deployment
wait_for_deployment() {
    print_status "Waiting for deployment to be ready..."
    
    kubectl rollout status deployment/ontoserver -n "$NAMESPACE" --timeout=600s
    
    print_success "Deployment is ready."
}

# Function to show deployment status
show_status() {
    print_status "Deployment Status:"
    echo "=================="
    
    kubectl get pods -n "$NAMESPACE"
    echo
    kubectl get services -n "$NAMESPACE"
    echo
    
    # Show ingress if it exists
    if kubectl get ingress -n "$NAMESPACE" &> /dev/null; then
        kubectl get ingress -n "$NAMESPACE"
        echo
    fi
}

# Function to show access information
show_access_info() {
    print_status "Access Information:"
    echo "==================="
    
    # Get service information
    SERVICE_IP=$(kubectl get service ontoserver -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$SERVICE_IP" ]; then
        echo "External IP: $SERVICE_IP"
        echo "Ontoserver URL: http://$SERVICE_IP/fhir"
    else
        print_warning "External IP not available yet. It may take a few minutes to provision."
        echo "You can check the status with: kubectl get service ontoserver -n $NAMESPACE"
    fi
    
    # Show ingress information if available
    if kubectl get ingress ontoserver-ingress -n "$NAMESPACE" &> /dev/null; then
        INGRESS_IP=$(kubectl get ingress ontoserver-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$INGRESS_IP" ]; then
            echo "Ingress IP: $INGRESS_IP"
        fi
    fi
    
    echo "==================="
}

# Function to show useful commands
show_useful_commands() {
    print_status "Useful Commands:"
    echo "================"
    echo "Check pods:        kubectl get pods -n $NAMESPACE"
    echo "Check logs:        kubectl logs -f deployment/ontoserver -n $NAMESPACE"
    echo "Check services:    kubectl get services -n $NAMESPACE"
    echo "Scale deployment:  kubectl scale deployment ontoserver --replicas=N -n $NAMESPACE"
    echo "Port forward:      kubectl port-forward service/ontoserver 8080:80 -n $NAMESPACE"
    echo "================"
}

# Function to cleanup temp files
cleanup() {
    if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Trap to ensure cleanup
trap cleanup EXIT

# Main execution
main() {
    print_status "Starting Ontoserver deployment to Kubernetes..."
    
    check_prerequisites
    get_terraform_outputs
    update_manifests
    create_db_secret
    apply_manifests
    wait_for_deployment
    show_status
    show_access_info
    show_useful_commands
    
    print_success "Ontoserver deployment completed successfully!"
}

# Check if running from correct directory
if [ ! -d "$K8S_DIR" ]; then
    print_error "Kubernetes directory not found. Please run this script from the scripts directory."
    exit 1
fi

if [ ! -d "$TERRAFORM_DIR" ]; then
    print_error "Terraform directory not found. Please run this script from the scripts directory."
    exit 1
fi

# Run main function
main "$@"