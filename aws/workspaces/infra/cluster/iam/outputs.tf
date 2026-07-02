output "controller_role_arn" {
  description = "Karpenter controller IAM role ARN."
  value       = try(aws_iam_role.controller[0].arn, null)
}

output "controller_role_name" {
  description = "Karpenter controller IAM role name."
  value       = try(aws_iam_role.controller[0].name, null)
}

output "node_iam_role_arn" {
  description = "Karpenter node IAM role ARN."
  value       = try(aws_iam_role.node[0].arn, null)
}

output "node_iam_role_name" {
  description = "Karpenter node IAM role name."
  value       = try(aws_iam_role.node[0].name, null)
}
