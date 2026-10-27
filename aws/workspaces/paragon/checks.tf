check "karpenter_requires_infra_outputs" {
  assert {
    condition = !try(local.infra_vars.enable_karpenter.value, false) || (
      try(local.infra_vars.k8s_version.value, null) != null &&
      try(local.infra_vars.karpenter.value, null) != null
    )
    error_message = "Karpenter requires k8s_version and karpenter in infra output. Re-apply the infra workspace before paragon."
  }
}

check "agent_os_karpenter_pools_from_infra" {
  assert {
    condition = !var.agent_os_enabled || !try(local.infra_vars.enable_karpenter.value, false) || (
      length(try(local.infra_vars.karpenter.value.agent_os_node_pools, {})) > 0
    )
    error_message = "Agent OS with Karpenter requires karpenter.agent_os_node_pools in the infra cluster secret. Re-apply the infra workspace before paragon."
  }
}

# check blocks warn; this precondition fails apply if Agent OS would schedule with no capacity.
resource "terraform_data" "agent_os_karpenter_pools" {
  count = var.agent_os_enabled && try(local.infra_vars.enable_karpenter.value, false) ? 1 : 0

  input = try(local.infra_vars.karpenter.value.agent_os_node_pools, {})

  lifecycle {
    precondition {
      condition     = length(try(local.infra_vars.karpenter.value.agent_os_node_pools, {})) > 0
      error_message = "Agent OS with Karpenter requires karpenter.agent_os_node_pools in the infra cluster secret. Re-apply the infra workspace before paragon."
    }
  }
}
