# One-time state migration for Agent OS RDS created on the removed rds_postgres
# catalog path. Safe no-op when the from address is absent in state.
# Remove this file after all infra stacks have applied the release that includes it.

moved {
  from = aws_db_instance.rds_postgres["agent_os"]
  to   = aws_db_instance.postgres["agent_os"]
}

moved {
  from = random_string.rds_postgres_root_username["agent_os"]
  to   = random_string.postgres_root_username["agent_os"]
}

moved {
  from = random_password.rds_postgres_root_password["agent_os"]
  to   = random_password.postgres_root_password["agent_os"]
}

moved {
  from = aws_db_instance.rds_postgres_replica["agent_os"]
  to   = aws_db_instance.postgres_replica["agent_os"]
}
