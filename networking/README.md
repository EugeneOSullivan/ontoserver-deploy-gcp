# Ontoserver GCP Networking Overview

This document provides a high-level overview of the networking architecture for the Ontoserver GCP deployment.

## Architecture

The deployment uses a private VPC architecture for security:

```
Internet
    │
    ▼
[Cloud Run Service] (public endpoint)
    │
    ▼
[VPC Connector]
    │
    ▼
[Private VPC]
    │
    ▼
[Cloud SQL Instance] (private IP only)
```

## Key Components

### VPC Configuration
- **VPC Name**: `ontoserver-vpc`
- **Subnet**: `ontoserver-subnet` (10.0.0.0/24)
- **Region**: `europe-west2`
- **Private Google Access**: Enabled

### Cloud SQL
- **Private IP only** - No public access
- **VPC Network**: Connected to `ontoserver-vpc`
- **SSL Required**: All connections use SSL/TLS

### Cloud Run
- **VPC Connector**: `ontoserver-connector`
- **Egress**: All traffic routed through VPC
- **Service Account**: `ontoserver-run-sa@project-id.iam.gserviceaccount.com`

### Load Balancer (Optional)
- **Type**: Global HTTP(S) Load Balancer
- **SSL Certificate**: Google-managed (if custom domain)
- **Health Checks**: `/fhir/metadata` endpoint

## Security Features

### Network Security
- ✅ All resources in private VPC
- ✅ Cloud SQL has no public IP
- ✅ VPC connector for secure database access
- ✅ Private service connection for Cloud SQL

### Data Protection
- ✅ SSL/TLS encryption in transit
- ✅ Cloud SQL encryption at rest
- ✅ Database credentials in Secret Manager
- ✅ Minimal IAM permissions

## Implementation

**All networking is automatically configured by Terraform** - no manual setup required.

### Terraform Resources Created
- VPC and subnet with private Google access
- VPC connector for Cloud Run
- Private service connection for Cloud SQL
- Firewall rules for internal communication
- Load balancer (if enabled)

## Troubleshooting

For networking issues, see:
- [CLOUD_SQL_TROUBLESHOOTING.md](../CLOUD_SQL_TROUBLESHOOTING.md) - Comprehensive diagnostics
- [Main README.md](../README.md) - Setup and deployment guide

### Common Commands
```bash
# Check VPC connector status
gcloud compute networks vpc-access connectors describe ontoserver-connector --region=europe-west2

# Verify private service connection
gcloud services vpc-peerings list --network=ontoserver-vpc

# Check Cloud SQL private IP
gcloud sql instances describe ontoserver-db --format="value(ipAddresses[0].ipAddress)"
```

## Cost Considerations

- **VPC**: No additional cost
- **VPC Connector**: $0.10 per vCPU-hour
- **Load Balancer**: $18/month (only if custom domain enabled)
- **SSL Certificate**: Free for managed certificates

## Compliance

- **Data Residency**: All resources in specified region
- **Audit Logging**: Enabled for all services
- **Backup**: Cloud SQL automated backups enabled 