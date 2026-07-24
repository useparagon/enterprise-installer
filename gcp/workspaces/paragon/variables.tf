# credentials
variable "gcp_credential_json_file" {
  description = "The path to the GCP credential JSON file. All other `gcp_` variables are ignored if this is provided."
  type        = string
  default     = null
}

variable "gcp_credential_json" {
  description = "Contents of the GCP credential JSON file. All other `gcp_` variables are ignored if this is provided."
  type        = map(any)
  default     = {}
}

variable "gcp_project_id" {
  description = "The id of the Google Cloud Project. Required if not using `gcp_credential_json_file`."
  type        = string
  default     = null
}

variable "gcp_private_key_id" {
  description = "The id of the private key for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_private_key" {
  description = "The private key for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_client_email" {
  description = "The client email for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_client_id" {
  description = "The client id for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_client_x509_cert_url" {
  description = "The client certificate url for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_assume_role" {
  description = "Whether to assume a role for the service account instead of using JSON credentials."
  type        = bool
  default     = false
}

# account
variable "organization" {
  description = "Name of organization to include in resource names."
  type        = string

  validation {
    condition     = length(var.organization) <= 16
    error_message = "The `organization` input must be 16 or less characters."
  }
}

variable "environment" {
  description = "Type of environment being deployed to."
  type        = string
  default     = "enterprise"
}

variable "domain" {
  description = "The root domain used for the microservices."
  type        = string
}

variable "docker_registry_server" {
  description = "Container registry server for image pull credentials (e.g. docker.io or artifactory.example.com). Must match the host portion of global.imageRegistry when using a private registry."
  type        = string
  default     = "docker.io"
}

variable "docker_pull_secret_name" {
  description = "Kubernetes secret name for registry pull credentials."
  type        = string
  default     = "docker-cfg"
}

variable "create_docker_pull_secret" {
  description = "Create the registry pull secret in the paragon namespace. Set false when the customer pre-provisions the secret and sets global.imagePullSecrets in helm_values."
  type        = bool
  default     = true
}

variable "docker_username" {
  description = "Docker username to pull images. Null when using a pre-provisioned pull secret (create_docker_pull_secret=false)."
  type        = string
  default     = null
}

variable "docker_password" {
  description = "Docker password to pull images. Null when using a pre-provisioned pull secret (create_docker_pull_secret=false)."
  type        = string
  default     = null
  sensitive   = true
}

variable "docker_email" {
  description = "Docker email to pull images."
  type        = string
  default     = null
}

variable "region" {
  description = "The region where to host Google Cloud Organization resources."
  type        = string
}

variable "region_zone" {
  description = "The zone in the region where to host Google Cloud Organization resources."
  type        = string
}

variable "monitors_enabled" {
  description = "Specifies that monitors are enabled."
  type        = bool
  default     = false
}

variable "monitor_version" {
  description = "The version of the Paragon monitors to install."
  type        = string
  default     = null
}

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync (deploy managed-sync Helm chart and config)."
  type        = bool
  default     = false
}

variable "managed_sync_version" {
  description = "The version of the Managed Sync Helm chart to install."
  type        = string
  default     = "0.0.131"
}

variable "excluded_microservices" {
  description = "The microservices that should be excluded from the deployment."
  type        = list(string)
  default     = []
}

variable "private_services" {
  description = "Services that should not be publicly exposed (filtered from public_microservices and public_monitors)."
  type        = list(string)
  default     = []
}

variable "feature_flags" {
  description = "Optional path to feature flags YAML file."
  type        = string
  default     = null
}

variable "ingress_scheme" {
  description = "Whether the load balancer is 'external' (public) or 'internal' (private)"
  type        = string
  default     = "external"
}

variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
  default     = "1.31"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Zone `DNS`"
  type        = string
  sensitive   = true
  default     = null
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone id to set CNAMEs."
  type        = string
  default     = null
}

variable "uptime_api_token" {
  description = "Optional API Token for setting up BetterStack Uptime monitors."
  type        = string
  default     = null
}

variable "uptime_company" {
  description = "Optional pretty company name to include in BetterStack Uptime monitors."
  type        = string
  default     = null
}

variable "health_checker_enabled" {
  description = "Specifies that health checker is enabled."
  type        = bool
  default     = false
}

variable "openobserve_email" {
  description = "OpenObserve admin login email."
  type        = string
  default     = null
}

variable "openobserve_password" {
  description = "OpenObserve admin login password."
  type        = string
  default     = null
}

variable "hoop_agent_id" {
  description = "Hoop agent ID for connections. Only used if hoop_enabled is true."
  type        = string
  default     = null
}

variable "hoop_api_url" {
  description = "Hoop API URL."
  type        = string
  default     = "https://hoop.ops.paragoninternal.com/api"
}

variable "hoop_api_key" {
  description = "Hoop API key. Only used if hoop_enabled is true."
  type        = string
  sensitive   = true
  default     = null
}

variable "hoop_slack_bot_token" {
  description = "Slack bot token for the Hoop Slack plugin."
  type        = string
  sensitive   = true
  default     = null
}

variable "hoop_slack_app_token" {
  description = "Slack app token for the Hoop Slack plugin."
  type        = string
  sensitive   = true
  default     = null
}

variable "hoop_slack_channel_ids" {
  description = "Slack channel IDs to notify for connections that require reviews."
  type        = list(string)
  default     = []
}

variable "hoop_all_access_groups" {
  description = "Additional access-control groups allowed when customer_facing is false."
  type        = list(string)
  default     = ["dev-team-engineering"]
}

variable "hoop_postgres_guardrail_rules" {
  description = "Guardrail rule IDs for PostgreSQL connections."
  type        = list(string)
  default     = ["a85115f6-5ef3-4618-b70c-f7cccdc62c5a"]
}

variable "hoop_redis_guardrail_rules" {
  description = "Guardrail rule IDs for Redis connections."
  type        = list(string)
  default     = ["182f59b2-5d5d-4ab8-978e-94472b3915fc"]
}

variable "hoop_custom_connections" {
  description = "Custom Hoop connections defined via tfvars. Map of connection names to their configuration."
  type = map(object({
    type                  = string
    subtype               = optional(string)
    access_mode_runbooks  = optional(string, "enabled")
    access_mode_exec      = optional(string, "enabled")
    access_mode_connect   = optional(string, "disabled")
    access_schema         = optional(string, "disabled")
    command               = optional(list(string))
    secrets               = map(string)
    tags                  = optional(map(string), {})
    guardrail_rules       = optional(list(string), [])
    reviewers             = optional(list(string), [])
    access_control_groups = optional(list(string), [])
  }))
  default = {}
}

variable "hoop_enabled" {
  description = "Whether to enable Hoop agent. hoop_key, hoop_api_key, and hoop_agent_id must be set if this is true."
  type        = bool
  default     = true
}

variable "hoop_grafana_connection" {
  description = "Whether to create a Hoop TCP connection to Grafana (grafana.paragon:4500)."
  type        = bool
  default     = false
}

variable "hoop_k8s_connections" {
  description = "Kubernetes Hoop connections defined via tfvars. Map of connection names to their configuration. If empty, a default k8s-admin connection will be created."
  type = map(object({
    type                  = optional(string, "custom")
    subtype               = optional(string)
    access_mode_runbooks  = optional(string, "enabled")
    access_mode_exec      = optional(string, "enabled")
    access_mode_connect   = optional(string, "enabled")
    access_schema         = optional(string, "disabled")
    command               = optional(list(string), ["bash"])
    remote_url            = optional(string, "https://kubernetes.default.svc.cluster.local")
    insecure              = optional(string, "true")
    namespace             = optional(string, "paragon")
    secrets               = optional(map(string), {})
    tags                  = optional(map(string), {})
    guardrail_rules       = optional(list(string), [])
    reviewers             = optional(list(string), [])
    access_control_groups = optional(list(string), [])
  }))
  default = {}
}

variable "hoop_key" {
  description = "Hoop agent key (token). Only used if hoop_enabled is true."
  type        = string
  sensitive   = true
  default     = null
}

variable "hoop_restricted_access_groups" {
  description = "Base access-control groups allowed for all connections."
  type        = list(string)
  default     = ["dev-team-oncall", "dev-team-managers", "admin"]
}

variable "hoop_agent_name" {
  description = "Override Hoop agent name in HOOP_KEY when organization does not identify the client (e.g. when organization is a region code like 'us', set to a client-identifying value such as 'client-us')."
  type        = string
  default     = null
}

variable "hoop_reviewers_access_groups" {
  description = "Reviewer groups required for customer-facing app connections."
  type        = list(string)
  default     = ["dev-team-managers", "admin"]
}

variable "customer_facing" {
  description = "Whether the connections are customer-facing (true limits access to dev-team-oncall/dev-team-managers/admin, false adds dev-team-engineering)."
  type        = bool
  default     = true
}

variable "infra_json_path" {
  description = "Deprecated legacy path to an `infra` workspace output JSON file. Prefer Secret Manager handoff secrets (PARA-21726)."
  type        = string
  default     = null
}

variable "infra_json" {
  description = "Deprecated legacy JSON string of `infra` workspace variables."
  type        = string
  default     = null
}

variable "cluster_name_override" {
  description = "Optional override for the GKE cluster name when it does not follow the default $${workspace}-cluster naming."
  type        = string
  default     = null
}

variable "helm_yaml_path" {
  description = "Path to helm values.yaml file."
  type        = string
  default     = ".secure/values.yaml"
}

variable "helm_yaml" {
  description = "YAML string of helm values to use instead of `helm_yaml_path`"
  type        = string
  default     = null
}

variable "waf_enabled" {
  description = "Enable Google Cloud Armor on the shared public Application Load Balancer. false by default — set true and configure waf_preconfigured_rules, rate limits, or IP lists in tfvars. Ignored when ingress_scheme is 'internal'. Disabling detaches the policy before destroying it, but the GKE controller detaches asynchronously, so a destroy that fails with resourceInUseByAnotherResource just needs apply to be re-run."
  type        = bool
  default     = false
}

variable "waf_ip_whitelist" {
  description = "CIDRs that bypass every other Cloud Armor rule (office IPs). Bare addresses are normalized to /32 or /128. Empty list = no allowlist rule. Example: `[\"203.0.113.10\", \"198.51.100.0/24\"]`"
  type        = list(string)
  default     = []
}

variable "waf_ip_blacklist" {
  description = "CIDRs that are always denied. Bare addresses are normalized to /32 or /128. Empty list = no denylist rule. Example: `[\"203.0.113.66\", \"192.0.2.0/24\"]`"
  type        = list(string)
  default     = []
}

variable "waf_ip_blacklist_deny_status" {
  description = "HTTP status returned by the denylist rule. Cloud Armor only allows 403, 404, or 502 for deny actions."
  type        = number
  default     = 403

  validation {
    condition     = contains([403, 404, 502], var.waf_ip_blacklist_deny_status)
    error_message = "waf_ip_blacklist_deny_status must be 403, 404, or 502."
  }
}

variable "waf_rate_limit_global" {
  description = "Requests per key allowed across all paths within the window. null or 0 = no global rate limit rule. Enforced per backend service and per region, so the aggregate limit scales with the number of protected backends."
  type        = number
  default     = null
  nullable    = true

  validation {
    condition     = var.waf_rate_limit_global == null || contains([0], coalesce(var.waf_rate_limit_global, 0)) || coalesce(var.waf_rate_limit_global, 1) >= 1
    error_message = "waf_rate_limit_global must be null, 0 (disabled), or a positive number of requests."
  }

  validation {
    condition     = coalesce(var.waf_rate_limit_global, 0) <= 10000
    error_message = "waf_rate_limit_global must be 10000 or less, the Cloud Armor ceiling for rate_based_ban. Throttle allows more, but the lower bound is enforced so switching waf_rate_limit_options.action never breaks an apply."
  }
}

variable "waf_rate_limit_global_window_sec" {
  description = "Evaluation window in seconds for the global rate limit."
  type        = number
  default     = 300

  validation {
    condition     = contains([10, 30, 60, 120, 180, 240, 300, 600, 900, 1200, 1800, 2700, 3600], var.waf_rate_limit_global_window_sec)
    error_message = "waf_rate_limit_global_window_sec must be one of 10, 30, 60, 120, 180, 240, 300, 600, 900, 1200, 1800, 2700, 3600."
  }
}

variable "waf_rate_limit_paths" {
  description = "Map of URL path prefix to requests per key per window, evaluated before the global limit. Paths without a leading / are normalized and match by prefix, so /actuator also covers /actuator/heapdump. Longer prefixes are evaluated first, so a stricter /api/foo limit takes precedence over a broader /api one. Empty = no path rate limit rules. Example: `{ \"/actuator\" = 20, \"/api/v1/webhooks\" = 600 }`"
  type        = map(number)
  default     = {}

  validation {
    condition = alltrue([
      for path in keys(var.waf_rate_limit_paths) :
      can(regex("^/?[A-Za-z0-9._~-][A-Za-z0-9._~/-]*$", path))
    ])
    error_message = "waf_rate_limit_paths keys must be non-empty URL path prefixes built from letters, digits and the characters . _ ~ - / (no quotes, wildcards or regular expressions). \"\" and \"/\" are rejected because they would match every request; use waf_rate_limit_global instead."
  }

  validation {
    condition     = alltrue([for limit in values(var.waf_rate_limit_paths) : limit >= 1 && limit <= 10000])
    error_message = "waf_rate_limit_paths values must be between 1 and 10000 requests."
  }
}

variable "waf_rate_limit_path_window_sec" {
  description = "Evaluation window in seconds for the path rate limits."
  type        = number
  default     = 300

  validation {
    condition     = contains([10, 30, 60, 120, 180, 240, 300, 600, 900, 1200, 1800, 2700, 3600], var.waf_rate_limit_path_window_sec)
    error_message = "waf_rate_limit_path_window_sec must be one of 10, 30, 60, 120, 180, 240, 300, 600, 900, 1200, 1800, 2700, 3600."
  }
}

variable "waf_rate_limit_options" {
  description = <<-EOT
    Shared behaviour for the rules generated from waf_rate_limit_global and waf_rate_limit_paths. Per-rule rate limiting is available through waf_custom_rules.

    - action: "throttle" caps traffic at the threshold; "rate_based_ban" blocks the key for ban_duration_sec. Cloud Armor rejects switching a rate_based_ban rule back to throttle in place.
    - exceed_status: status returned above the threshold (403, 404, 429 or 502)
    - enforce_on_key: what counts as one client. Use XFF_IP when a CDN or proxy such as Cloudflare fronts the load balancer.
    - enforce_on_key_name: header or cookie name, required for HTTP_HEADER/HTTP_COOKIE
    - ban_duration_sec: how long a banned key stays banned. rate_based_ban only.
    - ban_threshold_count / ban_threshold_interval_sec: optional second threshold that must also be breached before a ban. rate_based_ban only.
    - preview: evaluate and log without enforcing

    Example: `{ action = "rate_based_ban", enforce_on_key = "XFF_IP", ban_duration_sec = 1800 }`
  EOT
  type = object({
    action                     = optional(string, "throttle")
    exceed_status              = optional(number, 429)
    enforce_on_key             = optional(string, "IP")
    enforce_on_key_name        = optional(string)
    ban_duration_sec           = optional(number, 600)
    ban_threshold_count        = optional(number)
    ban_threshold_interval_sec = optional(number, 600)
    preview                    = optional(bool, false)
  })
  default = {}

  validation {
    condition     = contains(["throttle", "rate_based_ban"], coalesce(var.waf_rate_limit_options.action, "throttle"))
    error_message = "waf_rate_limit_options.action must be \"throttle\" or \"rate_based_ban\"."
  }

  validation {
    condition     = contains([403, 404, 429, 502], coalesce(var.waf_rate_limit_options.exceed_status, 429))
    error_message = "waf_rate_limit_options.exceed_status must be 403, 404, 429, or 502."
  }

  validation {
    condition = contains(
      ["ALL", "IP", "XFF_IP", "USER_IP", "HTTP_HEADER", "HTTP_COOKIE", "HTTP_PATH", "SNI", "REGION_CODE", "TLS_JA3_FINGERPRINT", "TLS_JA4_FINGERPRINT"],
      coalesce(var.waf_rate_limit_options.enforce_on_key, "IP")
    )
    error_message = "waf_rate_limit_options.enforce_on_key must be one of ALL, IP, XFF_IP, USER_IP, HTTP_HEADER, HTTP_COOKIE, HTTP_PATH, SNI, REGION_CODE, TLS_JA3_FINGERPRINT, TLS_JA4_FINGERPRINT."
  }

  validation {
    condition = !contains(["HTTP_HEADER", "HTTP_COOKIE"], coalesce(var.waf_rate_limit_options.enforce_on_key, "IP")) || (
      var.waf_rate_limit_options.enforce_on_key_name != null && trimspace(coalesce(var.waf_rate_limit_options.enforce_on_key_name, "")) != ""
    )
    error_message = "waf_rate_limit_options.enforce_on_key_name is required when enforce_on_key is HTTP_HEADER or HTTP_COOKIE."
  }

  validation {
    condition     = coalesce(var.waf_rate_limit_options.ban_duration_sec, 600) >= 1
    error_message = "waf_rate_limit_options.ban_duration_sec must be a positive number of seconds."
  }

  validation {
    condition     = contains([10, 30, 60, 120, 180, 240, 300, 600, 900, 1200, 1800, 2700, 3600], coalesce(var.waf_rate_limit_options.ban_threshold_interval_sec, 600))
    error_message = "waf_rate_limit_options.ban_threshold_interval_sec must be one of 10, 30, 60, 120, 180, 240, 300, 600, 900, 1200, 1800, 2700, 3600."
  }
}

variable "waf_preconfigured_rules" {
  description = <<-EOT
    Map of Google-managed (preconfigured) WAF rule sets to evaluate. Empty by default — you choose which sets to enable. Cloud Armor's equivalent of an AWS WAF managed rule group.

    Each key is the rule name inside the policy (unique). Each value configures one set:

    - rule_set (required): e.g. sqli-v422-stable, xss-v422-stable, lfi-v422-stable, rfi-v422-stable, rce-v422-stable, protocolattack-v422-stable, scannerdetection-v422-stable, methodenforcement-v422-stable, php-v422-stable, sessionfixation-v422-stable, java-v422-stable, generic-v422-stable, cve-canary, json-sqli-canary. CRS 4.22 (-v422-) is current; -v33- and unsuffixed names are older.
    - sensitivity: OWASP paranoia level 0-4, default 1. Higher adds signatures and false positives. 0 evaluates nothing unless opt_in_rule_ids is set.
    - deny_status: status returned on a match (403, 404 or 502)
    - priority: evaluation order. Auto-assigned in the 5000 band when omitted.
    - preview: evaluate and log without blocking, the equivalent of AWS WAF "count"
    - opt_in_rule_ids: signature IDs to enable even though sensitivity excludes them
    - opt_out_rule_ids: signature IDs to disable, for known false positives. Must match the CRS version of rule_set.
    - exclusions: request fields skipped during evaluation. Each entry optionally narrows to target_rule_ids and lists request_headers / request_cookies / request_uris / request_query_params as { operator, value }, where operator is EQUALS, STARTS_WITH, ENDS_WITH, CONTAINS or EQUALS_ANY and value is required for all but EQUALS_ANY.

    Example, rolling out SQLi in preview while XSS enforces with one signature disabled:

    `sqli = { rule_set = "sqli-v422-stable", preview = true }`

    `xss = { rule_set = "xss-v422-stable", sensitivity = 2, opt_out_rule_ids = ["owasp-crs-v042200-id941150-xss"] }`

    Reference: https://cloud.google.com/armor/docs/waf-rules
  EOT
  type = map(object({
    rule_set         = string
    sensitivity      = optional(number, 1)
    deny_status      = optional(number, 403)
    priority         = optional(number)
    preview          = optional(bool, false)
    opt_in_rule_ids  = optional(list(string), [])
    opt_out_rule_ids = optional(list(string), [])
    exclusions = optional(list(object({
      target_rule_ids = optional(list(string), [])
      request_headers = optional(list(object({
        operator = string
        value    = optional(string)
      })), [])
      request_cookies = optional(list(object({
        operator = string
        value    = optional(string)
      })), [])
      request_uris = optional(list(object({
        operator = string
        value    = optional(string)
      })), [])
      request_query_params = optional(list(object({
        operator = string
        value    = optional(string)
      })), [])
    })), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for _, rule in var.waf_preconfigured_rules :
      can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", rule.rule_set))
    ])
    error_message = "waf_preconfigured_rules.rule_set must be a Cloud Armor rule set name such as \"sqli-v422-stable\" (lowercase letters, digits and hyphens only)."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_preconfigured_rules :
      coalesce(rule.sensitivity, 1) >= 0 && coalesce(rule.sensitivity, 1) <= 4
    ])
    error_message = "waf_preconfigured_rules.sensitivity must be between 0 and 4."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_preconfigured_rules :
      coalesce(rule.sensitivity, 1) > 0 || length(coalesce(rule.opt_in_rule_ids, [])) > 0
    ])
    error_message = "waf_preconfigured_rules entries with sensitivity 0 evaluate no signatures unless opt_in_rule_ids is set."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_preconfigured_rules :
      contains([403, 404, 502], coalesce(rule.deny_status, 403))
    ])
    error_message = "waf_preconfigured_rules.deny_status must be 403, 404, or 502."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_preconfigured_rules :
      rule.priority == null || (coalesce(rule.priority, 1) >= 1 && coalesce(rule.priority, 1) <= 2147483646)
    ])
    error_message = "waf_preconfigured_rules.priority must be between 1 and 2147483646. 2147483647 is reserved for the default rule."
  }

  validation {
    condition = alltrue(flatten([
      for _, rule in var.waf_preconfigured_rules : [
        for id in concat(coalesce(rule.opt_in_rule_ids, []), coalesce(rule.opt_out_rule_ids, [])) :
        can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", id))
      ]
    ]))
    error_message = "waf_preconfigured_rules opt_in_rule_ids and opt_out_rule_ids must be signature IDs such as \"owasp-crs-v042200-id942350-sqli\" (lowercase letters, digits and hyphens only)."
  }

  validation {
    condition = alltrue(flatten([
      for _, rule in var.waf_preconfigured_rules : [
        for exclusion in coalesce(rule.exclusions, []) : [
          for field in concat(
            coalesce(exclusion.request_headers, []),
            coalesce(exclusion.request_cookies, []),
            coalesce(exclusion.request_uris, []),
            coalesce(exclusion.request_query_params, []),
          ) :
          contains(["EQUALS", "STARTS_WITH", "ENDS_WITH", "CONTAINS", "EQUALS_ANY"], field.operator)
        ]
      ]
    ]))
    error_message = "waf_preconfigured_rules exclusion operators must be EQUALS, STARTS_WITH, ENDS_WITH, CONTAINS, or EQUALS_ANY."
  }

  validation {
    condition = alltrue(flatten([
      for _, rule in var.waf_preconfigured_rules : [
        for exclusion in coalesce(rule.exclusions, []) : [
          for field in concat(
            coalesce(exclusion.request_headers, []),
            coalesce(exclusion.request_cookies, []),
            coalesce(exclusion.request_uris, []),
            coalesce(exclusion.request_query_params, []),
          ) :
          field.operator == "EQUALS_ANY" ? field.value == null : (field.value != null && trimspace(coalesce(field.value, "")) != "")
        ]
      ]
    ]))
    error_message = "waf_preconfigured_rules exclusions require a value for every operator except EQUALS_ANY, which must omit it."
  }
}

