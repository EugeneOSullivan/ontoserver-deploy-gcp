#!/bin/bash

# Ontoserver Database Connection Troubleshooting Script
# This script helps diagnose database connection issues in Cloud Run

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

print_header "Ontoserver Database Connection Troubleshooting"
print_status "Project: $PROJECT_ID"
print_status "Region: $REGION"
print_status "Service: $SERVICE_NAME"

# Set the project
gcloud config set project $PROJECT_ID

# Check if Terraform has been run
print_header "1. Checking Terraform Infrastructure"
if ! terraform -chdir=../terraform output database_instance_name >/dev/null 2>&1; then
    print_error "Terraform infrastructure not found!"
    print_error "Please run 'terraform apply' in the terraform directory first."
    exit 1
fi

# Get infrastructure details
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

# Check Cloud Run service
print_header "2. Checking Cloud Run Service"
if ! gcloud run services describe $SERVICE_NAME --region=$REGION >/dev/null 2>&1; then
    print_error "Cloud Run service '$SERVICE_NAME' not found!"
    exit 1
fi

SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)")
print_status "Service URL: $SERVICE_URL"

# Check Cloud SQL instance
print_header "3. Checking Cloud SQL Instance"
if ! gcloud sql instances describe $DB_INSTANCE >/dev/null 2>&1; then
    print_error "Cloud SQL instance '$DB_INSTANCE' not found!"
    exit 1
fi

DB_STATUS=$(gcloud sql instances describe $DB_INSTANCE --format="value(state)")
print_status "Database Status: $DB_STATUS"

if [ "$DB_STATUS" != "RUNNABLE" ]; then
    print_warning "Database is not in RUNNABLE state: $DB_STATUS"
fi

# Check VPC connector
print_header "4. Checking VPC Connector"
if ! gcloud compute networks vpc-access connectors describe $VPC_CONNECTOR --region=$REGION >/dev/null 2>&1; then
    print_error "VPC connector '$VPC_CONNECTOR' not found!"
    exit 1
fi

CONNECTOR_STATUS=$(gcloud compute networks vpc-access connectors describe $VPC_CONNECTOR --region=$REGION --format="value(state)")
print_status "VPC Connector Status: $CONNECTOR_STATUS"

# Check service account permissions
print_header "5. Checking Service Account Permissions"
print_status "Checking IAM bindings for: $SERVICE_ACCOUNT_EMAIL"

IAM_BINDINGS=$(gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:$SERVICE_ACCOUNT_EMAIL")

if echo "$IAM_BINDINGS" | grep -q "roles/cloudsql.client"; then
    print_status "✓ Cloud SQL Client role found"
else
    print_warning "✗ Cloud SQL Client role not found"
fi

if echo "$IAM_BINDINGS" | grep -q "roles/cloudsql.admin"; then
    print_status "✓ Cloud SQL Admin role found"
else
    print_warning "✗ Cloud SQL Admin role not found"
fi

if echo "$IAM_BINDINGS" | grep -q "roles/secretmanager.secretAccessor"; then
    print_status "✓ Secret Manager Secret Accessor role found"
else
    print_warning "✗ Secret Manager Secret Accessor role not found"
fi

# Check secrets
print_header "6. Checking Secrets"
if gcloud secrets describe ontoserver-db-password >/dev/null 2>&1; then
    print_status "✓ Database password secret exists"
else
    print_error "✗ Database password secret not found"
fi

if gcloud secrets describe ontoserver-db-user >/dev/null 2>&1; then
    print_status "✓ Database user secret exists"
else
    print_error "✗ Database user secret not found"
fi

# Check recent logs
print_header "7. Checking Recent Cloud Run Logs"
print_status "Fetching recent logs for service: $SERVICE_NAME"
echo ""

LOG_ENTRIES=$(gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME" --limit=10 --format="table(timestamp,severity,textPayload)" 2>/dev/null || echo "No logs found")

if [ -n "$LOG_ENTRIES" ] && [ "$LOG_ENTRIES" != "No logs found" ]; then
    echo "$LOG_ENTRIES"
else
    print_warning "No recent logs found"
fi

# Test service connectivity
print_header "8. Testing Service Connectivity"
print_status "Testing service endpoint: $SERVICE_URL/fhir/metadata"

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL/fhir/metadata" 2>/dev/null || echo "000")

if [ "$RESPONSE" = "200" ]; then
    print_status "✓ Service is responding (HTTP 200)"
elif [ "$RESPONSE" = "000" ]; then
    print_error "✗ Service is not responding (connection failed)"
else
    print_warning "✗ Service responded with HTTP $RESPONSE"
fi

# Network connectivity test
print_header "9. Network Connectivity Analysis"
print_status "Checking if Cloud Run can reach Cloud SQL..."

# Get Cloud Run service details
SERVICE_DETAILS=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="yaml")

if echo "$SERVICE_DETAILS" | grep -q "vpc-access-connector"; then
    print_status "✓ VPC connector is configured"
else
    print_error "✗ VPC connector is not configured"
fi

if echo "$SERVICE_DETAILS" | grep -q "vpc-access-egress.*all-traffic"; then
    print_status "✓ VPC egress is set to all-traffic"
else
    print_warning "✗ VPC egress is not set to all-traffic"
fi

# Summary and recommendations
print_header "10. Summary and Recommendations"
echo ""
print_status "Infrastructure Status:"
print_status "- Cloud SQL: $DB_STATUS"
print_status "- VPC Connector: $CONNECTOR_STATUS"
print_status "- Service Response: HTTP $RESPONSE"
echo ""

if [ "$DB_STATUS" != "RUNNABLE" ]; then
    print_warning "RECOMMENDATION: Database is not in RUNNABLE state. Check Cloud SQL console."
fi

if [ "$RESPONSE" != "200" ]; then
    print_warning "RECOMMENDATION: Service is not responding properly. Check logs for errors."
fi

print_status "Next steps for debugging:"
print_status "1. Check Cloud Run logs: gcloud logging read 'resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME' --limit=50"
print_status "2. Check Cloud SQL logs: gcloud sql logs tail $DB_INSTANCE"
print_status "3. Test database connectivity from Cloud Run: gcloud run jobs execute test-db-connection --region=$REGION"
print_status "4. Verify VPC connector: gcloud compute networks vpc-access connectors describe $VPC_CONNECTOR --region=$REGION" 