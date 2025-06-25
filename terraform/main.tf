terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    # Configure with: terraform init -backend-config="bucket=${PROJECT_ID}-terraform-state"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "vpcaccess.googleapis.com",
    "dns.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_dependent_services = true
  disable_on_destroy         = false
}

# Create VPC
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required_apis]
}

# Create subnet
resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true
}

# Create private service connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  depends_on    = [google_project_service.required_apis]
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  depends_on              = [google_project_service.required_apis]
}

# Create Cloud SQL instance
resource "google_sql_database_instance" "instance" {
  name             = var.database_instance_name
  database_version = var.database_version
  region           = var.region

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = var.database_tier
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }
    backup_configuration {
      enabled    = true
      start_time = "02:00"
    }
    maintenance_window {
      day          = 7
      hour         = 2
      update_track = "stable"
    }
  }

  deletion_protection = false
}

# Create database
resource "google_sql_database" "database" {
  name     = var.database_name
  instance = google_sql_database_instance.instance.name
}

# Create database user
resource "google_sql_user" "user" {
  name     = var.database_user
  instance = google_sql_database_instance.instance.name
  password = var.database_password
}

# Create Artifact Registry repository
resource "google_artifact_registry_repository" "repository" {
  location      = var.region
  repository_id = "ontoserver-repo"
  description   = "Repository for Ontoserver container images"
  format        = "DOCKER"

  depends_on = [google_project_service.required_apis]
}

# Create secrets
resource "google_secret_manager_secret" "db_password" {
  secret_id = "ontoserver-db-password"
  depends_on = [google_project_service.required_apis]

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.database_password
}

resource "google_secret_manager_secret" "db_user" {
  secret_id = "ontoserver-db-user"
  depends_on = [google_project_service.required_apis]

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_user" {
  secret      = google_secret_manager_secret.db_user.id
  secret_data = var.database_user
}

# Create VPC Connector for Cloud Run to access private resources
resource "google_vpc_access_connector" "connector" {
  name          = "ontoserver-connector"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name
  depends_on    = [google_project_service.required_apis]
}

# Create Cloud Run service
resource "google_cloud_run_service" "ontoserver" {
  name     = var.service_name
  location = var.region

  depends_on = [google_project_service.required_apis]

  template {
    spec {
      service_account_name = var.service_account_email
      
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/ontoserver-repo/ontoserver:latest"
        
        resources {
          limits = {
            cpu    = "2000m"
            memory = "4Gi"
          }
        }
        env {
          name  = "SPRING_DATASOURCE_URL"
          value = "jdbc:postgresql://${google_sql_database_instance.instance.private_ip_address}:5432/${google_sql_database.database.name}?sslmode=disable"
        }
        env {
          name  = "SPRING_DATASOURCE_USERNAME"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.db_user.secret_id
              key  = "latest"
            }
          }
        }
        env {
          name  = "SPRING_DATASOURCE_PASSWORD"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.db_password.secret_id
              key  = "latest"
            }
          }
        }
        env {
          name  = "DB_PORT"
          value = "5432"
        }
        env {
          name  = "ONTOSERVER_CLUSTERING_ENABLED"
          value = "false"
        }
        env {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "standalone"
        }
        env {
          name  = "JAVA_OPTS"
          value = "-Xmx2g -Xms1g"
        }
      }
    }

    metadata {
      annotations = {
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
        "run.googleapis.com/vpc-access-egress"    = "all-traffic"
        "run.googleapis.com/client-name"          = "terraform"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Allow unauthenticated access to Cloud Run service
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_service.ontoserver.location
  project  = google_cloud_run_service.ontoserver.project
  service  = google_cloud_run_service.ontoserver.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Create load balancer (optional)
resource "google_compute_global_address" "default" {
  count   = var.enable_load_balancer ? 1 : 0
  name    = "ontoserver-ip"
  project = var.project_id
}

# Create SSL certificate (optional)
resource "google_compute_managed_ssl_certificate" "default" {
  count   = var.enable_load_balancer && var.domain_name != "" ? 1 : 0
  name    = var.ssl_certificate_name
  project = var.project_id

  managed {
    domains = [var.domain_name]
  }
}

# Create backend service
resource "google_compute_backend_service" "default" {
  count       = var.enable_load_balancer ? 1 : 0
  name        = "ontoserver-backend"
  project     = var.project_id
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_network_endpoint_group.neg[0].id
  }

  health_checks = [google_compute_health_check.default[0].id]
}

# Create NEG for Cloud Run
resource "google_compute_region_network_endpoint_group" "neg" {
  count                 = var.enable_load_balancer ? 1 : 0
  name                  = "ontoserver-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  project               = var.project_id

  cloud_run {
    service = google_cloud_run_service.ontoserver.name
  }
}

# Create health check
resource "google_compute_health_check" "default" {
  count   = var.enable_load_balancer ? 1 : 0
  name    = "ontoserver-health-check"
  project = var.project_id

  http_health_check {
    port         = 80
    request_path = "/fhir/metadata"
  }
}

# Create URL map
resource "google_compute_url_map" "default" {
  count   = var.enable_load_balancer ? 1 : 0
  name    = "ontoserver-url-map"
  project = var.project_id

  default_service = google_compute_backend_service.default[0].id
}

# Create HTTPS proxy
resource "google_compute_target_https_proxy" "default" {
  count            = var.enable_load_balancer && var.domain_name != "" ? 1 : 0
  name             = "ontoserver-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.default[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.default[0].id]
}

# Create HTTP proxy
resource "google_compute_target_http_proxy" "default" {
  count   = var.enable_load_balancer ? 1 : 0
  name    = "ontoserver-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.default[0].id
}

# Create global forwarding rule for HTTPS
resource "google_compute_global_forwarding_rule" "https" {
  count      = var.enable_load_balancer && var.domain_name != "" ? 1 : 0
  name       = "ontoserver-https-forwarding-rule"
  project    = var.project_id
  target     = google_compute_target_https_proxy.default[0].id
  port_range = "443"
  ip_address = google_compute_global_address.default[0].address
}

# Create global forwarding rule for HTTP
resource "google_compute_global_forwarding_rule" "http" {
  count      = var.enable_load_balancer ? 1 : 0
  name       = "ontoserver-http-forwarding-rule"
  project    = var.project_id
  target     = google_compute_target_http_proxy.default[0].id
  port_range = "80"
  ip_address = google_compute_global_address.default[0].address
} 