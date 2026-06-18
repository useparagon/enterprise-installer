terraform {
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  credentials    = var.gcp_assume_role ? null : local.gcp_creds
  default_labels = local.default_labels
  project        = local.gcp_project_id
  region         = var.region
  zone           = var.region_zone
}

provider "google-beta" {
  credentials    = var.gcp_assume_role ? null : local.gcp_creds
  default_labels = local.default_labels
  project        = local.gcp_project_id
  region         = var.region
  zone           = var.region_zone
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Kubernetes providers at the infra root, consumed by the count-gated argocd
# module. The GKE control plane is PRIVATE, so reach it through Connect Gateway
# (a Google-managed proxy at connectgateway.googleapis.com) using an IAM OAuth
# token — works from the public Spacelift worker, no public endpoint/VPC peering.
# When ArgoCD is disabled, feed a static placeholder so alekc/kubectl doesn't
# error at configure time. No cluster_ca_certificate: the gateway endpoint
# presents a public Google TLS cert validated by system CAs. Referencing the
# membership resource (via one()) also orders it before the providers connect.
locals {
  k8s_host  = var.argocd_enabled ? "https://connectgateway.googleapis.com/v1/projects/${data.google_project.this.number}/locations/global/gkeMemberships/${one(google_gke_hub_membership.cluster[*].membership_id)}" : "https://localhost"
  k8s_token = var.argocd_enabled ? data.google_client_config.default.access_token : ""
}

provider "kubernetes" {
  host  = local.k8s_host
  token = local.k8s_token
}

provider "helm" {
  kubernetes {
    host  = local.k8s_host
    token = local.k8s_token
  }
}

provider "kubectl" {
  host             = local.k8s_host
  token            = local.k8s_token
  load_config_file = false
}
