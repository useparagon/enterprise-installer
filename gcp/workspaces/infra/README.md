# Paragon GCP Infrastructure

NOTE: The following APIs must be enabled for the project in the [GCP Console](https://console.cloud.google.com/apis/library).

- Identity and Access Management (IAM) API
- Cloud Resource Manager API
- Cloud SQL Admin API
- Compute Engine API
- Google Cloud Memorystore for Redis API
- Service Networking API

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 4.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 7.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.9 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.35.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_argocd"></a> [argocd](#module\_argocd) | ./argocd | n/a |
| <a name="module_bastion"></a> [bastion](#module\_bastion) | ./bastion | n/a |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | ./cluster | n/a |
| <a name="module_kafka"></a> [kafka](#module\_kafka) | ./kafka | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./network | n/a |
| <a name="module_postgres"></a> [postgres](#module\_postgres) | ./postgres | n/a |
| <a name="module_redis"></a> [redis](#module\_redis) | ./redis | n/a |
| <a name="module_storage"></a> [storage](#module\_storage) | ./storage | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [google_gke_hub_membership.cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/gke_hub_membership) | resource |
| [google_secret_manager_secret.runtime_bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.runtime_kafka](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.runtime_postgres](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.runtime_redis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.runtime_redis_ca_cert](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.runtime_storage](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_version.runtime_bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.runtime_kafka](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.runtime_postgres](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.runtime_redis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.runtime_redis_ca_cert](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.runtime_storage](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [terraform_data.validate_argocd_versions](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [google_client_config.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_argocd_addon_overrides"></a> [argocd\_addon\_overrides](#input\_argocd\_addon\_overrides) | Optional overrides merged into the ArgoCD Helm values. | `map(any)` | `{}` | no |
| <a name="input_argocd_app_chart_repository"></a> [argocd\_app\_chart\_repository](#input\_argocd\_app\_chart\_repository) | Helm chart repository URL for Paragon application charts. | `string` | `"https://paragon-helm-production.s3.amazonaws.com"` | no |
| <a name="input_argocd_app_secrets"></a> [argocd\_app\_secrets](#input\_argocd\_app\_secrets) | Customer-provided secret env vars (LICENSE, OAuth, SMTP, etc.) merged last into the flat env secret. | `map(string)` | `null` | no |
| <a name="input_argocd_auto_sync"></a> [argocd\_auto\_sync](#input\_argocd\_auto\_sync) | Whether ArgoCD Applications should auto-sync on git/chart changes. | `bool` | `true` | no |
| <a name="input_argocd_bootstrap_repo_path"></a> [argocd\_bootstrap\_repo\_path](#input\_argocd\_bootstrap\_repo\_path) | Path inside argocd\_bootstrap\_repo\_url containing child Application manifests. | `string` | `""` | no |
| <a name="input_argocd_bootstrap_repo_private"></a> [argocd\_bootstrap\_repo\_private](#input\_argocd\_bootstrap\_repo\_private) | When true, argocd\_bootstrap\_repo\_token is required to clone the bootstrap repository. | `bool` | `false` | no |
| <a name="input_argocd_bootstrap_repo_revision"></a> [argocd\_bootstrap\_repo\_revision](#input\_argocd\_bootstrap\_repo\_revision) | Git revision (branch, tag, or commit) for App-of-Apps bootstrap. | `string` | `"HEAD"` | no |
| <a name="input_argocd_bootstrap_repo_token"></a> [argocd\_bootstrap\_repo\_token](#input\_argocd\_bootstrap\_repo\_token) | GitHub PAT for argocd\_bootstrap\_repo\_url (HTTPS). Set via Spacelift context / TF\_VAR\_* (never commit). | `string` | `null` | no |
| <a name="input_argocd_bootstrap_repo_url"></a> [argocd\_bootstrap\_repo\_url](#input\_argocd\_bootstrap\_repo\_url) | HTTPS Git repository URL for Argo CD App-of-Apps bootstrap. Leave empty to skip. | `string` | `""` | no |
| <a name="input_argocd_docker_email"></a> [argocd\_docker\_email](#input\_argocd\_docker\_email) | Docker email for ArgoCD image pulls. | `string` | `null` | no |
| <a name="input_argocd_docker_password"></a> [argocd\_docker\_password](#input\_argocd\_docker\_password) | Docker password for ArgoCD image pulls. | `string` | `null` | no |
| <a name="input_argocd_docker_registry_server"></a> [argocd\_docker\_registry\_server](#input\_argocd\_docker\_registry\_server) | Docker registry server for ArgoCD image pulls. | `string` | `"docker.io"` | no |
| <a name="input_argocd_docker_username"></a> [argocd\_docker\_username](#input\_argocd\_docker\_username) | Docker username for ArgoCD image pulls. | `string` | `null` | no |
| <a name="input_argocd_enabled"></a> [argocd\_enabled](#input\_argocd\_enabled) | Enable ArgoCD-based GitOps deployment. When true, bootstraps ArgoCD and ESO on the cluster, writes config to Secret Manager, and applies ArgoCD Application manifests. | `bool` | `false` | no |
| <a name="input_argocd_env_overrides"></a> [argocd\_env\_overrides](#input\_argocd\_env\_overrides) | Optional overrides for any infra-derived env key written to Secret Manager. Merged on top of computed defaults. | `map(string)` | `null` | no |
| <a name="input_argocd_helm_chart_version"></a> [argocd\_helm\_chart\_version](#input\_argocd\_helm\_chart\_version) | Version of the argo-cd Helm chart from https://argoproj.github.io/argo-helm. | `string` | `"9.5.15"` | no |
| <a name="input_argocd_ingress_scheme"></a> [argocd\_ingress\_scheme](#input\_argocd\_ingress\_scheme) | GKE Gateway ingress scheme: external or internal. | `string` | `"external"` | no |
| <a name="input_argocd_self_heal"></a> [argocd\_self\_heal](#input\_argocd\_self\_heal) | Whether ArgoCD should auto-correct drift from desired state. | `bool` | `true` | no |
| <a name="input_argocd_slack_channel"></a> [argocd\_slack\_channel](#input\_argocd\_slack\_channel) | Slack channel name for ArgoCD notifications. | `string` | `""` | no |
| <a name="input_argocd_slack_token"></a> [argocd\_slack\_token](#input\_argocd\_slack\_token) | Optional Slack bot token for ArgoCD sync notifications. | `string` | `null` | no |
| <a name="input_argocd_version"></a> [argocd\_version](#input\_argocd\_version) | Argo CD container image tag (e.g. v3.4.2). Applied via the official argo-cd Helm chart. | `string` | `"v3.4.2"` | no |
| <a name="input_auditlogs_lock_enabled"></a> [auditlogs\_lock\_enabled](#input\_auditlogs\_lock\_enabled) | Whether to lock the GCS audit logs bucket retention policy. | `bool` | `false` | no |
| <a name="input_auditlogs_retention_days"></a> [auditlogs\_retention\_days](#input\_auditlogs\_retention\_days) | The number of days to retain audit logs before deletion. | `number` | `365` | no |
| <a name="input_bastion_enabled"></a> [bastion\_enabled](#input\_bastion\_enabled) | Whether to create the bastion host and its associated Cloudflare tunnel. | `bool` | `true` | no |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Account `Cloudflare Tunnel`, `Access: Organizations, Identity Providers, and Groups`, `Access: Apps and Policies` and Zone `DNS` | `string` | `"dummy-cloudflare-tokens-must-be-40-chars"` | no |
| <a name="input_cloudflare_tunnel_account_id"></a> [cloudflare\_tunnel\_account\_id](#input\_cloudflare\_tunnel\_account\_id) | Account ID for Cloudflare account | `string` | `""` | no |
| <a name="input_cloudflare_tunnel_email_domain"></a> [cloudflare\_tunnel\_email\_domain](#input\_cloudflare\_tunnel\_email\_domain) | Email domain for Cloudflare access | `string` | `"useparagon.com"` | no |
| <a name="input_cloudflare_tunnel_enabled"></a> [cloudflare\_tunnel\_enabled](#input\_cloudflare\_tunnel\_enabled) | Flag whether to enable Cloudflare Zero Trust tunnel for bastion | `bool` | `false` | no |
| <a name="input_cloudflare_tunnel_subdomain"></a> [cloudflare\_tunnel\_subdomain](#input\_cloudflare\_tunnel\_subdomain) | Subdomain under the Cloudflare Zone to create the tunnel | `string` | `""` | no |
| <a name="input_cloudflare_tunnel_zone_id"></a> [cloudflare\_tunnel\_zone\_id](#input\_cloudflare\_tunnel\_zone\_id) | Zone ID for Cloudflare domain | `string` | `""` | no |
| <a name="input_disable_deletion_protection"></a> [disable\_deletion\_protection](#input\_disable\_deletion\_protection) | Used to disable deletion protection on database and storage resources. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Type of environment being deployed to. | `string` | `"enterprise"` | no |
| <a name="input_eso_chart_version"></a> [eso\_chart\_version](#input\_eso\_chart\_version) | Helm chart version for external-secrets operator. | `string` | `"0.14.4"` | no |
| <a name="input_gcp_assume_role"></a> [gcp\_assume\_role](#input\_gcp\_assume\_role) | Whether to assume a role for the service account instead of using JSON credentials. | `bool` | `false` | no |
| <a name="input_gcp_client_email"></a> [gcp\_client\_email](#input\_gcp\_client\_email) | The client email for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_client_id"></a> [gcp\_client\_id](#input\_gcp\_client\_id) | The client id for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_client_x509_cert_url"></a> [gcp\_client\_x509\_cert\_url](#input\_gcp\_client\_x509\_cert\_url) | The client certificate url for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_credential_json_file"></a> [gcp\_credential\_json\_file](#input\_gcp\_credential\_json\_file) | The path to the GCP credential JSON file. All other `gcp_` variables are ignored if this is provided. | `string` | `null` | no |
| <a name="input_gcp_private_key"></a> [gcp\_private\_key](#input\_gcp\_private\_key) | The private key for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_private_key_id"></a> [gcp\_private\_key\_id](#input\_gcp\_private\_key\_id) | The id of the private key for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_project_id"></a> [gcp\_project\_id](#input\_gcp\_project\_id) | The id of the Google Cloud Project. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gmk_auto_rebalance"></a> [gmk\_auto\_rebalance](#input\_gmk\_auto\_rebalance) | Whether to enable automatic partition rebalancing across brokers (can add load). | `bool` | `false` | no |
| <a name="input_gmk_disk_size_gib"></a> [gmk\_disk\_size\_gib](#input\_gmk\_disk\_size\_gib) | Disk size in GiB per broker for the GMK cluster. | `number` | `100` | no |
| <a name="input_gmk_kafka_version"></a> [gmk\_kafka\_version](#input\_gmk\_kafka\_version) | Kafka version for the Google Managed Kafka cluster (version offered by the service). | `string` | `"3.7.1"` | no |
| <a name="input_gmk_memory_gib"></a> [gmk\_memory\_gib](#input\_gmk\_memory\_gib) | Memory in GiB for the GMK cluster (1-8 GiB per vCPU). | `number` | `6` | no |
| <a name="input_gmk_sasl_mechanism"></a> [gmk\_sasl\_mechanism](#input\_gmk\_sasl\_mechanism) | SASL mechanism: plain (module creates SA key and outputs in kafka.cluster\_password) or oauthbearer (Workload Identity). | `string` | `"plain"` | no |
| <a name="input_gmk_sasl_plain_key_file_path"></a> [gmk\_sasl\_plain\_key\_file\_path](#input\_gmk\_sasl\_plain\_key\_file\_path) | Optional path to your own Kafka SA key JSON for SASL/PLAIN. When empty, the module creates the key and outputs it in kafka.cluster\_password. | `string` | `""` | no |
| <a name="input_gmk_vcpu_count"></a> [gmk\_vcpu\_count](#input\_gmk\_vcpu\_count) | Number of vCPUs for the GMK cluster (minimum 3 in GCP). | `number` | `3` | no |
| <a name="input_k8s_disable_public_endpoint"></a> [k8s\_disable\_public\_endpoint](#input\_k8s\_disable\_public\_endpoint) | Used to disable public endpoint on GKE cluster. | `bool` | `true` | no |
| <a name="input_k8s_master_authorized_networks"></a> [k8s\_master\_authorized\_networks](#input\_k8s\_master\_authorized\_networks) | List of CIDRs allowed to reach the GKE control plane (Master Authorized Networks). Use [{ cidr\_block = "0.0.0.0/0", display\_name = "all" }] to allow all IPs (e.g. from any country). Empty list = only cluster nodes (restricted). | <pre>list(object({<br/>    cidr_block   = string<br/>    display_name = optional(string, "")<br/>  }))</pre> | `[]` | no |
| <a name="input_k8s_max_node_count"></a> [k8s\_max\_node\_count](#input\_k8s\_max\_node\_count) | Maximum number of node Kubernetes can scale up to. | `number` | `50` | no |
| <a name="input_k8s_min_node_count"></a> [k8s\_min\_node\_count](#input\_k8s\_min\_node\_count) | Minimum number of node Kubernetes can scale down to. | `number` | `2` | no |
| <a name="input_k8s_ondemand_node_instance_type"></a> [k8s\_ondemand\_node\_instance\_type](#input\_k8s\_ondemand\_node\_instance\_type) | The compute instance type to use for Kubernetes on demand nodes. | `string` | `"e2-standard-4"` | no |
| <a name="input_k8s_spot_instance_percent"></a> [k8s\_spot\_instance\_percent](#input\_k8s\_spot\_instance\_percent) | The percentage of spot instances to use for Kubernetes nodes. | `number` | `80` | no |
| <a name="input_k8s_spot_node_instance_type"></a> [k8s\_spot\_node\_instance\_type](#input\_k8s\_spot\_node\_instance\_type) | The compute instance type to use for Kubernetes spot nodes. | `string` | `"e2-standard-4"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | The version of Kubernetes to run in the cluster. | `string` | `"1.34"` | no |
| <a name="input_managed_sync_enabled"></a> [managed\_sync\_enabled](#input\_managed\_sync\_enabled) | Whether to enable managed sync (GMK cluster, managed\_sync bucket, postgres and redis instances). | `bool` | `false` | no |
| <a name="input_organization"></a> [organization](#input\_organization) | Name of organization to include in resource names. | `string` | n/a | yes |
| <a name="input_paragon_domain"></a> [paragon\_domain](#input\_paragon\_domain) | Customer-facing Paragon domain (e.g. customer.example.com). Written to Secret Manager as PARAGON\_DOMAIN and derived *\_PUBLIC\_URL values when argocd\_enabled. | `string` | `null` | no |
| <a name="input_paragon_managed_sync_config"></a> [paragon\_managed\_sync\_config](#input\_paragon\_managed\_sync\_config) | Optional managed-sync secret data to write to Secret Manager. Null when managed sync is disabled. | `map(string)` | `null` | no |
| <a name="input_paragon_managed_sync_version"></a> [paragon\_managed\_sync\_version](#input\_paragon\_managed\_sync\_version) | Chart version for managed-sync when deployed via ArgoCD. Required when argocd\_enabled and managed\_sync\_enabled are both true. | `string` | `null` | no |
| <a name="input_paragon_monitors_enabled"></a> [paragon\_monitors\_enabled](#input\_paragon\_monitors\_enabled) | Whether monitoring charts should be deployed via ArgoCD. | `bool` | `false` | no |
| <a name="input_postgres_multiple_instances"></a> [postgres\_multiple\_instances](#input\_postgres\_multiple\_instances) | Whether or not to create multiple Postgres instances. Used for higher volume installations. | `bool` | `true` | no |
| <a name="input_postgres_tier"></a> [postgres\_tier](#input\_postgres\_tier) | The instance type to use for Postgres. | `string` | `"db-custom-2-7680"` | no |
| <a name="input_redis_memory_size"></a> [redis\_memory\_size](#input\_redis\_memory\_size) | The size of the Redis instance (in GB). | `number` | `2` | no |
| <a name="input_redis_multiple_instances"></a> [redis\_multiple\_instances](#input\_redis\_multiple\_instances) | Whether or not to create multiple Redis instances. | `bool` | `true` | no |
| <a name="input_region"></a> [region](#input\_region) | The region where to host Google Cloud Organization resources. | `string` | n/a | yes |
| <a name="input_region_zone"></a> [region\_zone](#input\_region\_zone) | The zone in the region where to host Google Cloud Organization resources. | `string` | n/a | yes |
| <a name="input_region_zone_backup"></a> [region\_zone\_backup](#input\_region\_zone\_backup) | The backup zone in the region where to host Google Cloud Organization resources. | `string` | n/a | yes |
| <a name="input_ssh_whitelist"></a> [ssh\_whitelist](#input\_ssh\_whitelist) | An optional list of IP addresses to whitelist ssh access. | `string` | `""` | no |
| <a name="input_tfc_agent_token"></a> [tfc\_agent\_token](#input\_tfc\_agent\_token) | Terraform Cloud Agent token to support Terraform runs from the bastion | `string` | `""` | no |
| <a name="input_use_storage_account_key"></a> [use\_storage\_account\_key](#input\_use\_storage\_account\_key) | Whether to use the storage service account privatekey for the storage service account. | `bool` | `false` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR for the virtual network. A `/16` (65,536 IPs) or larger is recommended. | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_argocd_namespace"></a> [argocd\_namespace](#output\_argocd\_namespace) | Namespace where ArgoCD is installed. |
| <a name="output_auditlogs_bucket"></a> [auditlogs\_bucket](#output\_auditlogs\_bucket) | The bucket used to store audit logs. |
| <a name="output_bastion"></a> [bastion](#output\_bastion) | Bastion server connection info. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the GKE cluster. |
| <a name="output_cluster_secret_store_name"></a> [cluster\_secret\_store\_name](#output\_cluster\_secret\_store\_name) | Name of the GCP Secret Manager ClusterSecretStore. |
| <a name="output_eso_gsa_email"></a> [eso\_gsa\_email](#output\_eso\_gsa\_email) | GSA email for the External Secrets Operator. |
| <a name="output_kafka"></a> [kafka](#output\_kafka) | Connection info for Kafka (Managed Sync). OAUTHBEARER or PLAIN; when PLAIN, use cluster\_password\_file\_path for key JSON. |
| <a name="output_logs_bucket"></a> [logs\_bucket](#output\_logs\_bucket) | Alias for logs\_container; used by paragon for managed-sync ingress.logsBucket. |
| <a name="output_logs_container"></a> [logs\_container](#output\_logs\_container) | The bucket used to store system logs. |
| <a name="output_postgres"></a> [postgres](#output\_postgres) | Connection info for Postgres. |
| <a name="output_redis"></a> [redis](#output\_redis) | Connection information for Redis. |
| <a name="output_storage"></a> [storage](#output\_storage) | Object storage connection info. |
| <a name="output_workspace"></a> [workspace](#output\_workspace) | The resource group that all resources are associated with. |
<!-- END_TF_DOCS -->

## Updates

This Terraform documentation can be automatically regenerated with:

```
terraform-docs markdown table --output-file README.md --output-mode inject .
```