variable "waf_custom_rules" {
  description = <<-EOT
    Map of rules written in the Cloud Armor rules language (CEL), for anything the IP lists, path rate limits and preconfigured rule sets do not cover: geo blocking, header matching, per-rule rate limits.

    Each key is the rule name inside the policy (unique). Each value configures one rule:

    - expression (required): CEL, e.g. "origin.region_code == 'CN'", "request.headers['user-agent'].contains('curl')", "request.path.startsWith('/admin') && !inIpRange(origin.ip, '203.0.113.0/24')"
    - action: "deny" (default), "allow", "throttle" or "rate_based_ban". The rate limiting actions require rate_limit; allow and deny must omit it.
    - deny_status: status returned by a deny action (403, 404 or 502)
    - priority: evaluation order. Auto-assigned in the 6000 band when omitted; set below 1000 to run ahead of every generated rule.
    - preview: evaluate and log without enforcing
    - description: free text, truncated to 63 characters. Defaults to the map key.
    - rate_limit: threshold_count plus optional interval_sec (60), exceed_status (429), enforce_on_key (IP), enforce_on_key_name, ban_duration_sec, ban_threshold_count, ban_threshold_interval_sec. Ban fields apply to rate_based_ban only.

    Example, a geo block and a throttle on the login route:

    `block-cn = { expression = "origin.region_code == 'CN'" }`

    `throttle-login = { expression = "request.path.startsWith('/auth/login')", action = "throttle", rate_limit = { threshold_count = 100, interval_sec = 60 } }`

    Reference: https://cloud.google.com/armor/docs/rules-language-reference
  EOT
  type = map(object({
    expression  = string
    action      = optional(string, "deny")
    deny_status = optional(number, 403)
    priority    = optional(number)
    preview     = optional(bool, false)
    description = optional(string)
    rate_limit = optional(object({
      threshold_count            = number
      interval_sec               = optional(number, 60)
      exceed_status              = optional(number, 429)
      enforce_on_key             = optional(string, "IP")
      enforce_on_key_name        = optional(string)
      ban_duration_sec           = optional(number, 600)
      ban_threshold_count        = optional(number)
      ban_threshold_interval_sec = optional(number, 600)
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for _, rule in var.waf_custom_rules :
      trimspace(rule.expression) != ""
    ])
    error_message = "waf_custom_rules.expression must be a non-empty CEL expression."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_custom_rules :
      contains(["allow", "deny", "throttle", "rate_based_ban"], coalesce(rule.action, "deny"))
    ])
    error_message = "waf_custom_rules.action must be \"allow\", \"deny\", \"throttle\", or \"rate_based_ban\"."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_custom_rules :
      contains(["throttle", "rate_based_ban"], coalesce(rule.action, "deny")) == (rule.rate_limit != null)
    ])
    error_message = "waf_custom_rules entries must set rate_limit when action is \"throttle\" or \"rate_based_ban\", and must omit it for \"allow\" and \"deny\"."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_custom_rules :
      contains([403, 404, 502], coalesce(rule.deny_status, 403))
    ])
    error_message = "waf_custom_rules.deny_status must be 403, 404, or 502."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_custom_rules :
      rule.priority == null || (coalesce(rule.priority, 1) >= 1 && coalesce(rule.priority, 1) <= 2147483646)
    ])
    error_message = "waf_custom_rules.priority must be between 1 and 2147483646. 2147483647 is reserved for the default rule."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_custom_rules :
      rule.rate_limit == null || (
        rule.rate_limit.threshold_count >= 1 && rule.rate_limit.threshold_count <= 10000
      )
    ])
    error_message = "waf_custom_rules.rate_limit.threshold_count must be between 1 and 10000."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_custom_rules :
      rule.rate_limit == null || contains(
        [10, 30, 60, 120, 180, 240, 300, 600, 900, 1200, 1800, 2700, 3600],
        coalesce(rule.rate_limit.interval_sec, 60)
      )
    ])
    error_message = "waf_custom_rules.rate_limit.interval_sec must be one of 10, 30, 60, 120, 180, 240, 300, 600, 900, 1200, 1800, 2700, 3600."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_custom_rules :
      rule.rate_limit == null || contains([403, 404, 429, 502], coalesce(rule.rate_limit.exceed_status, 429))
    ])
    error_message = "waf_custom_rules.rate_limit.exceed_status must be 403, 404, 429, or 502."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_custom_rules :
      rule.rate_limit == null || contains(
        ["ALL", "IP", "XFF_IP", "USER_IP", "HTTP_HEADER", "HTTP_COOKIE", "HTTP_PATH", "SNI", "REGION_CODE", "TLS_JA3_FINGERPRINT", "TLS_JA4_FINGERPRINT"],
        coalesce(rule.rate_limit.enforce_on_key, "IP")
      )
    ])
    error_message = "waf_custom_rules.rate_limit.enforce_on_key must be one of ALL, IP, XFF_IP, USER_IP, HTTP_HEADER, HTTP_COOKIE, HTTP_PATH, SNI, REGION_CODE, TLS_JA3_FINGERPRINT, TLS_JA4_FINGERPRINT."
  }

  validation {
    condition = alltrue([
      for _, rule in var.waf_custom_rules :
      rule.rate_limit == null || !contains(["HTTP_HEADER", "HTTP_COOKIE"], coalesce(rule.rate_limit.enforce_on_key, "IP")) || (
        rule.rate_limit.enforce_on_key_name != null && trimspace(coalesce(rule.rate_limit.enforce_on_key_name, "")) != ""
      )
    ])
    error_message = "waf_custom_rules.rate_limit.enforce_on_key_name is required when enforce_on_key is HTTP_HEADER or HTTP_COOKIE."
  }
}

