#!/bin/bash

# Ontoserver Cloud Run Deployment Script
# This script updates the Ontoserver container image in Cloud Run
# NOTE: Infrastructure is managed by Terraform, this script only updates the image

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

if [ -z "$SERVICE_NAME" ]; then
    print_warning "SERVICE_NAME not set, using default: ontoserver"
    export SERVICE_NAME="ontoserver"
fi

print_status "Updating Ontoserver container image in Cloud Run"
print_status "Project: $PROJECT_ID"
print_status "Region: $REGION"
print_status "Service: $SERVICE_NAME"

# Set the project
gcloud config set project $PROJECT_ID

# Check if Terraform has been run and infrastructure exists
print_status "Checking if infrastructure exists..."
if ! terraform -chdir=../terraform output database_instance_name >/dev/null 2>&1; then
    print_error "Terraform infrastructure not found!"
    print_error "Please run 'terraform apply' in the terraform directory first."
    exit 1
fi

# Get infrastructure details from Terraform output
print_status "Getting infrastructure details from Terraform..."
DB_INSTANCE=$(terraform -chdir=../terraform output -raw database_instance_name)
DB_NAME=$(terraform -chdir=../terraform output -raw database_name)
DB_USER=$(terraform -chdir=../terraform output -raw database_user)
DB_HOST=$(terraform -chdir=../terraform output -raw database_private_ip)
SERVICE_ACCOUNT_EMAIL=$(terraform -chdir=../terraform output -raw service_account_email)
VPC_CONNECTOR=$(terraform -chdir=../terraform output -raw vpc_connector_name)

print_status "Database Instance: $DB_INSTANCE"
print_status "Database Name: $DB_NAME"
print_status "Database User: $DB_USER"
print_status "Database Host: $DB_HOST"
print_status "Service Account Email: $SERVICE_ACCOUNT_EMAIL"
print_status "VPC Connector: $VPC_CONNECTOR"

# Check if the Cloud Run service exists
if ! gcloud run services describe $SERVICE_NAME --region=$REGION >/dev/null 2>&1; then
    print_error "Cloud Run service '$SERVICE_NAME' not found!"
    print_error "Please run 'terraform apply' in the terraform directory first to create the infrastructure."
    exit 1
fi

# Update only the container image in the existing Cloud Run service
print_status "Updating container image in Cloud Run service..."
gcloud run services update $SERVICE_NAME \
  --image $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:latest \
  --region $REGION

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)")

print_status "Image update completed successfully!"
print_status "Service URL: $SERVICE_URL"
print_status ""
print_status "To test the deployment:"
print_status "curl $SERVICE_URL/fhir/metadata"
print_status ""
print_status "To view logs:"
print_status "gcloud logging read 'resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME' --limit=50"
print_status ""
print_status "To view the service in the console:"
print_status "https://console.cloud.google.com/run/detail/$REGION/$SERVICE_NAME/metrics?project=$PROJECT_ID"
print_status ""
print_warning "NOTE: If you need to change environment variables or other configuration,"
print_warning "please update the Terraform configuration and run 'terraform apply' instead." 