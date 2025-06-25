#!/bin/bash

# Ontoserver GCP Project Setup Script
# This script sets up the GCP project and enables required APIs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required environment variables are set
if [ -z "$PROJECT_ID" ]; then
    print_error "PROJECT_ID environment variable is not set"
    echo "Please set it with: export PROJECT_ID='your-project-id'"
    exit 1
fi

if [ -z "$REGION" ]; then
    print_warning "REGION not set, using default: europe-west2"
    export REGION="europe-west2"
fi

print_status "Setting up GCP project: $PROJECT_ID"
print_status "Region: $REGION"

# Set the project
print_status "Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
print_status "Enabling required GCP APIs..."

# Core APIs for GKE deployment
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com

# Networking APIs
gcloud services enable servicenetworking.googleapis.com
gcloud services enable dns.googleapis.com

# Security APIs
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable iamcredentials.googleapis.com

# Storage APIs
gcloud services enable storage.googleapis.com

print_status "All required APIs enabled successfully!"
print_status ""
print_status "⚠️  IMPORTANT: Project setup completed!"
print_status ""
print_status "Next steps:"
print_status "1. Run: ./setup-iam.sh"
print_status "2. Configure terraform/terraform.tfvars"
print_status "3. Run: ./deploy-gke-cluster.sh" 