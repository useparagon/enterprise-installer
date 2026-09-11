output "network" {
  description = "VPC used by Paragon resources. Projected fields only; google_compute_network.numeric_id is deprecated."
  value = {
    id         = google_compute_network.paragon.id
    name       = google_compute_network.paragon.name
    self_link  = google_compute_network.paragon.self_link
    network_id = google_compute_network.paragon.network_id
  }
}

output "public_subnet" {
  description = "Public subnet in the Paragon VPC. Projected fields only; google_compute_subnetwork.fingerprint is deprecated."
  value = {
    id            = google_compute_subnetwork.public.id
    name          = google_compute_subnetwork.public.name
    self_link     = google_compute_subnetwork.public.self_link
    ip_cidr_range = google_compute_subnetwork.public.ip_cidr_range
  }
}

output "private_subnet" {
  description = "Private subnet in the Paragon VPC. Projected fields only; google_compute_subnetwork.fingerprint is deprecated."
  value = {
    id            = google_compute_subnetwork.private.id
    name          = google_compute_subnetwork.private.name
    self_link     = google_compute_subnetwork.private.self_link
    ip_cidr_range = google_compute_subnetwork.private.ip_cidr_range
  }
}

output "nat_ip_address" {
  value = google_compute_address.nat_ip.address
}
