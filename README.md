# Ontoserver deployment on Google Cloud Platform

This example creates a recommended environment in Google Cloud Platform that exposes Ontoserver running on Cloud Run with managed services for optimal performance and cost-effectiveness.

## Architecture Overview

The GCP deployment uses the following managed services:
- **Cloud Run** - Serverless container platform for Ontoserver
- **Cloud SQL for PostgreSQL** - Managed PostgreSQL database with private IP
- **Cloud Load Balancing** - Global load balancer with SSL termination (optional)
- **Cloud CDN** - Content delivery network for caching (optional)
- **Artifact Registry** - Container image registry
- **Cloud Storage** - For Terraform state and persistent storage
- **VPC** - Virtual private cloud with proper network segmentation
- **Secret Manager** - For secure configuration management
- **VPC Access Connector** - For Cloud Run to access private resources

## Prerequisites

1. **Google Cloud SDK** installed and configured
2. **Terraform** (version >= 1.0)
3. **Docker** for pulling and pushing images
4. **gcloud** CLI authenticated with appropriate permissions
5. **Quay.io credentials** - You'll need a Quay.io account to pull the Ontoserver image

## ⚠️ Important: Quay.io Authentication

The Ontoserver image is hosted on Quay.io and requires authentication. You'll need:
- A Quay.io account
- Username and password for Quay.io

During setup, you'll be prompted for these credentials or you can set them as environment variables:
```bash
export QUAY_USERNAME="your-quay-username"
export QUAY_PASSWORD="your-quay-password"
```

## Quick Start

### 1. Set Environment Variables
```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export DATABASE_PASSWORD="your-secure-password"
```

### 2. Run Setup Scripts (Manual Admin Steps)
```bash
cd gcp/scripts

# Enable APIs and basic setup
./setup-project.sh

# Create service accounts and IAM roles (NOT infrastructure - that's handled by Terraform)
./setup-iam.sh
```

### 3. Configure Terraform
```bash
cd ../terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your actual values

# Set up Terraform backend
export GOOGLE_APPLICATION_CREDENTIALS="../scripts/terraform-sa-key.json"
terraform init -backend-config="bucket=${PROJECT_ID}-terraform-state"
```

### 4. Deploy Infrastructure
```bash
terraform plan
terraform apply
```

### 5. Set Up Container Registry and Deploy
```bash
cd ../scripts

# Pull from Quay.io and push to Artifact Registry (requires Quay.io credentials)
./setup-artifact-registry.sh

# Deploy Ontoserver to Cloud Run
./deploy-ontoserver.sh
```

## Directory Structure

```
gcp/
├── README.md                           # This file
├── scripts/                            # IAM and deployment scripts
│   ├── setup-project.sh               # Project setup and API enablement
│   ├── setup-iam.sh                   # Service account and IAM setup
│   ├── setup-artifact-registry.sh     # Container registry setup
│   └── deploy-ontoserver.sh           # Cloud Run deployment script
├── terraform/                          # Infrastructure as Code
│   ├── main.tf                        # Main Terraform configuration
│   ├── variables.tf                   # Variable definitions
│   ├── terraform.tfvars.example       # Example variable values
│   ├── outputs.tf                     # Output values
└── networking/                        # Network documentation
    └── README.md                      # Network requirements and setup
```

## Configuration

### Required Environment Variables

```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export DATABASE_PASSWORD="your-secure-password"

# For Quay.io authentication
export QUAY_USERNAME="your-quay-username"
export QUAY_PASSWORD="your-quay-password"

# For Terraform
export GOOGLE_APPLICATION_CREDENTIALS="path/to/terraform-sa-key.json"
```

### Terraform Backend Initialization

The Terraform state is stored in a GCS bucket. Initialize with:

```bash
terraform init -backend-config="bucket=${PROJECT_ID}-terraform-state"
```

## Security Considerations

1. **Private Database**: Cloud SQL uses private IP only
2. **VPC Isolation**: All resources in private VPC
3. **Service Accounts**: Minimal required permissions
4. **Secret Management**: Database credentials in Secret Manager
5. **Image Security**: Images stored in private Artifact Registry

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Ontoserver to GCP

on:
  push:
    branches: [ main ]

