# Cloud SQL Connection Troubleshooting Guide

Based on: https://stackoverflow.com/questions/68558542/how-to-connect-a-spring-boot-service-from-google-cloud-run-to-sql-cloud-instance

## Quick Diagnosis

Before diving into specific issues, run these commands to check your current setup:

```bash
# 1. Check if you have gcloud installed
which gcloud

# 2. Set your project ID (replace with your actual project ID)
export PROJECT_ID="your-actual-project-id"

# 3. Run the troubleshooting script
./scripts/troubleshoot-db-connection.sh
```

## Common Issues and Solutions

### Issue 1: VPC Connector Not Working

**Symptoms:**
- Cloud Run can't reach Cloud SQL
- Connection timeout errors
- "No route to host" errors

**Solution:**
```bash
# Check VPC connector status
gcloud compute networks vpc-access connectors describe ontoserver-connector --region=europe-west2

# Verify VPC connector is attached to Cloud Run
gcloud run services describe ontoserver --region=europe-west2 --format="yaml" | grep -A 5 -B 5 vpc-access
```

**Expected output should show:**
```yaml
metadata:
  annotations:
    run.googleapis.com/vpc-access-connector: ontoserver-connector
    run.googleapis.com/vpc-access-egress: all-traffic
```

### Issue 2: Private Service Connection Missing

**Symptoms:**
- Cloud SQL instance has no private IP
- Connection refused errors

**Solution:**
```bash
# Check if private service connection exists
gcloud services vpc-peerings list --network=ontoserver-vpc

# Check Cloud SQL private IP
gcloud sql instances describe ontoserver-db --format="value(settings.ipConfiguration.privateNetwork)"
```

**Expected output:**
```
projects/your-project/global/networks/ontoserver-vpc
```

### Issue 3: Service Account Permissions

**Symptoms:**
- Authentication errors
- Permission denied errors

**Solution:**
```bash
# Check service account roles
gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:ontoserver-run-sa@$PROJECT_ID.iam.gserviceaccount.com"

# Add missing roles if needed
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:ontoserver-run-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:ontoserver-run-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Issue 4: Database Connection String Format

**Symptoms:**
- Connection string parsing errors
- Wrong host format

**Solution:**
The connection string should use the private IP address, not the connection name:

```bash
# Get the private IP
gcloud sql instances describe ontoserver-db --format="value(ipAddresses[0].ipAddress)"

# Verify environment variables in Cloud Run
gcloud run services describe ontoserver --region=europe-west2 --format="yaml" | grep -A 10 -B 5 DB_HOST
```

**Correct format:**
```
DB_HOST=10.0.0.3  # Private IP address
DB_PORT=5432
DB_NAME=ontoserver
DB_USER=ontoserver
DB_PASSWORD=<from-secret-manager>
```

### Issue 5: Firewall Rules

**Symptoms:**
- Connection timeout
- Network unreachable

**Solution:**
```bash
# Check if internal firewall rule exists
gcloud compute firewall-rules list --filter="network=ontoserver-vpc"

# Create internal firewall rule if missing
gcloud compute firewall-rules create ontoserver-allow-internal \
  --network=ontoserver-vpc \
  --allow=tcp,udp,icmp \
  --source-ranges=10.0.0.0/8
```

### Issue 6: SSL/TLS Configuration

**Symptoms:**
- SSL handshake errors
- Certificate validation failures

**Solution:**
For Cloud SQL with private IP, SSL is required. Check your application configuration:

```properties
# application-cloud.properties
spring.datasource.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASSWORD}
```

## Step-by-Step Verification

### Step 1: Verify Infrastructure
```bash
cd terraform
terraform plan
```

### Step 2: Check Cloud SQL Status
```bash
gcloud sql instances describe ontoserver-db
```

Look for:
- `state: RUNNABLE`
- `ipConfiguration.privateNetwork` is set
- `ipConfiguration.ipv4Enabled: false`

### Step 3: Check VPC Connector
```bash
gcloud compute networks vpc-access connectors describe ontoserver-connector --region=europe-west2
```

Look for:
- `state: READY`
- `network: ontoserver-vpc`

### Step 4: Check Cloud Run Configuration
```bash
gcloud run services describe ontoserver --region=europe-west2
```

Look for:
- VPC connector annotation
- Environment variables are set correctly
- Service account is configured

### Step 5: Test Connectivity
```bash
# Test from Cloud Run (if you have a test job)
gcloud run jobs execute test-db-connection --region=europe-west2

# Or check logs for connection attempts
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=ontoserver" --limit=20
```

## Debugging Commands

### Check Recent Logs
```bash
# Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=ontoserver AND severity>=ERROR" --limit=20

# Cloud SQL logs
gcloud sql logs tail ontoserver-db

# VPC flow logs
gcloud logging read "resource.type=gce_subnetwork AND resource.labels.subnetwork_name=ontoserver-subnet" --limit=10
```

### Network Connectivity Test
```bash
# Check if VPC connector can reach Cloud SQL
gcloud compute networks vpc-access connectors describe ontoserver-connector --region=europe-west2 --format="value(network)"

# Verify private service connection
gcloud services vpc-peerings list --network=ontoserver-vpc
```

### Service Account Test
```bash
# Test service account permissions
gcloud auth list --filter="status:ACTIVE"

# Check IAM bindings
gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:ontoserver-run-sa@$PROJECT_ID.iam.gserviceaccount.com"
```

## Common Error Messages and Solutions

### "Connection refused"
- **Cause**: VPC connector not working or firewall blocking
- **Solution**: Check VPC connector status and firewall rules

### "No route to host"
- **Cause**: Private service connection not established
- **Solution**: Verify VPC peering with servicenetworking.googleapis.com

### "Authentication failed"
- **Cause**: Wrong credentials or service account permissions
- **Solution**: Check Secret Manager and IAM roles

### "SSL handshake failed"
- **Cause**: SSL configuration mismatch
- **Solution**: Use `sslmode=require` in connection string

### "Connection timeout"
- **Cause**: Network routing issues
- **Solution**: Check VPC connector and private service connection

## Prevention Checklist

Before deploying, ensure:

- [ ] VPC connector is created and in READY state
- [ ] Private service connection is established
- [ ] Cloud SQL has private IP enabled
- [ ] Service account has required IAM roles
- [ ] Firewall rules allow internal communication
- [ ] Environment variables are correctly set
- [ ] SSL is properly configured in application

## Getting Help

If you're still having issues:

1. Run the troubleshooting script: `./scripts/troubleshoot-db-connection.sh`
2. Check the Stack Overflow post for additional solutions
3. Review Cloud Run and Cloud SQL documentation
4. Check GCP console for detailed error messages 