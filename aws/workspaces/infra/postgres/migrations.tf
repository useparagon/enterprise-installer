# One-time state migration for Agent OS RDS created on the removed rds_postgres
# catalog path. Safe no-op when the from address is absent in state.
#
# Agent OS keeps its dedicated DB subnet group (Multi-AZ cannot change subnet
# group in place). Parameter group and security group merge to the shared
# postgres resources; removed blocks below drop legacy for_each instances from
# state with destroy = false so apply does not delete them before the DB
# instance is repointed.
#
# If a stack already applied an earlier revision that removed the subnet group
# from state, import it once before apply:
#   tofu import 'module.postgres.aws_db_subnet_group.agent_os["agent_os"]' <workspace>-agent-os-subnet
#
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

moved {
  from = aws_db_subnet_group.rds_postgres["agent_os"]
  to   = aws_db_subnet_group.agent_os["agent_os"]
}

removed {
  from = aws_db_parameter_group.rds_postgres

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_security_group.rds_postgres

  lifecycle {
    destroy = false
  }
}
