# Register the GKE cluster with Fleet so public automation workers can reach a
# private control plane through Connect Gateway. This uses Google APIs only;
# it does not require direct network access to the Kubernetes API.
resource "google_gke_hub_membership" "cluster" {
  project       = local.gcp_project_id
  membership_id = "${local.workspace}-fleet"

  endpoint {
    gke_cluster {
      resource_link = module.cluster.cluster_id
    }
  }

  authority {
    issuer = "https://container.googleapis.com/v1/${module.cluster.cluster_id}"
  }
}
