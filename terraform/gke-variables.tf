variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "europe-west2"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "ontoserver-cluster"
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
  default     = "ontoserver-vpc"
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
  default     = "ontoserver-subnet"
}

variable "subnet_cidr" {
  description = "The CIDR range for the subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "gke_num_nodes" {
  description = "Number of GKE nodes"
  type        = number
  default     = 2
}

variable "gke_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "database_instance_name" {
  description = "The name of the Cloud SQL instance"
  type        = string
  default     = "ontoserver-db"
}

variable "database_name" {
  description = "The name of the database"
  type        = string
  default     = "ontoserver"
}

variable "database_user" {
  description = "The database user"
  type        = string
  default     = "ontoserver"
}

variable "database_password" {
  description = "The database password"
  type        = string
  sensitive   = true
}

variable "database_version" {
  description = "The PostgreSQL version"
  type        = string
  default     = "POSTGRES_14"
}

variable "database_tier" {
  description = "The Cloud SQL instance tier"
  type        = string
  default     = "db-standard-2"
}

variable "enable_load_balancer" {
  description = "Whether to enable the load balancer"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "The domain name for SSL certificate"
  type        = string
  default     = ""
}

variable "ssl_certificate_name" {
  description = "The name of the SSL certificate"
  type        = string
  default     = "ontoserver-ssl-cert"
}

variable "environment" {
  description = "The environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "ontoserver"
    ManagedBy   = "terraform"
  }
}