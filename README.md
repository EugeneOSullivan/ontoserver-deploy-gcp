# Ontoserver deployment on Google Cloud Platform

This example creates a recommended environment in Google Cloud Platform that exposes Ontoserver running on Cloud Run with managed services for optimal performance and cost-effectiveness.

**This deployment is based on the official [AEHRC Ontoserver Docker deployment patterns](https://github.com/aehrc/ontoserver-deploy/tree/master/docker) and provides a serverless alternative to the Azure Kubernetes deployment.**

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

## Comparison with Azure Kubernetes

This GCP Cloud Run deployment provides the same functionality as the official Azure Kubernetes deployment with significant advantages:

| Aspect | Azure Kubernetes | GCP Cloud Run |
|--------|------------------|---------------|
| **Management** | Manual Kubernetes cluster | Fully managed serverless |
| **Scaling** | Manual HPA configuration | Automatic scaling to zero |
| **Cost** | Pay for nodes 24/7 | Pay only for requests |
| **Complexity** | High (Kubernetes expertise) | Low (managed service) |
| **Deployment** | `kubectl apply` | `terraform apply` |

See [COMPARISON.md](COMPARISON.md) for detailed comparison.

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
export REGION="europe-west2"
export DATABASE_PASSWORD="your-secure-password"
```

### 2. Run Setup Scripts (Manual Admin Steps)
```bash
cd scripts

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
ontoserver-gcp-deployment/
├── README.md                           # This file
├── COMPARISON.md                       # Azure Kubernetes vs GCP Cloud Run comparison
├── Dockerfile                          # Ontoserver container configuration
├── scripts/                            # IAM and deployment scripts
│   ├── setup-project.sh               # Project setup and API enablement
│   ├── setup-iam.sh                   # Service account and IAM setup
│   ├── setup-artifact-registry.sh     # Container registry setup
│   ├── deploy-ontoserver.sh           # Cloud Run deployment script
│   └── troubleshoot-db-connection.sh  # Database connection troubleshooting
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
export REGION="europe-west2"
export DATABASE_PASSWORD="your-secure-password"

# For Quay.io authentication
export QUAY_USERNAME="your-quay-username"
export QUAY_PASSWORD="your-quay-password"

# For Terraform
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account-key.json"
```

### Database Configuration

The deployment uses the same database configuration as the Azure Kubernetes deployment:

```bash
# Database settings (configured in terraform.tfvars)
database_name     = "ontoserver"
database_user     = "ontoserver"
database_password = "your-secure-password"
database_version  = "POSTGRES_14"
database_tier     = "db-f1-micro"  # Use db-custom-2-4096 for production
```

### Application Configuration

Environment variables match the Azure Kubernetes deployment:

```bash
# Application settings (configured in Terraform)
SPRING_PROFILES_ACTIVE=cloud
JAVA_OPTS=-Xmx2g -Xms1g
DB_PORT=5432
```

## Troubleshooting

### Database Connection Issues

If you're experiencing database connection problems, run the troubleshooting script:

```bash
./scripts/troubleshoot-db-connection.sh
```

This script will:
- Check Terraform infrastructure status
- Verify Cloud Run service configuration
- Validate Cloud SQL instance status
- Check VPC connector configuration
- Verify service account permissions
- Test service connectivity
- Provide actionable recommendations

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
   - Run the troubleshooting script: `./scripts/troubleshoot-db-connection.sh`
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

# Troubleshoot database connections
./scripts/troubleshoot-db-connection.sh
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

## Migration from Azure Kubernetes

If you're migrating from the Azure Kubernetes deployment:

1. **Export current configuration**:
   ```bash
   kubectl get deployment ontoserver -o yaml > current-deployment.yaml
   ```

2. **Extract environment variables**:
   ```bash
   kubectl get deployment ontoserver -o jsonpath='{.spec.template.spec.containers[0].env}' > env-vars.json
   ```

3. **Update Terraform variables** with values from your Azure deployment

4. **Deploy to GCP**:
   ```bash
   terraform apply
   ```

See [COMPARISON.md](COMPARISON.md) for detailed migration guidance.

## Support

For issues related to:
- **GCP Infrastructure**: Check Terraform documentation and GCP console
- **Cloud Run**: Review Cloud Run documentation and logs
- **Ontoserver**: Refer to [AEHRC Ontoserver documentation](https://github.com/aehrc/ontoserver-deploy)
- **Quay.io Access**: Contact your organization's Quay.io administrator

## License

This deployment follows the same license as the main Ontoserver project. 