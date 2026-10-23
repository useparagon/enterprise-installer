terraform {
  required_version = ">= 1.9.0"

  required_providers {
    betteruptime = {
      source  = "BetterStackHQ/better-uptime"
      version = "~> 0.22.2"
    }
  }
}


provider "betteruptime" {
  api_token = coalesce(var.uptime_api_token, "dummy-token")
}
