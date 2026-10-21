removed {
  from = hoop_plugin_config.slack

  lifecycle {
    destroy = false
  }
}

resource "hoop_plugin_connection" "slack" {
  for_each = nonsensitive(local.slack_enabled) ? toset(nonsensitive(keys(local.review_required_connections))) : toset([])

  plugin_name   = "slack"
  connection_id = hoop_connection.all_connections[each.key].id
  config        = [] # Default notification channel is owned by Ops
}
