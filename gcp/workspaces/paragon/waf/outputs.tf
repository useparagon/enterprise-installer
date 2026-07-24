output "security_policy_name" {
  description = "Name of the Cloud Armor security policy, as referenced by a BackendConfig."
  value       = google_compute_security_policy.this.name
}

output "security_policy_id" {
  description = "Fully qualified ID of the Cloud Armor security policy."
  value       = google_compute_security_policy.this.id
}

output "security_policy_self_link" {
  description = "Self link of the Cloud Armor security policy."
  value       = google_compute_security_policy.this.self_link
}

output "rule_count" {
  description = "Number of rules in the policy, including the default catch-all rule."
  value       = length(local.all_priorities)
}
