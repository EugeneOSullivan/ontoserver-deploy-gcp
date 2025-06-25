# GKE vs Azure Kubernetes Deployment Comparison

This document compares the GKE deployment with the official [AEHRC Ontoserver Azure Kubernetes deployment](https://github.com/aehrc/ontoserver-deploy/tree/master/docker).

## Architecture Comparison

### Azure Kubernetes (Official)
```
Internet
    │
    ▼
[Azure Load Balancer]
    │
    ▼
[Kubernetes Service]
    │
    ▼
[Ontoserver Pod]
    │
    ▼
[Azure Database for PostgreSQL]
```

### GKE (This Implementation)
```
Internet
    │
    ▼
[Cloud Load Balancer]
    │
    ▼
[GKE Cluster]
    │
    ▼
[Ontoserver Pods] (2+ replicas)
    │
    ▼
[Cloud SQL for PostgreSQL]
```

## Key Differences and Advantages

### 1. **Container Orchestration**

| Aspect | Azure Kubernetes | GKE |
|--------|------------------|-----|
| **Management** | Manual Kubernetes cluster | Managed Kubernetes with auto-upgrades |
| **Scaling** | Manual HPA configuration | Automatic node scaling + HPA |
| **Cost** | Pay for cluster nodes 24/7 | Pay for cluster nodes 24/7 |
| **Complexity** | High (Kubernetes expertise) | High (Kubernetes expertise) |

### 2. **Database Configuration**

| Aspect | Azure Kubernetes | GKE |
|--------|------------------|-----|
| **Database** | Azure Database for PostgreSQL | Cloud SQL for PostgreSQL |
| **Connection** | Direct network access | Private VPC with private IP |
| **Security** | Network security groups | Private IP with VPC isolation |
| **Backup** | Azure managed backups | Cloud SQL automated backups |

### 3. **Clustering Support**

| Aspect | Azure Kubernetes | GKE |
|--------|------------------|-----|
| **JGroups** | Supported | Supported |
| **Pod Discovery** | Kubernetes DNS | Kubernetes DNS |
| **Stable IPs** | Pod IPs | Pod IPs |
| **Clustering** | Manual configuration | Automated with manifests |

### 4. **Environment Variables**

Both deployments use the same core environment variables:

```bash
# Database Configuration
DB_HOST=<database-host>
DB_NAME=<database-name>
DB_USER=<database-user>
DB_PASSWORD=<database-password>
DB_PORT=5432

# Application Configuration
SPRING_PROFILES_ACTIVE=cloud
JAVA_OPTS=-Xmx2g -Xms1g
ONTOSERVER_CLUSTERING_ENABLED=true
```

### 5. **Container Image**

Both use the same official Ontoserver image:
```dockerfile
FROM quay.io/aehrc/ontoserver:ctsa-6
```

### 6. **Health Checks**

| Aspect | Azure Kubernetes | GKE |
|--------|------------------|-----|
| **Endpoint** | `/fhir/metadata` | `/fhir/metadata` |
| **Method** | Kubernetes liveness/readiness probes | Kubernetes liveness/readiness probes |
| **Configuration** | YAML manifest | YAML manifest |

## GKE Advantages

### 1. **Managed Kubernetes**
- **Automatic upgrades** and security patches
- **Built-in monitoring** and logging
- **Integrated with GCP services**
- **Better node management**

### 2. **Networking**
- **Private VPC** with isolated networking
- **Cloud SQL private IP** integration
- **VPC-native clusters** for better performance
- **Integrated load balancing**

### 3. **Security**
- **Workload Identity** for service accounts
- **Private clusters** with no public IPs
- **Integrated IAM** for access control
- **Secret Manager** integration

### 4. **Developer Experience**
- **Terraform infrastructure** as code
- **Automated deployment** scripts
- **Integrated monitoring** and logging
- **Better debugging tools**

## Configuration Mapping

### Azure Kubernetes → GKE

| Azure Kubernetes | GKE Equivalent |
|------------------|----------------|
| `kubectl apply -f deployment.yaml` | `kubectl apply -f k8s/` |
| `kubectl get pods` | `kubectl get pods -n ontoserver` |
| `kubectl logs` | `kubectl logs -f deployment/ontoserver -n ontoserver` |
| `kubectl port-forward` | `kubectl port-forward service/ontoserver 8080:80 -n ontoserver` |
| `kubectl scale` | `kubectl scale deployment ontoserver --replicas=3 -n ontoserver` |

### Environment Variables

```yaml
# Azure Kubernetes (deployment.yaml)
env:
- name: DB_HOST
  value: "azure-postgresql-host"
- name: DB_NAME
  value: "ontoserver"
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: username
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password
```

```yaml
# GKE (k8s/deployment.yaml)
env:
- name: DB_HOST
  value: "gcp-postgresql-private-ip"
- name: DB_NAME
  value: "ontoserver"
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: ontoserver-db-secret
      key: username
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: ontoserver-db-secret
      key: password
```

## Migration Path

If you're migrating from Azure Kubernetes to GKE:

1. **Export current configuration**:
   ```bash
   kubectl get deployment ontoserver -o yaml > current-deployment.yaml
   ```

2. **Extract environment variables**:
   ```bash
   kubectl get deployment ontoserver -o jsonpath='{.spec.template.spec.containers[0].env}' > env-vars.json
   ```

3. **Update Kubernetes manifests** in `k8s/` directory with values from your Azure deployment

4. **Deploy to GKE**:
   ```bash
   ./deploy-gke-cluster.sh
   ./deploy-ontoserver-k8s.sh
   ```

## Cost Comparison

### Azure Kubernetes
- **AKS**: ~$73/month (3 nodes, e2-standard-2)
- **Azure Database**: ~$25/month (Basic tier)
- **Load Balancer**: ~$18/month
- **Total**: ~$116/month

### GKE
- **GKE**: ~$73/month (3 nodes, e2-standard-2)
- **Cloud SQL**: ~$25/month (db-f1-micro)
- **Load Balancer**: ~$18/month
- **Total**: ~$116/month

**Note**: Costs are similar, but GKE provides better managed services and integration.

## Conclusion

GKE provides the same functionality as Azure Kubernetes with:
- ✅ **Better managed services** and integration
- ✅ **Improved networking** with private VPC
- ✅ **Enhanced security** with Workload Identity
- ✅ **Automated deployment** with Terraform
- ✅ **Better monitoring** and logging integration

The migration is straightforward since both use standard Kubernetes manifests and the same container image. 