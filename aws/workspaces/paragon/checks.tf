check "karpenter_requires_infra_outputs" {
  assert {
    condition = !try(local.infra_vars.enable_karpenter.value, false) || (
      try(local.infra_vars.k8s_version.value, null) != null &&
      try(local.infra_vars.karpenter.value, null) != null
    )
    error_message = "Karpenter requires k8s_version and karpenter in infra output. Re-apply the infra workspace before paragon."
  }
}