variable "waf_advanced_options" {
  description = <<-EOT
    Policy-wide Cloud Armor options.

    - json_parsing: "DISABLED" (default), "STANDARD" or "STANDARD_WITH_GRAPHQL". STANDARD lets preconfigured rule sets inspect JSON bodies field by field, which matters for the SQLi and XSS sets against Paragon's JSON APIs.
    - json_content_types: extra Content-Type values to parse as JSON. Requires json_parsing = "STANDARD".
    - log_level: "NORMAL" (default) or "VERBOSE". VERBOSE records the matched signature and request field, at higher log volume and cost.
    - user_ip_request_headers: headers to resolve the real client IP from, for enforce_on_key = "USER_IP"
    - adaptive_protection_enabled: machine-learned Layer 7 DDoS detection. Requires Cloud Armor Enterprise.
    - adaptive_protection_rule_visibility: "STANDARD" (default) or "PREMIUM"

    Example: `{ json_parsing = "STANDARD", log_level = "VERBOSE" }`
  EOT
  type = object({
    json_parsing                        = optional(string, "DISABLED")
    json_content_types                  = optional(list(string), [])
    log_level                           = optional(string, "NORMAL")
    user_ip_request_headers             = optional(list(string), [])
    adaptive_protection_enabled         = optional(bool, false)
    adaptive_protection_rule_visibility = optional(string, "STANDARD")
  })
  default = {}

  validation {
    condition     = contains(["DISABLED", "STANDARD", "STANDARD_WITH_GRAPHQL"], coalesce(var.waf_advanced_options.json_parsing, "DISABLED"))
    error_message = "waf_advanced_options.json_parsing must be \"DISABLED\", \"STANDARD\", or \"STANDARD_WITH_GRAPHQL\"."
  }

  validation {
    condition     = contains(["NORMAL", "VERBOSE"], coalesce(var.waf_advanced_options.log_level, "NORMAL"))
    error_message = "waf_advanced_options.log_level must be \"NORMAL\" or \"VERBOSE\"."
  }

  validation {
    condition     = contains(["STANDARD", "PREMIUM"], coalesce(var.waf_advanced_options.adaptive_protection_rule_visibility, "STANDARD"))
    error_message = "waf_advanced_options.adaptive_protection_rule_visibility must be \"STANDARD\" or \"PREMIUM\"."
  }

  validation {
    condition     = coalesce(var.waf_advanced_options.json_parsing, "DISABLED") == "STANDARD" || length(coalesce(var.waf_advanced_options.json_content_types, [])) == 0
    error_message = "waf_advanced_options.json_content_types is only honoured when json_parsing is \"STANDARD\"."
  }
}

