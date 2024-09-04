
variable "bucket_name" {
  description = "The name of the GCS bucket"
}

variable "domain_name" {
  description = "The domain name for the website"
}

variable "iap_support_email" {
  description = "The support email for IAP"
}

variable "iap_allowed_users" {
  description = "List of users allowed to access the website"
  type        = list(string)
}

# Create a GCS bucket for the static website
resource "google_storage_bucket" "website" {
  name     = var.bucket_name
  location = "US"

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  uniform_bucket_level_access = true

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "OPTIONS"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

# Make the bucket publicly readable
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.website.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Create a Cloud Identity-Aware Proxy (IAP) brand
resource "google_iap_brand" "project_brand" {
  support_email     = var.iap_support_email
  application_title = "Static Website"
}

# Create an OAuth client for IAP
resource "google_iap_client" "project_client" {
  display_name = "Static Website Client"
  brand        = google_iap_brand.project_brand.name
}

# Create a backend service for the bucket
resource "google_compute_backend_bucket" "website_backend" {
  name        = "website-backend"
  bucket_name = google_storage_bucket.website.name
  enable_cdn  = true
}

# Create a URL map
resource "google_compute_url_map" "website_url_map" {
  name            = "website-url-map"
  default_service = google_compute_backend_bucket.website_backend.self_link
}

# Create a managed SSL certificate
resource "google_compute_managed_ssl_certificate" "website_ssl" {
  name = "website-ssl-cert"
  managed {
    domains = [var.domain_name]
  }
}

# Create a target HTTPS proxy
resource "google_compute_target_https_proxy" "website_https_proxy" {
  name             = "website-https-proxy"
  url_map          = google_compute_url_map.website_url_map.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.website_ssl.self_link]
}

# Create a global forwarding rule
resource "google_compute_global_forwarding_rule" "website_forwarding_rule" {
  name       = "website-forwarding-rule"
  target     = google_compute_target_https_proxy.website_https_proxy.self_link
  port_range = "443"
}

# Enable IAP for the backend service
resource "google_iap_web_backend_service_iam_binding" "binding" {
  project             = google_compute_backend_bucket.website_backend.project
  web_backend_service = google_compute_backend_bucket.website_backend.name
  role                = "roles/iap.httpsResourceAccessor"
  members             = var.iap_allowed_users
}

# Output values
output "bucket_name" {
  value       = google_storage_bucket.website.name
  description = "The name of the GCS bucket"
}

output "bucket_url" {
  value       = google_storage_bucket.website.url
  description = "The URL of the GCS bucket"
}

output "website_url" {
  value       = "https://${var.domain_name}"
  description = "The URL of the website"
}