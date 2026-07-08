# Paragon AWS Infrastructure

See [setup-policy.json](../../setup-policy.json) for permissions that are required to execute this. Note that `<AWS_ACCOUNT_ID>` must be replaced to match target account.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.70 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 4.42 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_bastion"></a> [bastion](#module\_bastion) | ./bastion | n/a |
| <a name="module_cloudtrail"></a> [cloudtrail](#module\_cloudtrail) | ./cloudtrail | n/a |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | ./cluster | n/a |
| <a name="module_kafka"></a> [kafka](#module\_kafka) | ./kafka | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./network | n/a |
| <a name="module_postgres"></a> [postgres](#module\_postgres) | ./postgres | n/a |
| <a name="module_redis"></a> [redis](#module\_redis) | ./redis | n/a |
| <a name="module_storage"></a> [storage](#module\_storage) | ./storage | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_app_bucket_expiration"></a> [app\_bucket\_expiration](#input\_app\_bucket\_expiration) | The number of days to retain S3 app data before deleting | `number` | `90` | no |
| <a name="input_auditlogs_lock_enabled"></a> [auditlogs\_lock\_enabled](#input\_auditlogs\_lock\_enabled) | Whether to enable S3 Object Lock for the audit logs bucket. | `bool` | `false` | no |
| <a name="input_auditlogs_retention_days"></a> [auditlogs\_retention\_days](#input\_auditlogs\_retention\_days) | The number of days to retain audit logs before deletion. | `number` | `365` | no |
| <a name="input_aws_access_key_id"></a> [aws\_access\_key\_id](#input\_aws\_access\_key\_id) | AWS Access Key for AWS account to provision resources on. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The AWS region resources are created in. | `string` | n/a | yes |
| <a name="input_aws_secret_access_key"></a> [aws\_secret\_access\_key](#input\_aws\_secret\_access\_key) | AWS Secret Access Key for AWS account to provision resources on. | `string` | n/a | yes |
| <a name="input_aws_session_token"></a> [aws\_session\_token](#input\_aws\_session\_token) | AWS session token. | `string` | `null` | no |
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of AZs to cover in a given region. | `number` | `2` | no |
| <a name="input_bastion_enabled"></a> [bastion\_enabled](#input\_bastion\_enabled) | Whether to create the bastion host and its associated Cloudflare tunnel. | `bool` | `true` | no |
| <a name="input_cdn_bucket_acl_reset"></a> [cdn\_bucket\_acl\_reset](#input\_cdn\_bucket\_acl\_reset) | Reset the CDN S3 bucket ACL to private before BucketOwnerEnforced. Defaults to false; set true once when migrating a legacy CDN bucket with existing ACL grants, then remove. | `bool` | `false` | no |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Account `Cloudflare Tunnel`, `Access: Organizations, Identity Providers, and Groups`, `Access: Apps and Policies` and Zone `DNS` | `string` | `"dummy-cloudflare-tokens-must-be-40-chars"` | no |
| <a name="input_cloudflare_tunnel_account_id"></a> [cloudflare\_tunnel\_account\_id](#input\_cloudflare\_tunnel\_account\_id) | Account ID for Cloudflare account | `string` | `""` | no |
| <a name="input_cloudflare_tunnel_email_domain"></a> [cloudflare\_tunnel\_email\_domain](#input\_cloudflare\_tunnel\_email\_domain) | Email domain for Cloudflare access | `string` | `"useparagon.com"` | no |
| <a name="input_cloudflare_tunnel_enabled"></a> [cloudflare\_tunnel\_enabled](#input\_cloudflare\_tunnel\_enabled) | Flag whether to enable Cloudflare Zero Trust tunnel for bastion | `bool` | `false` | no |
| <a name="input_cloudflare_tunnel_subdomain"></a> [cloudflare\_tunnel\_subdomain](#input\_cloudflare\_tunnel\_subdomain) | Subdomain under the Cloudflare Zone to create the tunnel | `string` | `""` | no |
| <a name="input_cloudflare_tunnel_zone_id"></a> [cloudflare\_tunnel\_zone\_id](#input\_cloudflare\_tunnel\_zone\_id) | Zone ID for Cloudflare domain | `string` | `""` | no |
| <a name="input_create_autoscaling_linked_role"></a> [create\_autoscaling\_linked\_role](#input\_create\_autoscaling\_linked\_role) | Whether or not to create an IAM role for autoscaling. | `bool` | `true` | no |
| <a name="input_disable_cloudtrail"></a> [disable\_cloudtrail](#input\_disable\_cloudtrail) | Used to specify that Cloudtrail is disabled. | `bool` | `true` | no |
| <a name="input_disable_deletion_protection"></a> [disable\_deletion\_protection](#input\_disable\_deletion\_protection) | Used to disable deletion protection on RDS and S3 resources. | `bool` | `false` | no |
| <a name="input_eks_admin_arns"></a> [eks\_admin\_arns](#input\_eks\_admin\_arns) | Array of ARNs for IAM users or roles that should have admin access to cluster. Used for viewing cluster resources in AWS dashboard. | `list(string)` | `[]` | no |
| <a name="input_eks_max_node_count"></a> [eks\_max\_node\_count](#input\_eks\_max\_node\_count) | The maximum number of nodes to run in the Kubernetes cluster. | `number` | `50` | no |
| <a name="input_eks_min_node_count"></a> [eks\_min\_node\_count](#input\_eks\_min\_node\_count) | The minimum number of nodes to run in the Kubernetes cluster. | `number` | `4` | no |
| <a name="input_eks_ondemand_node_instance_type"></a> [eks\_ondemand\_node\_instance\_type](#input\_eks\_ondemand\_node\_instance\_type) | The compute instance type to use for Kubernetes nodes. | `string` | `"m6a.xlarge"` | no |
| <a name="input_eks_spot_instance_percent"></a> [eks\_spot\_instance\_percent](#input\_eks\_spot\_instance\_percent) | The percentage of spot instances to use for Kubernetes nodes. | `number` | `75` | no |
| <a name="input_eks_spot_node_instance_type"></a> [eks\_spot\_node\_instance\_type](#input\_eks\_spot\_node\_instance\_type) | The compute instance type to use for Kubernetes spot nodes. | `string` | `"t3a.xlarge,t3.xlarge,m5a.xlarge,m5.xlarge,m6a.xlarge,m6i.xlarge,m7a.xlarge,m7i.xlarge,r5a.xlarge,m4.xlarge"` | no |
| <a name="input_eks_system_managed_node_group"></a> [eks\_system\_managed\_node\_group](#input\_eks\_system\_managed\_node\_group) | System EKS managed node group for Karpenter controller and cluster add-on DaemonSets. Default node group and EC2 Name: <workspace>-node-default (e.g. paragon-admin-a1b2c3d4-node-default). | <pre>object({<br/>    map_key         = optional(string, "node-default")<br/>    name            = optional(string)<br/>    use_name_prefix = optional(bool, false)<br/>    ec2_name_tag    = optional(string)<br/>    instance_types  = optional(list(string))<br/>    min_size        = optional(number, 2)<br/>    max_size        = optional(number, 3)<br/>    desired_size    = optional(number, 2)<br/>    labels          = optional(map(string), { "karpenter.sh/controller" = "true" })<br/>  })</pre> | `{}` | no |
| <a name="input_elasticache_multi_az"></a> [elasticache\_multi\_az](#input\_elasticache\_multi\_az) | Whether or not to enable multi-AZ in each ElastiCache instance. | `bool` | `true` | no |
| <a name="input_elasticache_multiple_instances"></a> [elasticache\_multiple\_instances](#input\_elasticache\_multiple\_instances) | Whether or not to create multiple ElastiCache instances. Used for higher volume installations. | `bool` | `true` | no |
| <a name="input_elasticache_node_type"></a> [elasticache\_node\_type](#input\_elasticache\_node\_type) | The ElastiCache node type used for Redis. | `string` | `"cache.r6g.large"` | no |
| <a name="input_enable_karpenter"></a> [enable\_karpenter](#input\_enable\_karpenter) | Enable Karpenter autoscaling (SQS, IAM, Helm controller, EC2NodeClass, NodePools). | `bool` | `false` | no |
| <a name="input_enable_legacy_mng_pools"></a> [enable\_legacy\_mng\_pools](#input\_enable\_legacy\_mng\_pools) | Keep legacy on-demand and spot EKS managed node groups during Karpenter migration. | `bool` | `true` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | The version of Kubernetes to run in the cluster. | `string` | `"1.34"` | no |
| <a name="input_karpenter_chart_version"></a> [karpenter\_chart\_version](#input\_karpenter\_chart\_version) | Karpenter Helm chart version (OCI public.ecr.aws/karpenter/karpenter). | `string` | `"1.13.0"` | no |
| <a name="input_karpenter_iam_names"></a> [karpenter\_iam\_names](#input\_karpenter\_iam\_names) | Optional override for Karpenter IAM role names. | <pre>object({<br/>    controller_role_name = optional(string)<br/>    node_role_name       = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_managed_sync_enabled"></a> [managed\_sync\_enabled](#input\_managed\_sync\_enabled) | Whether to enable managed sync. | `bool` | `false` | no |
| <a name="input_master_guardduty_account_id"></a> [master\_guardduty\_account\_id](#input\_master\_guardduty\_account\_id) | Optional AWS account id to delegate GuardDuty control to. | `string` | `null` | no |
| <a name="input_mfa_enabled"></a> [mfa\_enabled](#input\_mfa\_enabled) | Whether to require MFA for certain configurations (e.g. cloudtrail s3 bucket deletion) | `bool` | `false` | no |
| <a name="input_migrated_passwords"></a> [migrated\_passwords](#input\_migrated\_passwords) | Override credentials to preserve complexity conventions when migrating from legacy workspaces | `map(string)` | `{}` | no |
| <a name="input_migrated_workspace"></a> [migrated\_workspace](#input\_migrated\_workspace) | Override the workspace name to preserve naming conventions when migrating from legacy workspaces | `string` | `null` | no |
| <a name="input_msk_autoscaling_enabled"></a> [msk\_autoscaling\_enabled](#input\_msk\_autoscaling\_enabled) | Whether to enable autoscaling for the MSK cluster. | `bool` | `true` | no |
| <a name="input_msk_instance_type"></a> [msk\_instance\_type](#input\_msk\_instance\_type) | The instance type for the MSK cluster. | `string` | `"kafka.t3.small"` | no |
| <a name="input_msk_kafka_num_broker_nodes"></a> [msk\_kafka\_num\_broker\_nodes](#input\_msk\_kafka\_num\_broker\_nodes) | The number of broker nodes for the MSK cluster. | `number` | `2` | no |
| <a name="input_msk_kafka_version"></a> [msk\_kafka\_version](#input\_msk\_kafka\_version) | The Kafka version for the MSK cluster. | `string` | `"3.9.x"` | no |
| <a name="input_organization"></a> [organization](#input\_organization) | Name of organization to include in resource names. | `string` | n/a | yes |
| <a name="input_rds_allocated_storage"></a> [rds\_allocated\_storage](#input\_rds\_allocated\_storage) | Initial allocated storage (GiB) for each Postgres RDS instance. | `number` | `20` | no |
| <a name="input_rds_final_snapshot_enabled"></a> [rds\_final\_snapshot\_enabled](#input\_rds\_final\_snapshot\_enabled) | Specifies that RDS instances should perform a final snapshot before being deleted. | `bool` | `true` | no |
| <a name="input_rds_gp3_iops"></a> [rds\_gp3\_iops](#input\_rds\_gp3\_iops) | gp3 IOPS for Postgres; null uses size-based baseline (3000 below 400 GiB, 12000 at/above). Set with rds\_gp3\_storage\_throughput to override; only valid when rds\_allocated\_storage >= 400 GiB. | `number` | `null` | no |
| <a name="input_rds_gp3_storage_throughput"></a> [rds\_gp3\_storage\_throughput](#input\_rds\_gp3\_storage\_throughput) | gp3 throughput (MiB/s); null uses size-based baseline (125 below 400 GiB, 500 at/above). Use a valid pair with rds\_gp3\_iops when overriding. | `number` | `null` | no |
| <a name="input_rds_instance_class"></a> [rds\_instance\_class](#input\_rds\_instance\_class) | The RDS instance class type used for Postgres. | `string` | `"db.t4g.small"` | no |
| <a name="input_rds_max_allocated_storage"></a> [rds\_max\_allocated\_storage](#input\_rds\_max\_allocated\_storage) | Maximum storage (GiB) for autoscaling on each Postgres RDS instance. | `number` | `1000` | no |
| <a name="input_rds_multi_az"></a> [rds\_multi\_az](#input\_rds\_multi\_az) | Whether or not to enable multi-AZ in each RDS instance. | `bool` | `true` | no |
| <a name="input_rds_multiple_instances"></a> [rds\_multiple\_instances](#input\_rds\_multiple\_instances) | Whether or not to create multiple Postgres instances. Used for higher volume installations. | `bool` | `true` | no |
| <a name="input_rds_postgres_version"></a> [rds\_postgres\_version](#input\_rds\_postgres\_version) | Postgres version for the database. | `string` | `"14"` | no |
| <a name="input_rds_restore_from_snapshot"></a> [rds\_restore\_from\_snapshot](#input\_rds\_restore\_from\_snapshot) | Specifies that RDS instances should be restored from a snapshot. | `bool` | `false` | no |
| <a name="input_s3_kms_encryption_enabled"></a> [s3\_kms\_encryption\_enabled](#input\_s3\_kms\_encryption\_enabled) | Encrypt the app, CDN, audit logs, and managed sync S3 buckets with AWS KMS (SSE-KMS) instead of S3-managed keys (SSE-S3). Existing deployments default to SSE-S3; enable for new installs or to migrate existing buckets to KMS. The logs bucket always uses SSE-S3 because ALB and S3 server access logs do not support SSE-KMS. | `bool` | `false` | no |
| <a name="input_s3_kms_key_arn"></a> [s3\_kms\_key\_arn](#input\_s3\_kms\_key\_arn) | ARN of an existing KMS key to use for S3 bucket encryption. When null and s3\_kms\_encryption\_enabled is true, a dedicated KMS key is created and managed by Terraform. Ignored when s3\_kms\_encryption\_enabled is false. | `string` | `null` | no |
| <a name="input_ssh_whitelist"></a> [ssh\_whitelist](#input\_ssh\_whitelist) | An optional list of IP addresses to whitelist ssh access. | `string` | `""` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR for the VPC. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_cidr_newbits"></a> [vpc\_cidr\_newbits](#input\_vpc\_cidr\_newbits) | Newbits used for calculating subnets. | `number` | `3` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_auditlogs_bucket"></a> [auditlogs\_bucket](#output\_auditlogs\_bucket) | The bucket used to store audit logs. |
| <a name="output_bastion"></a> [bastion](#output\_bastion) | Bastion server connection info. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster. |
| <a name="output_enable_karpenter"></a> [enable\_karpenter](#output\_enable\_karpenter) | Whether Karpenter autoscaling is enabled. Consumed by paragon workspace for EC2NodeClass and NodePool manifests. |
| <a name="output_enable_legacy_mng_pools"></a> [enable\_legacy\_mng\_pools](#output\_enable\_legacy\_mng\_pools) | Whether legacy on-demand and spot managed node groups are active. Consumed by paragon workspace for conditional AWS Node Termination Handler (NTH) deployment on legacy managed node groups. |
| <a name="output_k8s_version"></a> [k8s\_version](#output\_k8s\_version) | EKS control plane version. Consumed by paragon workspace for Karpenter drift tagging. |
| <a name="output_kafka"></a> [kafka](#output\_kafka) | Connection info for Kafka. |
| <a name="output_karpenter"></a> [karpenter](#output\_karpenter) | AWS resources created by infra for Karpenter worker nodes. Consumed by paragon workspace. |
| <a name="output_logs_bucket"></a> [logs\_bucket](#output\_logs\_bucket) | The bucket used to store system logs. |
| <a name="output_postgres"></a> [postgres](#output\_postgres) | Connection info for Postgres. |
| <a name="output_redis"></a> [redis](#output\_redis) | Connection information for Redis. |
| <a name="output_storage"></a> [storage](#output\_storage) | Object storage connection info. |
| <a name="output_workspace"></a> [workspace](#output\_workspace) | The resource group that all resources are associated with. |
<!-- END_TF_DOCS -->

## CDN bucket migration

The CDN S3 bucket (`<workspace>-cdn`) uses `BucketOwnerEnforced` object ownership. AWS rejects `PutBucketOwnershipControls` while the bucket ACL still grants other principals (for example legacy `public-read` or CloudFront OAI grants).

`cdn_bucket_acl_reset` defaults to `false`. Set it to `true` once when applying ownership controls to an existing CDN bucket with legacy ACLs, then remove it from tfvars after a successful apply.

```hcl
cdn_bucket_acl_reset = true
```

After `BucketOwnerEnforced` is active, ACL updates are ignored via `lifecycle.ignore_changes` to avoid S3 API errors on subsequent applies.

## S3 bucket encryption (SSE-S3 vs SSE-KMS)

By default the S3 buckets use server-side encryption with S3-managed keys (SSE-S3 / `AES256`). This preserves the behavior of existing deployments.

To meet compliance requirements that mandate AWS KMS, set `s3_kms_encryption_enabled = true`. This switches the app, CDN, audit logs, and managed sync buckets to SSE-KMS (with S3 Bucket Keys enabled to limit KMS request costs):

```hcl
s3_kms_encryption_enabled = true
```

When enabled, Terraform creates a dedicated customer-managed KMS key (alias `s3/<workspace>`) with rotation enabled, grants the application's S3 IAM user permission to use it, and adds the configured `eks_admin_arns` plus the Terraform caller as key administrators.

To use a pre-existing KMS key instead of creating one, also set `s3_kms_key_arn`. The key policy must allow the application's S3 IAM user to `Decrypt`/`GenerateDataKey`, or enable IAM-based access so the attached IAM policy grant applies:

```hcl
s3_kms_encryption_enabled = true
s3_kms_key_arn            = "arn:aws:kms:us-east-1:123456789012:key/abcd-..."
```

Notes:

- Toggling this on an existing deployment changes the bucket default encryption in place. New objects are encrypted with KMS; previously written objects keep their existing encryption until rewritten.
- The `logs` bucket always stays on SSE-S3. ALB access logs and S3 server access logs do not support SSE-KMS destination buckets, so it is intentionally excluded.
- Setting `s3_kms_encryption_enabled` back to false sets module.s3_kms_key count to zero, so Terraform schedules the managed CMK for deletion. Bucket default encryption reverts to SSE-S3, but existing objects stay SSE-KMS with that key and can become unreadable after the key is removed.

## Updates

This Terraform documentation can be automatically regenerated with:

```
terraform-docs markdown table --output-file README.md --output-mode inject .
```
