# Ontoserver GKE Deployment

This guide helps you deploy AEHRC Ontoserver on Google Kubernetes Engine (GKE) instead of Cloud Run, which is necessary for proper JGroups/Infinispan clustering support.

## Why GKE Instead of Cloud Run?

Cloud Run's serverless model doesn't support the persistent network connections and stable IP addresses required by JGroups clustering. GKE provides:

- Stable pod IPs for cluster member discovery
- Support for clustering protocols like JGroups
- Better resource management for stateful applications
- Persistent storage for Ontoserver data

## Architecture

The GKE deployment includes:

- **GKE Cluster**: Private cluster with 2+ nodes
- **Cloud SQL PostgreSQL**: Private database instance
- **Artifact Registry**: Container image storage
- **VPC**: Private networking with secondary ranges for pods/services
- **Load Balancer**: Optional HTTPS load balancer with SSL
- **Persistent Storage**: For Ontoserver data persistence

## Prerequisites

1. **GCP Project** with billing enabled
2. **Required tools**:
   - `gcloud` CLI (authenticated)
   - `terraform` >= 1.0
   - `kubectl`
3. **Permissions**: Editor or custom roles for GKE, Cloud SQL, networking

## Quick Start

### 1. Enable APIs and Set Up Project

```bash
# Clone and navigate to the repository
cd scripts/
./setup-project.sh
./setup-iam.sh
```

### 2. Configure Terraform Variables

```bash
# Copy and edit the terraform variables
cp terraform/gke-terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform/terraform.tfvars with your project details
```

Required variables:
- `project_id`: Your GCP project ID
- `database_password`: Secure password for PostgreSQL
- `domain_name`: Your domain (optional, for SSL)

### 3. Deploy GKE Cluster

```bash
cd scripts/
./deploy-gke-cluster.sh
```

This script will:
- Initialize Terraform with GCS backend
- Create GKE cluster, VPC, Cloud SQL, and other resources
- Configure kubectl to connect to the cluster

### 4. Build and Push Container Image

```bash
./setup-artifact-registry.sh
```

### 5. Deploy Ontoserver to Kubernetes

```bash
./deploy-ontoserver-k8s.sh
```

This script will:
- Update Kubernetes manifests with your configuration
- Create database secrets
- Deploy Ontoserver with clustering enabled
- Set up ingress (if configured)

## Configuration

### Kubernetes Manifests

The `k8s/` directory contains:

- `namespace.yaml`: Ontoserver namespace
- `deployment.yaml`: Main application deployment (2 replicas)
- `service.yaml`: ClusterIP and headless services
- `configmap.yaml`: Environment variables and JGroups config
- `secret.yaml`: Database credentials template
- `serviceaccount.yaml`: RBAC for pod discovery
- `pvc.yaml`: Persistent volume for data
- `ingress.yaml`: Optional external access

### Clustering Configuration

The deployment enables JGroups clustering with:

```yaml
ONTOSERVER_CLUSTERING_ENABLED: "true"
JGROUPS_BIND_ADDR: "0.0.0.0"
KUBERNETES_NAMESPACE: "ontoserver"
KUBERNETES_LABELS: "app=ontoserver"
```

### Scaling

Scale the deployment:

```bash
kubectl scale deployment ontoserver --replicas=3 -n ontoserver
```

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

## Customization

### Resource Limits

Edit `k8s/deployment.yaml`:

```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "2000m"
  limits:
    memory: "8Gi"
    cpu: "4000m"
```

### Storage

Edit `k8s/pvc.yaml` for different storage sizes:

```yaml
resources:
  requests:
    storage: 50Gi
```

### JGroups Configuration

Modify `k8s/configmap.yaml` for advanced clustering:

```yaml
JGROUPS_BIND_ADDR: "match-interface:eth0"
JGROUPS_EXTERNAL_ADDR: "match-interface:eth0"
```

## Cost Optimization

### Development Environment

- Use `e2-standard-2` machine type
- Set `gke_num_nodes = 1`
- Use `db-f1-micro` database tier

### Production Environment

- Use `e2-standard-4` or larger
- Set `gke_num_nodes = 3+`
- Use `db-standard-2` or larger
- Enable preemptible nodes for cost savings

## Security

The deployment includes:

- **Private GKE cluster**: No public IPs on nodes
- **Private Cloud SQL**: No public IP access
- **VPC-native networking**: Secure pod-to-pod communication
- **RBAC**: Minimal permissions for service accounts
- **Network policies**: Available for additional pod isolation

## Cleanup

To destroy all resources:

```bash
cd terraform/
terraform destroy -var-file=terraform.tfvars
```

## Migration from Cloud Run

If migrating from the existing Cloud Run setup:

1. **Backup data**: Export any important Ontoserver data
2. **Update DNS**: Point your domain to the new GKE ingress IP
3. **Monitor**: Verify clustering is working correctly
4. **Cleanup**: Remove old Cloud Run resources after validation

## Support

For issues:

1. Check pod logs: `kubectl logs -f deployment/ontoserver -n ontoserver`
2. Verify networking: Ensure pods can reach database and each other
3. Check RBAC: Verify service account has pod discovery permissions
4. Review JGroups logs: Look for clustering-related messages

## Differences from Azure Deployment

This GKE deployment is based on the Azure reference but adapted for Google Cloud:

- Uses Google Cloud SQL instead of Azure Database
- GKE instead of AKS
- Google Cloud Load Balancer instead of Application Gateway
- Artifact Registry instead of Azure Container Registry
- Cloud DNS instead of Azure DNS

The core Kubernetes manifests and JGroups configuration remain similar to ensure compatibility.