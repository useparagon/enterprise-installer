check "karpenter_paragon_inputs" {
  assert {
    condition = !var.enable_karpenter || (
      startswith(var.karpenter_controller_role_arn, "arn:aws:iam::") &&
      length(var.karpenter_node_iam_role_name) > 0
    )
    error_message = "When enable_karpenter is true, set karpenter_controller_role_arn (IAM role ARN) and karpenter_node_iam_role_name from the infra workspace output `terraform output -json karpenter` (see docs/aws-karpenter-poc.md)."
  }
}
