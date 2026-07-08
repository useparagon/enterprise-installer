# Service-agnostic ingress cloud resources for the GitOps shared GCE Ingress.
#
# The infra workspace stays agnostic to which Paragon services are deployed: it
# only provisions domain-keyed cloud resources (a reserved global IP and a
# wildcard TLS cert) and exposes them by deterministic name. The chart
# (paragon-onprem templates/shared-ingress.yaml) owns the service list and renders
# the single shared Ingress, referencing these by name via global.ingress.*:
#
#   global.ingress.loadBalancerName = google_compute_global_address.loadbalancer.name
#   global.ingress.certificate      = google_certificate_manager_certificate_map.paragon.name
#
# This mirrors the AWS pattern (wildcard ACM cert in argocd_acm.tf surfaced via
# global.ingress.certificate). All resources are gated on gitops_ingress_enabled.

# Reserved global external IP for the shared L7 load balancer (stable address for DNS).
resource "google_compute_global_address" "loadbalancer" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name    = "${var.workspace}-loadbalancer"
  project = var.gcp_project_id
}

# Wildcard TLS via Certificate Manager (classic GCE managed certs cannot do
# wildcards). One DNS authorization on the apex authorizes both the apex and
# "*.<domain>". Validated against the Cloud DNS zone this module already owns.
resource "google_certificate_manager_dns_authorization" "paragon" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name    = "${var.workspace}-dnsauth"
  domain  = trimspace(var.paragon_domain)
  project = var.gcp_project_id
  labels  = var.labels
}

# CNAME record that proves domain control for the DNS authorization.
resource "google_dns_record_set" "cert_auth" {
  count = local.gitops_ingress_enabled && local.create_dns_zone ? 1 : 0

  name         = google_certificate_manager_dns_authorization.paragon[0].dns_resource_record[0].name
  type         = google_certificate_manager_dns_authorization.paragon[0].dns_resource_record[0].type
  ttl          = 300
  managed_zone = google_dns_managed_zone.paragon[0].name
  rrdatas      = [google_certificate_manager_dns_authorization.paragon[0].dns_resource_record[0].data]
  project      = var.gcp_project_id
}

resource "google_certificate_manager_certificate" "paragon" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name    = "${var.workspace}-cert"
  project = var.gcp_project_id
  labels  = var.labels

  managed {
    domains            = [trimspace(var.paragon_domain), "*.${trimspace(var.paragon_domain)}"]
    dns_authorizations = [google_certificate_manager_dns_authorization.paragon[0].id]
  }
}

# Cert map consumed by the GKE Ingress via the networking.gke.io/certmap annotation.
resource "google_certificate_manager_certificate_map" "paragon" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name    = "${var.workspace}-cert-map"
  project = var.gcp_project_id
  labels  = var.labels
}

resource "google_certificate_manager_certificate_map_entry" "paragon" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name         = "${var.workspace}-cert-map-entry"
  map          = google_certificate_manager_certificate_map.paragon[0].name
  certificates = [google_certificate_manager_certificate.paragon[0].id]
  matcher      = "PRIMARY"
  project      = var.gcp_project_id
  labels       = var.labels
}
