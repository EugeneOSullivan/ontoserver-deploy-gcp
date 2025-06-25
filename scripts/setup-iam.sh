#!/bin/bash

# Ontoserver GCP IAM Setup Script
# This script creates service accounts and assigns appropriate roles for GKE deployment

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

print_status "Setting up IAM for project: $PROJECT_ID"
print_status "Region: $REGION"

# Set the project
gcloud config set project $PROJECT_ID

# Create service account for GKE (will be used by the application)
print_status "Creating GKE service account..."
gcloud iam service-accounts create ontoserver-gke-sa \
    --display-name="Ontoserver GKE Service Account" \
    --description="Service account for Ontoserver GKE deployment" || true

# Assign roles to GKE service account
print_status "Assigning roles to GKE service account..."
gke_sa="serviceAccount:ontoserver-gke-sa@$PROJECT_ID.iam.gserviceaccount.com"

CONDITION="expression=request.time < timestamp('2040-01-01T00:00:00Z'),title=temporary-access"

gcloud projects add-iam-policy-binding $PROJECT_ID --member="$gke_sa" --role="roles/cloudsql.client" --condition="$CONDITION"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="$gke_sa" --role="roles/secretmanager.secretAccessor" --condition="$CONDITION"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="$gke_sa" --role="roles/logging.logWriter" --condition="$CONDITION"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="$gke_sa" --role="roles/monitoring.metricWriter" --condition="$CONDITION"

# Create Terraform state bucket (this is the only infrastructure piece that must exist before Terraform)
print_status "Creating Terraform state bucket..."
gsutil mb -l $REGION gs://$PROJECT_ID-terraform-state 2>/dev/null || print_warning "Bucket already exists"
gsutil versioning set on gs://$PROJECT_ID-terraform-state

print_status "IAM setup completed successfully!"
print_status ""
print_status "Service account created:"
print_status "- ontoserver-gke-sa@$PROJECT_ID.iam.gserviceaccount.com"
print_status ""
print_status "Next steps:"
print_status "1. Configure terraform/terraform.tfvars"
print_status "2. Run: ./deploy-gke-cluster.sh" 