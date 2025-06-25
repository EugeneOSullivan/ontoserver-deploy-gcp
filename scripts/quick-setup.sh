#!/bin/bash

# Quick Setup Script for Ontoserver GCP Deployment
# This script helps set up the project configuration and run initial checks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

print_header "Ontoserver GCP Quick Setup"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed or not in PATH"
    print_error "Please install gcloud CLI: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

print_status "gcloud CLI found"

# Check if user is authenticated
if ! gcloud auth list --filter="status:ACTIVE" --format="value(account)" | grep -q .; then
    print_error "You are not authenticated with gcloud"
    print_error "Please run: gcloud auth login"
    exit 1
fi

print_status "User is authenticated with gcloud"

# Get current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")

if [ -z "$CURRENT_PROJECT" ]; then
    print_error "No project is set in gcloud config"
    print_error "Please set a project: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

print_status "Current project: $CURRENT_PROJECT"

# Ask user to confirm or change project
read -p "Do you want to use project '$CURRENT_PROJECT'? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter your project ID: " NEW_PROJECT
    gcloud config set project "$NEW_PROJECT"
    CURRENT_PROJECT="$NEW_PROJECT"
    print_status "Project set to: $CURRENT_PROJECT"
fi

# Set environment variables
export PROJECT_ID="$CURRENT_PROJECT"
export REGION="europe-west2"
export SERVICE_NAME="ontoserver"

print_status "Environment variables set:"
print_status "  PROJECT_ID=$PROJECT_ID"
print_status "  REGION=$REGION"
print_status "  SERVICE_NAME=$SERVICE_NAME"

# Update terraform.tfvars with the correct project ID
print_header "Updating Terraform Configuration"

cd terraform

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_error "terraform.tfvars not found. Please copy from example first:"
    print_error "cp terraform.tfvars.example terraform.tfvars"
    exit 1
fi

# Update project_id in terraform.tfvars
sed -i.bak "s/project_id = \"your-gcp-project-id\"/project_id = \"$PROJECT_ID\"/" terraform.tfvars
sed -i.bak "s/service_account_email = \"ontoserver-run-sa@your-gcp-project-id.iam.gserviceaccount.com\"/service_account_email = \"ontoserver-run-sa@$PROJECT_ID.iam.gserviceaccount.com\"/" terraform.tfvars

print_status "Updated terraform.tfvars with project ID: $PROJECT_ID"

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    print_warning "Terraform not initialized. Initializing now..."
    terraform init -backend-config="bucket=${PROJECT_ID}-terraform-state"
else
    print_status "Terraform already initialized"
fi

# Check if infrastructure exists
print_header "Checking Infrastructure Status"

if terraform output database_instance_name >/dev/null 2>&1; then
    print_status "Infrastructure exists. Checking status..."
    
    # Get infrastructure details
    DB_INSTANCE=$(terraform output -raw database_instance_name 2>/dev/null || echo "unknown")
    DB_HOST=$(terraform output -raw database_private_ip 2>/dev/null || echo "unknown")
    VPC_CONNECTOR=$(terraform output -raw vpc_connector_name 2>/dev/null || echo "unknown")
    
    print_status "Database Instance: $DB_INSTANCE"
    print_status "Database Host: $DB_HOST"
    print_status "VPC Connector: $VPC_CONNECTOR"
    
    # Check if Cloud SQL instance exists and is running
    if gcloud sql instances describe "$DB_INSTANCE" >/dev/null 2>&1; then
        DB_STATUS=$(gcloud sql instances describe "$DB_INSTANCE" --format="value(state)")
        print_status "Database Status: $DB_STATUS"
        
        if [ "$DB_STATUS" != "RUNNABLE" ]; then
            print_warning "Database is not in RUNNABLE state: $DB_STATUS"
        fi
    else
        print_error "Database instance '$DB_INSTANCE' not found"
    fi
    
    # Check VPC connector
    if gcloud compute networks vpc-access connectors describe "$VPC_CONNECTOR" --region="$REGION" >/dev/null 2>&1; then
        CONNECTOR_STATUS=$(gcloud compute networks vpc-access connectors describe "$VPC_CONNECTOR" --region="$REGION" --format="value(state)")
        print_status "VPC Connector Status: $CONNECTOR_STATUS"
        
        if [ "$CONNECTOR_STATUS" != "READY" ]; then
            print_warning "VPC connector is not in READY state: $CONNECTOR_STATUS"
        fi
    else
        print_error "VPC connector '$VPC_CONNECTOR' not found"
    fi
    
    # Check Cloud Run service
    if gcloud run services describe "$SERVICE_NAME" --region="$REGION" >/dev/null 2>&1; then
        SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$REGION" --format="value(status.url)")
        print_status "Cloud Run Service URL: $SERVICE_URL"
        
        # Test service connectivity
        print_status "Testing service connectivity..."
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL/fhir/metadata" 2>/dev/null || echo "000")
        
        if [ "$RESPONSE" = "200" ]; then
            print_status "✓ Service is responding (HTTP 200)"
        elif [ "$RESPONSE" = "000" ]; then
            print_error "✗ Service is not responding (connection failed)"
        else
            print_warning "✗ Service responded with HTTP $RESPONSE"
        fi
    else
        print_error "Cloud Run service '$SERVICE_NAME' not found"
    fi
    
else
    print_warning "Infrastructure does not exist yet"
    print_status "To create infrastructure, run:"
    print_status "  terraform plan"
    print_status "  terraform apply"
fi

print_header "Next Steps"

if [ "$RESPONSE" != "200" ] 2>/dev/null; then
    print_warning "Database connection issues detected!"
    print_status "Run the troubleshooting script:"
    print_status "  cd .. && ./scripts/troubleshoot-db-connection.sh"
    print_status ""
    print_status "Or check the troubleshooting guide:"
    print_status "  cat ../CLOUD_SQL_TROUBLESHOOTING.md"
else
    print_status "✓ Everything looks good!"
    print_status "Your Ontoserver is running at: $SERVICE_URL"
fi

print_status ""
print_status "Useful commands:"
print_status "  # View logs:"
print_status "  gcloud logging read 'resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME' --limit=20"
print_status ""
print_status "  # Check database:"
print_status "  gcloud sql connect $DB_INSTANCE --user=ontoserver"
print_status ""
print_status "  # Update application:"
print_status "  cd ../scripts && ./deploy-ontoserver.sh" 