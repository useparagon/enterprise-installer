provider "google" {
  credentials    = var.gcp_assume_role ? null : local.gcp_provider_credentials
  default_labels = local.default_labels
  project        = local.gcp_project_id
  region         = var.region
  zone           = var.region_zone
}

provider "google-beta" {
  credentials    = var.gcp_assume_role ? null : local.gcp_provider_credentials
  default_labels = local.default_labels
  project        = local.gcp_project_id
  region         = var.region
  zone           = var.region_zone
}

provider "kubernetes" {
  host  = local.gke_connect_gateway_host
  token = data.google_client_config.paragon.access_token
}

provider "helm" {
  kubernetes {
    host  = local.gke_connect_gateway_host
    token = data.google_client_config.paragon.access_token
  }
}

provider "kubectl" {
  host             = local.gke_connect_gateway_host
  token            = data.google_client_config.paragon.access_token
  load_config_file = false
}

provider "hoop" {
  api_url = var.hoop_api_url
  api_key = coalesce(var.hoop_api_key, "dummy-token")
}
