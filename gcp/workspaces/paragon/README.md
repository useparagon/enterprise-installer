# Paragon GCP Deployment

There are several ways to provide GCP credentials. Here are how they are evaluated in order with the first provided option being used.

1. `gcp_credential_json_file` = The file path to the local GCP credential JSON file. This only works if executing Terraform locally since the file won't exist on remote or agent executions.

2. `gcp_credential_json` = The contents of the GCP credential JSON file. Unlike the first option this will work with remote executions.

3. Other `gcp_*` variables (e.g. `gcp_project_id`) = The individual values that should be used without JSON formatting.

NOTE: The credentials above may refer to a Workload Identity Pool account instead of a service account. This would require additional configuration in Terraform Cloud as detailed [here](https://developer.hashicorp.com/terraform/cloud-docs/dynamic-provider-credentials/gcp-configuration).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 7.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_hoop"></a> [hoop](#requirement\_hoop) | >= 0.0.19 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.0.1 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_dns"></a> [dns](#module\_dns) | ./dns | n/a |
| <a name="module_helm"></a> [helm](#module\_helm) | ./helm | n/a |
| <a name="module_hoop"></a> [hoop](#module\_hoop) | ./hoop | n/a |
| <a name="module_managed_sync_config"></a> [managed\_sync\_config](#module\_managed\_sync\_config) | ./helm-config | n/a |
| <a name="module_monitors"></a> [monitors](#module\_monitors) | ./monitors | n/a |
| <a name="module_uptime"></a> [uptime](#module\_uptime) | ./uptime | n/a |
| <a name="module_waf"></a> [waf](#module\_waf) | ./waf | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [google_project_iam_member.eso_secret_accessor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_secret_manager_secret.docker_cfg](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.env](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.managed_sync](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.openobserve](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.openobserve_gcs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_version.docker_cfg](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.env](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.managed_sync](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.openobserve](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.openobserve_gcs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_service_account.eso](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.eso_workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [random_password.openobserve_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.openobserve_email](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [google_client_config.paragon](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_container_cluster.cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/container_cluster) | data source |
| [google_secret_manager_secret_version.infra_kafka](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version) | data source |
| [google_secret_manager_secret_version.infra_postgres](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version) | data source |
| [google_secret_manager_secret_version.infra_redis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version) | data source |
| [google_secret_manager_secret_version.infra_storage](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Zone `DNS` | `string` | `null` | no |
| <a name="input_cloudflare_zone_id"></a> [cloudflare\_zone\_id](#input\_cloudflare\_zone\_id) | Cloudflare zone id to set CNAMEs. | `string` | `null` | no |
| <a name="input_cluster_name_override"></a> [cluster\_name\_override](#input\_cluster\_name\_override) | Optional override for the GKE cluster name when it does not follow the default ${workspace}-cluster naming. | `string` | `null` | no |
| <a name="input_create_docker_pull_secret"></a> [create\_docker\_pull\_secret](#input\_create\_docker\_pull\_secret) | Create the registry pull secret in the paragon namespace. Set false when the customer pre-provisions the secret and sets global.imagePullSecrets in helm\_values. | `bool` | `true` | no |
| <a name="input_customer_facing"></a> [customer\_facing](#input\_customer\_facing) | Whether the connections are customer-facing (true limits access to dev-team-oncall/dev-team-managers/admin, false adds dev-team-engineering). | `bool` | `true` | no |
| <a name="input_docker_email"></a> [docker\_email](#input\_docker\_email) | Docker email to pull images. | `string` | `null` | no |
| <a name="input_docker_password"></a> [docker\_password](#input\_docker\_password) | Docker password to pull images. Null when using a pre-provisioned pull secret (create\_docker\_pull\_secret=false). | `string` | `null` | no |
| <a name="input_docker_pull_secret_name"></a> [docker\_pull\_secret\_name](#input\_docker\_pull\_secret\_name) | Kubernetes secret name for registry pull credentials. | `string` | `"docker-cfg"` | no |
| <a name="input_docker_registry_server"></a> [docker\_registry\_server](#input\_docker\_registry\_server) | Container registry server for image pull credentials (e.g. docker.io or artifactory.example.com). Must match the host portion of global.imageRegistry when using a private registry. | `string` | `"docker.io"` | no |
| <a name="input_docker_username"></a> [docker\_username](#input\_docker\_username) | Docker username to pull images. Null when using a pre-provisioned pull secret (create\_docker\_pull\_secret=false). | `string` | `null` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | The root domain used for the microservices. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Type of environment being deployed to. | `string` | `"enterprise"` | no |
| <a name="input_excluded_microservices"></a> [excluded\_microservices](#input\_excluded\_microservices) | The microservices that should be excluded from the deployment. | `list(string)` | `[]` | no |
| <a name="input_feature_flags"></a> [feature\_flags](#input\_feature\_flags) | Optional path to feature flags YAML file. | `string` | `null` | no |
| <a name="input_gcp_assume_role"></a> [gcp\_assume\_role](#input\_gcp\_assume\_role) | Whether to assume a role for the service account instead of using JSON credentials. | `bool` | `false` | no |
| <a name="input_gcp_client_email"></a> [gcp\_client\_email](#input\_gcp\_client\_email) | The client email for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_client_id"></a> [gcp\_client\_id](#input\_gcp\_client\_id) | The client id for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_client_x509_cert_url"></a> [gcp\_client\_x509\_cert\_url](#input\_gcp\_client\_x509\_cert\_url) | The client certificate url for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_credential_json"></a> [gcp\_credential\_json](#input\_gcp\_credential\_json) | Contents of the GCP credential JSON file. All other `gcp_` variables are ignored if this is provided. | `map(any)` | `{}` | no |
| <a name="input_gcp_credential_json_file"></a> [gcp\_credential\_json\_file](#input\_gcp\_credential\_json\_file) | The path to the GCP credential JSON file. All other `gcp_` variables are ignored if this is provided. | `string` | `null` | no |
| <a name="input_gcp_private_key"></a> [gcp\_private\_key](#input\_gcp\_private\_key) | The private key for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_private_key_id"></a> [gcp\_private\_key\_id](#input\_gcp\_private\_key\_id) | The id of the private key for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_project_id"></a> [gcp\_project\_id](#input\_gcp\_project\_id) | The id of the Google Cloud Project. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_health_checker_enabled"></a> [health\_checker\_enabled](#input\_health\_checker\_enabled) | Specifies that health checker is enabled. | `bool` | `false` | no |
| <a name="input_helm_yaml"></a> [helm\_yaml](#input\_helm\_yaml) | YAML string of helm values to use instead of `helm_yaml_path` | `string` | `null` | no |
| <a name="input_helm_yaml_path"></a> [helm\_yaml\_path](#input\_helm\_yaml\_path) | Path to helm values.yaml file. | `string` | `".secure/values.yaml"` | no |
| <a name="input_hoop_agent_id"></a> [hoop\_agent\_id](#input\_hoop\_agent\_id) | Hoop agent ID for connections. Only used if hoop\_enabled is true. | `string` | `null` | no |
| <a name="input_hoop_agent_name"></a> [hoop\_agent\_name](#input\_hoop\_agent\_name) | Override Hoop agent name in HOOP\_KEY when organization does not identify the client (e.g. when organization is a region code like 'us', set to a client-identifying value such as 'client-us'). | `string` | `null` | no |
| <a name="input_hoop_all_access_groups"></a> [hoop\_all\_access\_groups](#input\_hoop\_all\_access\_groups) | Additional access-control groups allowed when customer\_facing is false. | `list(string)` | <pre>[<br/>  "dev-team-engineering"<br/>]</pre> | no |
| <a name="input_hoop_api_key"></a> [hoop\_api\_key](#input\_hoop\_api\_key) | Hoop API key. Only used if hoop\_enabled is true. | `string` | `null` | no |
| <a name="input_hoop_api_url"></a> [hoop\_api\_url](#input\_hoop\_api\_url) | Hoop API URL. | `string` | `"https://hoop.ops.paragoninternal.com/api"` | no |
| <a name="input_hoop_custom_connections"></a> [hoop\_custom\_connections](#input\_hoop\_custom\_connections) | Custom Hoop connections defined via tfvars. Map of connection names to their configuration. | <pre>map(object({<br/>    type                  = string<br/>    subtype               = optional(string)<br/>    access_mode_runbooks  = optional(string, "enabled")<br/>    access_mode_exec      = optional(string, "enabled")<br/>    access_mode_connect   = optional(string, "disabled")<br/>    access_schema         = optional(string, "disabled")<br/>    command               = optional(list(string))<br/>    secrets               = map(string)<br/>    tags                  = optional(map(string), {})<br/>    guardrail_rules       = optional(list(string), [])<br/>    reviewers             = optional(list(string), [])<br/>    access_control_groups = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_hoop_enabled"></a> [hoop\_enabled](#input\_hoop\_enabled) | Whether to enable Hoop agent. hoop\_key, hoop\_api\_key, and hoop\_agent\_id must be set if this is true. | `bool` | `true` | no |
| <a name="input_hoop_grafana_connection"></a> [hoop\_grafana\_connection](#input\_hoop\_grafana\_connection) | Whether to create a Hoop TCP connection to Grafana (grafana.paragon:4500). | `bool` | `false` | no |
| <a name="input_hoop_k8s_connections"></a> [hoop\_k8s\_connections](#input\_hoop\_k8s\_connections) | Kubernetes Hoop connections defined via tfvars. Map of connection names to their configuration. If empty, a default k8s-admin connection will be created. | <pre>map(object({<br/>    type                  = optional(string, "custom")<br/>    subtype               = optional(string)<br/>    access_mode_runbooks  = optional(string, "enabled")<br/>    access_mode_exec      = optional(string, "enabled")<br/>    access_mode_connect   = optional(string, "enabled")<br/>    access_schema         = optional(string, "disabled")<br/>    command               = optional(list(string), ["bash"])<br/>    remote_url            = optional(string, "https://kubernetes.default.svc.cluster.local")<br/>    insecure              = optional(string, "true")<br/>    namespace             = optional(string, "paragon")<br/>    secrets               = optional(map(string), {})<br/>    tags                  = optional(map(string), {})<br/>    guardrail_rules       = optional(list(string), [])<br/>    reviewers             = optional(list(string), [])<br/>    access_control_groups = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_hoop_key"></a> [hoop\_key](#input\_hoop\_key) | Hoop agent key (token). Only used if hoop\_enabled is true. | `string` | `null` | no |
| <a name="input_hoop_postgres_guardrail_rules"></a> [hoop\_postgres\_guardrail\_rules](#input\_hoop\_postgres\_guardrail\_rules) | Guardrail rule IDs for PostgreSQL connections. | `list(string)` | <pre>[<br/>  "a85115f6-5ef3-4618-b70c-f7cccdc62c5a"<br/>]</pre> | no |
| <a name="input_hoop_redis_guardrail_rules"></a> [hoop\_redis\_guardrail\_rules](#input\_hoop\_redis\_guardrail\_rules) | Guardrail rule IDs for Redis connections. | `list(string)` | <pre>[<br/>  "182f59b2-5d5d-4ab8-978e-94472b3915fc"<br/>]</pre> | no |
| <a name="input_hoop_restricted_access_groups"></a> [hoop\_restricted\_access\_groups](#input\_hoop\_restricted\_access\_groups) | Base access-control groups allowed for all connections. | `list(string)` | <pre>[<br/>  "dev-team-oncall",<br/>  "dev-team-managers",<br/>  "admin"<br/>]</pre> | no |
| <a name="input_hoop_reviewers_access_groups"></a> [hoop\_reviewers\_access\_groups](#input\_hoop\_reviewers\_access\_groups) | Reviewer groups required for customer-facing app connections. | `list(string)` | <pre>[<br/>  "dev-team-managers",<br/>  "admin"<br/>]</pre> | no |
| <a name="input_hoop_slack_app_token"></a> [hoop\_slack\_app\_token](#input\_hoop\_slack\_app\_token) | Slack app token for the Hoop Slack plugin. | `string` | `null` | no |
| <a name="input_hoop_slack_bot_token"></a> [hoop\_slack\_bot\_token](#input\_hoop\_slack\_bot\_token) | Slack bot token for the Hoop Slack plugin. | `string` | `null` | no |
| <a name="input_hoop_slack_channel_ids"></a> [hoop\_slack\_channel\_ids](#input\_hoop\_slack\_channel\_ids) | Slack channel IDs to notify for connections that require reviews. | `list(string)` | `[]` | no |
| <a name="input_infra_json"></a> [infra\_json](#input\_infra\_json) | Deprecated legacy JSON string of `infra` workspace variables. | `string` | `null` | no |
| <a name="input_infra_json_path"></a> [infra\_json\_path](#input\_infra\_json\_path) | Deprecated legacy path to an `infra` workspace output JSON file. Prefer Secret Manager handoff secrets (PARA-21726). | `string` | `null` | no |
| <a name="input_ingress_scheme"></a> [ingress\_scheme](#input\_ingress\_scheme) | Whether the load balancer is 'external' (public) or 'internal' (private) | `string` | `"external"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | The version of Kubernetes to run in the cluster. | `string` | `"1.31"` | no |
| <a name="input_managed_sync_enabled"></a> [managed\_sync\_enabled](#input\_managed\_sync\_enabled) | Whether to enable managed sync (deploy managed-sync Helm chart and config). | `bool` | `false` | no |
| <a name="input_managed_sync_version"></a> [managed\_sync\_version](#input\_managed\_sync\_version) | The version of the Managed Sync Helm chart to install. | `string` | `"0.0.131"` | no |
| <a name="input_monitor_version"></a> [monitor\_version](#input\_monitor\_version) | The version of the Paragon monitors to install. | `string` | `null` | no |
| <a name="input_monitors_enabled"></a> [monitors\_enabled](#input\_monitors\_enabled) | Specifies that monitors are enabled. | `bool` | `false` | no |
| <a name="input_openobserve_email"></a> [openobserve\_email](#input\_openobserve\_email) | OpenObserve admin login email. | `string` | `null` | no |
| <a name="input_openobserve_password"></a> [openobserve\_password](#input\_openobserve\_password) | OpenObserve admin login password. | `string` | `null` | no |
| <a name="input_organization"></a> [organization](#input\_organization) | Name of organization to include in resource names. | `string` | n/a | yes |
| <a name="input_private_services"></a> [private\_services](#input\_private\_services) | Services that should not be publicly exposed (filtered from public\_microservices and public\_monitors). | `list(string)` | `[]` | no |
| <a name="input_region"></a> [region](#input\_region) | The region where to host Google Cloud Organization resources. | `string` | n/a | yes |
| <a name="input_region_zone"></a> [region\_zone](#input\_region\_zone) | The zone in the region where to host Google Cloud Organization resources. | `string` | n/a | yes |
| <a name="input_uptime_api_token"></a> [uptime\_api\_token](#input\_uptime\_api\_token) | Optional API Token for setting up BetterStack Uptime monitors. | `string` | `null` | no |
| <a name="input_uptime_company"></a> [uptime\_company](#input\_uptime\_company) | Optional pretty company name to include in BetterStack Uptime monitors. | `string` | `null` | no |
| <a name="input_waf_advanced_options"></a> [waf\_advanced\_options](#input\_waf\_advanced\_options) | Policy-wide Cloud Armor options.<br/><br/>- json\_parsing: "DISABLED" (default), "STANDARD" or "STANDARD\_WITH\_GRAPHQL". STANDARD lets preconfigured rule sets inspect JSON bodies field by field, which matters for the SQLi and XSS sets against Paragon's JSON APIs.<br/>- json\_content\_types: extra Content-Type values to parse as JSON. Requires json\_parsing = "STANDARD".<br/>- log\_level: "NORMAL" (default) or "VERBOSE". VERBOSE records the matched signature and request field, at higher log volume and cost.<br/>- user\_ip\_request\_headers: headers to resolve the real client IP from, for enforce\_on\_key = "USER\_IP"<br/>- adaptive\_protection\_enabled: machine-learned Layer 7 DDoS detection. Requires Cloud Armor Enterprise.<br/>- adaptive\_protection\_rule\_visibility: "STANDARD" (default) or "PREMIUM"<br/><br/>Example: `{ json_parsing = "STANDARD", log_level = "VERBOSE" }` | <pre>object({<br/>    json_parsing                        = optional(string, "DISABLED")<br/>    json_content_types                  = optional(list(string), [])<br/>    log_level                           = optional(string, "NORMAL")<br/>    user_ip_request_headers             = optional(list(string), [])<br/>    adaptive_protection_enabled         = optional(bool, false)<br/>    adaptive_protection_rule_visibility = optional(string, "STANDARD")<br/>  })</pre> | `{}` | no |
| <a name="input_waf_custom_rules"></a> [waf\_custom\_rules](#input\_waf\_custom\_rules) | Map of rules written in the Cloud Armor rules language (CEL), for anything the IP lists, path rate limits and preconfigured rule sets do not cover: geo blocking, header matching, per-rule rate limits.<br/><br/>Each key is the rule name inside the policy (unique). Each value configures one rule:<br/><br/>- expression (required): CEL, e.g. "origin.region\_code == 'CN'", "request.headers['user-agent'].contains('curl')", "request.path.startsWith('/admin') && !inIpRange(origin.ip, '203.0.113.0/24')"<br/>- action: "deny" (default), "allow", "throttle" or "rate\_based\_ban". The rate limiting actions require rate\_limit; allow and deny must omit it.<br/>- deny\_status: status returned by a deny action (403, 404 or 502)<br/>- priority: evaluation order. Auto-assigned in the 6000 band when omitted; set below 1000 to run ahead of every generated rule.<br/>- preview: evaluate and log without enforcing<br/>- description: free text, truncated to 63 characters. Defaults to the map key.<br/>- rate\_limit: threshold\_count plus optional interval\_sec (60), exceed\_status (429), enforce\_on\_key (IP), enforce\_on\_key\_name, ban\_duration\_sec, ban\_threshold\_count, ban\_threshold\_interval\_sec. Ban fields apply to rate\_based\_ban only.<br/><br/>Example, a geo block and a throttle on the login route:<br/><br/>`block-cn = { expression = "origin.region_code == 'CN'" }`<br/><br/>`throttle-login = { expression = "request.path.startsWith('/auth/login')", action = "throttle", rate_limit = { threshold_count = 100, interval_sec = 60 } }`<br/><br/>Reference: https://cloud.google.com/armor/docs/rules-language-reference | <pre>map(object({<br/>    expression  = string<br/>    action      = optional(string, "deny")<br/>    deny_status = optional(number, 403)<br/>    priority    = optional(number)<br/>    preview     = optional(bool, false)<br/>    description = optional(string)<br/>    rate_limit = optional(object({<br/>      threshold_count            = number<br/>      interval_sec               = optional(number, 60)<br/>      exceed_status              = optional(number, 429)<br/>      enforce_on_key             = optional(string, "IP")<br/>      enforce_on_key_name        = optional(string)<br/>      ban_duration_sec           = optional(number, 600)<br/>      ban_threshold_count        = optional(number)<br/>      ban_threshold_interval_sec = optional(number, 600)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_waf_enabled"></a> [waf\_enabled](#input\_waf\_enabled) | Enable Google Cloud Armor on the shared public Application Load Balancer. false by default — set true and configure waf\_preconfigured\_rules, rate limits, or IP lists in tfvars. Ignored when ingress\_scheme is 'internal'. Disabling detaches the policy before destroying it, but the GKE controller detaches asynchronously, so a destroy that fails with resourceInUseByAnotherResource just needs apply to be re-run. | `bool` | `false` | no |
| <a name="input_waf_ip_blacklist"></a> [waf\_ip\_blacklist](#input\_waf\_ip\_blacklist) | CIDRs that are always denied. Bare addresses are normalized to /32 or /128. Empty list = no denylist rule. Example: `["203.0.113.66", "192.0.2.0/24"]` | `list(string)` | `[]` | no |
| <a name="input_waf_ip_blacklist_deny_status"></a> [waf\_ip\_blacklist\_deny\_status](#input\_waf\_ip\_blacklist\_deny\_status) | HTTP status returned by the denylist rule. Cloud Armor only allows 403, 404, or 502 for deny actions. | `number` | `403` | no |
| <a name="input_waf_ip_whitelist"></a> [waf\_ip\_whitelist](#input\_waf\_ip\_whitelist) | CIDRs that bypass every other Cloud Armor rule (office IPs). Bare addresses are normalized to /32 or /128. Empty list = no allowlist rule. Example: `["203.0.113.10", "198.51.100.0/24"]` | `list(string)` | `[]` | no |
| <a name="input_waf_logs_sample_rate"></a> [waf\_logs\_sample\_rate](#input\_waf\_logs\_sample\_rate) | Fraction of requests logged to Cloud Logging on the protected backend services, between 0 and 1. Cloud Armor records the matched rule and action in those logs, so 1 keeps every enforcement decision visible. Only applies when WAF is active. | `number` | `1` | no |
| <a name="input_waf_preconfigured_rules"></a> [waf\_preconfigured\_rules](#input\_waf\_preconfigured\_rules) | Map of Google-managed (preconfigured) WAF rule sets to evaluate. Empty by default — you choose which sets to enable. Cloud Armor's equivalent of an AWS WAF managed rule group.<br/><br/>Each key is the rule name inside the policy (unique). Each value configures one set:<br/><br/>- rule\_set (required): e.g. sqli-v422-stable, xss-v422-stable, lfi-v422-stable, rfi-v422-stable, rce-v422-stable, protocolattack-v422-stable, scannerdetection-v422-stable, methodenforcement-v422-stable, php-v422-stable, sessionfixation-v422-stable, java-v422-stable, generic-v422-stable, cve-canary, json-sqli-canary. CRS 4.22 (-v422-) is current; -v33- and unsuffixed names are older.<br/>- sensitivity: OWASP paranoia level 0-4, default 1. Higher adds signatures and false positives. 0 evaluates nothing unless opt\_in\_rule\_ids is set.<br/>- deny\_status: status returned on a match (403, 404 or 502)<br/>- priority: evaluation order. Auto-assigned in the 5000 band when omitted.<br/>- preview: evaluate and log without blocking, the equivalent of AWS WAF "count"<br/>- opt\_in\_rule\_ids: signature IDs to enable even though sensitivity excludes them<br/>- opt\_out\_rule\_ids: signature IDs to disable, for known false positives. Must match the CRS version of rule\_set.<br/>- exclusions: request fields skipped during evaluation. Each entry optionally narrows to target\_rule\_ids and lists request\_headers / request\_cookies / request\_uris / request\_query\_params as { operator, value }, where operator is EQUALS, STARTS\_WITH, ENDS\_WITH, CONTAINS or EQUALS\_ANY and value is required for all but EQUALS\_ANY.<br/><br/>Example, rolling out SQLi in preview while XSS enforces with one signature disabled:<br/><br/>`sqli = { rule_set = "sqli-v422-stable", preview = true }`<br/><br/>`xss = { rule_set = "xss-v422-stable", sensitivity = 2, opt_out_rule_ids = ["owasp-crs-v042200-id941150-xss"] }`<br/><br/>Reference: https://cloud.google.com/armor/docs/waf-rules | <pre>map(object({<br/>    rule_set         = string<br/>    sensitivity      = optional(number, 1)<br/>    deny_status      = optional(number, 403)<br/>    priority         = optional(number)<br/>    preview          = optional(bool, false)<br/>    opt_in_rule_ids  = optional(list(string), [])<br/>    opt_out_rule_ids = optional(list(string), [])<br/>    exclusions = optional(list(object({<br/>      target_rule_ids = optional(list(string), [])<br/>      request_headers = optional(list(object({<br/>        operator = string<br/>        value    = optional(string)<br/>      })), [])<br/>      request_cookies = optional(list(object({<br/>        operator = string<br/>        value    = optional(string)<br/>      })), [])<br/>      request_uris = optional(list(object({<br/>        operator = string<br/>        value    = optional(string)<br/>      })), [])<br/>      request_query_params = optional(list(object({<br/>        operator = string<br/>        value    = optional(string)<br/>      })), [])<br/>    })), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_waf_rate_limit_global"></a> [waf\_rate\_limit\_global](#input\_waf\_rate\_limit\_global) | Requests per key allowed across all paths within the window. null or 0 = no global rate limit rule. Enforced per backend service and per region, so the aggregate limit scales with the number of protected backends. | `number` | `null` | no |
| <a name="input_waf_rate_limit_global_window_sec"></a> [waf\_rate\_limit\_global\_window\_sec](#input\_waf\_rate\_limit\_global\_window\_sec) | Evaluation window in seconds for the global rate limit. | `number` | `300` | no |
| <a name="input_waf_rate_limit_options"></a> [waf\_rate\_limit\_options](#input\_waf\_rate\_limit\_options) | Shared behaviour for the rules generated from waf\_rate\_limit\_global and waf\_rate\_limit\_paths. Per-rule rate limiting is available through waf\_custom\_rules.<br/><br/>- action: "throttle" caps traffic at the threshold; "rate\_based\_ban" blocks the key for ban\_duration\_sec. Cloud Armor rejects switching a rate\_based\_ban rule back to throttle in place.<br/>- exceed\_status: status returned above the threshold (403, 404, 429 or 502)<br/>- enforce\_on\_key: what counts as one client. Use XFF\_IP when a CDN or proxy such as Cloudflare fronts the load balancer.<br/>- enforce\_on\_key\_name: header or cookie name, required for HTTP\_HEADER/HTTP\_COOKIE<br/>- ban\_duration\_sec: how long a banned key stays banned. rate\_based\_ban only.<br/>- ban\_threshold\_count / ban\_threshold\_interval\_sec: optional second threshold that must also be breached before a ban. rate\_based\_ban only.<br/>- preview: evaluate and log without enforcing<br/><br/>Example: `{ action = "rate_based_ban", enforce_on_key = "XFF_IP", ban_duration_sec = 1800 }` | <pre>object({<br/>    action                     = optional(string, "throttle")<br/>    exceed_status              = optional(number, 429)<br/>    enforce_on_key             = optional(string, "IP")<br/>    enforce_on_key_name        = optional(string)<br/>    ban_duration_sec           = optional(number, 600)<br/>    ban_threshold_count        = optional(number)<br/>    ban_threshold_interval_sec = optional(number, 600)<br/>    preview                    = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_waf_rate_limit_path_window_sec"></a> [waf\_rate\_limit\_path\_window\_sec](#input\_waf\_rate\_limit\_path\_window\_sec) | Evaluation window in seconds for the path rate limits. | `number` | `300` | no |
| <a name="input_waf_rate_limit_paths"></a> [waf\_rate\_limit\_paths](#input\_waf\_rate\_limit\_paths) | Map of URL path prefix to requests per key per window, evaluated before the global limit. Paths without a leading / are normalized and match by prefix, so /actuator also covers /actuator/heapdump. Keys must be unique after that normalization — "actuator" and "/actuator" are the same prefix. Longer prefixes are evaluated first, so a stricter /api/foo limit takes precedence over a broader /api one. Empty = no path rate limit rules. Example: `{ "/actuator" = 20, "/api/v1/webhooks" = 600 }` | `map(number)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_grafana_admin_email"></a> [grafana\_admin\_email](#output\_grafana\_admin\_email) | Grafana admin login email. |
| <a name="output_grafana_admin_password"></a> [grafana\_admin\_password](#output\_grafana\_admin\_password) | Grafana admin login password. |
| <a name="output_load_balancer"></a> [load\_balancer](#output\_load\_balancer) | Location of the load balancer |
| <a name="output_pgadmin_admin_email"></a> [pgadmin\_admin\_email](#output\_pgadmin\_admin\_email) | PGAdmin admin login email. |
| <a name="output_pgadmin_admin_password"></a> [pgadmin\_admin\_password](#output\_pgadmin\_admin\_password) | PGAdmin admin login password. |
| <a name="output_uptime_webhook"></a> [uptime\_webhook](#output\_uptime\_webhook) | Uptime webhook URL |
| <a name="output_waf_rule_count"></a> [waf\_rule\_count](#output\_waf\_rule\_count) | Number of rules in the Cloud Armor policy when WAF is enabled, otherwise null. The default quota is 200 rules per policy. |
| <a name="output_waf_security_policy_name"></a> [waf\_security\_policy\_name](#output\_waf\_security\_policy\_name) | Name of the Cloud Armor security policy when WAF is enabled, otherwise null. |
<!-- END_TF_DOCS -->

## Updates

This Terraform documentation can be automatically regenerated with:

```
terraform-docs markdown table --output-file README.md --output-mode inject .
```
