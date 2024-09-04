# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Define variables
variable "project_id" {
  description = "The GCP project ID"
}

variable "region" {
  description = "The GCP region"
  default     = "us-central1"
}


