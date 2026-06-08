<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 4.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.9 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | ~> 4.0 |
| <a name="provider_google"></a> [google](#provider\_google) | ~> 7.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.9 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_record.paragon_nameserver](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/record) | resource |
| [google_dns_managed_zone.paragon](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_project_iam_member.eso_secret_accessor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.external_dns_dns_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_secret_manager_secret.docker_cfg](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.env](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.managed_sync](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.openobserve](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_version.docker_cfg](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.env](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.managed_sync](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.openobserve](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_service_account.eso](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.external_dns](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.eso_workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_iam_binding.external_dns_workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.external_dns](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.external_secrets](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.app_of_apps](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.cluster_secret_store](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.destination_namespace](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.external_secrets](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_secret_v1.bootstrap_repo](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.gitops_bridge_cluster](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [random_password.openobserve_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.openobserve_email](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_sleep.eso_crds](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_app_chart_repository"></a> [app\_chart\_repository](#input\_app\_chart\_repository) | Helm chart repository URL for Paragon application charts (GitOps bridge annotation). | `string` | `""` | no |
| <a name="input_argocd_addon_overrides"></a> [argocd\_addon\_overrides](#input\_argocd\_addon\_overrides) | Optional overrides merged into the ArgoCD Helm values. | `map(any)` | `{}` | no |
| <a name="input_argocd_helm_chart_version"></a> [argocd\_helm\_chart\_version](#input\_argocd\_helm\_chart\_version) | Version of the argo-cd Helm chart. | `string` | `"9.5.15"` | no |
| <a name="input_argocd_namespace"></a> [argocd\_namespace](#input\_argocd\_namespace) | Namespace to install ArgoCD into. | `string` | `"argocd"` | no |
| <a name="input_argocd_release_name"></a> [argocd\_release\_name](#input\_argocd\_release\_name) | Argo CD Helm release name used for in-cluster secret discovery. | `string` | `"argo-cd"` | no |
| <a name="input_argocd_version"></a> [argocd\_version](#input\_argocd\_version) | Argo CD container image tag. | `string` | `"v3.4.2"` | no |
| <a name="input_auto_sync"></a> [auto\_sync](#input\_auto\_sync) | Whether to enable automatic sync on the bootstrap Application. | `bool` | `true` | no |
| <a name="input_bootstrap_repo_path"></a> [bootstrap\_repo\_path](#input\_bootstrap\_repo\_path) | Path inside bootstrap\_repo\_url containing child Application manifests. | `string` | `""` | no |
| <a name="input_bootstrap_repo_revision"></a> [bootstrap\_repo\_revision](#input\_bootstrap\_repo\_revision) | Git revision for App-of-Apps bootstrap. | `string` | `"HEAD"` | no |
| <a name="input_bootstrap_repo_token"></a> [bootstrap\_repo\_token](#input\_bootstrap\_repo\_token) | GitHub personal access token for cloning bootstrap\_repo\_url (HTTPS). | `string` | `null` | no |
| <a name="input_bootstrap_repo_url"></a> [bootstrap\_repo\_url](#input\_bootstrap\_repo\_url) | Git repository URL for App-of-Apps bootstrap. | `string` | `""` | no |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token for NS delegation. Empty string disables Cloudflare records. | `string` | `""` | no |
| <a name="input_cloudflare_zone_id"></a> [cloudflare\_zone\_id](#input\_cloudflare\_zone\_id) | Cloudflare zone ID for NS record delegation. | `string` | `""` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the GKE cluster. | `string` | n/a | yes |
| <a name="input_cluster_secret_store_name"></a> [cluster\_secret\_store\_name](#input\_cluster\_secret\_store\_name) | Name of the ClusterSecretStore for ExternalSecrets. | `string` | `"gcp-secret-manager"` | no |
| <a name="input_destination_namespace"></a> [destination\_namespace](#input\_destination\_namespace) | Target namespace for Paragon workloads. | `string` | `"paragon"` | no |
| <a name="input_docker_email"></a> [docker\_email](#input\_docker\_email) | Docker registry email (optional). | `string` | `null` | no |
| <a name="input_docker_password"></a> [docker\_password](#input\_docker\_password) | Docker registry password for image pulls. | `string` | `null` | no |
| <a name="input_docker_registry_server"></a> [docker\_registry\_server](#input\_docker\_registry\_server) | Docker registry server (default docker.io). | `string` | `"docker.io"` | no |
| <a name="input_docker_username"></a> [docker\_username](#input\_docker\_username) | Docker registry username for image pulls. | `string` | `null` | no |
| <a name="input_env_config"></a> [env\_config](#input\_env\_config) | Flat map of environment variables written to the env Secret Manager secret. | `map(string)` | `{}` | no |
| <a name="input_eso_chart_version"></a> [eso\_chart\_version](#input\_eso\_chart\_version) | Helm chart version for external-secrets operator. | `string` | `"0.14.4"` | no |
| <a name="input_gcp_project_id"></a> [gcp\_project\_id](#input\_gcp\_project\_id) | GCP project ID. | `string` | n/a | yes |
| <a name="input_gcp_region"></a> [gcp\_region](#input\_gcp\_region) | GCP region for the cluster. | `string` | n/a | yes |
| <a name="input_ingress_scheme"></a> [ingress\_scheme](#input\_ingress\_scheme) | GKE Gateway ingress scheme for Argo CD-managed ingress (GitOps bridge annotation). | `string` | `"external"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to GCP resources (must be lowercase key/value pairs). | `map(string)` | `{}` | no |
| <a name="input_managed_sync_config"></a> [managed\_sync\_config](#input\_managed\_sync\_config) | Optional managed-sync secret data (null when managed sync is disabled). | `map(string)` | `null` | no |
| <a name="input_managed_sync_enabled"></a> [managed\_sync\_enabled](#input\_managed\_sync\_enabled) | Whether managed sync is enabled (GitOps bridge annotation). | `bool` | `false` | no |
| <a name="input_paragon_chart_version"></a> [paragon\_chart\_version](#input\_paragon\_chart\_version) | Target chart version or constraint for Paragon charts (GitOps bridge annotation). | `string` | `null` | no |
| <a name="input_paragon_domain"></a> [paragon\_domain](#input\_paragon\_domain) | Customer-facing Paragon domain (GitOps bridge annotation paragon\_domain). | `string` | `""` | no |
| <a name="input_paragon_managed_sync_version"></a> [paragon\_managed\_sync\_version](#input\_paragon\_managed\_sync\_version) | Chart version for managed-sync (GitOps bridge annotation). | `string` | `null` | no |
| <a name="input_paragon_monitor_version"></a> [paragon\_monitor\_version](#input\_paragon\_monitor\_version) | Chart version for the monitoring stack (GitOps bridge annotation). | `string` | `null` | no |
| <a name="input_paragon_monitors_enabled"></a> [paragon\_monitors\_enabled](#input\_paragon\_monitors\_enabled) | Whether monitoring charts are deployed via Argo CD (GitOps bridge annotation). | `bool` | `false` | no |
| <a name="input_self_heal"></a> [self\_heal](#input\_self\_heal) | Whether to enable self-healing on the bootstrap Application. | `bool` | `true` | no |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | Workspace name used for resource naming. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_argocd_helm_release"></a> [argocd\_helm\_release](#output\_argocd\_helm\_release) | ArgoCD Helm release name. |
| <a name="output_argocd_namespace"></a> [argocd\_namespace](#output\_argocd\_namespace) | Namespace where ArgoCD is installed. |
| <a name="output_cluster_secret_store_name"></a> [cluster\_secret\_store\_name](#output\_cluster\_secret\_store\_name) | Name of the ClusterSecretStore. |
| <a name="output_eso_gsa_email"></a> [eso\_gsa\_email](#output\_eso\_gsa\_email) | GSA email for the External Secrets Operator. |
| <a name="output_gitops_bridge_secret_name"></a> [gitops\_bridge\_secret\_name](#output\_gitops\_bridge\_secret\_name) | Name of the GitOps bridge cluster secret. |
<!-- END_TF_DOCS -->