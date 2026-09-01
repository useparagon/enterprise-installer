data "google_client_config" "paragon" {}

data "google_project" "paragon" {
  project_id = local.gcp_project_id
}

data "google_container_cluster" "cluster" {
  name     = local.cluster_name
  location = var.region
}
