# GCP Cloud Run vs Azure Kubernetes Deployment Comparison

This document compares the GCP Cloud Run deployment with the official [AEHRC Ontoserver Azure Kubernetes deployment](https://github.com/aehrc/ontoserver-deploy/tree/master/docker).

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

### GCP Cloud Run (This Implementation)
```
Internet
    │
    ▼
[Cloud Load Balancer] (optional)
    │
    ▼
[Cloud Run Service]
    │
    ▼
[VPC Connector]
    │
    ▼
[Cloud SQL for PostgreSQL]
```

## Key Differences and Advantages

### 1. **Container Orchestration**

| Aspect | Azure Kubernetes | GCP Cloud Run |
|--------|------------------|---------------|
| **Management** | Manual Kubernetes cluster management | Fully managed serverless platform |
| **Scaling** | Manual HPA configuration | Automatic scaling to zero |
| **Cost** | Pay for cluster nodes 24/7 | Pay only for actual requests |
| **Complexity** | High (Kubernetes expertise required) | Low (managed service) |

### 2. **Database Configuration**

| Aspect | Azure Kubernetes | GCP Cloud Run |
|--------|------------------|---------------|
| **Database** | Azure Database for PostgreSQL | Cloud SQL for PostgreSQL |
| **Connection** | Direct network access | Private VPC with VPC connector |
| **Security** | Network security groups | Private IP with VPC isolation |
| **Backup** | Azure managed backups | Cloud SQL automated backups |

### 3. **Environment Variables**

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
```

### 4. **Container Image**

Both use the same official Ontoserver image:
```dockerfile
FROM quay.io/aehrc/ontoserver:ctsa-6
```

### 5. **Health Checks**

| Aspect | Azure Kubernetes | GCP Cloud Run |
|--------|------------------|---------------|
| **Endpoint** | `/fhir/metadata` | `/fhir/metadata` |
| **Method** | Kubernetes liveness/readiness probes | Cloud Run health checks |
| **Configuration** | YAML manifest | Terraform annotations |

## GCP Cloud Run Advantages

### 1. **Simplified Operations**
- **No Kubernetes expertise required**
- **Automatic scaling and load balancing**
- **Built-in monitoring and logging**
- **Zero-downtime deployments**

### 2. **Cost Optimization**
- **Scale to zero** when not in use
- **Pay per request** instead of per node
- **No cluster management overhead**

### 3. **Security**
- **Private VPC** with isolated networking
- **Secret Manager** for sensitive data
- **IAM integration** for access control
- **VPC connector** for private database access

### 4. **Developer Experience**
- **Faster deployments** (no cluster setup)
- **Simplified debugging** with Cloud Logging
- **Terraform infrastructure as code**
- **Automated CI/CD integration**

## Configuration Mapping

### Azure Kubernetes → GCP Cloud Run

| Azure Kubernetes | GCP Cloud Run Equivalent |
|------------------|--------------------------|
| `kubectl apply -f deployment.yaml` | `terraform apply` |
| `kubectl get pods` | `gcloud run services describe` |
| `kubectl logs` | `gcloud logging read` |
| `kubectl port-forward` | `gcloud run services update-traffic` |
| `kubectl scale` | Automatic scaling (configurable) |

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

```hcl
# GCP Cloud Run (main.tf)
env {
  name  = "DB_HOST"
  value = google_sql_database_instance.instance.private_ip_address
}
env {
  name = "DB_USER"
  value_from {
    secret_key_ref {
      name = google_secret_manager_secret.db_user.secret_id
      key  = "latest"
    }
  }
}
env {
  name = "DB_PASSWORD"
  value_from {
    secret_key_ref {
      name = google_secret_manager_secret.db_password.secret_id
      key  = "latest"
    }
  }
}
```

## Migration Path

If you're migrating from Azure Kubernetes to GCP Cloud Run:

1. **Export current configuration**:
   ```bash
   kubectl get deployment ontoserver -o yaml > current-deployment.yaml
   ```

2. **Extract environment variables**:
   ```bash
   kubectl get deployment ontoserver -o jsonpath='{.spec.template.spec.containers[0].env}' > env-vars.json
   ```

3. **Update Terraform variables**:
   ```bash
   # Copy values from env-vars.json to terraform.tfvars
   ```

4. **Deploy to GCP**:
   ```bash
   terraform apply
   ```

## Best Practices Alignment

Both deployments follow the same best practices:

### 1. **Security**
- ✅ Private database access
- ✅ Secret management
- ✅ Network isolation
- ✅ IAM roles and permissions

### 2. **Monitoring**
- ✅ Health checks
- ✅ Logging integration
- ✅ Metrics collection
- ✅ Alerting capabilities

### 3. **Scalability**
- ✅ Horizontal scaling
- ✅ Load balancing
- ✅ Resource limits
- ✅ Performance optimization

### 4. **Reliability**
- ✅ High availability
- ✅ Automatic failover
- ✅ Backup strategies
- ✅ Disaster recovery

## Conclusion

The GCP Cloud Run deployment provides the same functionality as the Azure Kubernetes deployment with significant operational advantages:

- **Reduced complexity** for developers and operators
- **Lower costs** through serverless pricing
- **Faster time to market** with managed services
- **Better security** with GCP's security-first approach
- **Simplified maintenance** with automatic updates and scaling

The core Ontoserver application remains unchanged, ensuring compatibility with existing FHIR workflows and integrations. 