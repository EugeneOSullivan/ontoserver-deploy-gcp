# Ontoserver GKE Deployment

This repository provides a complete deployment solution for AEHRC Ontoserver on Google Kubernetes Engine (GKE) with proper clustering support.

## Why GKE?

GKE provides the necessary features for Ontoserver clustering:
- **Stable pod IPs** for cluster member discovery
- **JGroups clustering** support
- **Persistent storage** for Ontoserver data
- **Better resource management** for stateful applications

## Architecture

```
Internet
    │
    ▼
[Load Balancer] (optional)
    │
    ▼
[GKE Cluster]
    │
    ▼
[Ontoserver Pods] (2+ replicas)
    │
    ▼
[Cloud SQL PostgreSQL] (private IP)
```

## Prerequisites

1. **Google Cloud SDK** installed and configured
2. **Terraform** (version >= 1.0)
3. **Docker** for pulling and pushing images
4. **kubectl** for Kubernetes management
5. **gcloud** CLI authenticated with appropriate permissions
6. **Quay.io credentials** - You'll need a Quay.io account to pull the Ontoserver image

## Quick Start

### 1. Set Environment Variables
```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="europe-west2"
export DATABASE_PASSWORD="your-secure-password"
export QUAY_USERNAME="your-quay-username"
export QUAY_PASSWORD="your-quay-password"
```

### 2. Enable APIs and Setup Project
```bash
cd scripts
./setup-project.sh
./setup-iam.sh
```

### 3. Configure Terraform
```bash
cd ../terraform
cp gke-terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 4. Deploy GKE Cluster
```bash
cd ../scripts
./deploy-gke-cluster.sh
```

### 5. Setup Container Registry
```bash
./setup-artifact-registry.sh
```

### 6. Deploy Ontoserver to Kubernetes
```bash
./deploy-ontoserver-k8s.sh
```

### 7. Access Your Application
```bash
# Get the external IP
kubectl get ingress ontoserver-ingress -n ontoserver

# Or port forward for local access
kubectl port-forward service/ontoserver 8080:80 -n ontoserver
# Access at http://localhost:8080/fhir
```

## Directory Structure

```
ontoserver-gcp-deployment/
├── README.md                           # This file
├── COMPARISON.md                       # Azure Kubernetes vs GKE comparison
├── scripts/                            # Deployment scripts
│   ├── setup-project.sh               # Project setup and API enablement
│   ├── setup-iam.sh                   # Service account and IAM setup
│   ├── setup-artifact-registry.sh     # Container registry setup
│   ├── deploy-gke-cluster.sh          # GKE cluster deployment
│   └── deploy-ontoserver-k8s.sh       # Kubernetes deployment
├── terraform/                          # Infrastructure as Code
│   ├── gke-main.tf                    # GKE Terraform configuration
│   ├── gke-variables.tf               # Variable definitions
│   ├── gke-terraform.tfvars.example   # Example variable values
│   └── gke-outputs.tf                 # Output values
└── k8s/                               # Kubernetes manifests
    ├── namespace.yaml                 # Ontoserver namespace
    ├── deployment.yaml                # Main application deployment
    ├── service.yaml                   # ClusterIP and headless services
    ├── configmap.yaml                 # Environment variables
    ├── secret.yaml                    # Database credentials template
    ├── serviceaccount.yaml            # RBAC for pod discovery
    ├── pvc.yaml                       # Persistent volume for data
    └── ingress.yaml                   # External access
```

## Configuration

### Required Environment Variables

```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="europe-west2"
export DATABASE_PASSWORD="your-secure-password"
export QUAY_USERNAME="your-quay-username"
export QUAY_PASSWORD="your-quay-password"
```

### Database Configuration

The deployment uses PostgreSQL with the same configuration as the Azure Kubernetes deployment:

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
# Application settings (configured in Kubernetes manifests)
SPRING_PROFILES_ACTIVE=cloud
JAVA_OPTS=-Xmx2g -Xms1g
DB_PORT=5432
ONTOSERVER_CLUSTERING_ENABLED=true
```

## Clustering Configuration

The deployment enables JGroups clustering with:

```yaml
ONTOSERVER_CLUSTERING_ENABLED: "true"
JGROUPS_BIND_ADDR: "0.0.0.0"
KUBERNETES_NAMESPACE: "ontoserver"
KUBERNETES_LABELS: "app=ontoserver"
```

## Scaling

Scale the deployment:

```bash
kubectl scale deployment ontoserver --replicas=3 -n ontoserver
```

## Monitoring and Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n ontoserver
kubectl describe pod <pod-name> -n ontoserver
```

### View Logs
```bash
kubectl logs -f deployment/ontoserver -n ontoserver
```

### Check Clustering
```bash
# Check if pods can discover each other
kubectl exec -it <pod-name> -n ontoserver -- curl http://ontoserver-headless:7800
```

### Database Connection
```bash
# Test database connectivity
kubectl exec -it <pod-name> -n ontoserver -- nc -zv <db-ip> 5432
```

## Troubleshooting

### Common Issues

1. **Pod startup failures**: Check logs with `kubectl logs -f deployment/ontoserver -n ontoserver`
2. **Database connection issues**: Verify Cloud SQL instance is running and accessible
3. **Clustering not working**: Ensure pods can communicate via headless service
4. **Image pull errors**: Verify Quay.io credentials and Artifact Registry setup

### Getting Help

- Check the [COMPARISON.md](COMPARISON.md) for differences between Azure and GKE deployments
- Review Terraform outputs for resource information
- Use `kubectl describe` commands for detailed resource status

## Accessing Ontoserver

### Via Load Balancer (Recommended)
If you configured a domain name:
```
https://your-domain.com/fhir
```

### Via External IP
Get the external IP:
```bash
kubectl get ingress ontoserver-ingress -n ontoserver
```

### Via Port Forward (Development)
```bash
kubectl port-forward service/ontoserver 8080:80 -n ontoserver
# Access at http://localhost:8080/fhir
```

## Cost Optimization

- **GKE**: Use preemptible nodes for development
- **Cloud SQL**: Use smallest tier for development (`db-f1-micro`)
- **Load Balancer**: Only enable if custom domain is required
- **Persistent Storage**: Use appropriate storage class

## Production Considerations

1. **Database Tier**: Use `db-custom-2-4096` or higher for production
2. **GKE Node Pool**: Use dedicated nodes for production
3. **Backup**: Cloud SQL automated backups are enabled
4. **Monitoring**: Cloud Monitoring and Logging are configured
5. **SSL**: Enable load balancer with custom domain for production
6. **Scaling**: Configure appropriate min/max replicas

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

4. **Deploy to GKE**:
   ```bash
   ./deploy-gke-cluster.sh
   ./deploy-ontoserver-k8s.sh
   ```

See [COMPARISON.md](COMPARISON.md) for detailed migration guidance.

## Support

For issues related to:
- **GCP Infrastructure**: Check Terraform documentation and GCP console
- **GKE**: Review GKE documentation and logs
- **Ontoserver**: Refer to [AEHRC Ontoserver documentation](https://github.com/aehrc/ontoserver-deploy)
- **Quay.io Access**: Contact your organization's Quay.io administrator

## License

This deployment follows the same license as the main Ontoserver project. 