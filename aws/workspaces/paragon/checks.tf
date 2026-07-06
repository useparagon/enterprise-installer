check "karpenter_requires_infra_k8s_version" {
  assert {
    condition = !try(local.infra_vars.enable_karpenter.value, false) || try(local.infra_vars.k8s_version.value, null) != null
    error_message = "Karpenter requires k8s_version in infra output. Re-apply the infra workspace before paragon."
  }
}
