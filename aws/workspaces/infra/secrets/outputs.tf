output "secret_arns" {
  description = "ARNs of all application Secrets Manager secrets created by this module."
  value = compact([
    aws_secretsmanager_secret.env.arn,
    aws_secretsmanager_secret.docker_cfg.arn,
    try(aws_secretsmanager_secret.managed_sync[0].arn, ""),
    try(aws_secretsmanager_secret.openobserve[0].arn, ""),
    try(aws_secretsmanager_secret.agent_os_app[0].arn, ""),
    try(aws_secretsmanager_secret.agent_os_admin[0].arn, ""),
    try(aws_secretsmanager_secret.agent_os_vendor[0].arn, ""),
  ])
}

output "agent_os_secret_names" {
  description = "Names of the Agent OS secrets in Secrets Manager (null when Agent OS is disabled)."
  value = var.agent_os_enabled ? {
    app    = aws_secretsmanager_secret.agent_os_app[0].name
    admin  = try(aws_secretsmanager_secret.agent_os_admin[0].name, null)
    vendor = aws_secretsmanager_secret.agent_os_vendor[0].name
  } : null
}

output "env_secret_name" {
  description = "Name of the environment config secret in Secrets Manager."
  value       = aws_secretsmanager_secret.env.name
}

output "docker_cfg_secret_name" {
  description = "Name of the Docker config secret in Secrets Manager."
  value       = aws_secretsmanager_secret.docker_cfg.name
}

output "managed_sync_secret_name" {
  description = "Name of the managed sync secret in Secrets Manager (null if disabled)."
  value       = try(aws_secretsmanager_secret.managed_sync[0].name, null)
}

output "openobserve_secret_name" {
  description = "Name of the OpenObserve credentials secret in Secrets Manager (null if not created)."
  value       = try(aws_secretsmanager_secret.openobserve[0].name, null)
}
