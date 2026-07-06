output "queue_arn" {
  description = "Interruption queue ARN."
  value       = try(aws_sqs_queue.interruption[0].arn, null)
}

output "queue_url" {
  description = "Interruption queue URL."
  value       = try(aws_sqs_queue.interruption[0].url, null)
}

output "queue_name" {
  description = "Interruption queue name (Helm settings.interruptionQueue)."
  value       = try(aws_sqs_queue.interruption[0].name, null)
}
