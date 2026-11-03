# One-time state migration for Agent OS RDS created on the removed rds_postgres
# catalog path. Safe no-op when the from address is absent in state.
#
# The catalog merge points agent_os at the shared subnet group, parameter group,
# and security group. Without the removed blocks below, apply tries to delete
# the legacy Agent OS–scoped resources before the instance is repointed (see
# InvalidDBSubnetGroupStateFault / dependency errors on SG and param groups).
#
# destroy = false drops them from state without a delete call; the instance
# update in the same apply switches to the shared resources. Orphaned AWS objects
# can be removed manually once every stack has applied this release.
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

removed {
  from = aws_db_subnet_group.rds_postgres["agent_os"]

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_db_parameter_group.rds_postgres["agent_os"]

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_security_group.rds_postgres["agent_os"]

  lifecycle {
    destroy = false
  }
}
