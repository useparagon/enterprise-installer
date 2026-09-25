check "karpenter_requires_infra_outputs" {
  assert {
    condition = !try(local.infra_vars.enable_karpenter.value, false) || (
      try(local.infra_vars.k8s_version.value, null) != null &&
      try(local.infra_vars.karpenter.value, null) != null
    )
    error_message = "Karpenter requires k8s_version and karpenter in infra output. Re-apply the infra workspace before paragon."
  }
}

resource "terraform_data" "path_based_routing_validation" {
  count = var.path_based_routing_enabled ? 1 : 0

  input = {
    services = local.path_routed_microservices
  }

  lifecycle {
    precondition {
      condition = alltrue([
        for microservice in keys(local.public_microservices_raw) :
        length(local.public_microservice_url_parts[microservice]) > 0
      ])
      error_message = "When path_based_routing_enabled is true, public service URLs must be absolute http:// or https:// URLs without query strings or fragments."
    }

    precondition {
      condition = alltrue([
        for microservice in keys(local.public_microservices_raw) :
        contains(local.path_based_routing_services, microservice) ? (
          try(local.public_microservice_url_parts[microservice][1] != null, false) &&
          try(local.public_microservice_url_parts[microservice][1] != "/", false) &&
          try(!endswith(local.public_microservice_url_parts[microservice][1], "/"), false)
        ) : try(local.public_microservice_url_parts[microservice][1] == null, true)
      ])
      error_message = "Path-based routing currently supports connect, hermes, passport, worker-proxy, and zeus. Their public URLs must include a non-root path prefix with no trailing slash; other public service URLs must remain host-only."
    }

    precondition {
      condition = (
        length(local.path_routed_microservices) > 0 &&
        length(distinct([
          for config in values(local.path_routed_microservices) : config.path_prefix
        ])) == length(local.path_routed_microservices)
      )
      error_message = "Path-based routing requires at least one routed service and each service path prefix must be unique."
    }

    precondition {
      condition = length(distinct([
        for config in values(local.path_routed_microservices) : lower(config.public_host)
      ])) <= 1
      error_message = "Path-based routing requires all routed services to use the same public host."
    }

    precondition {
      condition = alltrue([
        for config in values(local.path_routed_microservices) :
        length(config.path_prefix) <= 128
      ])
      error_message = "AWS ALB path patterns can be at most 128 characters."
    }
  }
}
