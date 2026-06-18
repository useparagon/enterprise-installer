# GKE Connect Gateway: lets the kubernetes/helm/kubectl providers reach the
# PRIVATE GKE control plane from outside the VPC (e.g. the public Spacelift
# worker) without a public endpoint, VPC peering, or a bastion. The providers
# target a Google-managed proxy (connectgateway.googleapis.com) authenticated by
# an IAM OAuth token. Only registered when ArgoCD is enabled.
data "google_client_config" "default" {}

data "google_project" "this" {
  project_id = local.gcp_project_id
}

resource "google_gke_hub_membership" "cluster" {
  count         = var.argocd_enabled ? 1 : 0
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