variable "waf_logs_sample_rate" {
  description = "Fraction of requests logged to Cloud Logging on the protected backend services, between 0 and 1. Cloud Armor records the matched rule and action in those logs, so 1 keeps every enforcement decision visible. Only applies when WAF is active."
  type        = number
  default     = 1

  validation {
    condition     = var.waf_logs_sample_rate >= 0 && var.waf_logs_sample_rate <= 1
    error_message = "waf_logs_sample_rate must be between 0 and 1."
  }
}

locals {
  creds_json     = try(jsondecode(file(var.gcp_credential_json_file)), var.gcp_credential_json)
  gcp_project_id = try(local.creds_json.project_id, var.gcp_project_id)

  # hash of project ID to help ensure uniqueness of resources like bucket names
  hash              = substr(sha256(local.gcp_project_id), 0, 8)
  default_workspace = "paragon-${var.organization}-${local.hash}"

  default_labels = {
    name         = local.workspace
    environment  = var.environment
    organization = var.organization
    creator      = "terraform"
  }

  dns_enabled = var.ingress_scheme != "internal" && var.cloudflare_api_token != null && var.cloudflare_zone_id != null

  # Cloud Armor backend policies only apply to the external Application Load Balancer.
  waf_active = var.waf_enabled && var.ingress_scheme != "internal"

  infra_json_path       = var.infra_json_path != null ? abspath(var.infra_json_path) : null
  use_legacy_infra_json = var.infra_json != null || var.infra_json_path != null
  legacy_infra_vars     = local.use_legacy_infra_json ? jsondecode(var.infra_json != null ? var.infra_json : file(local.infra_json_path)) : null

  # `local.infra_vars` is resolved in infra_secrets.tf (legacy infra.json when provided,
  # otherwise infra secrets sourced from Secret Manager). Backward compatible with infra
  # workspaces that still emit the legacy "minio" output instead of the renamed "storage"
  # output; null-safe when neither is present.
  storage_output = try(local.infra_vars.storage.value, local.infra_vars.minio.value, {})

  workspace        = nonsensitive(local.use_legacy_infra_json ? try(local.legacy_infra_vars.workspace.value, local.default_workspace) : local.default_workspace)
  cluster_name     = coalesce(var.cluster_name_override, local.use_legacy_infra_json ? try(local.legacy_infra_vars.cluster_name.value, null) : null, "${local.workspace}-cluster")
  logs_bucket      = local.use_legacy_infra_json ? try(local.legacy_infra_vars.logs_bucket.value, "${local.workspace}-logs") : "${local.workspace}-logs"
  auditlogs_bucket = local.use_legacy_infra_json ? try(local.legacy_infra_vars.auditlogs_bucket.value, "${local.workspace}-auditlogs") : "${local.workspace}-auditlogs"

  helm_yaml_path = abspath(var.helm_yaml_path)
  helm_vars      = yamldecode(fileexists(local.helm_yaml_path) && var.helm_yaml == null ? file(local.helm_yaml_path) : var.helm_yaml)

  gcp_provider_credentials = jsonencode({
    type                        = "service_account",
    auth_provider_x509_cert_url = "https://www.googleapis.com/oauth2/v1/certs",
    auth_uri                    = "https://accounts.google.com/o/oauth2/auth",
    token_uri                   = "https://oauth2.googleapis.com/token",
    client_email                = try(local.creds_json.client_email, var.gcp_client_email),
    client_id                   = try(local.creds_json.client_id, var.gcp_client_id),
    client_x509_cert_url        = try(local.creds_json.client_x509_cert_url, var.gcp_client_x509_cert_url),
    project_id                  = try(local.creds_json.project_id, var.gcp_project_id),
    private_key                 = try(local.creds_json.private_key, var.gcp_private_key),
    private_key_id              = try(local.creds_json.private_key_id, var.gcp_private_key_id),
  })

  # WIF deployments store the storage SA key in infra secrets; static JSON creds otherwise.
  # Keep this separate from provider credentials to avoid a cycle with Secret Manager data sources.
  gcp_creds = var.gcp_assume_role ? try(base64decode(local.storage_output.root_password), null) : local.gcp_provider_credentials

  cloud_storage_type = try(local.helm_vars.global.env["CLOUD_STORAGE_TYPE"], "GCP")

  all_microservices = {
    "account" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["ACCOUNT_PORT"], 1708)
      "public_url"       = try(local.helm_vars.global.env["ACCOUNT_PUBLIC_URL"], "https://account.${var.domain}")
    }
    "api-triggerkit" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["API_TRIGGERKIT_PORT"], 1725)
      "public_url"       = try(local.helm_vars.global.env["API_TRIGGERKIT_PUBLIC_URL"], "https://api-triggerkit.${var.domain}")
    }
    "cache-replay" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["CACHE_REPLAY_PORT"], 1724)
      "public_url"       = try(local.helm_vars.global.env["CACHE_REPLAY_PUBLIC_URL"], "https://cache-replay.${var.domain}")
    }
    "cerberus" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["CERBERUS_PORT"], 1700)
      "public_url"       = try(local.helm_vars.global.env["CERBERUS_PUBLIC_URL"], "https://cerberus.${var.domain}")
    }
    "connect" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["CONNECT_PORT"], 1707)
      "public_url"       = try(local.helm_vars.global.env["CONNECT_PUBLIC_URL"], "https://connect.${var.domain}")
    }
    "dashboard" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["DASHBOARD_PORT"], 1704)
      "public_url"       = try(local.helm_vars.global.env["DASHBOARD_PUBLIC_URL"], "https://dashboard.${var.domain}")
    }
    "flipt" = {
      "healthcheck_path" = "/health"
      "port"             = try(local.helm_vars.global.env["FLIPT_PORT"], 1722)
      "public_url"       = try(local.helm_vars.global.env["FLIPT_PUBLIC_URL"], null)
    }
    "hades" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["HADES_PORT"], 1710)
      "public_url"       = try(local.helm_vars.global.env["HADES_PUBLIC_URL"], "https://hades.${var.domain}")
    }
    "health-checker" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["HEALTH_CHECKER_PORT"], 1733)
      "public_url"       = try(local.helm_vars.global.env["HEALTH_CHECKER_PUBLIC_URL"], "https://health-checker.${var.domain}")
    }
    "hermes" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["HERMES_PORT"], 1702)
      "public_url"       = try(local.helm_vars.global.env["HERMES_PUBLIC_URL"], "https://hermes.${var.domain}")
    }
    "passport" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["PASSPORT_PORT"], 1706)
      "public_url"       = try(local.helm_vars.global.env["PASSPORT_PUBLIC_URL"], "https://passport.${var.domain}")
    }
    "pheme" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["PHEME_PORT"], 1709)
      "public_url"       = try(local.helm_vars.global.env["PHEME_PUBLIC_URL"], "https://pheme.${var.domain}")
    }
    "release" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["RELEASE_PORT"], 1719)
      "public_url"       = try(local.helm_vars.global.env["RELEASE_PUBLIC_URL"], "https://release.${var.domain}")
    }
    "zeus" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["ZEUS_PORT"], 1703)
      "public_url"       = try(local.helm_vars.global.env["ZEUS_PUBLIC_URL"], "https://zeus.${var.domain}")
    }
    "worker-actionkit" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_ACTIONKIT_PORT"], 1721)
      "public_url"       = try(local.helm_vars.global.env["WORKER_ACTIONKIT_PUBLIC_URL"], "https://worker-actionkit.${var.domain}")
    }
    "worker-actions" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_ACTIONS_PORT"], 1712)
      "public_url"       = try(local.helm_vars.global.env["WORKER_ACTIONS_PUBLIC_URL"], "https://worker-actions.${var.domain}")
    }
    "worker-auditlogs" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_AUDIT_LOGS_PORT"], 1727)
      "public_url"       = try(local.helm_vars.global.env["WORKER_AUDIT_LOGS_PUBLIC_URL"], "https://worker-auditlogs.${var.domain}")
    }
    "worker-credentials" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_CREDENTIALS_PORT"], 1713)
      "public_url"       = try(local.helm_vars.global.env["WORKER_CREDENTIALS_PUBLIC_URL"], "https://worker-credentials.${var.domain}")
    }
    "worker-crons" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_CRONS_PORT"], 1714)
      "public_url"       = try(local.helm_vars.global.env["WORKER_CRONS_PUBLIC_URL"], "https://worker-crons.${var.domain}")
    }
    "worker-deployments" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_DEPLOYMENTS_PORT"], 1718)
      "public_url"       = try(local.helm_vars.global.env["WORKER_DEPLOYMENTS_PUBLIC_URL"], "https://worker-deployments.${var.domain}")
    }
    "worker-eventlogs" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_EVENT_LOGS_PORT"], 1723)
      "public_url"       = try(local.helm_vars.global.env["WORKER_EVENT_LOGS_PUBLIC_URL"], "https://worker-eventlogs.${var.domain}")
    }
    "worker-proxy" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_PROXY_PORT"], 1715)
      "public_url"       = try(local.helm_vars.global.env["WORKER_PROXY_PUBLIC_URL"], "https://worker-proxy.${var.domain}")
    }
    "worker-triggerkit" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_TRIGGERKIT_PORT"], 1726)
      "public_url"       = try(local.helm_vars.global.env["WORKER_TRIGGERKIT_PUBLIC_URL"], "https://worker-triggerkit.${var.domain}")
    }
    "worker-triggers" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_TRIGGERS_PORT"], 1716)
      "public_url"       = try(local.helm_vars.global.env["WORKER_TRIGGERS_PUBLIC_URL"], "https://worker-triggers.${var.domain}")
    }
    "worker-workflows" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_WORKFLOWS_PORT"], 1717)
      "public_url"       = try(local.helm_vars.global.env["WORKER_WORKFLOWS_PUBLIC_URL"], "https://worker-workflows.${var.domain}")
    }
  }

  microservices = {
    for microservice, config in local.all_microservices :
    microservice => config
    if !contains(var.excluded_microservices, microservice)
  }

  public_microservices = {
    for microservice, config in local.microservices :
    microservice => config
    if config.public_url != null && config.public_url != "" && !contains(var.private_services, microservice)
  }

  uptime_services = {
    for microservice, config in local.public_microservices :
    microservice => config
    if var.ingress_scheme != "internal" && (microservice == "health-checker" || !var.health_checker_enabled)
  }

  monitors = {
    "bull-exporter" = {
      "port"       = 9538
      "public_url" = null
    }
    "grafana" = {
      "port"       = 4500
      "public_url" = try(local.helm_vars.global.env["MONITOR_GRAFANA_SERVER_DOMAIN"], "https://grafana.${var.domain}")
    }
    "kafka-exporter" = {
      "port"       = 9308
      "public_url" = null
    }
    "kube-state-metrics" = {
      "port"       = 2550
      "public_url" = null
    }
    "pgadmin" = {
      "port"       = 5050
      "public_url" = null
    }
    "prometheus" = {
      "port"       = 9090
      "public_url" = null
    }
    "postgres-exporter" = {
      "port"       = 9187
      "public_url" = null
    }
    "redis-exporter" = {
      "port"       = 9121
      "public_url" = null
    }
    "redis-insight" = {
      "port"       = 8500
      "public_url" = null
    }
  }

  public_monitors = var.monitors_enabled ? {
    for monitor, config in local.monitors :
    monitor => config
    if lookup(config, "public_url", null) != null && !contains(var.private_services, monitor)
  } : {}

  public_services = merge(local.public_microservices, local.public_monitors)

  helm_keys_to_remove = [
    "POSTGRES_HOST",
    "POSTGRES_PORT",
    "POSTGRES_USER",
    "POSTGRES_PASSWORD",
    "POSTGRES_DATABASE",
    "REDIS_HOST",
    "REDIS_PORT",
  ]

  default_redis_cluster = try(
    local.helm_vars.global.env["REDIS_CLUSTER"],
    local.infra_vars.redis.value.cache.cluster,
    "false"
  )

  default_redis_ssl = try(
    local.helm_vars.global.env["REDIS_SSL"],
    local.infra_vars.redis.value.cache.ssl,
    "false"
  )

  # Build full redis:// or rediss:// URLs from infra (Memorystore uses TLS; connection_string has no scheme and causes 0x15 if app uses redis://).
  redis_instance_urls = {
    for name, r in try(local.infra_vars.redis.value, {}) :
    name => "${r.ssl ? "rediss" : "redis"}://${r.password != null ? ":${urlencode(r.password)}@" : ""}${r.host}:${r.port}"
  }

  default_redis_url = try(
    local.helm_vars.global.env["REDIS_URL"],
    "${local.helm_vars.global.env["REDIS_HOST"]}:${local.helm_vars.global.env["REDIS_PORT"]}",
    try(local.redis_instance_urls["cache"], local.infra_vars.redis.value.cache.connection_string, "${local.infra_vars.redis.value.cache.host}:${local.infra_vars.redis.value.cache.port}")
  )

  helm_values = merge(local.helm_vars, {
    global = merge(local.helm_vars.global, {
      # Redis CA certificate configuration
      # Enable if any Redis instance has a CA certificate
      redisCaCert = {
        enabled = try(
          local.infra_vars.redis.value.cache.ca_certificate != null ||
          local.infra_vars.redis.value.queue.ca_certificate != null ||
          local.infra_vars.redis.value.system.ca_certificate != null,
          false
        )
        secretName = "redis-ca-cert"
      },
      env = merge({
        BRANCH                 = "main"
        EMAIL_DELIVERY_SERVICE = "none"
        HOST_ENV               = "GCP_K8"
        LOG_LEVEL              = "info"
        NODE_ENV               = "production"
        ORGANIZATION           = var.organization
        PARAGON_DOMAIN         = var.domain
        PLATFORM_ENV           = "enterprise"

        # Service ports
        ACCOUNT_PORT            = try(local.microservices.account.port, null)
        API_TRIGGERKIT_PORT     = try(local.microservices["api-triggerkit"].port, null)
        CACHE_REPLAY_PORT       = try(local.microservices["cache-replay"].port, null)
        CERBERUS_PORT           = try(local.microservices.cerberus.port, null)
        CONNECT_PORT            = try(local.microservices.connect.port, null)
        DASHBOARD_PORT          = try(local.microservices.dashboard.port, null)
        HADES_PORT              = try(local.microservices.hades.port, null)
        HEALTH_CHECKER_PORT     = try(local.microservices["health-checker"].port, null)
        HERMES_PORT             = try(local.microservices.hermes.port, null)
        PASSPORT_PORT           = try(local.microservices.passport.port, null)
        PHEME_PORT              = try(local.microservices.pheme.port, null)
        RELEASE_PORT            = try(local.microservices.release.port, null)
        WORKER_ACTIONKIT_PORT   = try(local.microservices["worker-actionkit"].port, null)
        WORKER_ACTIONS_PORT     = try(local.microservices["worker-actions"].port, null)
        WORKER_AUDIT_LOGS_PORT  = try(local.microservices["worker-auditlogs"].port, null)
        WORKER_CREDENTIALS_PORT = try(local.microservices["worker-credentials"].port, null)
        WORKER_CRONS_PORT       = try(local.microservices["worker-crons"].port, null)
        WORKER_DEPLOYMENTS_PORT = try(local.microservices["worker-deployments"].port, null)
        WORKER_EVENT_LOGS_PORT  = try(local.microservices["worker-eventlogs"].port, null)
        WORKER_PROXY_PORT       = try(local.microservices["worker-proxy"].port, null)
        WORKER_TRIGGERKIT_PORT  = try(local.microservices["worker-triggerkit"].port, null)
        WORKER_TRIGGERS_PORT    = try(local.microservices["worker-triggers"].port, null)
        WORKER_WORKFLOWS_PORT   = try(local.microservices["worker-workflows"].port, null)
        ZEUS_PORT               = try(local.microservices.zeus.port, null)

        # Service Private URLs
        ACCOUNT_PRIVATE_URL            = try("http://account:${local.microservices.account.port}", null)
        API_TRIGGERKIT_PRIVATE_URL     = try("http://api-triggerkit:${local.microservices["api-triggerkit"].port}", null)
        CACHE_REPLAY_PRIVATE_URL       = try("http://cache-replay:${local.microservices["cache-replay"].port}", null)
        CERBERUS_PRIVATE_URL           = try("http://cerberus:${local.microservices.cerberus.port}", null)
        CONNECT_PRIVATE_URL            = try("http://connect:${local.microservices.connect.port}", null)
        DASHBOARD_PRIVATE_URL          = try("http://dashboard:${local.microservices.dashboard.port}", null)
        EMBASSY_PRIVATE_URL            = "http://embassy:1705"
        HADES_PRIVATE_URL              = try("http://hades:${local.microservices.hades.port}", null)
        HEALTH_CHECKER_PRIVATE_URL     = try("http://health-checker:${local.microservices["health-checker"].port}", null)
        HERMES_PRIVATE_URL             = try("http://hermes:${local.microservices.hermes.port}", null)
        PASSPORT_PRIVATE_URL           = try("http://passport:${local.microservices.passport.port}", null)
        PHEME_PRIVATE_URL              = try("http://pheme:${local.microservices.pheme.port}", null)
        RELEASE_PRIVATE_URL            = try("http://release:${local.microservices.release.port}", null)
        WORKER_ACTIONKIT_PRIVATE_URL   = try("http://worker-actionkit:${local.microservices["worker-actionkit"].port}", null)
        WORKER_ACTIONS_PRIVATE_URL     = try("http://worker-actions:${local.microservices["worker-actions"].port}", null)
        WORKER_AUDIT_LOGS_PRIVATE_URL  = try("http://worker-auditlogs:${local.microservices["worker-auditlogs"].port}", null)
        WORKER_CREDENTIALS_PRIVATE_URL = try("http://worker-credentials:${local.microservices["worker-credentials"].port}", null)
        WORKER_CRONS_PRIVATE_URL       = try("http://worker-crons:${local.microservices["worker-crons"].port}", null)
        WORKER_DEPLOYMENTS_PRIVATE_URL = try("http://worker-deployments:${local.microservices["worker-deployments"].port}", null)
        WORKER_EVENT_LOGS_PRIVATE_URL  = try("http://worker-eventlogs:${local.microservices["worker-eventlogs"].port}", null)
        WORKER_PROXY_PRIVATE_URL       = try("http://worker-proxy:${local.microservices["worker-proxy"].port}", null)
        WORKER_TRIGGERKIT_PRIVATE_URL  = try("http://worker-triggerkit:${local.microservices["worker-triggerkit"].port}", null)
        WORKER_TRIGGERS_PRIVATE_URL    = try("http://worker-triggers:${local.microservices["worker-triggers"].port}", null)
        WORKER_WORKFLOWS_PRIVATE_URL   = try("http://worker-workflows:${local.microservices["worker-workflows"].port}", null)
        ZEUS_PRIVATE_URL               = try("http://zeus:${local.microservices.zeus.port}", null)

        # Service Public URLs
        ACCOUNT_PUBLIC_URL            = try(local.microservices.account.public_url, null)
        API_TRIGGERKIT_PUBLIC_URL     = try(local.microservices["api-triggerkit"].public_url, null)
        CERBERUS_PUBLIC_URL           = try(local.microservices.cerberus.public_url, null)
        CONNECT_PUBLIC_URL            = try(local.microservices.connect.public_url, null)
        DASHBOARD_PUBLIC_URL          = try(local.microservices.dashboard.public_url, null)
        HADES_PUBLIC_URL              = try(local.microservices.hades.public_url, null)
        HEALTH_CHECKER_PUBLIC_URL     = try(local.microservices["health-checker"].public_url, null)
        HERMES_PUBLIC_URL             = try(local.microservices.hermes.public_url, null)
        PASSPORT_PUBLIC_URL           = try(local.microservices.passport.public_url, null)
        PHEME_PUBLIC_URL              = try(local.microservices.pheme.public_url, null)
        PUBLIC_UPLOAD_PROXY_BASE_URL  = try("${local.microservices.zeus.public_url}/public-upload-proxy", null)
        RELEASE_PUBLIC_URL            = try(local.microservices.release.public_url, null)
        WORKER_ACTIONKIT_PUBLIC_URL   = try(local.microservices["worker-actionkit"].public_url, null)
        WORKER_ACTIONS_PUBLIC_URL     = try(local.microservices["worker-actions"].public_url, null)
        WORKER_AUDIT_LOGS_PUBLIC_URL  = try(local.microservices["worker-auditlogs"].public_url, null)
        WORKER_CREDENTIALS_PUBLIC_URL = try(local.microservices["worker-credentials"].public_url, null)
        WORKER_CRONS_PUBLIC_URL       = try(local.microservices["worker-crons"].public_url, null)
        WORKER_DEPLOYMENTS_PUBLIC_URL = try(local.microservices["worker-deployments"].public_url, null)
        WORKER_EVENT_LOGS_PUBLIC_URL  = try(local.microservices["worker-eventlogs"].public_url, null)
        WORKER_PROXY_PUBLIC_URL       = try(local.microservices["worker-proxy"].public_url, null)
        WORKER_TRIGGERKIT_PUBLIC_URL  = try(local.microservices["worker-triggerkit"].public_url, null)
        WORKER_TRIGGERS_PUBLIC_URL    = try(local.microservices["worker-triggers"].public_url, null)
        WORKER_WORKFLOWS_PUBLIC_URL   = try(local.microservices["worker-workflows"].public_url, null)
        ZEUS_PUBLIC_URL               = try(local.microservices.zeus.public_url, null)

        # Worker variables
        WORKER_WORKFLOWS_MINIMUM_HERMES_PROCESSOR_QUEUE_COUNT = 0
        WORKER_WORKFLOWS_MINIMUM_TEST_WORKFLOW_QUEUE_COUNT    = 1

        # Authentication
        ADMIN_BASIC_AUTH_USERNAME = try(local.helm_vars.global.env["LICENSE"], null)
        ADMIN_BASIC_AUTH_PASSWORD = try(local.helm_vars.global.env["LICENSE"], null)

        # Feature flags
        FEATURE_FLAG_PLATFORM_ENABLED  = "true"
        FEATURE_FLAG_PLATFORM_ENDPOINT = "http://flipt:${local.microservices.flipt.port}"

        # Audit logs
        AUDIT_LOGS_EVENT_BATCH_SIZE     = try(local.helm_vars.global.env["AUDIT_LOGS_EVENT_BATCH_SIZE"], 1000)
        CLOUD_STORAGE_COMPLIANCE_BUCKET = try(local.helm_vars.global.env["CLOUD_STORAGE_COMPLIANCE_BUCKET"], local.auditlogs_bucket)

        # Database configurations
        CERBERUS_POSTGRES_DATABASE      = try(local.infra_vars.postgres.value.cerberus.database, local.infra_vars.postgres.value.paragon.database)
        CERBERUS_POSTGRES_HOST          = try(local.infra_vars.postgres.value.cerberus.host, local.infra_vars.postgres.value.paragon.host)
        CERBERUS_POSTGRES_PASSWORD      = try(local.infra_vars.postgres.value.cerberus.password, local.infra_vars.postgres.value.paragon.password)
        CERBERUS_POSTGRES_PORT          = try(local.infra_vars.postgres.value.cerberus.port, local.infra_vars.postgres.value.paragon.port)
        CERBERUS_POSTGRES_SSL_ENABLED   = try(local.infra_vars.postgres.value.cerberus.ssl, "true")
        CERBERUS_POSTGRES_USERNAME      = try(local.infra_vars.postgres.value.cerberus.user, local.infra_vars.postgres.value.paragon.user)
        EVENT_LOGS_POSTGRES_DATABASE    = try(local.infra_vars.postgres.value.eventlogs.database, local.infra_vars.postgres.value.paragon.database)
        EVENT_LOGS_POSTGRES_HOST        = try(local.infra_vars.postgres.value.eventlogs.host, local.infra_vars.postgres.value.paragon.host)
        EVENT_LOGS_POSTGRES_PASSWORD    = try(local.infra_vars.postgres.value.eventlogs.password, local.infra_vars.postgres.value.paragon.password)
        EVENT_LOGS_POSTGRES_PORT        = try(local.infra_vars.postgres.value.eventlogs.port, local.infra_vars.postgres.value.paragon.port)
        EVENT_LOGS_POSTGRES_SSL_ENABLED = try(local.infra_vars.postgres.value.eventlogs.ssl, "true")
        EVENT_LOGS_POSTGRES_USERNAME    = try(local.infra_vars.postgres.value.eventlogs.user, local.infra_vars.postgres.value.paragon.user)
        HERMES_POSTGRES_DATABASE        = try(local.infra_vars.postgres.value.hermes.database, local.infra_vars.postgres.value.paragon.database)
        HERMES_POSTGRES_HOST            = try(local.infra_vars.postgres.value.hermes.host, local.infra_vars.postgres.value.paragon.host)
        HERMES_POSTGRES_PASSWORD        = try(local.infra_vars.postgres.value.hermes.password, local.infra_vars.postgres.value.paragon.password)
        HERMES_POSTGRES_PORT            = try(local.infra_vars.postgres.value.hermes.port, local.infra_vars.postgres.value.paragon.port)
        HERMES_POSTGRES_SSL_ENABLED     = try(local.infra_vars.postgres.value.hermes.ssl, "true")
        HERMES_POSTGRES_USERNAME        = try(local.infra_vars.postgres.value.hermes.user, local.infra_vars.postgres.value.paragon.user)
        PHEME_POSTGRES_DATABASE         = try(local.infra_vars.postgres.value.hermes.database, local.infra_vars.postgres.value.paragon.database)
        PHEME_POSTGRES_HOST             = try(local.infra_vars.postgres.value.hermes.host, local.infra_vars.postgres.value.paragon.host)
        PHEME_POSTGRES_PASSWORD         = try(local.infra_vars.postgres.value.hermes.password, local.infra_vars.postgres.value.paragon.password)
        PHEME_POSTGRES_PORT             = try(local.infra_vars.postgres.value.hermes.port, local.infra_vars.postgres.value.paragon.port)
        PHEME_POSTGRES_SSL_ENABLED      = try(local.infra_vars.postgres.value.hermes.ssl, "true")
        PHEME_POSTGRES_USERNAME         = try(local.infra_vars.postgres.value.hermes.user, local.infra_vars.postgres.value.paragon.user)
        TRIGGERKIT_POSTGRES_DATABASE    = try(local.infra_vars.postgres.value.triggerkit.database, local.infra_vars.postgres.value.paragon.database)
        TRIGGERKIT_POSTGRES_HOST        = try(local.infra_vars.postgres.value.triggerkit.host, local.infra_vars.postgres.value.paragon.host)
        TRIGGERKIT_POSTGRES_PASSWORD    = try(local.infra_vars.postgres.value.triggerkit.password, local.infra_vars.postgres.value.paragon.password)
        TRIGGERKIT_POSTGRES_PORT        = try(local.infra_vars.postgres.value.triggerkit.port, local.infra_vars.postgres.value.paragon.port)
        TRIGGERKIT_POSTGRES_SSL_ENABLED = try(local.infra_vars.postgres.value.triggerkit.ssl, "true")
        TRIGGERKIT_POSTGRES_USERNAME    = try(local.infra_vars.postgres.value.triggerkit.user, local.infra_vars.postgres.value.paragon.user)
        ZEUS_POSTGRES_DATABASE          = try(local.infra_vars.postgres.value.zeus.database, local.infra_vars.postgres.value.paragon.database)
        ZEUS_POSTGRES_HOST              = try(local.infra_vars.postgres.value.zeus.host, local.infra_vars.postgres.value.paragon.host)
        ZEUS_POSTGRES_PASSWORD          = try(local.infra_vars.postgres.value.zeus.password, local.infra_vars.postgres.value.paragon.password)
        ZEUS_POSTGRES_PORT              = try(local.infra_vars.postgres.value.zeus.port, local.infra_vars.postgres.value.paragon.port)
        ZEUS_POSTGRES_SSL_ENABLED       = try(local.infra_vars.postgres.value.zeus.ssl, "true")
        ZEUS_POSTGRES_USERNAME          = try(local.infra_vars.postgres.value.zeus.user, local.infra_vars.postgres.value.paragon.user)

        # Redis configurations (full redis:// or rediss:// URLs so TLS is used when infra has ssl=true, e.g. Memorystore).
        REDIS_URL = local.default_redis_url

        CACHE_REDIS_CLUSTER_ENABLED    = try(local.infra_vars.redis.value.cache.cluster, local.default_redis_cluster)
        CACHE_REDIS_TLS_ENABLED        = try(local.infra_vars.redis.value.cache.ssl, local.default_redis_ssl)
        CACHE_REDIS_URL                = try(local.redis_instance_urls["cache"], local.default_redis_url)
        QUEUE_REDIS_CLUSTER_ENABLED    = try(local.infra_vars.redis.value.queue.cluster, local.default_redis_cluster)
        QUEUE_REDIS_TLS_ENABLED        = try(local.infra_vars.redis.value.queue.ssl, local.default_redis_ssl)
        QUEUE_REDIS_URL                = try(local.redis_instance_urls["queue"], local.default_redis_url)
        SYSTEM_REDIS_CLUSTER_ENABLED   = try(local.infra_vars.redis.value.system.cluster, local.default_redis_cluster)
        SYSTEM_REDIS_TLS_ENABLED       = try(local.infra_vars.redis.value.system.ssl, local.default_redis_ssl)
        SYSTEM_REDIS_URL               = try(local.redis_instance_urls["system"], local.default_redis_url)
        WORKFLOW_REDIS_CLUSTER_ENABLED = try(local.infra_vars.redis.value.workflow.cluster, local.default_redis_cluster)
        WORKFLOW_REDIS_TLS_ENABLED     = try(local.infra_vars.redis.value.workflow.ssl, local.default_redis_ssl)
        WORKFLOW_REDIS_URL             = try(local.redis_instance_urls["workflow"], local.default_redis_url)

        # Cloud Storage configurations
        CLOUD_STORAGE_MICROSERVICE_PASS = local.storage_output.root_password
        CLOUD_STORAGE_MICROSERVICE_USER = local.storage_output.root_user
        CLOUD_STORAGE_PUBLIC_BUCKET     = try(local.storage_output.public_bucket, "${local.workspace}-cdn")
        CLOUD_STORAGE_SYSTEM_BUCKET     = try(local.storage_output.private_bucket, "${local.workspace}-app")
        CLOUD_STORAGE_TYPE              = local.cloud_storage_type

        CLOUD_STORAGE_PUBLIC_URL = coalesce(
          try(local.helm_vars.global.env["CLOUD_STORAGE_PUBLIC_URL"], null),
          local.cloud_storage_type == "GCP" ? "https://storage.googleapis.com" : null,
        )
        # TODO: In the future, we should use a private link to access the storage account so traffic stays within the VPC. This affects costs and performance.
        CLOUD_STORAGE_PRIVATE_URL = coalesce(
          try(local.helm_vars.global.env["CLOUD_STORAGE_PUBLIC_URL"], null),
          local.cloud_storage_type == "GCP" ? "https://storage.googleapis.com" : null,
        )

        # Monitor configurations
        MONITOR_BULL_EXPORTER_HOST              = "http://bull-exporter"
        MONITOR_BULL_EXPORTER_PORT              = try(local.monitors["bull-exporter"].port, null)
        MONITOR_GRAFANA_HOST                    = "http://grafana"
        MONITOR_GRAFANA_PORT                    = try(local.monitors["grafana"].port, null)
        MONITOR_GRAFANA_SECURITY_ADMIN_PASSWORD = var.monitors_enabled ? module.monitors[0].grafana_admin_password : null
        MONITOR_GRAFANA_SECURITY_ADMIN_USER     = var.monitors_enabled ? module.monitors[0].grafana_admin_email : null
        MONITOR_GRAFANA_SERVER_DOMAIN           = try(local.monitors["grafana"].public_url, null)
        MONITOR_GRAFANA_UPTIME_WEBHOOK_URL      = module.uptime.webhook
        MONITOR_KAFKA_EXPORTER_HOST             = "http://kafka-exporter"
        MONITOR_KAFKA_EXPORTER_PORT             = try(local.monitors["kafka-exporter"].port, null)
        MONITOR_KUBE_STATE_METRICS_HOST         = "http://kube-state-metrics"
        MONITOR_KUBE_STATE_METRICS_PORT         = try(local.monitors["kube-state-metrics"].port, null)
        MONITOR_PGADMIN_EMAIL                   = var.monitors_enabled ? module.monitors[0].pgadmin_admin_email : null
        MONITOR_PGADMIN_HOST                    = "http://pgadmin"
        MONITOR_PGADMIN_PASSWORD                = var.monitors_enabled ? module.monitors[0].pgadmin_admin_password : null
        MONITOR_PGADMIN_PORT                    = try(local.monitors["pgadmin"].port, null)
        MONITOR_PGADMIN_SSL_MODE                = "require"
        MONITOR_POSTGRES_EXPORTER_HOST          = "http://postgres-exporter"
        MONITOR_POSTGRES_EXPORTER_PORT          = try(local.monitors["postgres-exporter"].port, null)
        MONITOR_POSTGRES_EXPORTER_SSL_MODE      = "require"
        MONITOR_PROMETHEUS_HOST                 = "http://prometheus"
        MONITOR_PROMETHEUS_PORT                 = try(local.monitors["prometheus"].port, null)
        MONITOR_QUEUE_REDIS_TARGET              = try(local.infra_vars.redis.value.queue.host, local.infra_vars.redis.value.cache.host)
        MONITOR_REDIS_EXPORTER_HOST             = "http://redis-exporter"
        MONITOR_REDIS_EXPORTER_PORT             = try(local.monitors["redis-exporter"].port, null)
        MONITOR_REDIS_INSIGHT_HOST              = "http://redis-insight"
        MONITOR_REDIS_INSIGHT_PORT              = try(local.monitors["redis-insight"].port, null)
        }, {
        for key, value in local.helm_vars.global.env :
        key => value if value != null && !contains(local.helm_keys_to_remove, key) && !startswith(key, "FLIPT_")
      }, var.managed_sync_enabled ? module.managed_sync_config[0].config : {})
    })
  })

  # Split env by chart service-inputs.json:
  # - envKeys → Helm global.env (plain `value:` on pods)
  # - secretKeys (and not also envKeys) → Secret Manager for secretKeyRef
  # Prefer prepared workspace charts (./prepare.sh). GCP has no infra flat-env
  # secret (unlike AWS); secretKeys come from helm_values built from nested infra JSON.
  chart_service_input_files = fileset("${path.root}/charts", "**/files/service-inputs.json")
  chart_service_inputs = [
    for f in local.chart_service_input_files :
    jsondecode(file("${path.root}/charts/${f}"))
  ]
  chart_env_keys = toset(flatten([
    for s in local.chart_service_inputs : try(s.envKeys, [])
  ]))
  chart_secret_keys = toset(flatten([
    for s in local.chart_service_inputs : try(s.secretKeys, [])
  ]))
  helm_is_secret_env_key = {
    for key, _ in local.helm_values.global.env :
    key => contains(local.chart_secret_keys, key) && !contains(local.chart_env_keys, key)
  }
  helm_secret_values = {
    for key, value in local.helm_values.global.env :
    key => tostring(value)
    if value != null && tostring(value) != "" && local.helm_is_secret_env_key[key]
  }
  helm_values_public = merge(local.helm_values, {
    global = merge(local.helm_values.global, {
      env = {
        for key, value in local.helm_values.global.env :
        key => value
        if value != null && !local.helm_is_secret_env_key[key]
      }
    })
  })

  monitor_version = var.monitor_version != null ? var.monitor_version : try(local.helm_values.global.env["VERSION"], "latest")

  feature_flags_content = var.feature_flags != null ? file(var.feature_flags) : null

  flipt_options = {
    for key, value in merge(
      {
        FLIPT_CACHE_ENABLED             = "true"
        FLIPT_LOG_GRPC_LEVEL            = "warn"
        FLIPT_LOG_LEVEL                 = "warn"
        FLIPT_STORAGE_GIT_POLL_INTERVAL = "30s"
        FLIPT_STORAGE_GIT_REF           = "main"
        FLIPT_STORAGE_GIT_REPOSITORY    = local.feature_flags_content != null ? null : "https://github.com/useparagon/feature-flags.git"
        FLIPT_STORAGE_LOCAL_PATH        = local.feature_flags_content != null ? "/var/opt/flipt" : null
        FLIPT_STORAGE_READ_ONLY         = "true"
        FLIPT_STORAGE_TYPE              = local.feature_flags_content != null ? "local" : "git"
      },
      # user overrides
      local.helm_vars.global.env
    ) :
    key => value
    if key != null && startswith(key, "FLIPT_") && value != null && value != ""
  }
}
