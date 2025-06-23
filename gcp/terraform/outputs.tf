output "cloud_run_service_url" {
  description = "The URL of the Cloud Run service"
  value       = google_cloud_run_service.ontoserver.status[0].url
}

output "cloud_run_service_name" {
  description = "The name of the Cloud Run service"
  value       = google_cloud_run_service.ontoserver.name
}

output "database_instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.name
}

output "database_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.connection_name
}

output "database_name" {
  description = "The name of the database"
  value       = google_sql_database.database.name
}

output "database_user" {
  description = "The database user"
  value       = google_sql_user.user.name
}

output "database_private_ip" {
  description = "The private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.private_ip_address
}

output "vpc_connector_name" {
  description = "The name of the VPC connector"
  value       = google_vpc_access_connector.connector.name
}

output "vpc_name" {
  description = "The name of the VPC"
  value       = google_compute_network.vpc.name
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = google_compute_network.vpc.id
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_id" {
  description = "The ID of the subnet"
  value       = google_compute_subnetwork.subnet.id
}

output "artifact_registry_repository" {
  description = "The Artifact Registry repository"
  value       = google_artifact_registry_repository.repository.name
}

output "load_balancer_ip" {
  description = "The IP address of the load balancer"
  value       = var.enable_load_balancer ? google_compute_global_address.default[0].address : null
}

output "load_balancer_url" {
  description = "The URL of the load balancer"
  value       = var.enable_load_balancer ? "http://${google_compute_global_address.default[0].address}" : null
}

output "ssl_certificate_name" {
  description = "The name of the SSL certificate"
  value       = var.enable_load_balancer && var.domain_name != "" ? google_compute_managed_ssl_certificate.default[0].name : null
}

output "service_account_email" {
  description = "The service account email used by Cloud Run"
  value       = var.service_account_email
}

output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
} 