env:
  PROJECT_ID: ${{ secrets.PROJECT_ID }}
  REGION: us-central1

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Google Cloud CLI
      uses: google-github-actions/setup-gcloud@v1
      with:
        service_account_key: ${{ secrets.GCP_SA_KEY }}
        project_id: ${{ secrets.PROJECT_ID }}
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
    
    - name: Terraform Init
      run: |
        cd gcp/terraform
        terraform init -backend-config="bucket=${{ env.PROJECT_ID }}-terraform-state"
    
    - name: Terraform Apply
      run: |
        cd gcp/terraform
        terraform apply -auto-approve
      env:
        TF_VAR_project_id: ${{ env.PROJECT_ID }}
        TF_VAR_database_password: ${{ secrets.DATABASE_PASSWORD }}
        TF_VAR_service_account_email: "ontoserver-run-sa@${{ env.PROJECT_ID }}.iam.gserviceaccount.com"
    
    - name: Deploy to Cloud Run
      run: |
        cd gcp/scripts
        ./deploy-ontoserver.sh
```

### Azure DevOps Example

```yaml
trigger:
- main

variables:
  projectId: '$(PROJECT_ID)'
  region: 'us-central1'

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: TerraformInstaller@0
  inputs:
    terraformVersion: '1.0.0'

- script: |
    echo $(GCP_SA_KEY) | base64 -d > gcp-key.json
    export GOOGLE_APPLICATION_CREDENTIALS=gcp-key.json
    gcloud auth activate-service-account --key-file=gcp-key.json
    gcloud config set project $(projectId)
  displayName: 'Authenticate to GCP'

- script: |
    cd gcp/terraform
    terraform init -backend-config="bucket=$(projectId)-terraform-state"
    terraform apply -auto-approve
  displayName: 'Deploy Infrastructure'
  env:
    TF_VAR_project_id: $(projectId)
    TF_VAR_database_password: $(DATABASE_PASSWORD)
    TF_VAR_service_account_email: "ontoserver-run-sa@$(projectId).iam.gserviceaccount.com"

- script: |
    cd gcp/scripts
    ./deploy-ontoserver.sh
  displayName: 'Deploy Ontoserver'
```

## Troubleshooting

### Common Issues

1. **Quay.io Authentication Failed**
   - Verify your Quay.io credentials
   - Ensure your account has access to the aehrc/ontoserver repository

2. **Terraform Backend Error**
   - Ensure the bucket exists: `gsutil ls gs://${PROJECT_ID}-terraform-state`
   - Verify your service account has storage admin permissions

3. **Cloud Run Deployment Failed**
   - Check if the image exists in Artifact Registry
   - Verify service account permissions
   - Check Cloud Run logs for application errors

4. **Database Connection Failed**
   - Verify VPC connector is properly configured
   - Check if private service connection is established
   - Validate database credentials in Secret Manager

### Useful Commands

```bash
# Check Cloud Run service status
gcloud run services describe ontoserver --region=$REGION

# View application logs
gcloud logging read "resource.type=cloud_run_revision" --limit=50

# Test database connectivity
gcloud sql connect ontoserver-db --user=ontoserver

# Check Artifact Registry images
gcloud artifacts docker images list $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo

# Test the service
curl $(gcloud run services describe ontoserver --region=$REGION --format="value(status.url)")/fhir/metadata
```

## Cost Optimization

- **Cloud Run**: Pay only for actual usage with automatic scaling to zero
- **Cloud SQL**: Use smallest tier for development (`db-f1-micro`)
- **VPC Access Connector**: Minimal throughput setting
- **Load Balancer**: Only enable if custom domain is required

## Production Considerations

1. **Database Tier**: Use `db-custom-2-4096` or higher for production
2. **Backup**: Cloud SQL automated backups are enabled
3. **Monitoring**: Cloud Monitoring and Logging are configured
4. **SSL**: Enable load balancer with custom domain for production
5. **Scaling**: Configure appropriate min/max instances for Cloud Run

## Support

For issues related to:
- **GCP Infrastructure**: Check Terraform documentation and GCP console
- **Cloud Run**: Review Cloud Run documentation and logs
- **Ontoserver**: Refer to Ontoserver documentation
- **Quay.io Access**: Contact your organization's Quay.io administrator

## License

This deployment follows the same license as the main Ontoserver project. 