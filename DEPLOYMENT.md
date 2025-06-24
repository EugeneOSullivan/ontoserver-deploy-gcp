# Ontoserver GCP Cloud Run Deployment Guide

This guide provides step-by-step instructions to deploy Ontoserver to Google Cloud Platform using Cloud Run, based on the official [AEHRC Ontoserver Docker deployment patterns](https://github.com/aehrc/ontoserver-deploy/tree/master/docker).

## Prerequisites

### 1. Required Tools
- **Google Cloud SDK** (gcloud CLI) - [Install Guide](https://cloud.google.com/sdk/docs/install)
- **Terraform** (version >= 1.0) - [Install Guide](https://developer.hashicorp.com/terraform/downloads)
- **Docker** - [Install Guide](https://docs.docker.com/get-docker/)
- **Git** - [Install Guide](https://git-scm.com/downloads)

### 2. Required Accounts
- **Google Cloud Platform** account with billing enabled
- **Quay.io** account for pulling the Ontoserver image

### 3. Required Permissions
Your GCP account needs the following roles:
- `roles/owner` (for initial setup)
- `roles/iam.serviceAccountAdmin`
- `roles/resourcemanager.projectIamAdmin`
- `roles/storage.admin`

## Step 1: Clone and Setup Repository

```bash
# Clone the repository
git clone <your-repo-url>
cd ontoserver-gcp-deployment

# Verify the structure
ls -la
```

Expected output:
```
README.md
DEPLOYMENT.md
COMPARISON.md
Dockerfile
scripts/
terraform/
networking/
```

## Step 2: Set Environment Variables

```bash
# Set your GCP project ID
export PROJECT_ID="your-gcp-project-id"

# Set your preferred region
export REGION="europe-west2"

# Set a secure database password
export DATABASE_PASSWORD="your-secure-password-here"

# Set Quay.io credentials (required for pulling Ontoserver image)
export QUAY_USERNAME="your-quay-username"
export QUAY_PASSWORD="your-quay-password"

# Verify environment variables
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Database Password: [HIDDEN]"
echo "Quay Username: $QUAY_USERNAME"
```

## Step 3: Authenticate with Google Cloud

```bash
# Login to Google Cloud
gcloud auth login

# Set the project
gcloud config set project $PROJECT_ID

# Verify authentication
gcloud auth list
```

Expected output:
```
ACTIVE  ACCOUNT
*       your-email@gmail.com

To set the active account, run:
    gcloud config set account `ACCOUNT`
```

## Step 4: Enable Required APIs

```bash
# Navigate to scripts directory
cd scripts

# Run the project setup script
./setup-project.sh
```

This script enables the following APIs:
- `compute.googleapis.com`
- `sqladmin.googleapis.com`
- `run.googleapis.com`
- `cloudbuild.googleapis.com`
- `artifactregistry.googleapis.com`
- `secretmanager.googleapis.com`
- `monitoring.googleapis.com`
- `logging.googleapis.com`
- `servicenetworking.googleapis.com`
- `vpcaccess.googleapis.com`
- `dns.googleapis.com`
- `cloudresourcemanager.googleapis.com`
- `iam.googleapis.com`
- `iamcredentials.googleapis.com`
- `storage.googleapis.com`

## Step 5: Setup IAM and Service Accounts

```bash
# Run the IAM setup script
./setup-iam.sh
```

This script creates:
- Service account: `ontoserver-run-sa@$PROJECT_ID.iam.gserviceaccount.com`
- IAM roles for Cloud SQL, Secret Manager, Logging, and Monitoring
- Terraform state bucket: `gs://$PROJECT_ID-terraform-state`

Expected output:
```
[INFO] Setting up IAM for project: your-project-id
[INFO] Region: europe-west2
[INFO] Creating Cloud Run service account...
[INFO] Assigning roles to Cloud Run service account...
[INFO] Creating Terraform state bucket...
[INFO] IAM setup completed successfully!
```

## Step 6: Configure Terraform

```bash
# Navigate to terraform directory
cd ../terraform

# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit the configuration file
nano terraform.tfvars
```

Update `terraform.tfvars` with your values:

```hcl
# GCP Project Configuration
project_id = "your-gcp-project-id"
region     = "europe-west2"

# Cloud Run Configuration
service_name = "ontoserver"
service_account_email = "ontoserver-run-sa@your-gcp-project-id.iam.gserviceaccount.com"

# Network Configuration
vpc_name = "ontoserver-vpc"
subnet_name = "ontoserver-subnet"
subnet_cidr = "10.0.0.0/24"

# Database Configuration
database_instance_name = "ontoserver-db"
database_name     = "ontoserver"
database_user     = "ontoserver"
database_password = "your-secure-password-here"
database_version  = "POSTGRES_14"
database_tier     = "db-f1-micro"

# Load Balancer Configuration (optional)
enable_load_balancer = false
domain_name = ""
ssl_certificate_name = "ontoserver-ssl-cert"

# Environment Configuration
environment = "dev"

# Tags
tags = {
  Environment = "dev"
  Project     = "ontoserver"
  ManagedBy   = "terraform"
  Owner       = "your-team"
}
```

## Step 7: Initialize Terraform

```bash
# Initialize Terraform with GCS backend
terraform init -backend-config="bucket=${PROJECT_ID}-terraform-state"

# Verify the configuration
terraform plan
```

Expected output:
```
Terraform will perform the following actions:

  # google_artifact_registry_repository.repository will be created
  + resource "google_artifact_registry_repository" "repository" {
      + description = "Repository for Ontoserver container images"
      + format      = "DOCKER"
      + location    = "europe-west2"
      + name        = "projects/your-project-id/locations/europe-west2/repositories/ontoserver-repo"
      + repository_id = "ontoserver-repo"
    }

  # google_cloud_run_service.ontoserver will be created
  + resource "google_cloud_run_service" "ontoserver" {
      + location = "europe-west2"
      + name     = "ontoserver"
      ...
    }

  # google_sql_database_instance.instance will be created
  + resource "google_sql_database_instance" "instance" {
      + database_version = "POSTGRES_14"
      + name            = "ontoserver-db"
      + region          = "europe-west2"
      ...
    }

  Plan: 15 to add, 0 to change, 0 to destroy.
```

## Step 8: Deploy Infrastructure

```bash
# Apply the Terraform configuration
terraform apply

# Type 'yes' when prompted to confirm
```

This step creates:
- VPC and subnet
- Cloud SQL PostgreSQL instance with private IP
- Artifact Registry repository
- Secret Manager secrets
- VPC Access Connector
- Cloud Run service (without container image)

Expected output:
```
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:

cloud_run_service_url = "https://ontoserver-xxxxx-ew.a.run.app"
database_instance_name = "ontoserver-db"
database_name = "ontoserver"
database_private_ip = "10.0.0.3"
vpc_connector_name = "ontoserver-connector"
```

## Step 9: Setup Container Registry and Pull Images

```bash
# Navigate back to scripts directory
cd ../scripts

# Run the artifact registry setup script
./setup-artifact-registry.sh
```

This script:
- Authenticates with Quay.io
- Pulls the Ontoserver image: `quay.io/aehrc/ontoserver:ctsa-6`
- Tags and pushes to Artifact Registry
- Creates a sync script for future updates

Expected output:
```
[INFO] Setting up Artifact Registry for project: your-project-id
[INFO] Configuring Docker authentication for Artifact Registry...
[INFO] Logging in to Quay.io...
[INFO] Pulling Ontoserver image from Quay.io...
[INFO] Tagging image for Artifact Registry...
[INFO] Pushing image to Artifact Registry...
[INFO] Artifact Registry setup completed successfully!
```

## Step 10: Deploy Ontoserver Application

```bash
# Deploy the application to Cloud Run
./deploy-ontoserver.sh
```

This script:
- Updates the Cloud Run service with the container image
- Maintains all infrastructure configuration from Terraform
- Provides the service URL

Expected output:
```
[INFO] Updating Ontoserver container image in Cloud Run
[INFO] Project: your-project-id
[INFO] Region: europe-west2
[INFO] Service: ontoserver
[INFO] Getting infrastructure details from Terraform...
[INFO] Database Instance: ontoserver-db
[INFO] Database Name: ontoserver
[INFO] Database User: ontoserver
[INFO] Database Host: 10.0.0.3
[INFO] Updating container image in Cloud Run service...
[INFO] Image update completed successfully!
[INFO] Service URL: https://ontoserver-xxxxx-ew.a.run.app
```

## Step 11: Verify Deployment

### Test the Service

```bash
# Get the service URL
SERVICE_URL=$(gcloud run services describe ontoserver --region=$REGION --format="value(status.url)")

# Test the FHIR metadata endpoint
curl -v $SERVICE_URL/fhir/metadata

# Test a simple health check
curl -v $SERVICE_URL/fhir/metadata | jq '.'
```

Expected output:
```json
{
  "resourceType": "CapabilityStatement",
  "status": "active",
  "date": "2024-01-01T00:00:00.000Z",
  "publisher": "AEHRC",
  "kind": "instance",
  "software": {
    "name": "Ontoserver",
    "version": "6.0.0"
  },
  "fhirVersion": "4.0.1",
  "format": ["application/fhir+json"],
  "rest": [...]
}
```

### Check Service Status

```bash
# Check Cloud Run service status
gcloud run services describe ontoserver --region=$REGION

# Check recent logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=ontoserver" --limit=10

# Check database connectivity
gcloud sql instances describe ontoserver-db
```

### Run Troubleshooting Script

```bash
# Run comprehensive diagnostics
./troubleshoot-db-connection.sh
```

This script checks:
- Terraform infrastructure status
- Cloud Run service configuration
- Cloud SQL instance status
- VPC connector configuration
- Service account permissions
- Service connectivity

## Step 12: Configure Custom Domain (Optional)

If you want to use a custom domain:

```bash
# Update terraform.tfvars
nano ../terraform/terraform.tfvars
```

Add your domain:
```hcl
enable_load_balancer = true
domain_name = "your-domain.com"
```

```bash
# Apply the changes
cd ../terraform
terraform apply
```

## Step 13: Monitor and Maintain

### View Logs

```bash
# View real-time logs
gcloud logging tail "resource.type=cloud_run_revision AND resource.labels.service_name=ontoserver"

# View specific log entries
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=ontoserver AND severity>=ERROR" --limit=50
```

### Update Application

```bash
# When you have a new container image
cd scripts
./deploy-ontoserver.sh
```

### Scale the Service

```bash
# Update scaling configuration in Terraform
nano ../terraform/main.tf
```

Modify the Cloud Run service:
```hcl
metadata {
  annotations = {
    "autoscaling.knative.dev/minScale" = "1"
    "autoscaling.knative.dev/maxScale" = "10"
  }
}
```

```bash
# Apply changes
cd ../terraform
terraform apply
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Database Connection Failed

```bash
# Run the troubleshooting script
./scripts/troubleshoot-db-connection.sh

# Check VPC connector status
gcloud compute networks vpc-access connectors describe ontoserver-connector --region=$REGION

# Verify private service connection
gcloud services vpc-peerings list --network=ontoserver-vpc
```

#### 2. Quay.io Authentication Failed

```bash
# Re-authenticate with Quay.io
docker login quay.io -u $QUAY_USERNAME -p $QUAY_PASSWORD

# Verify access to the repository
docker pull quay.io/aehrc/ontoserver:ctsa-6
```

#### 3. Terraform Backend Error

```bash
# Check if the bucket exists
gsutil ls gs://$PROJECT_ID-terraform-state

# Create the bucket if it doesn't exist
gsutil mb -l $REGION gs://$PROJECT_ID-terraform-state
```

#### 4. Cloud Run Service Not Responding

```bash
# Check service status
gcloud run services describe ontoserver --region=$REGION

# Check recent logs for errors
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=ontoserver AND severity>=ERROR" --limit=20

# Test the service directly
curl -v https://ontoserver-xxxxx-ew.a.run.app/fhir/metadata
```

### Useful Commands

```bash
# Get all outputs from Terraform
cd terraform
terraform output

# Check service account permissions
gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:ontoserver-run-sa@$PROJECT_ID.iam.gserviceaccount.com"

# Check Artifact Registry images
gcloud artifacts docker images list $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo

# Check Cloud SQL logs
gcloud sql logs tail ontoserver-db

# Check VPC flow logs
gcloud logging read "resource.type=gce_subnetwork AND resource.labels.subnetwork_name=ontoserver-subnet" --limit=10
```

## Cleanup

To remove all resources:

```bash
# Navigate to terraform directory
cd terraform

# Destroy all resources
terraform destroy

# Type 'yes' when prompted to confirm
```

**Warning**: This will delete all resources including the database and its data.

## Next Steps

1. **Production Deployment**: Update `database_tier` to `db-custom-2-4096` or higher
2. **Custom Domain**: Configure SSL certificate and load balancer
3. **Monitoring**: Set up Cloud Monitoring alerts
4. **Backup**: Verify Cloud SQL automated backups are working
5. **CI/CD**: Integrate with GitHub Actions or Cloud Build

## Support

- **GCP Issues**: [Google Cloud Support](https://cloud.google.com/support)
- **Terraform Issues**: [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- **Ontoserver Issues**: [AEHRC Ontoserver Repository](https://github.com/aehrc/ontoserver-deploy)
- **Quay.io Issues**: [Quay.io Documentation](https://docs.quay.io/)

## Cost Estimation

Monthly costs for development environment:
- **Cloud Run**: ~$5-20 (depending on usage)
- **Cloud SQL**: ~$25 (db-f1-micro)
- **VPC Access Connector**: ~$5
- **Artifact Registry**: ~$1-5
- **Secret Manager**: ~$1
- **Total**: ~$35-55/month

Production costs will be higher due to larger database tier and increased usage. 