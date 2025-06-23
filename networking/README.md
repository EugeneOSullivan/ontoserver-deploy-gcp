# Ontoserver GCP Networking Requirements

This document outlines the networking requirements and configuration for deploying Ontoserver on Google Cloud Platform.

## Overview

The Ontoserver deployment requires a secure, private network configuration with the following components:
- Private VPC with custom subnets
- Cloud SQL with private IP
- Cloud Run with VPC connector
- Load balancer (optional) with SSL termination
- Firewall rules for security

## Network Architecture

```
Internet
    │
    ▼
[Load Balancer] (optional)
    │
    ▼
[Cloud Run Service]
    │
    ▼
[VPC Connector]
    │
    ▼
[Private VPC]
    │
    ▼
[Cloud SQL Instance]
```

## Required Network Components

### 1. VPC Configuration

**VPC Name**: `ontoserver-vpc`
**Subnet**: `ontoserver-subnet`
**CIDR Range**: `10.0.0.0/24`
**Region**: `europe-west2`

**Features**:
- Private Google Access enabled
- Custom subnet mode
- Regional routing

### 2. Cloud SQL Network Configuration

**Private IP**: Enabled
**VPC Network**: `ontoserver-vpc`
**Authorized Networks**: None (private only)

**Security**:
- No public IP access
- SSL connections required
- Private service connection

### 3. Cloud Run Network Configuration

**VPC Connector**: Required for private database access
**Service Account**: `ontoserver-run-sa@project-id.iam.gserviceaccount.com`
**Network**: `ontoserver-vpc`

### 4. Load Balancer Configuration (Optional)

**Type**: Global HTTP(S) Load Balancer
**Backend**: Cloud Run service
**SSL Certificate**: Managed certificate
**Domain**: Custom domain (if provided)

## Firewall Rules

### Required Rules

1. **Internal Communication**
   - Source: `10.0.0.0/8`
   - Protocol: TCP, UDP, ICMP
   - Purpose: Internal service communication

2. **Cloud SQL Access**
   - Source: Cloud Run service
   - Destination: Cloud SQL instance
   - Protocol: TCP/5432
   - Purpose: Database connectivity

3. **Health Checks**
   - Source: Google health check ranges
   - Destination: Cloud Run service
   - Protocol: HTTP/80
   - Purpose: Load balancer health checks

### Optional Rules

4. **SSH Access** (for debugging)
   - Source: `0.0.0.0/0`
   - Protocol: TCP/22
   - Purpose: Administrative access

## DNS Configuration

### Required DNS Records

If using a custom domain:

```
Type: A
Name: @
Value: [Load Balancer IP]

Type: CNAME
Name: www
Value: [Custom Domain]
```

### SSL Certificate

- **Type**: Google-managed SSL certificate
- **Domain**: Custom domain
- **Auto-renewal**: Enabled
- **Validation**: DNS or HTTP validation

## Security Considerations

### Network Security

1. **Private Network**: All resources use private IP addresses
2. **No Public Access**: Cloud SQL has no public IP
3. **VPC Isolation**: Resources are isolated in private VPC
4. **Service Accounts**: Minimal required permissions

### Data Protection

1. **Encryption in Transit**: SSL/TLS for all connections
2. **Encryption at Rest**: Cloud SQL data encrypted
3. **Secret Management**: Database credentials in Secret Manager

### Access Control

1. **IAM Roles**: Principle of least privilege
2. **Service Accounts**: Dedicated accounts per service
3. **Network Policies**: Restrictive firewall rules

## Monitoring and Logging

### Network Monitoring

1. **VPC Flow Logs**: Enable for traffic analysis
2. **Firewall Logs**: Monitor rule hits
3. **Cloud SQL Logs**: Database access logs
4. **Cloud Run Logs**: Application logs

### Alerting

1. **Network Errors**: Alert on connection failures
2. **Security Events**: Monitor for unauthorized access
3. **Performance**: Track latency and throughput

## Implementation Steps

### For Infrastructure Team

1. **Create VPC and Subnet**
   ```bash
   gcloud compute networks create ontoserver-vpc \
     --subnet-mode=custom \
     --bgp-routing-mode=regional
   
   gcloud compute networks subnets create ontoserver-subnet \
     --network=ontoserver-vpc \
     --region=europe-west2 \
     --range=10.0.0.0/24 \
     --enable-private-ip-google-access
   ```

2. **Configure Firewall Rules**
   ```bash
   gcloud compute firewall-rules create ontoserver-allow-internal \
     --network=ontoserver-vpc \
     --allow=tcp,udp,icmp \
     --source-ranges=10.0.0.0/8
   ```

3. **Enable VPC Flow Logs**
   ```bash
   gcloud compute networks subnets update ontoserver-subnet \
     --region=europe-west2 \
     --enable-flow-logs
   ```

### For Network Team

1. **DNS Configuration**
   - Add A record pointing to load balancer IP
   - Configure CNAME for www subdomain
   - Set up SSL certificate validation

2. **SSL Certificate**
   - Request managed SSL certificate
   - Validate domain ownership
   - Monitor certificate expiration

3. **Load Balancer**
   - Configure backend service
   - Set up health checks
   - Configure SSL termination

## Troubleshooting

### Common Issues

1. **Database Connection Failures**
   - Verify VPC connector configuration
   - Check firewall rules
   - Validate service account permissions

2. **Load Balancer Health Check Failures**
   - Verify Cloud Run service is running
   - Check health check path (`/fhir/metadata`)
   - Validate network connectivity

3. **SSL Certificate Issues**
   - Verify domain ownership
   - Check DNS propagation
   - Monitor certificate status

### Useful Commands

```bash
# Check VPC configuration
gcloud compute networks describe ontoserver-vpc

# Verify subnet configuration
gcloud compute networks subnets describe ontoserver-subnet --region=europe-west2

# Test database connectivity
gcloud sql connect ontoserver-db --user=ontoserver

# Check firewall rules
gcloud compute firewall-rules list --filter="network=ontoserver-vpc"

# Monitor VPC flow logs
gcloud logging read "resource.type=gce_subnetwork AND resource.labels.subnetwork_name=ontoserver-subnet"
```

## Cost Considerations

### Network Costs

1. **VPC**: No additional cost
2. **Subnet**: No additional cost
3. **VPC Connector**: $0.10 per vCPU-hour
4. **Load Balancer**: $18/month + data processing
5. **SSL Certificate**: Free for managed certificates

### Optimization

1. **VPC Connector**: Use minimal vCPU allocation
2. **Load Balancer**: Only enable if custom domain required
3. **Flow Logs**: Enable only for troubleshooting

## Compliance and Governance

### Data Residency

- Ensure all resources are in the required region
- Verify data doesn't cross geographic boundaries
- Monitor for compliance violations

### Audit Requirements

- Enable audit logging for all services
- Retain logs for required period
- Monitor for security events

### Backup and Recovery

- Cloud SQL automated backups
- VPC configuration backup
- Disaster recovery procedures 