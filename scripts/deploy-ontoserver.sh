#!/bin/bash

# Ontoserver Cloud Run Deployment Script
# This script deploys Ontoserver to Cloud Run using the image from Artifact Registry

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

print_status "Deploying Ontoserver to Cloud Run"
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

# Check if the Cloud Run service already exists and get current image
if gcloud run services describe $SERVICE_NAME --region=$REGION >/dev/null 2>&1; then
    print_status "Cloud Run service already exists, updating..."
else
    print_status "Creating new Cloud Run service..."
fi

# Deploy to Cloud Run using the image from Artifact Registry
print_status "Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
  --image $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:latest \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --service-account $SERVICE_ACCOUNT_EMAIL \
  --set-env-vars "DB_HOST=$DB_HOST,DB_NAME=$DB_NAME,DB_PORT=5432,SPRING_PROFILES_ACTIVE=cloud,JAVA_OPTS=-Xmx2g -Xms1g" \
  --set-secrets "DB_PASSWORD=ontoserver-db-password:latest,DB_USER=ontoserver-db-user:latest" \
  --vpc-egress private-ranges-only \
  --vpc-connector $VPC_CONNECTOR \
  --memory 4Gi \
  --cpu 2 \
  --max-instances 10 \
  --min-instances 0 \
  --timeout 900 \
  --concurrency 80 \
  --port 8080

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)")

print_status "Deployment completed successfully!"
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